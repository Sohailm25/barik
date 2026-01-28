// ABOUTME: Weather widget displaying current temperature and condition icon.
// ABOUTME: Taps open WeatherPopup with hourly forecast details.

import SwiftUI

struct WeatherWidget: View {
    @StateObject private var manager = WeatherManager()
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            if manager.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let weather = manager.currentWeather {
                Image(systemName: weather.conditionIcon)
                    .font(.system(size: 14))
                Text(weather.temperatureString)
                    .font(.system(size: 13, weight: .medium))
            } else if manager.errorMessage != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.yellow)
            } else {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.gray)
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
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "weather") {
                WeatherPopup(manager: manager)
            }
        }
        .onAppear {
            manager.refresh()
        }
    }
}
