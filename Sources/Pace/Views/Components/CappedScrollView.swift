import SwiftUI

struct CappedScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            content
        } else {
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    func onSizeChange(_ action: @escaping (CGSize) -> Void) -> some View {
        onGeometryChange(for: CGSize.self) { $0.size } action: { action($0) }
    }
}
