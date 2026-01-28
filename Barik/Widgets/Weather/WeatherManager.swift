// ABOUTME: Weather data manager that fetches from Open-Meteo API.
// ABOUTME: Uses CoreLocation for user position, URLSession for API calls.

import CoreLocation
import Foundation
import SwiftUI

final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private var lastFetchTime: Date?
    private var cachedLocation: CLLocation?

    private let refreshInterval: TimeInterval = 15 * 60

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }

    func refresh() {
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < refreshInterval {
            return
        }

        if let location = cachedLocation {
            fetchWeather(for: location)
        } else {
            locationManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        cachedLocation = location
        fetchWeather(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Location unavailable"
            self.isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Location access denied"
            }
        default:
            break
        }
    }

    private func fetchWeather(for location: CLLocation) {
        isLoading = true
        errorMessage = nil

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true&hourly=temperature_2m,weathercode,precipitation_probability&daily=temperature_2m_max,temperature_2m_min&timezone=auto"

        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }

                do {
                    let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                    self?.processResponse(response)
                    self?.lastFetchTime = Date()
                } catch {
                    self?.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func processResponse(_ response: OpenMeteoResponse) {
        let current = response.currentWeather
        let daily = response.daily

        let tempString = String(format: "%.0f°", current.temperature)
        let icon = WeatherCodeMapper.sfSymbol(for: current.weathercode)
        let condition = WeatherCodeMapper.conditionText(for: current.weathercode)

        var highLow = ""
        if let high = daily.temperature2mMax.first, let low = daily.temperature2mMin.first {
            highLow = "H:\(Int(high))° L:\(Int(low))°"
        }

        currentWeather = CurrentWeather(
            temperatureString: tempString,
            conditionIcon: icon,
            conditionText: condition,
            highLow: highLow
        )

        let hourly = response.hourly
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "ha"

        let now = Date()
        var forecasts: [HourlyForecast] = []

        for i in 0..<min(hourly.time.count, 24) {
            guard let date = dateFormatter.date(from: hourly.time[i]),
                  date >= now else { continue }

            let hourStr = hourFormatter.string(from: date).lowercased()
            let temp = String(format: "%.0f°", hourly.temperature2m[i])
            let icon = WeatherCodeMapper.sfSymbol(for: hourly.weathercode[i])
            let precip = hourly.precipitationProbability[i]

            forecasts.append(HourlyForecast(
                hour: hourStr,
                temperature: temp,
                conditionIcon: icon,
                precipProbability: precip
            ))

            if forecasts.count >= 12 { break }
        }

        hourlyForecast = forecasts
    }
}
