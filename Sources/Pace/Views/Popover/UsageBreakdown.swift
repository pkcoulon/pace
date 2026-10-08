import SwiftUI

struct UsageBreakdown: View {
    let models: [ModelUsage]
    let extra: ExtraUsage?

    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.s, verticalSpacing: 7) {
            ForEach(models) { model in
                let percent = model.window.utilization
                GridRow {
                    Text(model.name)
                        .foregroundStyle(.secondary)
                        .accessibilityValue(UsageFormat.percent(percent))
                    UsageBar(fraction: percent / 100, tint: tint(percent))
                        .accessibilityHidden(true)
                    Text(UsageFormat.percent(percent))
                        .foregroundStyle(tint(percent))
                        .gridColumnAlignment(.trailing)
                        .accessibilityHidden(true)
                }
            }
            if let extra {
                GridRow {
                    Text(extra.label)
                        .foregroundStyle(.secondary)
                        .accessibilityValue(extra.detail)
                    if let fraction = extra.fraction {
                        UsageBar(fraction: fraction, tint: tint(fraction * 100))
                            .accessibilityHidden(true)
                    } else {
                        Color.clear
                            .frame(height: Theme.Size.bar)
                    }
                    Text(extra.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .gridColumnAlignment(.trailing)
                        .accessibilityHidden(true)
                }
            }
        }
        .font(.caption)
        .monospacedDigit()
        .lineLimit(1)
    }

    private func tint(_ percent: Double) -> Color {
        Theme.color(for: UsageLevel(percent: percent), highlightOnlyAlerts: settings.highlightOnlyAlerts, neutral: .secondary)
    }
}
