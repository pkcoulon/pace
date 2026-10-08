import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ConnectorsSettingsTab()
                .tabItem { Label("Connectors", systemImage: "powerplug") }
            MenuBarSettingsTab()
                .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            NotificationsSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell.badge") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
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
