import SwiftUI

struct TrackProgressStyle: ProgressViewStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        TrackProgressContent(
            fractionCompleted: configuration.fractionCompleted ?? 0
        )
    }
}

private struct TrackProgressContent: View {
    let fractionCompleted: Double
    @State private var isHovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                Rectangle()
                    .fill(isHovered ? .white : .white.opacity(0.8))
                    .frame(width: geometry.size.width * CGFloat(fractionCompleted))
                    .animation(.interactiveSpring.speed(2), value: fractionCompleted)
            }
            .clipShape(.capsule)
        }
        .padding(.vertical, isHovered ? 0 : 1.5)
        .animation(.bouncy.speed(2), value: isHovered)
        .frame(height: 8.5)
        .background(.black.opacity(0.0001))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Preview provider для тестирования стиля
struct TrackProgressStyle_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ProgressView(value: 0.3)
                .progressViewStyle(TrackProgressStyle())

            ProgressView(value: 0.7)
                .progressViewStyle(
                    TrackProgressStyle())
            ProgressView(value: 1)
                .progressViewStyle(
                    TrackProgressStyle())
        }
        .padding()
    }
}
