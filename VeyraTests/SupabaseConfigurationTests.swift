import Foundation
import Testing
@testable import Veyra

struct SupabaseConfigurationTests {
    @Test func createsConfigurationFromValidValues() throws {
        let configuration = try SupabaseConfiguration(values: [
            SupabaseConfiguration.urlKey: "https://example.supabase.co",
            SupabaseConfiguration.publishableKeyKey: "publishable-key"
        ])

        #expect(configuration.url == URL(string: "https://example.supabase.co"))
        #expect(configuration.publishableKey == "publishable-key")
    }

    @Test func rejectsMissingURL() {
        #expect(throws: SupabaseConfiguration.ConfigurationError.missingURL) {
            try SupabaseConfiguration(values: [SupabaseConfiguration.publishableKeyKey: "key"])
        }
    }

    @Test func rejectsNonHTTPSURL() {
        #expect(throws: SupabaseConfiguration.ConfigurationError.invalidURL) {
            try SupabaseConfiguration(values: [
                SupabaseConfiguration.urlKey: "http://example.supabase.co",
                SupabaseConfiguration.publishableKeyKey: "key"
            ])
        }
    }

    @Test func rejectsMissingPublishableKey() {
        #expect(throws: SupabaseConfiguration.ConfigurationError.missingPublishableKey) {
            try SupabaseConfiguration(values: [SupabaseConfiguration.urlKey: "https://example.supabase.co"])
        }
    }
}
