import Foundation

enum ProviderFactory {
    static func makeProviders() -> [any UsageProvider] {
        if ProcessInfo.processInfo.environment["USAGEBAR_MOCK"] == "1" {
            return [MockProvider(kind: .claude), MockProvider(kind: .codex)]
        }
        return [ClaudeUsageProvider(), CodexUsageProvider()]
    }
}
