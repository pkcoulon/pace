import Foundation

protocol UsageProvider: Sendable {
    var kind: ProviderKind { get }
    func fetchUsage() async throws -> ProviderUsage
}
