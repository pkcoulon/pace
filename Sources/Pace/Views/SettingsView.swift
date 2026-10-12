import SwiftUI

enum SettingsPane: Int, CaseIterable {
    case general
    case connectors
    case menuBar
    case notifications
    case about

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .connectors: String(localized: "Connectors")
        case .menuBar: String(localized: "Menu Bar")
        case .notifications: String(localized: "Notifications")
        case .about: String(localized: "About")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .connectors: "powerplug"
        case .menuBar: "menubar.rectangle"
        case .notifications: "bell.badge"
        case .about: "info.circle"
        }
    }

    @MainActor @ViewBuilder
    var content: some View {
        switch self {
        case .general: GeneralSettingsTab()
        case .connectors: ConnectorsSettingsTab()
        case .menuBar: MenuBarSettingsTab()
        case .notifications: NotificationsSettingsTab()
        case .about: AboutSettingsTab()
        }
    }
}

extension View {
    func settingsPane(height: CGFloat? = nil) -> some View {
        formStyle(.grouped)
            .frame(width: 500, height: height)
            .fixedSize(horizontal: false, vertical: height == nil)
    }
}
