import AppKit
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 10) {
                toolbar(now: context.date)

                if settings.enabledProviders.isEmpty {
                    Text("Aucun provider activé")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                ForEach(settings.enabledProviders) { kind in
                    ProviderCard(
                        kind: kind,
                        state: store.states[kind] ?? .idle,
                        now: context.date,
                        showPacing: settings.showPacing,
                        status: store.statuses[kind] ?? .unknown
                    )
                }
            }
            .padding(12)
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    private func toolbar(now: Date) -> some View {
        HStack(spacing: 8) {
            Group {
                if store.isRefreshing {
                    Text("Mise à jour…")
                } else if let lastRefresh = store.lastRefresh {
                    Text("Mis à jour \(UsageFormat.relative(lastRefresh, now: now))")
                } else {
                    Text("Pas encore de données")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task { await store.refresh(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Rafraîchir")
            .disabled(store.isRefreshing)

            Button {
                openSettings()
                NSApp.activate()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Réglages")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quitter")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 2)
    }
}
