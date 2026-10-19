// The Mac App Store build ships without com.apple.security.network.server
// (App Review rejects the entitlement), so the loopback MCP server compiles
// out entirely; direct-distribution and debug builds keep the feature.
#if !ROSTER_MAS
import Foundation
import MCP
import Network

// MARK: - Pending summary

package struct AgentAccessOperationSummary: Codable, Hashable, Sendable {
    package var displayName: String
    package var status: String
    package var errorMessage: String?

    package init(displayName: String, status: String, errorMessage: String? = nil) {
        self.displayName = displayName
        self.status = status
        self.errorMessage = errorMessage
    }
}

package struct AgentAccessPendingSummary: Codable, Hashable, Sendable {
    package var pending: [AgentAccessOperationSummary]
    package var conflicts: [AgentAccessOperationSummary]
    package var failed: [AgentAccessOperationSummary]

    package init(
        pending: [AgentAccessOperationSummary] = [],
        conflicts: [AgentAccessOperationSummary] = [],
        failed: [AgentAccessOperationSummary] = []
    ) {
        self.pending = pending
        self.conflicts = conflicts
        self.failed = failed
    }
}

// MARK: - Tool response payload

struct AgentAccessQueueResponse: Codable, Sendable {
    struct ItemResult: Codable, Sendable {
        var index: Int
        var displayName: String
    }

    struct Rejection: Codable, Sendable {
        var index: Int
        var reason: String
    }

    var schemaVersion: Int
    var accepted: [ItemResult]
    var conflicts: [ItemResult]
    var rejected: [Rejection]
}

// MARK: - Handler abstraction

/// The only surface the MCP server can act on: queue drafts (never write
/// Contacts) and read back a redacted pending summary.
package protocol AgentAccessHandling: Sendable {
    func queueDrafts(payload: Data) async -> ContactDraftIntakeOutcome
    func pendingSummary() async -> AgentAccessPendingSummary
}

// MARK: - Server

