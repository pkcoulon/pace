import Foundation
import Combine

/// Ce qu'un provider affiche dans la barre de menu.
enum BarWindow: String, CaseIterable, Identifiable, Sendable {
    case short = "fiveHour"
    case long = "weekly"
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short: String(localized: "Short window")
        case .long: String(localized: "Long window")
        case .both: String(localized: "Both")
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Sendable {
    case text
    case rings
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: String(localized: "Text")
        case .rings: String(localized: "Rings")
        case .compact: String(localized: "Compact")
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let enabledProviders = "enabledProviders"
        static let legacyEnabled: [(String, ProviderID)] = [("claudeEnabled", .claude), ("codexEnabled", .codex)]
        static let refreshMinutes = "refreshMinutes"
        static let showPacing = "showPacing"
        static func bar(_ id: ProviderID) -> String { "bar.\(id.rawValue)" }
        static let shortWarning = "notif.5h.warning"
        static let shortCritical = "notif.5h.critical"
        static let longWarning = "notif.weekly.warning"
        static let longCritical = "notif.weekly.critical"
        static let menuBarStyle = "menuBarStyle"
        static let highlightOnlyAlerts = "highlightOnlyAlerts"
        static let showCountdownInMenuBar = "showCountdownInMenuBar"
        static let notifyOnReset = "notifyOnReset"
        static let notifyOnPace = "notifyOnPace"
        static let checkForUpdates = "checkForUpdates"
        static let exportJSON = "exportJSON"
    }

    static let refreshChoices = [1, 3, 5]

    private let defaults: UserDefaults
    private var enabledOverrides: [String: Bool]

    @Published private(set) var enabledProviders: [ProviderID]
    @Published private var bars: [ProviderID: BarWindow]
    @Published var refreshMinutes: Int {
        didSet { defaults.set(refreshMinutes, forKey: Key.refreshMinutes) }
    }
    @Published var showPacing: Bool {
        didSet { defaults.set(showPacing, forKey: Key.showPacing) }
    }
    @Published var shortWarning: Int {
        didSet { defaults.set(shortWarning, forKey: Key.shortWarning) }
    }
    @Published var shortCritical: Int {
        didSet { defaults.set(shortCritical, forKey: Key.shortCritical) }
    }
    @Published var longWarning: Int {
        didSet { defaults.set(longWarning, forKey: Key.longWarning) }
    }
    @Published var longCritical: Int {
        didSet { defaults.set(longCritical, forKey: Key.longCritical) }
    }
    @Published var menuBarStyle: MenuBarStyle {
        didSet { defaults.set(menuBarStyle.rawValue, forKey: Key.menuBarStyle) }
    }
    @Published var highlightOnlyAlerts: Bool {
        didSet { defaults.set(highlightOnlyAlerts, forKey: Key.highlightOnlyAlerts) }
    }
    @Published var showCountdownInMenuBar: Bool {
        didSet { defaults.set(showCountdownInMenuBar, forKey: Key.showCountdownInMenuBar) }
    }
    @Published var notifyOnReset: Bool {
        didSet { defaults.set(notifyOnReset, forKey: Key.notifyOnReset) }
    }
    @Published var notifyOnPace: Bool {
        didSet { defaults.set(notifyOnPace, forKey: Key.notifyOnPace) }
    }
    @Published var checkForUpdates: Bool {
        didSet { defaults.set(checkForUpdates, forKey: Key.checkForUpdates) }
    }
    @Published var exportJSON: Bool {
        didSet { defaults.set(exportJSON, forKey: Key.exportJSON) }
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
            Key.refreshMinutes: 3,
            Key.showPacing: true,
            Key.shortWarning: 80,
            Key.shortCritical: 95,
            Key.longWarning: 80,
            Key.longCritical: 95,
            Key.menuBarStyle: MenuBarStyle.text.rawValue,
            Key.highlightOnlyAlerts: true,
            Key.showCountdownInMenuBar: true,
            Key.notifyOnReset: true,
            Key.notifyOnPace: true,
            Key.checkForUpdates: false,
            Key.exportJSON: true,
        ])

        var overrides = defaults.dictionary(forKey: Key.enabledProviders) as? [String: Bool] ?? [:]
        for (legacyKey, id) in Key.legacyEnabled {
            guard let value = defaults.object(forKey: legacyKey) as? Bool else { continue }
            if overrides[id.rawValue] == nil { overrides[id.rawValue] = value }
            defaults.removeObject(forKey: legacyKey)
            defaults.set(overrides, forKey: Key.enabledProviders)
        }
        enabledOverrides = overrides
        enabledProviders = ProviderRegistry.all.filter { overrides[$0.id.rawValue] ?? $0.isDetected() }.map(\.id)
        bars = Dictionary(uniqueKeysWithValues: ProviderRegistry.all.map {
            ($0.id, BarWindow(rawValue: defaults.string(forKey: Key.bar($0.id)) ?? "") ?? .both)
        })

        refreshMinutes = defaults.integer(forKey: Key.refreshMinutes)
        showPacing = defaults.bool(forKey: Key.showPacing)
        shortWarning = defaults.integer(forKey: Key.shortWarning)
        shortCritical = defaults.integer(forKey: Key.shortCritical)
        longWarning = defaults.integer(forKey: Key.longWarning)
        longCritical = defaults.integer(forKey: Key.longCritical)
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: Key.menuBarStyle) ?? "") ?? .text
        highlightOnlyAlerts = defaults.bool(forKey: Key.highlightOnlyAlerts)
        showCountdownInMenuBar = defaults.bool(forKey: Key.showCountdownInMenuBar)
        notifyOnReset = defaults.bool(forKey: Key.notifyOnReset)
        notifyOnPace = defaults.bool(forKey: Key.notifyOnPace)
        checkForUpdates = defaults.bool(forKey: Key.checkForUpdates)
        exportJSON = defaults.bool(forKey: Key.exportJSON)
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    var refreshInterval: Duration {
        .seconds(refreshMinutes * 60)
    }

    func isEnabled(_ id: ProviderID) -> Bool {
        enabledProviders.contains(id)
    }

    func setEnabled(_ id: ProviderID, _ enabled: Bool) {
        enabledOverrides[id.rawValue] = enabled
        defaults.set(enabledOverrides, forKey: Key.enabledProviders)
        guard isEnabled(id) != enabled else { return }
        enabledProviders = ProviderRegistry.all.map(\.id).filter { $0 == id ? enabled : isEnabled($0) }
    }

    func bar(for id: ProviderID) -> BarWindow {
        bars[id] ?? .both
    }

    func setBar(_ bar: BarWindow, for id: ProviderID) {
        bars[id] = bar
        defaults.set(bar.rawValue, forKey: Key.bar(id))
    }

    func thresholds(for slot: WindowSlot) -> [Int] {
        switch slot {
        case .short: [shortWarning, shortCritical].filter { $0 > 0 }
        case .long: [longWarning, longCritical].filter { $0 > 0 }
        }
    }

    func critical(for slot: WindowSlot) -> Int {
        switch slot {
        case .short: shortCritical
        case .long: longCritical
        }
    }
}
