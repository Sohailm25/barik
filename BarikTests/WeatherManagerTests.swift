// ABOUTME: Tests for weather code mapping and Open-Meteo API response parsing.
// ABOUTME: TDD tests for WeatherManager (WMO codes, JSON parsing, display models).

import XCTest
@testable import Barik

final class WeatherManagerTests: XCTestCase {

    func testWMOCodeClearSkyMapsToSunMax() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 0), "sun.max.fill")
    }

    func testWMOCodeMainlyClearMapsToSunMax() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 1), "sun.max.fill")
    }

    func testWMOCodePartlyCloudyMapsToCloudSun() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 2), "cloud.sun.fill")
    }

    func testWMOCodeOvercastMapsToCloud() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 3), "cloud.fill")
    }

    func testWMOCodeFogMapsToCloudFog() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 45), "cloud.fog.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 48), "cloud.fog.fill")
    }

    func testWMOCodeDrizzleMapsToCloudDrizzle() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 51), "cloud.drizzle.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 53), "cloud.drizzle.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 55), "cloud.drizzle.fill")
    }

    func testWMOCodeRainMapsToCloudRain() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 61), "cloud.rain.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 63), "cloud.rain.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 65), "cloud.heavyrain.fill")
    }

    func testWMOCodeSnowMapsToCloudSnow() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 71), "cloud.snow.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 73), "cloud.snow.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 75), "cloud.snow.fill")
    }

    func testWMOCodeThunderstormMapsToCloudBolt() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 95), "cloud.bolt.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 96), "cloud.bolt.rain.fill")
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 99), "cloud.bolt.rain.fill")
    }

    func testWMOCodeUnknownMapsToQuestionmark() {
        XCTAssertEqual(WeatherCodeMapper.sfSymbol(for: 999), "questionmark.circle")
    }

    func testWMOCodeConditionTextForClearSky() {
        XCTAssertEqual(WeatherCodeMapper.conditionText(for: 0), "Clear Sky")
    }

    func testWMOCodeConditionTextForPartlyCloudy() {
        XCTAssertEqual(WeatherCodeMapper.conditionText(for: 2), "Partly Cloudy")
    }

    func testWMOCodeConditionTextForRain() {
        XCTAssertEqual(WeatherCodeMapper.conditionText(for: 63), "Moderate Rain")
    }

    func testOpenMeteoResponseParsesCurrentWeather() throws {
        let json = """
        {
            "current_weather": {
                "temperature": 22.5,
                "weathercode": 2,
                "windspeed": 12.3
            },
            "hourly": {
                "time": ["2026-01-28T10:00", "2026-01-28T11:00"],
                "temperature_2m": [21.0, 23.0],
                "weathercode": [1, 2],
                "precipitation_probability": [10, 20]
            },
            "daily": {
                "temperature_2m_max": [25.0],
                "temperature_2m_min": [15.0]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(OpenMeteoResponse.self, from: data)

        XCTAssertEqual(response.currentWeather.temperature, 22.5)
        XCTAssertEqual(response.currentWeather.weathercode, 2)
        XCTAssertEqual(response.currentWeather.windspeed, 12.3)
    }

    func testOpenMeteoResponseParsesHourlyData() throws {
        let json = """
        {
            "current_weather": {
                "temperature": 22.5,
                "weathercode": 2,
                "windspeed": 12.3
            },
            "hourly": {
                "time": ["2026-01-28T10:00", "2026-01-28T11:00", "2026-01-28T12:00"],
                "temperature_2m": [21.0, 23.0, 24.0],
                "weathercode": [1, 2, 3],
                "precipitation_probability": [10, 20, 30]
            },
            "daily": {
                "temperature_2m_max": [25.0],
                "temperature_2m_min": [15.0]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(OpenMeteoResponse.self, from: data)

        XCTAssertEqual(response.hourly.time.count, 3)
        XCTAssertEqual(response.hourly.temperature2m.count, 3)
        XCTAssertEqual(response.hourly.precipitationProbability[2], 30)
    }

    func testOpenMeteoResponseParsesDailyHighLow() throws {
        let json = """
        {
            "current_weather": {
                "temperature": 22.5,
                "weathercode": 2,
                "windspeed": 12.3
            },
            "hourly": {
                "time": [],
                "temperature_2m": [],
                "weathercode": [],
                "precipitation_probability": []
            },
            "daily": {
                "temperature_2m_max": [28.5],
                "temperature_2m_min": [18.2]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(OpenMeteoResponse.self, from: data)

        XCTAssertEqual(response.daily.temperature2mMax[0], 28.5)
        XCTAssertEqual(response.daily.temperature2mMin[0], 18.2)
    }
}
