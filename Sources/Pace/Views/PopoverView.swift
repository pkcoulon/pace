import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: SettingsStore

    private var providers: [ProviderDescriptor] {
        settings.enabledProviders.compactMap(ProviderRegistry.descriptor(for:))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 0) {
                PopoverHeader(now: context.date)
                    .padding(.leading, Theme.Spacing.xs)
                    .padding([.horizontal, .top], Theme.Inset.popover)
                CappedScrollView(maxHeight: Theme.Size.popoverContentMaxHeight) {
                    VStack(spacing: Theme.Spacing.m) {
                        if let update = store.availableUpdate {
                            UpdateBanner(update: update)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        if providers.isEmpty {
                            EmptyStateView()
                                .transition(.opacity)
                        }
                        ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                            ProviderCard(provider: provider, now: context.date)
                                .modifier(Entrance())
                                .environment(\.entranceDelay, Double(index) * Theme.stagger)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(Theme.Inset.popover)
                    .animation(Theme.layout, value: providers.map(\.id))
                    .animation(Theme.layout, value: store.availableUpdate)
                }
            }
        }
        .frame(width: Theme.Size.popoverWidth)
    }
}