/// In-process MCP server for external agents, served over a loopback-only
/// HTTP endpoint guarded by a local bearer token. Its tools can only enqueue
/// drafts; writing to the Contacts store stays behind the user's write-back
/// confirmation in the app UI.
package final class AgentAccessServer: @unchecked Sendable {
    package static let defaultPort: UInt16 = 47110
    package static let endpointPath = "/mcp"
    package static let queueDraftsName = "queue_drafts"
    package static let listPendingName = "list_pending"

    private let handler: any AgentAccessHandling
    private let token: String
    private let transport = StatelessHTTPServerTransport()
    private let server: Server
    private let stateQueue = DispatchQueue(label: "com.bearoste.agent-access.server")
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: AgentAccessConnection] = [:]
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var actualPort: UInt16 = 0
    private static let startTimeout: TimeInterval = 10

    package init(handler: any AgentAccessHandling, token: String) {
        self.handler = handler
        self.token = token
        self.server = Server(
            name: "Bearoster",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

    }

    private func registerHandlers() async {
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [Self.queueDraftsTool, Self.listPendingTool])
        }

        await server.withMethodHandler(CallTool.self) { [handler] params in
            switch params.name {
            case Self.queueDraftsName:
                return try await Self.handleQueueDrafts(params: params, handler: handler)
            case Self.listPendingName:
                return try await Self.handleListPending(handler: handler)
            default:
                throw MCPError.methodNotFound("Unknown tool: \(params.name)")
            }
        }
    }

    package var port: UInt16 {
        stateQueue.sync { actualPort }
    }

    package var endpointDescription: String {
        "http://127.0.0.1:\(port)\(Self.endpointPath)"
    }

    package var isRunning: Bool {
        stateQueue.sync { listener?.state == .ready }
    }

    package func start(port requestedPort: UInt16) async throws {
        await registerHandlers()
        try await server.start(transport: transport)

        do {
            try await startListener(port: requestedPort)
        } catch {
            // The MCP transport is already running; without this cleanup it
            // would keep its internal tasks alive with no one to stop it.
            await transport.disconnect()
            throw error
        }
    }

    private func startListener(port requestedPort: UInt16) async throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: requestedPort) ?? .any
        )
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.stateQueue.async {
                    self.actualPort = listener.port?.rawValue ?? requestedPort
                    self.resumeStartContinuation()
                }
            case .failed(let error):
                self.stateQueue.async {
                    self.failStartContinuation(error)
                    self.teardownListener(error: .failedToListen)
                }
            case .cancelled:
                self.stateQueue.async {
                    self.failStartContinuation(AgentAccessServerError.cancelled)
                }
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        stateQueue.sync {
            self.listener = listener
        }
        listener.start(queue: stateQueue)

        // A listener stuck outside ready/failed would otherwise hang the
        // caller (the main actor) forever.
        stateQueue.asyncAfter(deadline: .now() + Self.startTimeout) { [weak self] in
            guard let self, self.startContinuation != nil else { return }
            self.failStartContinuation(AgentAccessServerError.failedToListen)
            self.teardownListener(error: .failedToListen)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stateQueue.async {
                if case .ready = listener.state {
                    continuation.resume()
                    return
                }
                if case .failed = listener.state {
                    continuation.resume(throwing: AgentAccessServerError.failedToListen)
                    return
                }
                if case .cancelled = listener.state {
                    continuation.resume(throwing: AgentAccessServerError.cancelled)
                    return
                }
                self.startContinuation = continuation
            }
        }
    }

    package func stop() {
        stateQueue.async { self.teardownListener(error: .cancelled) }
        Task { [transport] in await transport.disconnect() }
    }

    // All listener/connection state is confined to stateQueue.

    private func resumeStartContinuation() {
        startContinuation?.resume()
        startContinuation = nil
    }

    private func failStartContinuation(_ error: Error) {
        startContinuation?.resume(throwing: error)
        startContinuation = nil
    }

    private func teardownListener(error: AgentAccessServerError) {
        listener?.cancel()
        listener = nil
        actualPort = 0
        connections.values.forEach { $0.close() }
        connections.removeAll()
        failStartContinuation(error)
    }

    private func accept(_ connection: NWConnection) {
        let access = AgentAccessConnection(
            connection: connection,
            token: token,
            endpointPath: Self.endpointPath
        ) { [weak self] request in
            guard let self else { return nil }
            return await self.transport.handleRequest(request)
        }
        let connectionKey = ObjectIdentifier(connection)
        access.onClose = { [weak self] in
            guard let self else { return }
            self.stateQueue.async {
                self.connections[connectionKey] = nil
            }
        }
        connections[connectionKey] = access
        access.start()
    }

    // MARK: - Tool handlers

    private static func handleQueueDrafts(
        params: CallTool.Parameters,
        handler: any AgentAccessHandling
    ) async throws -> CallTool.Result {
        guard let arguments = params.arguments else {
            throw MCPError.invalidRequest("queue_drafts requires arguments")
        }
        let payload = try JSONEncoder().encode(Value.object(arguments))
        let outcome = await handler.queueDrafts(payload: payload)

        let response = AgentAccessQueueResponse(
            schemaVersion: ContactDraftIntakeService.schemaVersion,
            accepted: outcome.accepted.map {
                .init(index: $0.index, displayName: $0.draft.displayName)
            },
            conflicts: outcome.conflicts.map {
                .init(index: $0.index, displayName: $0.draft.displayName)
            },
            rejected: outcome.rejected.map {
                .init(index: $0.index, reason: $0.reason)
            }
        )
        let encoded = try JSONEncoder().encode(response)
        let text = String(decoding: encoded, as: UTF8.self)
        let failedEntirely = outcome.requestError != nil
            && response.accepted.isEmpty && response.conflicts.isEmpty
        return CallTool.Result(
            content: [.text(text: text, annotations: nil, _meta: nil)],
            isError: failedEntirely ? true : nil
        )
    }

    private static func handleListPending(
        handler: any AgentAccessHandling
    ) async throws -> CallTool.Result {
        let summary = await handler.pendingSummary()
        let encoded = try JSONEncoder().encode(summary)
        return CallTool.Result(
            content: [.text(text: String(decoding: encoded, as: UTF8.self), annotations: nil, _meta: nil)]
        )
    }

    // MARK: - Tool definitions

    private static var queueDraftsDescription: String {
        """
        Queue contact drafts for the user to confirm in Bearoster. This tool never \
        writes to the macOS Contacts store directly: drafts land in a local journal, \
        and the user's write-back confirmation governs when contacts are actually \
        created. Input: a JSON object with schemaVersion (integer, currently \
        \(ContactDraftIntakeService.schemaVersion)) and drafts (1...\(ContactDraftIntakeService.maxDraftCount) items, payload at most \
        \(ContactDraftIntakeService.maxPayloadBytes) bytes total). Each draft accepts displayName (required, ≤128 chars), \
        givenName, familyName, nickname, organizationName, departmentName, jobTitle, \
        phoneNumbers (≤8), emailAddresses (≤8), postalAddresses (≤4), and birthdays \
        (at most 1 entry: {date: YYYY-MM-DD or MM-DD, label?}). Unknown fields are \
        rejected per item. Drafts matching an existing contact by name plus a shared \
        phone/email are queued as conflicts for user adjudication; duplicates within \
        one batch are rejected. The response reports per-item accepted/conflict/ \
        rejected results so invalid items can be fixed and retried.
        """
    }

    private static var queueDraftsTool: Tool {
        let draftItemSchema: Value = .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "required": .array([.string("displayName")]),
            "properties": .object([
                "displayName": .object(["type": .string("string")]),
                "givenName": .object(["type": .string("string")]),
                "familyName": .object(["type": .string("string")]),
                "nickname": .object(["type": .string("string")]),
                "organizationName": .object(["type": .string("string")]),
                "departmentName": .object(["type": .string("string")]),
                "jobTitle": .object(["type": .string("string")]),
                "phoneNumbers": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")])
                ]),
                "emailAddresses": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")])
                ]),
                "postalAddresses": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")])
                ]),
                "birthdays": .object([
                    "type": .string("array"),
                    "maxItems": .int(1),
                    "items": .object([
                        "type": .string("object"),
                        "required": .array([.string("date")]),
                        "properties": .object([
                            "date": .object([
                                "type": .string("string"),
                                "description": .string("Gregorian date as YYYY-MM-DD (with year) or MM-DD (year-less)")
                            ]),
                            "label": .object(["type": .string("string")])
                        ])
                    ])
                ])
            ])
        ])

        return Tool(
            name: queueDraftsName,
            title: "Queue contact drafts",
            description: queueDraftsDescription,
            inputSchema: .object([
                "type": .string("object"),
                "required": .array([.string("schemaVersion"), .string("drafts")]),
                "properties": .object([
                    "schemaVersion": .object([
                        "type": .string("integer"),
                        "const": .int(ContactDraftIntakeService.schemaVersion)
                    ]),
                    "drafts": .object([
                        "type": .string("array"),
                        "minItems": .int(1),
                        "maxItems": .int(ContactDraftIntakeService.maxDraftCount),
                        "items": draftItemSchema
                    ])
                ])
            ]),
            annotations: .init(
                title: "Queue contact drafts",
                readOnlyHint: false,
                destructiveHint: false,
                idempotentHint: false,
                openWorldHint: false
            )
        )
    }

    private static var listPendingTool: Tool {
        Tool(
            name: listPendingName,
            title: "List pending contact operations",
            description: """
                Read-only. Returns a redacted summary of queued contact operations: \
                pending (awaiting the user's write-back), conflicts (awaiting the \
                user's choice between the macOS version and the local draft), and \
                failed entries with error messages. Contains display names only.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:])
            ]),
            annotations: .init(
                title: "List pending contact operations",
                readOnlyHint: true,
                openWorldHint: false
            )
        )
    }
}

package enum AgentAccessServerError: Error {
    case failedToListen
    case cancelled
}

// MARK: - Connection

/// One keep-it-simple HTTP/1.1 connection: a single request, then close.
/// Binds no state beyond its socket; all heavy lifting is delegated.
/// All mutable state (`buffer`, `closed`, `handledRequest`) is confined to the
/// connection's serial `queue`: receive callbacks run there, and every path
/// that responds hops back onto it before touching state.
final class AgentAccessConnection: @unchecked Sendable {
    static let maxRequestBytes = 8 * 1024 * 1024
    static let maxHeaderBytes = 64 * 1024

    private let connection: NWConnection
    private let token: String
    private let endpointPath: String
    private let requestHandler: @Sendable (HTTPRequest) async -> HTTPResponse?
    private var buffer = Data()
    private var closed = false
    private var handledRequest = false
    private let queue = DispatchQueue(label: "com.bearoste.agent-access.connection")

    var onClose: (@Sendable () -> Void)?

    init(
        connection: NWConnection,
        token: String,
        endpointPath: String,
        requestHandler: @escaping @Sendable (HTTPRequest) async -> HTTPResponse?
    ) {
        self.connection = connection
        self.token = token
        self.endpointPath = endpointPath
        self.requestHandler = requestHandler
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .failed = state {
                self.finish()
            }
            if case .cancelled = state {
                self.finish()
            }
        }
        connection.start(queue: queue)
        queue.async { self.receive() }
    }

    func close() {
        queue.async { self.finish() }
    }

    // All methods below run on `queue`.

    private func receive() {
        guard !closed, !handledRequest else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            self.handleReceived(data: data, isComplete: isComplete, error: error)
        }
    }

    private func handleReceived(data: Data?, isComplete: Bool, error: NWError?) {
        if let data, !data.isEmpty {
            buffer.append(data)
            processBufferIfComplete()
        }
        if error != nil || isComplete {
            finish()
            return
        }
        receive()
    }

    private func processBufferIfComplete() {
        guard !handledRequest else { return }
        if buffer.count > Self.maxRequestBytes {
            respondAndClose(status: "413 Content Too Large", body: jsonRPCError(message: "Request too large"))
            return
        }

        switch parseRequest(from: buffer) {
        case .needsMoreData:
            break
        case .invalid(let message, let status):
            respondAndClose(status: status, body: jsonRPCError(message: message))
        case .success(let request):
            handledRequest = true
            route(request)
        }
    }

    private func route(_ request: ParsedRequest) {
        if request.path != endpointPath {
            respondAndClose(status: "404 Not Found", body: jsonRPCError(message: "Not found"))
            return
        }
        guard request.method == "POST" else {
            respondAndClose(status: "405 Method Not Allowed", body: jsonRPCError(message: "POST only"))
            return
        }
        let authorization = request.headerValue("Authorization") ?? ""
        guard Self.tokensMatch(authorization, "Bearer \(token)") else {
            respondAndClose(status: "401 Unauthorized", body: jsonRPCError(message: "Invalid or missing bearer token"))
            return
        }

        let handler = requestHandler
        Task {
            let mcpResponse = await handler(HTTPRequest(
                method: request.method,
                headers: request.headers,
                body: request.body
            ))
            let status: String
            let body: Data
            switch mcpResponse {
            case .data(let data, _):
                status = "200 OK"
                body = data
            case .ok, .accepted:
                status = "200 OK"
                body = Data()
            case .error:
                status = "400 Bad Request"
                body = mcpResponse?.bodyData ?? Data()
            case .stream, .none:
                status = "500 Internal Server Error"
                body = jsonRPCError(message: "Streaming responses are not supported")
            }
            self.queue.async {
                self.respondAndClose(status: status, body: body)
            }
        }
    }

    private struct ParsedRequest {
        var method: String
        var path: String
        var headers: [String: String]
        var body: Data

        func headerValue(_ name: String) -> String? {
            let lowercased = name.lowercased()
            return headers.first { $0.key.lowercased() == lowercased }?.value
        }
    }

    private enum ParsedRequestResult {
        case needsMoreData
        case invalid(message: String, status: String)
        case success(ParsedRequest)
    }

    private func parseRequest(from data: Data) -> ParsedRequestResult {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else {
            // A header terminator that never arrives must not grow the buffer
            // without bound.
            if data.count > Self.maxHeaderBytes {
                return .invalid(message: "Header section too large", status: "431 Request Header Fields Too Large")
            }
            return .needsMoreData
        }
        let headerData = data.subdata(in: 0..<headerEnd.lowerBound)
        guard headerData.count <= Self.maxHeaderBytes else {
            return .invalid(message: "Header section too large", status: "431 Request Header Fields Too Large")
        }
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            return .invalid(message: "Malformed request headers", status: "400 Bad Request")
        }
        var lines = headerText.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return .invalid(message: "Malformed request", status: "400 Bad Request") }
        let requestLine = lines.removeFirst()
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return .invalid(message: "Malformed request line", status: "400 Bad Request") }

        var headers: [String: String] = [:]
        for line in lines {
            let pair = line.split(separator: ":", maxSplits: 1)
            guard pair.count == 2 else { continue }
            headers[String(pair[0]).trimmingCharacters(in: .whitespaces)] =
                String(pair[1]).trimmingCharacters(in: .whitespaces)
        }

        let lengthHeader = headers.first { $0.key.lowercased() == "content-length" }?.value
        let contentLength: Int
        if let lengthHeader {
            guard let parsed = Int(lengthHeader), parsed >= 0 else {
                return .invalid(message: "Invalid Content-Length", status: "400 Bad Request")
            }
            guard parsed <= Self.maxRequestBytes else {
                return .invalid(message: "Request body too large", status: "413 Content Too Large")
            }
            contentLength = parsed
        } else {
            contentLength = 0
        }

        let bodyStart = headerEnd.upperBound
        guard data.count - bodyStart >= contentLength else { return .needsMoreData }

        let body = data.subdata(in: bodyStart..<bodyStart + contentLength)
        // Drop any query string; only the fixed endpoint path is served.
        let path = String(parts[1].split(separator: "?", maxSplits: 1).first ?? "")
        return .success(ParsedRequest(
            method: String(parts[0]),
            path: path,
            headers: headers,
            body: body
        ))
    }

    private func respondAndClose(status: String, body: Data) {
        handledRequest = true
        var response = Data("HTTP/1.1 \(status)\r\n".utf8)
        response.append(Data("Content-Type: application/json\r\n".utf8))
        response.append(Data("Content-Length: \(body.count)\r\n".utf8))
        response.append(Data("Connection: close\r\n\r\n".utf8))
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                self.finish()
            }
        })
    }

    /// Constant-time byte comparison so token checking does not leak how far
    /// a guess matched.
    private static func tokensMatch(_ received: String, _ expected: String) -> Bool {
        let lhs = Array(received.utf8)
        let rhs = Array(expected.utf8)
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }

    private func jsonRPCError(message: String) -> Data {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": NSNull(),
            "error": ["code": -32000, "message": message]
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    private func finish() {
        guard !closed else { return }
        closed = true
        connection.cancel()
        onClose?()
    }
}


// MARK: - Model bridge

/// Forwards MCP tool calls into the main-actor app model. The queueDrafts
/// path only enqueues drafts; it never writes to the Contacts store.
package final class RosterAgentAccessBridge: AgentAccessHandling, @unchecked Sendable {
    private weak var model: RosterAppModel?

    package init(model: RosterAppModel) {
        self.model = model
    }

    package func queueDrafts(payload: Data) async -> ContactDraftIntakeOutcome {
        await model?.handleAgentDraftIntake(payload: payload)
            ?? ContactDraftIntakeOutcome(requestError: "Bearoster is shutting down")
    }

    package func pendingSummary() async -> AgentAccessPendingSummary {
        await model?.agentAccessPendingSummary ?? AgentAccessPendingSummary()
    }
}
#endif
