import SwiftUI

struct EmptyStateView: View {
    @Environment(\.isPanelOpen) private var isOpen

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: isOpen)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.xs) {
                Text("No active connector")
                    .font(.headline)
                Text("Pace tracks usage for \(ProviderRegistry.all.map(\.displayName).formatted(.list(type: .and))).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Enable a connector") {
                AppShell.shared?.showSettings(.connectors)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.xl)
    }
}
