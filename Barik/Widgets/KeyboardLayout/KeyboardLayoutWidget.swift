import SwiftUI

private let popupId = "keyboardlayout"

struct KeyboardLayoutWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject var configManager = ConfigManager.shared
    @ObservedObject private var layoutManager = KeyboardLayoutManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    @State private var widgetFrame: CGRect = .zero

    var body: some View {
        ZStack {
            // Показываем текущую раскладку или значок по умолчанию
            if let currentLayout = layoutManager.currentLayout {
                Text(currentLayout.shortDisplayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 13))
            }
        }
        .frame(height: foregroundHeight < 45 ? 20 : 25)
        .frame(width: foregroundHeight < 45 ? 23 : 26)
        .background(configManager.config.experimental.foreground.widgetsBackground.blur)
        .clipShape(RoundedRectangle(cornerRadius: 5)).overlay(
            RoundedRectangle(cornerRadius: 5).stroke(Color("NoActive"), lineWidth: 1)
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        widgetFrame = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                        widgetFrame = newFrame
                    }
            }
        )
    }
}

struct KeyboardLayoutWidget_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardLayoutWidget()
            .environmentObject(ConfigProvider(config: [:]))
    }
}
