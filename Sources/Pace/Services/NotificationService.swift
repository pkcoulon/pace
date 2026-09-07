import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private let isAvailable: Bool
    private var firedThresholds: [String: Set<Int>] = [:]

    init() {
        isAvailable = Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(kind: ProviderKind, usage: ProviderUsage, fiveHourThresholds: [Int], weeklyThresholds: [Int]) {
        check(kind: kind, windowName: "5 h", window: usage.fiveHour, thresholds: fiveHourThresholds)
        check(kind: kind, windowName: "hebdo", window: usage.weekly, thresholds: weeklyThresholds)
    }

    private func check(kind: ProviderKind, windowName: String, window: UsageWindow?, thresholds: [Int]) {
        guard let window else { return }
        let prefix = "\(kind.rawValue)|\(windowName)|"
        let cycleKey = prefix + String(Int(window.resetsAt?.timeIntervalSince1970 ?? 0))
        for key in firedThresholds.keys where key.hasPrefix(prefix) && key != cycleKey {
            firedThresholds.removeValue(forKey: key)
        }

        var fired = firedThresholds[cycleKey] ?? []
        let crossed = thresholds.filter { window.utilization >= Double($0) }
        guard let highest = crossed.max(), !fired.contains(highest) else { return }
        fired.formUnion(crossed)
        firedThresholds[cycleKey] = fired

        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(kind.displayName) · fenêtre \(windowName)"
        var body = "Utilisation à \(UsageFormat.percent(window.utilization)) (seuil \(highest)\u{202F}%)"
        if let resetsAt = window.resetsAt {
            body += ", \(UsageFormat.countdown(to: resetsAt, from: Date()))"
        }
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: cycleKey + "|\(highest)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
