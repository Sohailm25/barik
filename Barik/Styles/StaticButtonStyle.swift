import SwiftUI

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StaticStyleContent(configuration: configuration)
    }
}

struct StaticStyleContent: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isHovered || configuration.isPressed
                            ? .hovered : Color.black.opacity(0.0001)
                    )
                    .padding(.vertical, -5)
                    .padding(.horizontal, -10)
                    .frame(minHeight: 20)
            )
            .padding(5)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
