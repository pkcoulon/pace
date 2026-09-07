import Foundation
import Combine

enum MenuBarMode: String, CaseIterable, Identifiable, Sendable {
    case fiveHourOnly
    case fiveHourAndWeekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fiveHourOnly: "5 h seulement"
        case .fiveHourAndWeekly: "5 h + hebdo"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let claudeEnabled = "claudeEnabled"
        static let codexEnabled = "codexEnabled"
        static let menuBarMode = "menuBarMode"
        static let refreshMinutes = "refreshMinutes"
        static let warningThreshold = "warningThreshold"
        static let criticalThreshold = "criticalThreshold"
    }

    static let refreshChoices = [1, 3, 5]

    private let defaults: UserDefaults

    @Published var claudeEnabled: Bool {
        didSet { defaults.set(claudeEnabled, forKey: Key.claudeEnabled) }
    }
    @Published var codexEnabled: Bool {
        didSet { defaults.set(codexEnabled, forKey: Key.codexEnabled) }
    }
    @Published var menuBarMode: MenuBarMode {
        didSet { defaults.set(menuBarMode.rawValue, forKey: Key.menuBarMode) }
    }
    @Published var refreshMinutes: Int {
        didSet { defaults.set(refreshMinutes, forKey: Key.refreshMinutes) }
    }
    @Published var warningThreshold: Int {
        didSet { defaults.set(warningThreshold, forKey: Key.warningThreshold) }
    }
    @Published var criticalThreshold: Int {
        didSet { defaults.set(criticalThreshold, forKey: Key.criticalThreshold) }
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
            Key.menuBarMode: MenuBarMode.fiveHourAndWeekly.rawValue,
            Key.refreshMinutes: 3,
            Key.warningThreshold: 80,
            Key.criticalThreshold: 95,
        ])
        claudeEnabled = defaults.bool(forKey: Key.claudeEnabled)
        codexEnabled = defaults.bool(forKey: Key.codexEnabled)
        menuBarMode = MenuBarMode(rawValue: defaults.string(forKey: Key.menuBarMode) ?? "") ?? .fiveHourAndWeekly
        refreshMinutes = defaults.integer(forKey: Key.refreshMinutes)
        warningThreshold = defaults.integer(forKey: Key.warningThreshold)
        criticalThreshold = defaults.integer(forKey: Key.criticalThreshold)
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    var refreshInterval: Duration {
        .seconds(refreshMinutes * 60)
    }

    var notificationThresholds: [Int] {
        [warningThreshold, criticalThreshold].filter { $0 > 0 }
    }

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
