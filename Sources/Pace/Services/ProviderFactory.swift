import Foundation

enum ProviderFactory {
    static let isMock = ProcessInfo.processInfo.environment["PACE_MOCK"] == "1"

    static func makeProviders() -> [any UsageProvider] {
        ProviderRegistry.all.map { isMock ? MockProvider(id: $0.id) : $0.makeProvider() }
    }
}
