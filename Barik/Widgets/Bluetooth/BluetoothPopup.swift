import EventKit
import SwiftUI
import Shimmer

struct BluetoothPopup: View {
    var body: some View {
        BluetoothPopupBox()
    }
}

struct BluetoothDeviceRow: View {
    let device: BluetoothDevice
    let onConnection: () -> Void

    var body: some View {
        Button(action: onConnection) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            device.status == DeviceStatus.disconnected || device.status == DeviceStatus.connecting
                                ? .gray.opacity(0.3)
                                : .blue
                        )
                        .font(.system(size: 13))
                    Image(systemName: device.type.iconName)
                }
                    .frame(width: 25, height: 25)
                    .opacity(device.status == DeviceStatus.connecting ? 0.5 : 1)

                VStack(alignment: .leading) {
                Text(device.name)
                        .font(.system(size: 13, weight: .medium))
                    if device.status == DeviceStatus.connected {
                    Text("Connected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .transition(.blurReplace)
                    }
                }
                .shimmering(
                    active: device.status == DeviceStatus.connecting,
                    animation: Animation.linear(duration: 0.8).delay(0.25).repeatForever(autoreverses: false))

                Spacer()
            }
        }
        .buttonStyle(DefaultButtonStyle(pressedScaleEffect: 0.95))
        .padding(.vertical, 2)
        .transition(.blurReplace)
    }
}

struct BluetoothDeviceListView: View {
    @ObservedObject private var bluetoothManager = BluetoothManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let connectedDevices = filterDevices(connected: true), !connectedDevices.isEmpty {
                ForEach(connectedDevices) { device in
                    BluetoothDeviceRow(device: device) {
                        bluetoothManager.disconnectDevice(address: device.address)
                    }
                }
            }

            // Сохраненные устройства
            if let savedDevices = filterDevices(connected: false), !savedDevices.isEmpty {
                ForEach(savedDevices) { device in
                    BluetoothDeviceRow(device: device) {
                        bluetoothManager.connectDevice(address: device.address)
                    }
                }
            }

            // Нет устройств
            if bluetoothManager.devices.isEmpty {
                HStack {
                    Spacer()
                    Text("Устройства не найдены")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .padding()
                    Spacer()
                }
            }
        }
    }

    private func filterDevices(connected: Bool) -> [BluetoothDevice]? {
        let filteredDevices = bluetoothManager.devices.filter { device in
            if connected {
                return device.status == .connected || device.status == .connecting
            } else {
                return device.status == .disconnected
            }
        }
        return filteredDevices.isEmpty ? nil : filteredDevices
    }
}

struct BluetoothPopupBox: View {
    var body: some View {
        VStack(alignment: .leading) {
            BluetoothDeviceListView()
        }
        .padding(20)
        .frame(width: 300)
    }
}

struct BluetoothPopup_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BluetoothPopupBox()
                .previewLayout(.sizeThatFits)
                .environmentObject(ConfigProvider(config: [:]))
        }
        .preferredColorScheme(.dark)
    }
}
