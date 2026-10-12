import SwiftUI

extension EnvironmentValues {
    @Entry var isSnapshot = false
    @Entry var isPanelOpen = true
    @Entry var entranceDelay: Double = 0
}

struct Entrance: ViewModifier {
    var delay: Double = 0
    var offset: CGFloat = 10

    @Environment(\.isPanelOpen) private var isOpen
    @Environment(\.entranceDelay) private var baseDelay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hidden = false

    func body(content: Content) -> some View {
        content
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden ? offset : 0)
            .onChange(of: isOpen, initial: true) { _, open in
                if open {
                    withAnimation(Theme.entrance.delay(baseDelay + delay)) { hidden = false }
                } else if !reduceMotion {
                    hidden = true
                }
            }
    }
}

struct CardBackground: ViewModifier {
    var highlighted = false

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Theme.card.fill(fill))
            .overlay(Theme.card.strokeBorder(stroke, lineWidth: 1))
    }

    private var fill: Color {
        colorScheme == .dark
            ? .white.opacity(highlighted ? 0.1 : 0.06)
            : .white.opacity(highlighted ? 0.75 : 0.55)
    }

    private var stroke: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.07)
    }
}

struct LinkPointer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(.link)
        } else {
            content
        }
    }
}

struct SpinningSymbol: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.symbolEffect(.rotate, options: .repeat(.continuous), isActive: isActive)
        } else {
            content
                .rotationEffect(.degrees(isActive ? 360 : 0))
                .animation(isActive ? .linear(duration: 1).repeatForever(autoreverses: false) : nil, value: isActive)
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration)
    }
}

private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration

    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(hovering ? HierarchicalShapeStyle.primary : .secondary)
            .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
            .background(Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.14 : hovering ? 0.08 : 0)))
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .animation(Theme.hover, value: hovering)
    }
}
