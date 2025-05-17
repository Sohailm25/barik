import SwiftUI

struct TransparentButtonStyle: ButtonStyle {
    let withPadding: Bool

    init(withPadding: Bool = false) {
        self.withPadding = withPadding
    }

    func makeBody(configuration: Configuration) -> some View {
        TransparentButtonStyleContent(withPadding: withPadding, configuration: configuration)
    }
}

struct TransparentButtonStyleContent: View {
    let withPadding: Bool
    let configuration: ButtonStyle.Configuration

    @State private var isHovered = false

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.bouncy(duration: 0.5), value: configuration.isPressed)
            .padding(withPadding ? 5 : 0)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
