import Foundation

@MainActor
enum UsageExporter {
    static var fileURL: URL {
        AppSupport.directory.appendingPathComponent("usage.json")
    }

    static func write(_ store: UsageStore, providers: [ProviderID], now: Date = Date()) {
        var entries: [String: Any] = [:]
        for id in providers {
            let state = store.states[id] ?? .idle
            let usage = state.usage?.effective(at: now)
            var entry: [String: Any] = [
                "name": ProviderRegistry.descriptor(for: id)?.displayName ?? id.rawValue,
                "plan": json(usage?.plan),
                "source": json(usage?.source),
                "fetchedAt": json(usage.map { ISO8601.string(from: $0.fetchedAt) }),
                "stale": store.isStale(id, now: now),
                "error": json(state.error?.message),
            ]
            for slot in WindowSlot.allCases {
                entry[slot.rawValue] = json(usage?.window(slot).map { window in
                    [
                        "label": window.label,
                        "percent": rounded(window.utilization),
                        "resetsAt": json(window.resetsAt.map(ISO8601.string(from:))),
                        "pace": json(store.pacing(for: id, slot: slot, now: now).map(pace)),
                    ] as [String: Any]
                })
            }
            entries[id.rawValue] = entry
        }
        let root: [String: Any] = ["version": 1, "updatedAt": ISO8601.string(from: now), "providers": entries]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func pace(_ pacing: Pacing) -> [String: Any] {
        [
            "level": pacing.level.rawValue,
            "projected": rounded(pacing.projected),
            "timeToLimitSeconds": json(pacing.timeToLimit.map { Int($0.rounded()) }),
            "dailyBudget": json(pacing.dailyBudget.map(rounded)),
        ]
    }

    private static func json(_ value: Any?) -> Any {
        value ?? NSNull()
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
