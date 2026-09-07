import AppKit
import SwiftUI

struct ProviderCard: View {
    let kind: ProviderKind
    let state: ProviderState
    let now: Date
    var showPacing: Bool = true
    var status: ProviderStatus = .unknown

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header

            if status.level.isProblem {
                Label {
                    Text("\(status.level.label)\(status.detail.map { " · \($0)" } ?? "")")
                } icon: {
                    Image(systemName: status.level.icon)
                }
                .font(.caption)
                .foregroundStyle(status.level.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(status.level.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let usage = state.usage {
                if let fiveHour = usage.fiveHour {
                    UsageRow(
                        title: "5 h",
                        window: fiveHour,
                        subtitle: fiveHour.resetsAt.map { UsageFormat.countdown(to: $0, from: now) },
                        pacing: showPacing ? PacingCalculator.evaluate(fiveHour, now: now) : nil
                    )
                }
                if let weekly = usage.weekly {
                    UsageRow(
                        title: "Semaine",
                        window: weekly,
                        subtitle: weekly.resetsAt.map(UsageFormat.resetDate),
                        pacing: showPacing ? PacingCalculator.evaluate(weekly, now: now) : nil
                    )
                }
                if !usage.models.isEmpty {
                    Divider().opacity(0.4)
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
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.09 : 0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { NSWorkspace.shared.open(kind.usagePageURL) }
        .onHover { hovering = $0 }
        .help("Ouvrir la page d'usage \(kind.displayName)")
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
            if status.level.isProblem {
                Image(systemName: status.level.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(status.level.color)
            }
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(hovering ? 1 : 0)
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
    var pacing: Pacing? = nil

    private var level: UsageLevel { UsageLevel(percent: window?.utilization) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(compact ? .caption2 : .caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                Spacer()
                Text(window.map { UsageFormat.percent($0.utilization) } ?? "—")
                    .font(compact ? Font.subheadline.weight(.semibold).monospacedDigit()
                                  : Font.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(level.color)
            }
            ProgressBar(
                fraction: (window?.utilization ?? 0) / 100,
                color: level.color,
                height: compact ? 4 : 8,
                paceMarker: pacing?.marker
            )
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let pacing {
                HStack(spacing: 4) {
                    Image(systemName: pacing.icon)
                        .font(.system(size: 10))
                    Text(pacing.message)
                }
                .font(pacing.level == .tight ? .caption.weight(.medium) : .caption2)
                .foregroundStyle(pacing.color)
            }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6
    var paceMarker: Double? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                if let marker = paceMarker {
                    // Repère « rythme » : position du temps écoulé. Si la barre le
                    // dépasse, tu consommes plus vite que le temps ne passe.
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: 2, height: height + 4)
                        .offset(x: geometry.size.width * min(max(marker, 0), 1) - 1)
                }
            }
        }
        .frame(height: height)
    }
}
