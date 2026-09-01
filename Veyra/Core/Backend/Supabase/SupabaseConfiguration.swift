import Foundation

struct SupabaseConfiguration: Equatable {
    enum ConfigurationError: Error, Equatable {
        case missingURL
        case invalidURL
        case missingPublishableKey
    }

    static let urlKey = "SupabaseURL"
    static let publishableKeyKey = "SupabasePublishableKey"

    let url: URL
    let publishableKey: String

    init(values: [String: String]) throws {
        guard let rawURL = values[Self.urlKey], !rawURL.isEmpty else {
            throw ConfigurationError.missingURL
        }
        guard let url = URL(string: rawURL), url.scheme == "https", url.host != nil else {
            throw ConfigurationError.invalidURL
        }
        guard let key = values[Self.publishableKeyKey], !key.isEmpty else {
            throw ConfigurationError.missingPublishableKey
        }
        self.url = url
        publishableKey = key
    }

    static func from(bundle: Bundle = .main) throws -> SupabaseConfiguration {
        try SupabaseConfiguration(values: [
            urlKey: bundle.object(forInfoDictionaryKey: urlKey) as? String ?? "",
            publishableKeyKey: bundle.object(forInfoDictionaryKey: publishableKeyKey) as? String ?? ""
        ])
    }
}
