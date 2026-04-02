//
//  WeatherAPIClient.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//
//  V3: 使用和风天气 API (QWeather) 获取精准天气数据
//  请在 Info.plist 中配置 QWeatherAPIKey 或者通过环境变量设置
//

import Foundation

public class WeatherAPIClient: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://qv3qqrnxxu.re.qweatherapi.com/v7"
    private let urlSession: URLSession
    
    @Published public var isLoading = false
    @Published public var error: Error?
    
    public init(apiKey: String = "") {
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            self.apiKey = (Bundle.main.object(forInfoDictionaryKey: "QWeatherAPIKey") as? String) ?? ""
        }
        
        // 开发调试用：允许代理和自签名证书
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config, delegate: InsecureURLSessionDelegate(), delegateQueue: nil)
    }
    
    // MARK: - V4: 和风天气 Web API v7 数据模型
    
    /// v7 实时天气响应
    public struct QWeatherNowResponseV7: Codable {
        public let code: String
        public let now: QWeatherNowV7
        public let location: QWeatherLocationV7?
    }
    
    public struct QWeatherNowV7: Codable {
        public let temp: String      // 温度
        public let feelsLike: String // 体感温度
        public let humidity: String  // 湿度
        public let windSpeed: String // 风速 km/h
        public let text: String      // 天气状况描述
        public let icon: String      // 天气图标代码
    }
    
    public struct QWeatherLocationV7: Codable {
        public let name: String    // 城市名称
    }
    
    /// v7 空气质量响应
    public struct QWeatherAirResponseV7: Codable {
        public let code: String
        public let now: QWeatherAirNowV7?
    }
    
    public struct QWeatherAirNowV7: Codable {
        public let aqi: String     // AQI 指数
        public let category: String // 空气质量等级
    }
    
    /// v7 紫外线响应（通过天气指数 API）
    public struct QWeatherIndicesResponseV7: Codable {
        public let code: String
        public let daily: [QWeatherIndexV7]?
    }
    
    public struct QWeatherIndexV7: Codable {
        public let type: String    // 指数类型
        public let category: String // 等级描述
        public let level: String?   // 等级数字
    }
    
    // 保留旧模型用于兼容性
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
        
        // V4: 使用和风天气 Web API v7 - 先通过 GeoAPI 获取 Location ID
        let locationId = try await fetchLocationId(latitude: latitude, longitude: longitude)
        
        // 1. 获取当前天气
        let nowData = try await fetchQWeatherNowV7(locationId: locationId)
        // 2. 获取空气质量
        let aqi = try await fetchQWeatherAirV7(locationId: locationId)
        // 3. 获取紫外线指数（通过天气指数 API，type=5）
        let uv = try await fetchQWeatherUVV7(locationId: locationId)
        
        return WeatherData(
            temperature: Double(nowData.temp) ?? 0,
            feelsLike: Double(nowData.feelsLike) ?? 0,
            uvIndex: uv,
            aqi: aqi,
            windSpeed: Double(nowData.windSpeed) ?? 0,
            condition: nowData.text,
            humidity: Double(nowData.humidity) ?? 0
        )
    }
    
    // MARK: - GeoAPI: 获取城市 ID
    
    public struct GeoLookupResponse: Codable {
        public let code: String
        public let location: [GeoLocation]?
    }
    
    public struct GeoLocation: Codable {
        public let id: String      // Location ID，如 "101220101"
        public let name: String    // 城市名称
        public let lat: String     // 纬度
        public let lon: String     // 经度
    }
    
    private func fetchLocationId(latitude: Double, longitude: Double) async throws -> String {
        let geoURL = "https://qv3qqrnxxu.re.qweatherapi.com/geo/v2/city/lookup?location=\(longitude.rounded(toPlaces: 6)),\(latitude.rounded(toPlaces: 6))&key=\(apiKey)"
        print("[WeatherAPI] Geo URL: \(geoURL)")
        
        guard let url = URL(string: geoURL) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 调试输出
        let responseString = String(data: data, encoding: .utf8) ?? "无法解码"
        print("[WeatherAPI] Geo HTTP Status: \(httpResponse.statusCode)")
        print("[WeatherAPI] Geo Response: \(responseString)")
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(GeoLookupResponse.self, from: data)
        guard result.code == "200", let firstLocation = result.location?.first else {
            print("[WeatherAPI] Geo API Error Code: \(result.code)")
            throw APIError.apiError(code: result.code)
        }
        
        print("[WeatherAPI] Got Location ID: \(firstLocation.id), Name: \(firstLocation.name)")
        return firstLocation.id
    }
    
    // MARK: - V4: 和风天气 Web API v7 方法
    
    private func fetchQWeatherNowV7(locationId: String) async throws -> QWeatherNowV7 {
        let urlString = "\(baseURL)/weather/now?location=\(locationId)&key=\(apiKey)"
        print("[WeatherAPI] Weather URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 调试输出
        let responseString = String(data: data, encoding: .utf8) ?? "无法解码"
        print("[WeatherAPI] HTTP Status: \(httpResponse.statusCode)")
        print("[WeatherAPI] Response: \(responseString)")
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(QWeatherNowResponseV7.self, from: data)
        guard result.code == "200" else {
            print("[WeatherAPI] API Error Code: \(result.code)")
            throw APIError.apiError(code: result.code)
        }
        return result.now
    }
    
    private func fetchQWeatherAirV7(locationId: String) async throws -> Int {
        let urlString = "\(baseURL)/air/now?location=\(locationId)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(QWeatherAirResponseV7.self, from: data)
        guard result.code == "200", let airNow = result.now else {
            return 0
        }
        return Int(airNow.aqi) ?? 0
    }
    
    private func fetchQWeatherUVV7(locationId: String) async throws -> Double {
        // v7: 使用天气指数 API，type=5 表示紫外线指数
        let urlString = "\(baseURL)/indices/1d?location=\(locationId)&type=5&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(QWeatherIndicesResponseV7.self, from: data)
        guard result.code == "200", let daily = result.daily?.first else {
            return 0
        }
        // level 字段包含紫外线等级数字
        return Double(daily.level ?? "0") ?? 0
    }
    
    // MARK: - V4: 和风天气预报 (Web API v7)
    
    public func fetchForecast(latitude: Double, longitude: Double) async throws -> [QWeatherHourlyV7] {
        // 先获取城市 ID
        let locationId = try await fetchLocationId(latitude: latitude, longitude: longitude)
        
        // v7: 24小时预报 API
        let urlString = "\(baseURL)/weather/24h?location=\(locationId)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(QWeatherHourlyResponseV7.self, from: data)
        guard result.code == "200" else {
            return []
        }
        return result.hourly ?? []
    }
    
    public struct QWeatherHourlyResponseV7: Codable {
        public let code: String
        public let hourly: [QWeatherHourlyV7]?
    }
    
    public struct QWeatherHourlyV7: Codable {
        public let fxTime: String     // 时间 "2023-10-01T14:00+08:00"
        public let temp: String       // 温度
        public let text: String       // 天气描述
        public let icon: String       // 天气图标代码
        public let windSpeed: String  // 风速 km/h
        public let humidity: String   // 湿度
        
        public var date: Date? {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: fxTime)
        }
        
        public var temperature: Double {
            return Double(temp) ?? 0
        }
        
        public var humidityValue: Double {
            return Double(humidity) ?? 0
        }
        
        public var windSpeedValue: Double {
            return Double(windSpeed) ?? 0
        }
    }
    
    // MARK: - API 错误
    
    public enum APIError: Error {
        case invalidURL
        case invalidResponse
        case missingAPIKey
        case httpError(statusCode: Int)
        case apiError(code: String)
    }
}

extension WeatherAPIClient.APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API URL"
        case .invalidResponse:
            return "API 返回无效响应"
        case .missingAPIKey:
            return "缺少天气 API Key，请在项目设置中配置"
        case .httpError(let statusCode):
            return "HTTP 错误: \(statusCode)"
        case .apiError(let code):
            return "API 错误码: \(code) - 请检查 API Key 是否正确或是否有权限访问该接口"
        }
    }
}

// MARK: - 开发调试用：允许自签名证书和代理 MITM

class InsecureURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 完全禁用证书验证，允许代理 MITM
        completionHandler(.useCredential, URLCredential(user: "", password: "", persistence: .none))
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 任务级别的验证也禁用
        completionHandler(.useCredential, URLCredential(user: "", password: "", persistence: .none))
    }
}

// MARK: - Double 扩展

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
