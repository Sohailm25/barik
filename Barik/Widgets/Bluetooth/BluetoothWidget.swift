import SwiftUI

private let popupId = "bluetooth"

struct BluetoothWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var bluetoothManager = BluetoothManager.shared

    @State private var widgetFrame: CGRect = .zero

    var body: some View {
        if bluetoothManager.isBluetoothEnabled {
            Button(action: {
                MenuBarPopup.show(rect: widgetFrame, id: popupId) {
                    BluetoothPopup()
                }
            }) {
                ZStack {
                    Image(.bluetooth)
                        .resizable()
                        .frame(width: 9, height: 14)
                        .foregroundColor(.foreground)
                }
                .padding(.horizontal, 2)
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
    }
}

struct BluetoothWidget_Previews: PreviewProvider {
    static var previews: some View {
        BluetoothWidget()
            .environmentObject(ConfigProvider(config: [:]))
    }
}
