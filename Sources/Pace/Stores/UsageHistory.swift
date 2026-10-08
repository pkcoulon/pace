import Foundation
import Combine

struct UsageSample: Codable, Sendable, Equatable {
    var date: Date
    var utilization: Double
    var resetsAt: Date?
}

@MainActor
final class UsageHistory: ObservableObject {
    private typealias Series = [ProviderID: [WindowSlot: [UsageSample]]]

    private static let retention: TimeInterval = 8 * 86400
    private static let recordInterval: TimeInterval = 10 * 60
    private static let rateWindow: TimeInterval = 60 * 60
    private static let minimumRateSpan: TimeInterval = 10 * 60

    private static var fileURL: URL {
        AppSupport.directory.appendingPathComponent("history.json")
    }

    @Published private var series: Series
    private var saveTask: Task<Void, Never>?

    init() {
        let stored = (try? Data(contentsOf: Self.fileURL)).flatMap { try? JSONDecoder().decode(Series.self, from: $0) }
        series = Self.pruned(stored ?? [:], now: Date())
    }

    func record(_ usage: ProviderUsage, for id: ProviderID) {
        var updated = series
        var changed = false
        for slot in WindowSlot.allCases {
            guard let window = usage.window(slot) else { continue }
            let sample = UsageSample(date: usage.fetchedAt, utilization: window.utilization, resetsAt: window.resetsAt)
            var samples = updated[id]?[slot] ?? []
            if let last = samples.last {
                guard sample.date > last.date else { continue }
                let unchanged = last.utilization == sample.utilization && UsageWindow.sameCycle(last.resetsAt, sample.resetsAt)
                if unchanged && sample.date.timeIntervalSince(last.date) < Self.recordInterval { continue }
            }
            samples.append(sample)
            updated[id, default: [:]][slot] = samples
            changed = true
        }
        guard changed else { return }
        series = Self.pruned(updated, now: usage.fetchedAt)
        scheduleSave()
    }

    func samples(for id: ProviderID, slot: WindowSlot, matching window: UsageWindow) -> [UsageSample] {
        guard window.resetsAt != nil else { return [] }
        return (series[id]?[slot] ?? []).filter { UsageWindow.sameCycle($0.resetsAt, window.resetsAt) }
    }

    func recentRate(for id: ProviderID, slot: WindowSlot, window: UsageWindow, now: Date) -> Double? {
        let recent = samples(for: id, slot: slot, matching: window)
            .filter { now.timeIntervalSince($0.date) <= Self.rateWindow }
        guard recent.count >= 2, let first = recent.first, let last = recent.last else { return nil }
        let span = last.date.timeIntervalSince(first.date)
        guard span >= Self.minimumRateSpan else { return nil }
        return max(0, (last.utilization - first.utilization) / span)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(series) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    private static func pruned(_ series: Series, now: Date) -> Series {
        let cutoff = now.addingTimeInterval(-retention)
        return series.mapValues { $0.mapValues { $0.filter { $0.date >= cutoff } } }
    }
}
