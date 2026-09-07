import SwiftUI

struct ProviderCard: View {
    let kind: ProviderKind
    let state: ProviderState
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let usage = state.usage {
                if let fiveHour = usage.fiveHour {
                    UsageRow(
                        title: "5 h",
                        window: fiveHour,
                        subtitle: fiveHour.resetsAt.map { UsageFormat.countdown(to: $0, from: now) }
                    )
                }
                if let weekly = usage.weekly {
                    UsageRow(
                        title: "Semaine",
                        window: weekly,
                        subtitle: weekly.resetsAt.map(UsageFormat.resetDate)
                    )
                }
                if !usage.models.isEmpty {
                    Divider().opacity(0.5)
                    ForEach(usage.models) { model in
                        UsageRow(title: model.name, window: model.window, subtitle: nil, compact: true)
                    }
                }
                if let extra = usage.extra {
                    HStack {
                        Text(extra.label)
                        Spacer()
                        Text(extra.detail).monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else if state.error == nil {
                Text("Chargement…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = state.error {
                Label(error.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(error.isAuthFailure ? .red : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(kind.glyph)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(kind.displayName)
                .font(.headline)
            Spacer()
            if let plan = state.usage?.plan {
                Text(plan)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}

struct UsageRow: View {
    let title: String
    let window: UsageWindow?
    let subtitle: String?
    var compact = false

    private var level: UsageLevel { UsageLevel(percent: window?.utilization) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(compact ? .secondary : .primary)
                Spacer()
                Text(window.map { UsageFormat.percent($0.utilization) } ?? "—")
                    .font(compact ? Font.caption.monospacedDigit() : Font.subheadline.monospacedDigit())
                    .foregroundStyle(level.color)
            }
            ProgressBar(fraction: (window?.utilization ?? 0) / 100, color: level.color, height: compact ? 4 : 6)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
    }
}
