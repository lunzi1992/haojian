//
//  WeatherAPIClient.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//
//  使用 OpenWeatherMap API 获取天气数据
//  请在 Info.plist 中配置 your_api_key 或者通过环境变量设置
//

import Foundation

public class WeatherAPIClient: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    @Published public var isLoading = false
    @Published public var error: Error?
    
    public init(apiKey: String = "") {
        // 优先使用传入的 API Key，否则尝试从 Info.plist 获取
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            // 尝试从 Info.plist 读取
            self.apiKey = (Bundle.main.object(forInfoDictionaryKey: "WeatherAPIKey") as? String) ?? ""
        }
    }
    
    public struct WeatherResponse: Codable {
        public let main: Main
        public let wind: Wind
        public let weather: [Weather]
        public let coord: Coord
    }
    
    public struct Coord: Codable {
        public let lat: Double
        public let lon: Double
    }
    
    public struct Main: Codable {
        public let temp: Double
        public let feels_like: Double
        public let humidity: Double
    }
    
    public struct Wind: Codable {
        public let speed: Double
    }
    
    public struct Weather: Codable {
        public let description: String
    }
    
    public struct UVResponse: Codable {
        public let value: Double
    }
    
    public struct AirQualityResponse: Codable {
        public let list: [AirQualityItem]
    }
    
    public struct AirQualityItem: Codable {
        public let main: AQIMain
    }
    
    public struct AQIMain: Codable {
        public let aqi: Int
    }
    
    public func fetchWeather(
        latitude: Double,
        longitude: Double
    ) async throws -> WeatherData {
        isLoading = true
        defer { isLoading = false }
        
        // 1. 获取当前天气
        let weather = try await fetchCurrentWeather(lat: latitude, lon: longitude)
        // 2. 获取紫外线指数
        let uv = try await fetchUVIndex(lat: latitude, lon: longitude)
        // 3. 获取空气质量
        let aqi = try await fetchAirQuality(lat: latitude, lon: longitude)
        
        return WeatherData(
            temperature: weather.main.temp,
            feelsLike: weather.main.feels_like,
            uvIndex: uv,
            aqi: aqi,
            windSpeed: weather.wind.speed * 3.6, // 转换为 km/h
            condition: weather.weather.first?.description.capitalized ?? "Unknown",
            humidity: weather.main.humidity
        )
    }
    
    private func fetchCurrentWeather(lat: Double, lon: Double) async throws -> WeatherResponse {
        let urlString = "\(baseURL)/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }
    
    private func fetchUVIndex(lat: Double, lon: Double) async throws -> Double {
        let urlString = "\(baseURL)/uvi?lat=\(lat)&lon=\(lon)&appid=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(UVResponse.self, from: data)
        return result.value
    }
    
    private func fetchAirQuality(lat: Double, lon: Double) async throws -> Int {
        let urlString = "\(baseURL)/air_pollution?lat=\(lat)&lon=\(lon)&appid=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(AirQualityResponse.self, from: data)
        // OpenWeatherMap AQI: 1 = Good, 2 = Fair, 3 = Moderate, 4 = Poor, 5 = Very Poor
        // 转换为标准 AQI 0-500
        guard let first = result.list.first else {
            return 0
        }
        return convertToStandardAQI(first.main.aqi)
    }
    
    /// 将 OpenWeatherMap AQI (1-5) 转换为标准 AQI
    private func convertToStandardAQI(_ aqi: Int) -> Int {
        switch aqi {
        case 1: return 25   // Good
        case 2: return 75   // Fair
        case 3: return 125  // Moderate
        case 4: return 175  // Poor
        case 5: return 300  // Very Poor
        default: return 0
        }
    }
    
    public struct ForecastResponse: Codable {
        public let list: [ForecastItem]
    }
    
    public struct ForecastItem: Codable {
        public let dt: TimeInterval
        public let main: Main
        public let wind: Wind
        public let weather: [Weather]
        
        public var date: Date {
            return Date(timeIntervalSince1970: dt)
        }
    }
    
    public func fetchForecast(
        latitude: Double,
        longitude: Double
    ) async throws -> [ForecastItem] {
        let urlString = "\(baseURL)/forecast?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric&cnt=8"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(ForecastResponse.self, from: data)
        return result.list
    }
    
    public enum APIError: Error {
        case invalidURL
        case invalidResponse
        case missingAPIKey
    }
}

extension WeatherAPIClient.APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API URL"
        case .invalidResponse:
            return "API 返回无效响应，请检查 API Key 是否正确"
        case .missingAPIKey:
            return "缺少天气 API Key，请在项目设置中配置"
        }
    }
}
