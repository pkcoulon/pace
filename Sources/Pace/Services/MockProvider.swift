import Foundation

struct MockProvider: UsageProvider {
    let id: ProviderID

    func fetchUsage() async throws -> ProviderUsage {
        try await Task.sleep(for: .milliseconds(300))
        let now = Date()
        switch id {
        case .claude:
            return ProviderUsage(
                shortWindow: UsageWindow(utilization: 42, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), windowSeconds: 5 * 3600),
                longWindow: UsageWindow(utilization: 18, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600), windowSeconds: 7 * 86400),
                models: [
                    ModelUsage(name: "Opus", window: UsageWindow(utilization: 12, resetsAt: nil)),
                    ModelUsage(name: "Sonnet", window: UsageWindow(utilization: 35, resetsAt: nil)),
                ],
                extra: ExtraUsage(label: String(localized: "Extra usage"), detail: "\(Money.format(12.5, currency: "USD")) / \(Money.format(50, currency: "USD"))", fraction: 0.25),
                plan: "Max",
                source: String(localized: "Demo"),
                fetchedAt: now
            )
        case .copilot:
            return ProviderUsage(
                longWindow: UsageWindow(utilization: 34, resetsAt: now.addingTimeInterval(12 * 86400), windowSeconds: 30 * 86400),
                extra: ExtraUsage(label: String(localized: "Overage"), detail: "0", fraction: nil),
                plan: "Pro",
                source: String(localized: "Demo"),
                fetchedAt: now
            )
        case .cursor:
            return ProviderUsage(
                longWindow: UsageWindow(utilization: 47, resetsAt: now.addingTimeInterval(9 * 86400 + 6 * 3600), windowSeconds: 30 * 86400),
                models: [
                    ModelUsage(name: "Auto", window: UsageWindow(utilization: 30, resetsAt: nil)),
                    ModelUsage(name: "API", window: UsageWindow(utilization: 17, resetsAt: nil)),
                ],
                extra: ExtraUsage(label: String(localized: "On-demand"), detail: "\(Money.format(4.2, currency: "USD")) / \(Money.format(20, currency: "USD"))", fraction: 0.21),
                plan: "Pro",
                source: String(localized: "Demo"),
                fetchedAt: now
            )
        case .zai:
            return ProviderUsage(
                shortWindow: UsageWindow(utilization: 23, resetsAt: nil, windowSeconds: 5 * 3600),
                longWindow: UsageWindow(utilization: 41, resetsAt: now.addingTimeInterval(4 * 86400 + 3 * 3600), windowSeconds: 7 * 86400),
                models: [
                    ModelUsage(name: String(localized: "MCP tools"), window: UsageWindow(utilization: 12, resetsAt: nil)),
                ],
                plan: "Pro",
                source: String(localized: "Demo"),
                fetchedAt: now
            )
        case .openRouter:
            return ProviderUsage(
                longWindow: UsageWindow(utilization: 58, resetsAt: now.addingTimeInterval(17 * 86400), windowSeconds: 31 * 86400),
                extra: ExtraUsage(label: String(localized: "Credits"), detail: Money.format(8.42, currency: "USD"), fraction: nil),
                plan: "Pay as you go",
                source: String(localized: "Demo"),
                fetchedAt: now
            )
        default:
            return ProviderUsage(
                shortWindow: UsageWindow(utilization: 61, resetsAt: now.addingTimeInterval(48 * 60), windowSeconds: 5 * 3600),
                longWindow: UsageWindow(utilization: 7, resetsAt: now.addingTimeInterval(5 * 86400), windowSeconds: 7 * 86400),
                extra: ExtraUsage(label: String(localized: "Credits"), detail: Money.format(12.5, currency: "USD"), fraction: nil),
                plan: "Plus",
                source: String(localized: "Demo"),
                fetchedAt: now
            )
        }
    }
}
