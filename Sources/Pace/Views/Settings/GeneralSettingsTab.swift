import AppKit
import SwiftUI

struct GeneralSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.launchAtLogin) {
                    Text("Open Pace at login")
                    if !LaunchAtLogin.isAvailable {
                        Text("Available when Pace runs from Pace.app.")
                    }
                }
                .disabled(!LaunchAtLogin.isAvailable)
                if let error = settings.launchAtLoginError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                Picker("Refresh every", selection: $settings.refreshMinutes) {
                    ForEach(SettingsStore.refreshChoices, id: \.self) { Text("\($0) min").tag($0) }
                }
                Toggle(isOn: $settings.showPacing) {
                    Text("Show pace")
                    Text("Projection at reset and time left before the limit, in the popover.")
                }
            }

            Section("Updates") {
                Toggle(isOn: $settings.checkForUpdates) {
                    Text("Check for updates")
                    Text("One request a day to api.github.com, nothing is sent.")
                }
                if let update = store.availableUpdate {
                    LabeledContent {
                        Link("Download", destination: update.url)
                    } label: {
                        Label("Pace \(update.version) is available", systemImage: "arrow.down.circle.fill")
                    }
                }
            }

            Section("Export") {
                Toggle(isOn: $settings.exportJSON) {
                    Text("Export usage as JSON")
                    Text("Rewritten on every refresh, for your scripts, Raycast or SketchyBar.")
                }
                LabeledContent {
                    Button("Reveal in Finder", action: revealExport)
                } label: {
                    Text(UsageExporter.fileURL.lastPathComponent)
                    Text((UsageExporter.fileURL.path as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .disabled(!settings.exportJSON)
            }
        }
        .settingsPane()
    }

    private func revealExport() {
        let url = UsageExporter.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }
}
