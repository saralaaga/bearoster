import Foundation

enum ContactQuickAction: Sendable {
    case message
    case call
    case video
    case email
}

enum ContactActionURLFactory {
    static func url(
        for action: ContactQuickAction,
        phoneNumbers: [String],
        emailAddresses: [String]
    ) -> URL? {
        switch action {
        case .message:
            return firstPhoneURL(scheme: "sms", phoneNumbers: phoneNumbers)
                ?? firstEmailURL(scheme: "sms", emailAddresses: emailAddresses)
        case .call:
            return firstPhoneURL(scheme: "tel", phoneNumbers: phoneNumbers)
        case .video:
            return firstPhoneURL(scheme: "facetime", phoneNumbers: phoneNumbers)
                ?? firstEmailURL(scheme: "facetime", emailAddresses: emailAddresses)
        case .email:
            return firstEmailURL(scheme: "mailto", emailAddresses: emailAddresses)
        }
    }

    private static func firstPhoneURL(scheme: String, phoneNumbers: [String]) -> URL? {
        phoneNumbers.lazy
            .map(normalizedPhone(_:))
            .first { !$0.isEmpty }
            .flatMap { URL(string: "\(scheme):\($0)") }
    }

    private static func firstEmailURL(scheme: String, emailAddresses: [String]) -> URL? {
        emailAddresses.lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            .flatMap { URL(string: "\(scheme):\($0)") }
    }

    private static func normalizedPhone(_ value: String) -> String {
        value.filter { $0.isNumber || $0 == "+" }
    }
}
