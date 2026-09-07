import Foundation

struct MockProvider: UsageProvider {
    let kind: ProviderKind

    func fetchUsage() async throws -> ProviderUsage {
        try await Task.sleep(for: .milliseconds(300))
        let now = Date()
        switch kind {
        case .claude:
            return ProviderUsage(
                fiveHour: UsageWindow(utilization: 42, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60)),
                weekly: UsageWindow(utilization: 18, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600)),
                models: [
                    ModelUsage(name: "Opus", window: UsageWindow(utilization: 12, resetsAt: nil)),
                    ModelUsage(name: "Sonnet", window: UsageWindow(utilization: 35, resetsAt: nil)),
                ],
                extra: ExtraUsage(label: "Extra usage", detail: "12,50 $ / 50 $", fraction: 0.25),
                plan: "Max",
                fetchedAt: now
            )
        case .codex:
            return ProviderUsage(
                fiveHour: UsageWindow(utilization: 61, resetsAt: now.addingTimeInterval(48 * 60)),
                weekly: UsageWindow(utilization: 7, resetsAt: now.addingTimeInterval(5 * 86400)),
                extra: ExtraUsage(label: "Crédits", detail: "12,50 $", fraction: nil),
                plan: "Plus",
                fetchedAt: now
            )
        }
    }
}
