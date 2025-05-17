import SwiftUI

struct BarikSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var onEditingBegan: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                Rectangle()
                    .fill(.gray.opacity(0.3))

                // Filled portion
                Rectangle()
                    .fill(isHovered || isDragging ? .white : .white.opacity(0.8))
                    .frame(width: geometry.size.width * CGFloat(normalizedValue))
                    .animation(.interactiveSpring.speed(2), value: value)
                    .animation(.interactiveSpring.speed(2), value: isDragging)
            }
            .clipShape(.capsule)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingBegan?()
                        }
                        let newValue = min(max(gesture.location.x / geometry.size.width, 0), 1)
                        let scaledValue =
                            (newValue * (range.upperBound - range.lowerBound)) + range.lowerBound
                        value = scaledValue
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
        }
        .padding(.vertical, isHovered || isDragging ? 0 : 1.5)
        .animation(.bouncy.speed(2), value: isHovered)
        .animation(.bouncy.speed(2), value: isDragging)
        .frame(height: 8.5)
        .background(.black.opacity(0.0001))
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var normalizedValue: Double {
        if range.upperBound == range.lowerBound { return 0 }
        return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

// Preview provider для тестирования компонента
struct BarikSlider_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            BarikSlider(value: .constant(0.3))
                .frame(height: 30)

            BarikSlider(value: .constant(0.7))
                .frame(height: 30)

            BarikSlider(value: .constant(1.0), range: 0...1)
                .frame(height: 30)

            BarikSlider(value: .constant(50), range: 0...100)
                .frame(height: 30)
        }
        .padding()
    }
}
