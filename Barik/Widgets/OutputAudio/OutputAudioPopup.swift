import SwiftUI

// TODO: Add necessary imports if needed, e.g., for audio management APIs

struct OutputAudioPopup: View {
    var body: some View {
        OutputAudioPopupBox()
    }
}

struct OutputAudioDeviceRow: View {
    let device: OutputAudioDevice  // This struct needs to be defined in OutputAudioManager.swift
    let onSelect: () -> Void  // Changed from onConnection

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(device.isActive ? .blue : .gray.opacity(0.3))
                        .font(.system(size: 13))
                    Image(systemName: device.iconName)
                        .font(.system(size: 13))
                }
                .frame(width: 25, height: 25)

                Text(device.name)
                    .font(.system(size: 13, weight: .medium))

                Spacer()
            }
        }
        .buttonStyle(DefaultButtonStyle(pressedScaleEffect: 0.95))
        .padding(.vertical, 2)
    }

    // Removed battery logic, add back if relevant for certain audio devices
}

struct OutputAudioDeviceListView: View {
    // Use @StateObject or @ObservedObject depending on how OutputAudioManager is structured
    @ObservedObject private var audioManager = OutputAudioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !audioManager.devices.isEmpty {
                // Сортируем устройства по имени для стабильного порядка
                let sortedDevices = audioManager.devices.sorted { $0.name < $1.name }
                ForEach(sortedDevices) { device in  // Используем отсортированный список
                    OutputAudioDeviceRow(device: device) {
                        // Action to select the device
                        audioManager.selectDevice(uid: device.uid)  // Use appropriate identifier (e.g., UID)
                    }
                }
            } else {
                // No devices found
                HStack {
                    Spacer()
                    Text("Аудиоустройства не найдены")  // Changed text
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .padding()
                    Spacer()
                }
            }
        }
    }

    // Removed filterDevices, logic for filtering/sorting might be different or simpler
}

struct OutputAudioPopupBox: View {
    @ObservedObject private var audioManager = OutputAudioManager.shared
    @State private var sliderVolume: Double = 0.0  // Изменено с Float на Double

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(
                    systemName: "speaker.fill"
                )
                .foregroundColor(.gray)

                BarikSlider(value: $sliderVolume)  // Убраны лишние параметры
                    .onChange(of: sliderVolume) { _, newValue in
                        audioManager.setVolume(Float(newValue))
                    }
                
                Image(
                    systemName: "speaker.3.fill"
                )
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .onAppear {
                sliderVolume = Double(audioManager.currentVolume)  // Конвертируем Float в Double
            }
            .onChange(of: audioManager.currentVolume) { _, newValue in
                sliderVolume = Double(newValue)  // Конвертируем Float в Double
            }

            Divider()
            OutputAudioDeviceListView()
                .padding(.top, 5)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(width: 250)  // Adjust width if needed
    }
}

struct OutputAudioPopup_Previews: PreviewProvider {
    static var previews: some View {
        // TODO: Setup preview environment for OutputAudioManager if needed
        Group {
            OutputAudioPopupBox()
                .previewLayout(.sizeThatFits)
                .environmentObject(ConfigProvider(config: [:]))
            // Add a mock OutputAudioManager if necessary for preview
            // .environmentObject(OutputAudioManager.mockInstance)
        }
        .preferredColorScheme(.dark)
    }
}
