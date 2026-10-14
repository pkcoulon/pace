import Charts
import SwiftUI

struct UsageChart: View {
    let provider: ProviderDescriptor
    let slot: WindowSlot
    let window: UsageWindow
    let now: Date
    @ObservedObject var history: UsageHistory

    @EnvironmentObject private var store: UsageStore
    @State private var hovered: UsageSample?

    var body: some View {
        if let end = window.resetsAt, let seconds = window.windowSeconds, seconds > 0 {
            let start = end.addingTimeInterval(-seconds)
            let samples = history.samples(for: provider.id, slot: slot, matching: window)
                .filter { $0.date >= start && $0.date <= now.addingTimeInterval(60) }
            let pacing = store.pacing(for: provider.id, slot: slot, now: now)
            VStack(alignment: .leading, spacing: 6) {
                header(samples: samples, pacing: pacing)
                if samples.count >= 2 {
                    UsageChartPlot(
                        samples: samples,
                        start: start,
                        end: end,
                        now: now,
                        pacing: pacing,
                        tint: provider.accent,
                        isShortWindow: slot == .short,
                        hovered: $hovered
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(window.label) window trend")
                    .accessibilityValue(accessibilityValue(samples: samples, pacing: pacing))
                } else {
                    placeholder
                }
            }
        }
    }

    private func header(samples: [UsageSample], pacing: Pacing?) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("\(window.label) cycle")
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.s)
            if let hovered {
                Text(verbatim: "\(timeLabel(hovered.date)) · \(UsageFormat.percent(hovered.utilization))")
                    .foregroundStyle(.primary)
                    .transition(.opacity)
            } else if let trend = trend(samples) {
                Label(trend.text, systemImage: trend.icon)
                    .foregroundStyle(trend.rising && pacing?.level == .tight ? Color.orange : Color.secondary)
                    .help(slot == .short ? String(localized: "Usage over the last hour") : String(localized: "Usage over the last 24 hours"))
                    .transition(.opacity)
            }
        }
        .font(.caption2.weight(.medium))
        .monospacedDigit()
        .lineLimit(1)
        .animation(Theme.hover, value: hovered)
    }

    private var placeholder: some View {
        Label("The chart fills in as Pace collects data", systemImage: "chart.xyaxis.line")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trend(_ samples: [UsageSample]) -> (text: String, icon: String, rising: Bool)? {
        guard let first = samples.first, let last = samples.last else { return nil }
        let lookback: TimeInterval = slot == .short ? 3600 : 86400
        let base = samples.last { $0.date <= last.date.addingTimeInterval(-lookback) } ?? first
        let span = last.date.timeIntervalSince(base.date)
        guard span >= 600 else { return nil }
        let rate = max(0, (last.utilization - base.utilization) / span * lookback)
        guard rate >= 0.5 else { return (String(localized: "Steady"), "arrow.right", false) }
        let value = UsageFormat.percent(rate)
        return (slot == .short ? String(localized: "+\(value)/h") : String(localized: "+\(value)/day"), "arrow.up.right", true)
    }

    private func timeLabel(_ date: Date) -> String {
        slot == .short
            ? date.formatted(.dateTime.hour().minute())
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private func accessibilityValue(samples: [UsageSample], pacing: Pacing?) -> String {
        guard let first = samples.first, let last = samples.last else { return "" }
        let range = String(localized: "From \(UsageFormat.percent(first.utilization)) to \(UsageFormat.percent(last.utilization))")
        return [range, pacing?.message].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct UsageChartPlot: View {
    let samples: [UsageSample]
    let start: Date
    let end: Date
    let now: Date
    let pacing: Pacing?
    let tint: Color
    let isShortWindow: Bool
    @Binding var hovered: UsageSample?

    @Environment(\.isPanelOpen) private var isOpen
    @Environment(\.entranceDelay) private var entranceDelay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = true

    private struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    private var projection: (points: [Point], hitsLimit: Bool)? {
        guard let last = samples.last, let pacing, last.utilization < 100 else { return nil }
        let origin = Point(date: last.date, value: last.utilization)
        if let ttl = pacing.timeToLimit, ttl > 0, now.addingTimeInterval(ttl) < end {
            return ([origin, Point(date: now.addingTimeInterval(ttl), value: 100)], true)
        }
        return ([origin, Point(date: end, value: min(pacing.projected, 100))], false)
    }

    var body: some View {
        VStack(spacing: 3) {
            chart
                .frame(height: Theme.Size.chart)
                .mask(alignment: .leading) {
                    GeometryReader { geometry in
                        Rectangle().frame(width: revealed ? geometry.size.width : 0)
                    }
                }
            HStack {
                Text(verbatim: label(start))
                Spacer()
                Text(verbatim: "↻ " + label(end))
            }
            .font(.system(size: 9, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.tertiary)
        }
        .onChange(of: isOpen, initial: true) { _, open in
            if open {
                withAnimation(.easeOut(duration: 0.9).delay(entranceDelay + 0.2)) { revealed = true }
            } else if !reduceMotion {
                revealed = false
            }
        }
    }

    private var chart: some View {
        Chart {
            RuleMark(y: .value("Usage", 100))
                .foregroundStyle(Color.red.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .annotation(position: .top, alignment: .leading, spacing: 1) {
                    Text("Limit")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.75))
                }
            RuleMark(y: .value("Usage", 50))
                .foregroundStyle(Color.secondary.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
            ForEach(samples, id: \.date) { sample in
                AreaMark(x: .value("Time", sample.date), y: .value("Usage", sample.utilization))
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.32), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("Usage", sample.utilization),
                    series: .value("Series", "usage")
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
            if let projection {
                ForEach(projection.points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Usage", point.value),
                        series: .value("Series", "projection")
                    )
                    .foregroundStyle(projection.hitsLimit ? Color.orange : Color.secondary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [2, 3]))
                }
                if projection.hitsLimit, let hit = projection.points.last {
                    PointMark(x: .value("Time", hit.date), y: .value("Usage", hit.value))
                        .foregroundStyle(Color.orange)
                        .symbolSize(30)
                }
            }
            if let last = samples.last {
                PointMark(x: .value("Time", last.date), y: .value("Usage", last.utilization))
                    .foregroundStyle(tint)
                    .symbolSize(26)
            }
            if let hovered {
                RuleMark(x: .value("Time", hovered.date))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Time", hovered.date), y: .value("Usage", hovered.utilization))
                    .foregroundStyle(tint)
                    .symbolSize(44)
            }
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: 0...118)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let plot = geometry[anchor]
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    let date: Date? = proxy.value(atX: location.x - plot.origin.x)
                                    hovered = date.flatMap { nearest(to: $0) }
                                case .ended:
                                    hovered = nil
                                }
                            }
                        if isOpen, !reduceMotion, let last = samples.last,
                           let x = proxy.position(forX: last.date),
                           let y = proxy.position(forY: last.utilization) {
                            PulseDot(color: tint)
                                .position(x: plot.origin.x + x, y: plot.origin.y + y)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    private func nearest(to date: Date) -> UsageSample? {
        samples.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func label(_ date: Date) -> String {
        isShortWindow
            ? date.formatted(.dateTime.hour().minute())
            : date.formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct PulseDot: View {
    let color: Color
    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.45))
            .frame(width: 12, height: 12)
            .scaleEffect(expanded ? 2 : 0.6)
            .opacity(expanded ? 0 : 0.9)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatCount(3, autoreverses: false)) { expanded = true }
            }
    }
}
