import SwiftUI

// TODO: Add necessary imports if needed, e.g., for audio management APIs

struct OutputAudioPopup: View {
    var body: some View {
        OutputAudioPopupBox()
    }
}

struct OutputAudioDeviceRow: View {
    @ObservedObject private var audioManager = OutputAudioManager.shared
    @State private var sliderVolume: Double = 0.0  // Изменено с Float на Double
    let device: OutputAudioDevice  // This struct needs to be defined in OutputAudioManager.swift
    let onSelect: () -> Void  // Changed from onConnection

    var body: some View {
        VStack {
            Button(action: onSelect) {
                VStack {
                    HStack(spacing: 10) {   
                        ZStack {
                            if(device.isActive) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                            } else {
                                EmptyView()
                            }
                        }
                        .frame(width: 20, height: 20)
                        
                        Text(device.name)
                            .font(.system(size: 13,  weight: .medium))
                        
                        Spacer()
                    }
                }}.buttonStyle(DefaultButtonStyle(pressedScaleEffect: 0.95))
            }
        }
        
    // Removed battery logic, add back if relevant for certain audio devices
}

struct OutputAudioDeviceListView: View {
    // Use @StateObject or @ObservedObject depending on how OutputAudioManager is structured
    @ObservedObject private var audioManager = OutputAudioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

    var body: some View {
        VStack(alignment: .leading) {
            
            OutputAudioDeviceListView()
                .padding(.top, 20)
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: 250)  // Adjust width if needed
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
