import Supabase

enum SupabaseClientProvider {
    static func make(configuration: SupabaseConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }
}
