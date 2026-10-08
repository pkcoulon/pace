import SwiftUI

struct CappedScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content

    @State private var contentHeight: CGFloat = 0
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if contentHeight > maxHeight, !isSnapshot {
            ScrollView {
                measured
            }
            .frame(height: maxHeight)
        } else {
            measured
        }
    }

    private var measured: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
    }
}
