import SwiftUI

enum ButtonHoverStyle {
    case horizontal
    case square
}

struct DefaultButtonStyle: ButtonStyle {
    var selected: Bool
    let withPadding: Bool
    var pressedScaleEffect: CGFloat
    var hoverStyle: ButtonHoverStyle

    init(
        selected: Bool = false, withPadding: Bool = true, pressedScaleEffect: CGFloat = 0.9,
        hoverStyle: ButtonHoverStyle = .horizontal
    ) {
        self.selected = selected
        self.withPadding = withPadding
        self.pressedScaleEffect = pressedScaleEffect
        self.hoverStyle = hoverStyle
    }

    func makeBody(configuration: Configuration) -> some View {
        ButtonStyleContent(
            configuration: configuration, selected: selected, withPadding: withPadding,
            pressedScaleEffect: pressedScaleEffect, hoverStyle: hoverStyle
        )
    }
}

struct ButtonStyleContent: View {
    let configuration: ButtonStyle.Configuration
    var selected: Bool
    var withPadding: Bool
    var pressedScaleEffect: CGFloat
    var hoverStyle: ButtonHoverStyle
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isHovered || configuration.isPressed || selected
                            ? .hovered : Color.black.opacity(0.0001)
                    )
                    .if(hoverStyle == .square) {
                        $0.padding(.all, -3)
                    }
                    .if(hoverStyle == .horizontal) {
                        $0.padding(.vertical, -5)
                            .padding(.horizontal, -10)
                    }
                    .frame(minHeight: 20)
            )
            .scaleEffect(configuration.isPressed ? pressedScaleEffect : 1)
            .animation(.bouncy(duration: 0.3), value: configuration.isPressed)
            .padding(withPadding ? 5 : 0)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
