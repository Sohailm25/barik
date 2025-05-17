import SwiftUI

struct DragButtonStyle: ButtonStyle {
    var horizontal: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        DragButtonStyleButtonContent(configuration: configuration, horizontal: horizontal)
    }
}

struct DragButtonStyleButtonContent: View {
    let configuration: ButtonStyle.Configuration
    var horizontal: Bool
    @State private var isHovered = false

    var body: some View {
        Capsule()
            .fill(.white.opacity(configuration.isPressed ? 0.8 : (isHovered ? 0.2 : 0.0)))
            .frame(width: horizontal ? 50 : 4, height: horizontal ? 4 : 50)
            .animation(.bouncy(duration: 0.3), value: isHovered)
            .padding(10)
            .frame(maxWidth: horizontal ? .infinity : nil, maxHeight: !horizontal ? .infinity : nil)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
