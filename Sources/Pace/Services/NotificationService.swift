import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private struct Cycle: Codable, Equatable {
        var resetsAt: Date?
        var fired: Set<Int> = []
        var paceAlerted = false
        var resetScheduled = false
    }

    private static let cyclesKey = "notif.cycles"
    private static let paceAlertHorizon: TimeInterval = 3600

    private let isAvailable: Bool
    private let defaults: UserDefaults
    private var cycles: [String: Cycle]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isAvailable = !ProviderFactory.isMock && Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
        cycles = defaults.data(forKey: Self.cyclesKey)
            .flatMap { try? JSONDecoder().decode([String: Cycle].self, from: $0) } ?? [:]
    }

    func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(id: ProviderID, usage: ProviderUsage, settings: SettingsStore, shortPacing: Pacing?, now: Date = Date()) {
        guard isAvailable else { return }
        let name = ProviderRegistry.descriptor(for: id)?.displayName ?? id.rawValue
        let usage = usage.effective(at: now)
        var updated = cycles
        for slot in WindowSlot.allCases {
            guard let window = usage.window(slot) else { continue }
            let key = Self.key(id, slot)
            var cycle = updated[key].flatMap {
                $0.resetsAt == nil || window.resetsAt == nil || UsageWindow.sameCycle($0.resetsAt, window.resetsAt) ? $0 : nil
            } ?? Cycle()
            cycle.resetsAt = window.resetsAt ?? cycle.resetsAt
            cycle.fired = cycle.fired.filter { window.utilization >= Double($0) }
            let title = Self.title(name, window, reset: false)
            let critical = Double(settings.critical(for: slot))

            let crossed = settings.thresholds(for: slot).filter { window.utilization >= Double($0) }
            if let highest = crossed.max(), !cycle.fired.contains(highest) {
                cycle.fired.formUnion(crossed)
                var body = String(localized: "Usage at \(UsageFormat.percent(window.utilization)) (threshold \(UsageFormat.percent(Double(highest))))")
                if let resetsAt = window.resetsAt {
                    body += ", \(UsageFormat.countdown(to: resetsAt, from: now))"
                }
                post(identifier: key + "|threshold", title: title, body: body)
            }

            if settings.notifyOnReset, !cycle.resetScheduled, window.utilization >= critical,
               let resetsAt = window.resetsAt, resetsAt > now {
                cycle.resetScheduled = true
                post(
                    identifier: Self.resetIdentifier(key),
                    title: Self.title(name, window, reset: true),
                    body: String(localized: "Quota available again."),
                    at: resetsAt
                )
            }

            if slot == .short, settings.notifyOnPace, !cycle.paceAlerted, window.utilization < critical,
               let pacing = shortPacing, pacing.level == .tight,
               let timeToLimit = pacing.timeToLimit, timeToLimit > 0, timeToLimit <= Self.paceAlertHorizon {
                cycle.paceAlerted = true
                post(identifier: key + "|pace", title: title, body: pacing.message)
            }

            updated[key] = cycle
        }
        save(updated)
    }

    func cancelResetNotifications(for ids: [ProviderID]) {
        let keys = ids.flatMap { id in WindowSlot.allCases.map { Self.key(id, $0) } }
        guard isAvailable, !keys.isEmpty else { return }
        var updated = cycles
        for key in keys {
            updated[key]?.resetScheduled = false
        }
        save(updated)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: keys.map(Self.resetIdentifier))
    }

    private func post(identifier: String, title: String, body: String, at date: Date? = nil) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = date.map {
            UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: $0),
                repeats: false
            )
        }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private func save(_ updated: [String: Cycle]) {
        guard updated != cycles else { return }
        cycles = updated
        defaults.set(try? JSONEncoder().encode(updated), forKey: Self.cyclesKey)
    }

    private static func key(_ id: ProviderID, _ slot: WindowSlot) -> String {
        "\(id.rawValue)|\(slot.rawValue)"
    }

    private static func resetIdentifier(_ key: String) -> String {
        key + "|reset"
    }

    private static func title(_ name: String, _ window: UsageWindow, reset: Bool) -> String {
        guard window.windowSeconds != nil else {
            return reset ? String(localized: "\(name) · window reset") : String(localized: "\(name) · window")
        }
        let label = window.label.lowercased()
        return reset ? String(localized: "\(name) · \(label) window reset") : String(localized: "\(name) · \(label) window")
    }
}
