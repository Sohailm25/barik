import SwiftUI

private let popupId = "network"

/// Widget for the menu, displaying Wi‑Fi icon.
struct NetworkWidget: View {
    @StateObject private var viewModel = NetworkStatusViewModel()
    @State private var rect: CGRect = .zero

    var body: some View {
        Button(action: {
            MenuBarPopup.show(rect: rect, id: popupId) { NetworkPopup() }
        }) {
            HStack(spacing: 15) {
                if viewModel.wifiState != .notSupported {
                    wifiIcon
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { rect = geometry.frame(in: .global) }
                        .onChange(of: geometry.frame(in: .global)) { _, newValue in
                            rect = newValue
                        }
                }
            )
            .contentShape(Rectangle())
            .font(.system(size: 15))
        }
    }

    private var wifiIcon: some View {
        if viewModel.ssid == "Not connected" {
            return Image(systemName: "wifi.slash")
                .foregroundColor(.red)
        }
        switch viewModel.wifiState {
        case .connected:
            return Image(systemName: "wifi")
                .foregroundColor(.foregroundOutside)
        case .connecting:
            return Image(systemName: "wifi")
                .foregroundColor(.yellow)
        case .connectedWithoutInternet:
            return Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.yellow)
        case .disconnected:
            return Image(systemName: "wifi.slash")
                .foregroundColor(.gray)
        case .disabled:
            return Image(systemName: "wifi.slash")
                .foregroundColor(.red)
        case .notSupported:
            return Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.gray)
        }
    }
}

struct NetworkWidget_Previews: PreviewProvider {
    static var previews: some View {
        NetworkWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
    }
}
