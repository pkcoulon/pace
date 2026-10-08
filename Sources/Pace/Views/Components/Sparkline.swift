import Charts
import SwiftUI

struct Sparkline: View {
    let samples: [UsageSample]
    let start: Date
    let end: Date
    let tint: Color

    private var ceiling: Double {
        max(100, samples.map(\.utilization).max() ?? 0)
    }

    var body: some View {
        Chart {
            ForEach([start, end], id: \.self) { date in
                LineMark(
                    x: .value("Time", date),
                    y: .value("Usage", date == start ? 0 : 100),
                    series: .value("Series", "Pace")
                )
                .foregroundStyle(Color.secondary.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
            ForEach(samples, id: \.date) { sample in
                AreaMark(x: .value("Time", sample.date), y: .value("Usage", sample.utilization))
                    .foregroundStyle(
                        LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("Usage", sample.utilization),
                    series: .value("Series", "Usage")
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
            if let last = samples.last {
                PointMark(x: .value("Time", last.date), y: .value("Usage", last.utilization))
                    .foregroundStyle(tint)
                    .symbolSize(18)
            }
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: 0...ceiling)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: Theme.Size.sparkline)
    }
}
