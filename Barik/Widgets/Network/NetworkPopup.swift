import SwiftUI

/// Window displaying detailed network status information.
struct NetworkPopup: View {
    @StateObject private var viewModel = NetworkStatusViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.wifiState != .notSupported {
                HStack(spacing: 8) {
                    wifiIcon
                    VStack(alignment: .leading, spacing: 1) {
                        Text(viewModel.ssid)
                            .font(.system(size: 13,  weight: .medium))
                        Text(viewModel.wifiState.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .opacity(0.8)
                    }
                }

                if viewModel.ssid != "Not connected"
                    && viewModel.ssid != "No interface"
                {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            "Signal strength: \(viewModel.wifiSignalStrength.rawValue)"
                        )
                        Text("RSSI: \(viewModel.rssi)")
                        Text("Noise: \(viewModel.noise)")
                        Text("Channel: \(viewModel.channel)")
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(25)
    }

    /// Chooses the Wi‑Fi icon based on the stat us and connection availability.
    private var wifiIcon: some View {
        if viewModel.ssid == "Not connected" {
            return Image(systemName: "wifi.slash")
                .padding(8)
                .background(Color.red.opacity(0.8))
                .clipShape(Circle())
                .foregroundStyle(.white)
        }
        switch viewModel.wifiState {
        case .connected:
            return Image(systemName: "wifi")
                .padding(8)
                .background(Color.blue.opacity(0.8))
                .clipShape(Circle())
                .foregroundStyle(.white)
        case .connecting:
            return Image(systemName: "wifi")
                .padding(8)
                .background(Color.yellow.opacity(0.8))
                .clipShape(Circle())
                .foregroundStyle(.white)
        case .connectedWithoutInternet:
            return Image(systemName: "wifi.exclamationmark")
                .padding(8)
                .background(Color.yellow.opacity(0.8))
                .clipShape(Circle())
                .foregroundStyle(.white)
        case .disconnected:
            return Image(systemName: "wifi.slash")
                .padding(8)
                .background(Color.gray.opacity(0.8))
                .clipShape(Circle())
                .foregroundStyle(.white)
        case .disabled:
            return Image(systemName: "wifi.slash")
                .padding(8)
                .background(Color.red.opacity(0.8))
                .clipShape(Circle())
                .foregroundStyle(.white)
        case .notSupported:
            return Image(systemName: "wifi.exclamationmark")
                .padding(8)
                .background(Color.gray.opacity(0.8))
                .clipShape(Circle())
                .foregroundStyle(.white)
        }
    }
}

struct NetworkPopup_Previews: PreviewProvider {
    static var previews: some View {
        NetworkPopup()
            .previewLayout(.sizeThatFits)
    }
}
