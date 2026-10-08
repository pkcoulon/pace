import SwiftUI

struct ProviderCardHeader: View {
    let provider: ProviderDescriptor
    let plan: String?
    let staleSince: Date?
    let now: Date
    let hovering: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ProviderMonogram(provider: provider)
            Text(provider.displayName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if let plan {
                TintedPill(text: plan, tint: provider.accent)
            }
            Spacer(minLength: Theme.Spacing.xs)
            if let staleSince {
                let age = UsageFormat.relative(staleSince, now: now)
                TintedPill(text: age, icon: "clock", tint: .orange)
                    .help("Last data received \(age)")
                    .accessibilityLabel("Data from \(age)")
            }
            Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(hovering ? 1 : 0)
                .accessibilityHidden(true)
        }
    }
}

private struct TintedPill: View {
    let text: String
    var icon: String? = nil
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .imageScale(.small)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(tint.opacity(Theme.Opacity.tint), in: Theme.pill)
    }
}
