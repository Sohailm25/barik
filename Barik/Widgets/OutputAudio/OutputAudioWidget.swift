import SwiftUI

private let popupId = "outputaudio"

struct OutputAudioWidget: View {
    let showBackground: Bool

    init(showBackground: Bool = true) {
        self.showBackground = showBackground
    }

    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject var configManager = ConfigManager.shared
    @ObservedObject private var audioManager = OutputAudioManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    @State private var widgetFrame: CGRect = .zero

    var body: some View {
        // TODO: Determine the condition for showing this widget (e.g., always, or based on some audio state)
        Button(action: {
            MenuBarPopup.show(rect: widgetFrame, id: popupId) {
                OutputAudioPopup()
            }
        }) {
            ZStack {
                // Используем иконку активного устройства или иконку по умолчанию
                Image(
                    systemName: audioManager.devices.first(where: { $0.isActive })?.iconName
                        ?? "speaker.wave.2.fill"
                )
                .font(.system(size: 13))
            }
            .if(showBackground) { view in
                view
                    .frame(height: foregroundHeight < 45 ? 20 : 25)
                    .frame(width: foregroundHeight < 45 ? 20 : 25)
                    .background(.noActive)
                    .clipShape(Capsule()).overlay(
                        Capsule().stroke(
                            GlassGradient.gradient,
                            lineWidth: 1
                        )
                    )
            }
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
        .if(showBackground) { view in
            view
                .buttonStyle(TransparentButtonStyle(withPadding: false))
        }
    }
}

struct OutputAudioWidget_Previews: PreviewProvider {
    static var previews: some View {
        OutputAudioWidget()
            .environmentObject(ConfigProvider(config: [:]))
    }
}
