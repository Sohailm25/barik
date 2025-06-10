import SwiftUI

struct GlassGradient {
    static var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(
                colors: [
                    Color(.glassBorder),
                    Color(.glassBorder),
                    Color(.glassBorder).opacity(0.2),
                    Color(.glassBorder),
                    Color(.glassBorder),
                    Color(.glassBorder).opacity(0.2),
                    Color(.glassBorder),
                ]
            ),
            center: .center,
            angle: .degrees(30)
        )
    }
}
