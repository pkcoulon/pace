import Combine
import SwiftUI

struct MenuBarValue: Equatable {
    var percent: Double?
    var level: UsageLevel
    var countdown: String?
    var spoken: String

    var fraction: Double {
        min(max((percent ?? 0) / 100, 0), 1)
    }
}

struct MenuBarItem: Equatable {
    var glyph: String
    var name: String
    var primary: MenuBarValue
    var secondary: MenuBarValue?
    var dimmed: Bool
    var note: String?

    var values: [MenuBarValue] {
        [primary] + [secondary].compactMap { $0 }
    }
}

@MainActor
enum MenuBarComposer {
    static func items(store: UsageStore, settings: SettingsStore, now: Date) -> [MenuBarItem] {
        settings.enabledProviders.compactMap(ProviderRegistry.descriptor(for:)).map { provider in
            let state = store.states[provider.id] ?? .idle
            let authFailed = state.error?.isAuthFailure ?? false
            let usage = state.usage?.effective(at: now)
            let short = usage?.shortWindow
            let long = usage?.longWindow

            // Choix par provider. Quand la fenêtre demandée manque (ex. Codex sans
            // 5 h), on retombe sur l'autre plutôt que d'afficher un tiret.
            let primary: UsageWindow?
            let secondary: UsageWindow?
            switch settings.bar(for: provider.id) {
            case .short:
                primary = short ?? long
                secondary = nil
            case .long:
                primary = long ?? short
                secondary = nil
            case .both:
                primary = short ?? long
                secondary = short != nil ? long : nil
            }

            let countdown = settings.showCountdownInMenuBar && !authFailed
            let note: String? = if authFailed {
                String(localized: "not connected")
            } else if store.isStale(provider.id, now: now) {
                String(localized: "stale data")
            } else {
                nil
            }
            return MenuBarItem(
                glyph: provider.glyph,
                name: provider.displayName,
                primary: value(primary, authFailed: authFailed, countdown: countdown, now: now),
                secondary: secondary.map { value($0, authFailed: authFailed, countdown: countdown, now: now) },
                dimmed: note != nil,
                note: note
            )
        }
    }

    static func worst(in items: [MenuBarItem]) -> (item: MenuBarItem, value: MenuBarValue)? {
        items
            .flatMap { item in item.values.map { (item: item, value: $0) } }
            .max { rank($0.value) < rank($1.value) }
    }

    static func accessibilityLabel(_ items: [MenuBarItem]) -> String {
        guard !items.isEmpty else { return String(localized: "Pace, no active connector") }
        let providers = items.map { item in
            let details = item.values.map(\.spoken) + [item.note].compactMap { $0 }
            return String(localized: "\(item.name): \(details.joined(separator: ", "))")
        }
        return "Pace. " + providers.joined(separator: String(localized: "; "))
    }

    private static func value(_ window: UsageWindow?, authFailed: Bool, countdown: Bool, now: Date) -> MenuBarValue {
        guard let window else {
            return MenuBarValue(percent: nil, level: .unavailable, countdown: nil, spoken: String(localized: "no data"))
        }
        let level = authFailed ? UsageLevel.unavailable : UsageLevel(percent: window.utilization)
        let period = spokenPeriod(window)
        if countdown, window.utilization >= 100, let reset = window.resetsAt, reset > now {
            let remaining = reset.timeIntervalSince(now)
            let duration = UsageFormat.duration(remaining)
            return MenuBarValue(
                percent: window.utilization,
                level: level,
                countdown: compactDuration(remaining),
                spoken: period.isEmpty
                    ? String(localized: "limit reached, resets in \(duration)")
                    : String(localized: "limit reached \(period), resets in \(duration)")
            )
        }
        return MenuBarValue(
            percent: window.utilization,
            level: level,
            countdown: nil,
            spoken: [UsageFormat.percent(window.utilization), period].filter { !$0.isEmpty }.joined(separator: " ")
        )
    }

    private static func rank(_ value: MenuBarValue) -> (Int, Int, Double) {
        (value.percent == nil ? 0 : 1, value.level == .unavailable ? 0 : 1, value.percent ?? 0)
    }

    private static func spokenPeriod(_ window: UsageWindow) -> String {
        guard let seconds = window.windowSeconds, seconds > 0 else { return "" }
        switch Int((seconds / 3600).rounded()) {
        case 24: return String(localized: "over the day")
        case 168: return String(localized: "over the week")
        case 672...744: return String(localized: "over the month")
        default: return String(localized: "over \(window.label)")
        }
    }

    private static func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        guard minutes >= 60 else { return "\(max(minutes, 1))m" }
        let hours = minutes / 60
        guard hours >= 24 else {
            return minutes % 60 == 0 ? "\(hours)h" : "\(hours)h\(String(format: "%02d", minutes % 60))"
        }
        return String(localized: "menubar.countdown.days", defaultValue: "\(hours / 24)d")
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: SettingsStore
    @StateObject private var clock = MenuBarClock()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let items = MenuBarComposer.items(store: store, settings: settings, now: clock.now)
        Image(nsImage: MenuBarRenderer.image(
            for: items,
            style: settings.menuBarStyle,
            highlightOnlyAlerts: settings.highlightOnlyAlerts,
            dark: colorScheme == .dark
        ))
        .accessibilityLabel(MenuBarComposer.accessibilityLabel(items))
    }
}

@MainActor
private final class MenuBarClock: ObservableObject {
    @Published private(set) var now = Date()

    init() {
        Timer.publish(every: 30, tolerance: 5, on: .main, in: .common)
            .autoconnect()
            .assign(to: &$now)
    }
}
