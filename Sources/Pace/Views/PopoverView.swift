import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: SettingsStore

    private var providers: [ProviderDescriptor] {
        settings.enabledProviders.compactMap(ProviderRegistry.descriptor(for:))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                PopoverHeader(now: context.date)
                    .padding(.leading, Theme.Spacing.xs)
                CappedScrollView(maxHeight: Theme.Size.popoverContentMaxHeight) {
                    VStack(spacing: Theme.Spacing.m) {
                        if let update = store.availableUpdate {
                            UpdateBanner(update: update)
                        }
                        if providers.isEmpty {
                            EmptyStateView()
                        }
                        ForEach(providers) { provider in
                            ProviderCard(provider: provider, now: context.date)
                        }
                    }
                }
            }
            .padding(Theme.Inset.popover)
        }
        .frame(width: Theme.Size.popoverWidth)
        .background(.ultraThinMaterial)
        .onAppear {
            Task { await store.refreshIfStale() }
        }
    }
}
