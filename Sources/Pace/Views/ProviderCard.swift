import AppKit
import SwiftUI

struct ProviderCard: View {
    let provider: ProviderDescriptor
    let now: Date

    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var hovering = false

    private var state: ProviderState { store.states[provider.id] ?? .idle }
    private var status: ProviderStatus { store.statuses[provider.id] ?? .unknown }
    private var isStale: Bool { store.isStale(provider.id, now: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ProviderCardHeader(
                provider: provider,
                plan: state.usage?.plan,
                staleSince: isStale ? state.usage?.fetchedAt : nil,
                now: now,
                hovering: hovering
            )
            if status.level.isProblem {
                Callout(
                    icon: status.level.icon,
                    text: status.level.label + (status.detail.map { " · \($0)" } ?? ""),
                    tint: status.level.color
                )
            }
            if let error = state.error {
                Callout(icon: Self.icon(for: error), text: error.message, tint: Self.tint(for: error), markdown: error.isAuthFailure)
            }
            if let usage = state.usage {
                content(usage)
                    .compositingGroup()
                    .opacity(isStale ? Theme.Opacity.stale : 1)
            } else if state.error == nil {
                loading
            }
        }
        .padding(Theme.Inset.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackground(highlighted: hovering))
        .contentShape(Theme.card)
        .onTapGesture(perform: openUsagePage)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .modifier(LinkPointer())
        .help("Open the \(provider.displayName) usage page")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(provider.displayName)
        .accessibilityAction(named: "Open the usage page", openUsagePage)
    }

    private func content(_ usage: ProviderUsage) -> some View {
        let slots = WindowSlot.allCases.filter { usage.window($0) != nil }
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if slots.count > 1 {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    ForEach(slots, id: \.self) { slot in
                        if let window = usage.window(slot) {
                            WindowGaugeView(provider: provider.id, slot: slot, raw: window, now: now)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            } else if let slot = slots.first, let window = usage.window(slot) {
                WindowGaugeView(provider: provider.id, slot: slot, raw: window, now: now, layout: .row)
            }
            if let short = usage.shortWindow {
                UsageSparkline(provider: provider, window: short.effective(at: now), history: store.history)
            }
            if !usage.models.isEmpty || usage.extra != nil {
                if !slots.isEmpty {
                    Divider()
                }
                UsageBreakdown(models: usage.effective(at: now).models, extra: usage.extra)
            }
        }
    }

    private var loading: some View {
        HStack(spacing: Theme.Spacing.s) {
            ProgressView()
                .controlSize(.small)
            Text("Loading…")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.gauge)
    }

    private func openUsagePage() {
        NSWorkspace.shared.open(provider.usagePageURL)
    }

    private static func icon(for error: ProviderError) -> String {
        switch error {
        case .notConfigured: "key.fill"
        case .unauthorized: "lock.fill"
        case .rateLimited: "hourglass"
        case .network: "wifi.exclamationmark"
        case .decoding: "exclamationmark.triangle.fill"
        }
    }

    private static func tint(for error: ProviderError) -> Color {
        switch error {
        case .notConfigured: .secondary
        case .unauthorized: .red
        case .rateLimited, .network, .decoding: .orange
        }
    }
}
