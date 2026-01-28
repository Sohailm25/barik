// ABOUTME: Weather popup showing current conditions and 12-hour forecast.
// ABOUTME: Displays temperature, condition text, high/low, and hourly breakdown.

import SwiftUI

struct WeatherPopup: View {
    @ObservedObject var manager: WeatherManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if manager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let weather = manager.currentWeather {
                currentWeatherSection(weather)

                if !manager.hourlyForecast.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.3))
                    hourlyForecastSection
                }
            } else if let error = manager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
        .background(Color.black)
    }

    private func currentWeatherSection(_ weather: CurrentWeather) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: weather.conditionIcon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.temperatureString)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                    Text(weather.conditionText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            if !weather.highLow.isEmpty {
                Text(weather.highLow)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Forecast")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(manager.hourlyForecast) { forecast in
                        hourlyCell(forecast)
                    }
                }
            }
        }
    }

    private func hourlyCell(_ forecast: HourlyForecast) -> some View {
        VStack(spacing: 6) {
            Text(forecast.hour)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))

            Image(systemName: forecast.conditionIcon)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Text(forecast.temperature)
                .font(.caption)
                .foregroundColor(.white)

            if forecast.precipProbability > 0 {
                Text("\(forecast.precipProbability)%")
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
        }
        .frame(width: 44)
    }
}
