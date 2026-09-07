import Foundation
import Combine

/// Ce qu'un provider affiche dans la barre de menu.
enum BarWindow: String, CaseIterable, Identifiable, Sendable {
    case fiveHour
    case weekly
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiveHour: "5 h"
        case .weekly: "Hebdo"
        case .both: "5 h + hebdo"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let claudeEnabled = "claudeEnabled"
        static let codexEnabled = "codexEnabled"
        static let refreshMinutes = "refreshMinutes"
        static let showPacing = "showPacing"
        static func bar(_ kind: ProviderKind) -> String { "bar.\(kind.rawValue)" }
        static let fiveHourWarning = "notif.5h.warning"
        static let fiveHourCritical = "notif.5h.critical"
        static let weeklyWarning = "notif.weekly.warning"
        static let weeklyCritical = "notif.weekly.critical"
    }

    static let refreshChoices = [1, 3, 5]

    private let defaults: UserDefaults

    @Published var claudeEnabled: Bool {
        didSet { defaults.set(claudeEnabled, forKey: Key.claudeEnabled) }
    }
    @Published var codexEnabled: Bool {
        didSet { defaults.set(codexEnabled, forKey: Key.codexEnabled) }
    }
    @Published var refreshMinutes: Int {
        didSet { defaults.set(refreshMinutes, forKey: Key.refreshMinutes) }
    }
    @Published var showPacing: Bool {
        didSet { defaults.set(showPacing, forKey: Key.showPacing) }
    }
    @Published var claudeBar: BarWindow {
        didSet { defaults.set(claudeBar.rawValue, forKey: Key.bar(.claude)) }
    }
    @Published var codexBar: BarWindow {
        didSet { defaults.set(codexBar.rawValue, forKey: Key.bar(.codex)) }
    }
    @Published var fiveHourWarning: Int {
        didSet { defaults.set(fiveHourWarning, forKey: Key.fiveHourWarning) }
    }
    @Published var fiveHourCritical: Int {
        didSet { defaults.set(fiveHourCritical, forKey: Key.fiveHourCritical) }
    }
    @Published var weeklyWarning: Int {
        didSet { defaults.set(weeklyWarning, forKey: Key.weeklyWarning) }
    }
    @Published var weeklyCritical: Int {
        didSet { defaults.set(weeklyCritical, forKey: Key.weeklyCritical) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                try LaunchAtLogin.set(launchAtLogin)
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
                launchAtLogin = oldValue
            }
        }
    }
    @Published private(set) var launchAtLoginError: String?

    /// Incrémenté quand un secret change (session key) pour déclencher un refresh.
    @Published private(set) var credentialsRevision = 0
    @Published private(set) var hasClaudeSessionKey: Bool = SecretStore.get(SecretAccount.claudeSessionKey) != nil

    func setClaudeSessionKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        SecretStore.set(trimmed.isEmpty ? nil : trimmed, account: SecretAccount.claudeSessionKey)
        hasClaudeSessionKey = !trimmed.isEmpty
        credentialsRevision += 1
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.claudeEnabled: true,
            Key.codexEnabled: true,
            Key.refreshMinutes: 3,
            Key.showPacing: true,
            Key.bar(.claude): BarWindow.both.rawValue,
            Key.bar(.codex): BarWindow.both.rawValue,
            Key.fiveHourWarning: 80,
            Key.fiveHourCritical: 95,
            Key.weeklyWarning: 80,
            Key.weeklyCritical: 95,
        ])
        claudeEnabled = defaults.bool(forKey: Key.claudeEnabled)
        codexEnabled = defaults.bool(forKey: Key.codexEnabled)
        refreshMinutes = defaults.integer(forKey: Key.refreshMinutes)
        showPacing = defaults.bool(forKey: Key.showPacing)
        claudeBar = BarWindow(rawValue: defaults.string(forKey: Key.bar(.claude)) ?? "") ?? .both
        codexBar = BarWindow(rawValue: defaults.string(forKey: Key.bar(.codex)) ?? "") ?? .both
        fiveHourWarning = defaults.integer(forKey: Key.fiveHourWarning)
        fiveHourCritical = defaults.integer(forKey: Key.fiveHourCritical)
        weeklyWarning = defaults.integer(forKey: Key.weeklyWarning)
        weeklyCritical = defaults.integer(forKey: Key.weeklyCritical)
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    var refreshInterval: Duration {
        .seconds(refreshMinutes * 60)
    }

    func bar(for kind: ProviderKind) -> BarWindow {
        switch kind {
        case .claude: claudeBar
        case .codex: codexBar
        }
    }

    var fiveHourThresholds: [Int] { [fiveHourWarning, fiveHourCritical].filter { $0 > 0 } }
    var weeklyThresholds: [Int] { [weeklyWarning, weeklyCritical].filter { $0 > 0 } }

    var enabledProviders: [ProviderKind] {
        ProviderKind.allCases.filter(isEnabled)
    }

    func isEnabled(_ kind: ProviderKind) -> Bool {
        switch kind {
        case .claude: claudeEnabled
        case .codex: codexEnabled
        }
    }
}
