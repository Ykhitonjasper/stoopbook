import Foundation

enum Legal {
    static var privacy: URL? { url(for: "PrivacyPolicyURL") }
    static var terms: URL? { url(for: "TermsOfUseURL") }

    private static func url(for key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host, !host.isEmpty else { return nil }
        if host == "example.com" || host.hasSuffix(".example.com") { return nil }
        return url
    }
}
