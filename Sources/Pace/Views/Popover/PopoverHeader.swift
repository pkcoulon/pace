import AppKit
import SwiftUI

struct PopoverHeader: View {
    let now: Date

    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Pace")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                freshness
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: Theme.Spacing.xxs) {
                Button {
                    Task { await store.refresh(force: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .modifier(SpinningSymbol(isActive: store.isRefreshing))
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh (⌘R)")

                Button {
                    openSettings()
                    NSApp.activate()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
                .help("Settings (⌘,)")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit Pace", systemImage: "power")
                }
                .keyboardShortcut("q", modifiers: .command)
                .help("Quit Pace (⌘Q)")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(IconButtonStyle())
        }
    }

    @ViewBuilder
    private var freshness: some View {
        if store.isRefreshing {
            Text("Updating…")
                .foregroundStyle(.secondary)
        } else if let oldest = store.oldestFetchedAt {
            let age = now.timeIntervalSince(oldest)
            if store.hasStaleData(now: now) {
                Label("Data from \(UsageFormat.duration(age)) ago", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
            } else {
                Text(age < 60 ? "Up to date" : "Updated \(UsageFormat.relative(oldest, now: now))")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(settings.enabledProviders.isEmpty ? "No active connector" : "Waiting for data")
                .foregroundStyle(.secondary)
        }
    }
}
