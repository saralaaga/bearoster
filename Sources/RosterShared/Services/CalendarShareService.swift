import Foundation

/// Relays the birthday feed to the Bearoster share endpoint (a Cloudflare
/// Worker backed by KV). Reads are authorized by the unguessable read token
/// in the URL; updates and deletion additionally present the write secret as
/// a bearer token. The write secret never leaves the device except inside
/// this Authorization header.
package struct CalendarShareService: Sendable {
    package static let baseURL = URL(string: "https://bearoster.com/c")!
    /// Speed bump that marks app-originated share creation at the worker; the
    /// real write protection is the per-share write secret.
    package static let appMarker = "bearoster-share-v1"

    private let session: URLSession

    package init(session: URLSession = .shared) {
        self.session = session
    }

    package enum APIError: LocalizedError {
        case http(statusCode: Int)

        package var errorDescription: String? {
            switch self {
            case .http(let statusCode): "HTTP \(statusCode)"
            }
        }
    }

    package func upload(readToken: String, writeSecret: String, ics: String) async throws {
        var request = Self.request(readToken: readToken, writeSecret: writeSecret, method: "PUT")
        request.setValue("text/calendar; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(ics.utf8)
        try await run(request)
    }

    package func delete(readToken: String, writeSecret: String) async throws {
        try await run(Self.request(readToken: readToken, writeSecret: writeSecret, method: "DELETE"))
    }

    private static func request(readToken: String, writeSecret: String, method: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(readToken))
        request.httpMethod = method
        request.setValue("Bearer \(writeSecret)", forHTTPHeaderField: "Authorization")
        if method == "PUT" {
            request.setValue(appMarker, forHTTPHeaderField: "X-Bearoster-App")
        }
        request.timeoutInterval = 30
        return request
    }

    private func run(_ request: URLRequest) async throws {
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}
