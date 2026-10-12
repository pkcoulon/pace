import SwiftUI

struct RingGauge<Center: View>: View {
    var fraction: Double
    var tint: Color
    var projection: Double? = nil
    var glow: Color? = nil
    var size: CGFloat = Theme.Size.gauge
    var lineWidth: CGFloat = Theme.Size.gaugeStroke
    @ViewBuilder var center: Center

    private var value: Double { min(max(fraction, 0), 1) }
    private var reachesLimit: Bool { (projection ?? 0) >= 1 }
    private var projectedEnd: Double? {
        guard let projection else { return nil }
        let end = min(projection, 1)
        return end > value + 0.01 ? end : nil
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            if let glow, value > 0 {
                GlowArc(value: value, color: glow, lineWidth: lineWidth)
            }
            if let end = projectedEnd {
                Circle()
                    .trim(from: value, to: end)
                    .stroke(
                        reachesLimit ? Color.orange : Color.secondary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.01, 5.5])
                    )
                    .rotationEffect(.degrees(-90))
            }
            if value > 0 {
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            center
                .padding(lineWidth)
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
    }
}

private struct GlowArc: View {
    let value: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: 0, to: value)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .blur(radius: 6)
            .phaseAnimator([false, true]) { content, bright in
                content.opacity(bright ? 0.75 : 0.15)
            } animation: { _ in
                .easeInOut(duration: 1.3)
            }
    }
}
