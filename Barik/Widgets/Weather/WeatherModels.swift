// ABOUTME: Weather data models for Open-Meteo API responses.
// ABOUTME: Includes WMO weather code to SF Symbol mapping.

import Foundation

struct OpenMeteoResponse: Codable {
    let currentWeather: OpenMeteoCurrentWeather
    let hourly: OpenMeteoHourly
    let daily: OpenMeteoDaily

    enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
        case hourly, daily
    }
}

struct OpenMeteoCurrentWeather: Codable {
    let temperature: Double
    let weathercode: Int
    let windspeed: Double
}

struct OpenMeteoHourly: Codable {
    let time: [String]
    let temperature2m: [Double]
    let weathercode: [Int]
    let precipitationProbability: [Int]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case weathercode
        case precipitationProbability = "precipitation_probability"
    }
}

struct OpenMeteoDaily: Codable {
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]

    enum CodingKeys: String, CodingKey {
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
    }
}

struct CurrentWeather {
    let temperatureString: String
    let conditionIcon: String
    let conditionText: String
    let highLow: String
}

struct HourlyForecast: Identifiable {
    let id = UUID()
    let hour: String
    let temperature: String
    let conditionIcon: String
    let precipProbability: Int
}

enum WeatherCodeMapper {
    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0:
            return "sun.max.fill"
        case 1:
            return "sun.max.fill"
        case 2:
            return "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63:
            return "cloud.rain.fill"
        case 65, 66, 67:
            return "cloud.heavyrain.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.rain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95:
            return "cloud.bolt.fill"
        case 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "questionmark.circle"
        }
    }

    static func conditionText(for code: Int) -> String {
        switch code {
        case 0:
            return "Clear Sky"
        case 1:
            return "Mainly Clear"
        case 2:
            return "Partly Cloudy"
        case 3:
            return "Overcast"
        case 45:
            return "Fog"
        case 48:
            return "Depositing Rime Fog"
        case 51:
            return "Light Drizzle"
        case 53:
            return "Moderate Drizzle"
        case 55:
            return "Dense Drizzle"
        case 56, 57:
            return "Freezing Drizzle"
        case 61:
            return "Slight Rain"
        case 63:
            return "Moderate Rain"
        case 65:
            return "Heavy Rain"
        case 66, 67:
            return "Freezing Rain"
        case 71:
            return "Slight Snow"
        case 73:
            return "Moderate Snow"
        case 75:
            return "Heavy Snow"
        case 77:
            return "Snow Grains"
        case 80:
            return "Slight Rain Showers"
        case 81:
            return "Moderate Rain Showers"
        case 82:
            return "Violent Rain Showers"
        case 85:
            return "Slight Snow Showers"
        case 86:
            return "Heavy Snow Showers"
        case 95:
            return "Thunderstorm"
        case 96, 99:
            return "Thunderstorm with Hail"
        default:
            return "Unknown"
        }
    }
}
