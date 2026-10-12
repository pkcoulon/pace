import AppKit
import SwiftUI

struct PopoverHeader: View {
    let now: Date

    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Pace")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                HStack(spacing: 5) {
                    LiveDot(color: dotColor, isActive: store.isRefreshing)
                    freshness
                        .contentTransition(.opacity)
                }
                .font(.subheadline)
                .lineLimit(1)
                .animation(Theme.smooth, value: store.isRefreshing)
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
                    AppShell.shared?.showSettings()
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

    private var dotColor: Color {
        if store.oldestFetchedAt == nil { return .secondary }
        return store.hasStaleData(now: now) ? .orange : .green
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

private struct LiveDot: View {
    let color: Color
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .background {
                if isActive {
                    Circle()
                        .fill(color.opacity(0.5))
                        .phaseAnimator([false, true]) { content, expanded in
                            content
                                .scaleEffect(expanded ? 2.6 : 1)
                                .opacity(expanded ? 0 : 0.8)
                        } animation: { expanded in
                            expanded ? .easeOut(duration: 1) : nil
                        }
                }
            }
            .accessibilityHidden(true)
    }
}
