//
//  HomeView.swift
//  BabyTrip
//
//  Created by BabyTrip Project
//  V2: 全新首页布局
//

import SwiftUI
import BabyTripShared
import CoreLocation

class HomeViewModel: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var evaluationResult: EvaluationResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationName: String?
    
    private let weatherAPIClient = WeatherAPIClient()
    private let riskEvaluator = RiskEvaluator()
    private let geocoder = CLGeocoder()
    
    // MARK: - 缓存
    private var cachedWeather: WeatherData?
    private var cachedResult: EvaluationResult?
    private var cachedLocation: CLLocation?
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 15 * 60 // 15分钟
    
    func loadWeatherAndEvaluate(location: CLLocation, baby: BabyProfile) async {
        // 检查缓存是否有效（15分钟内且位置变化小于1公里）
        if let cachedLoc = cachedLocation,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheDuration,
           let weather = cachedWeather,
           let result = cachedResult {
            let distance = location.distance(from: cachedLoc)
            if distance < 1000 { // 1公里内使用缓存
                DispatchQueue.main.async {
                    self.weatherData = weather
                    self.evaluationResult = result
                    self.isLoading = false
                }
                return
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // 1. 获取当前天气
            let weather = try await weatherAPIClient.fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            // 2. 获取未来天气预报（用于计算最佳外出时间）
            let forecastItems = try await weatherAPIClient.fetchForecast(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            // 3. 评估当前天气
            var result = riskEvaluator.evaluate(baby: baby, weather: weather)
            
            // 4. 计算最佳外出时间
            let forecastData = forecastItems.map { item in
                (
                    date: item.date,
                    temperature: item.main.temp,
                    feelsLike: item.main.feels_like,
                    humidity: item.main.humidity,
                    windSpeed: item.wind.speed * 3.6
                )
            }
            
            if let bestTime = riskEvaluator.calculateBestTimeRange(
                forecast: forecastData,
                babyAgeInMonths: baby.ageInMonths
            ) {
                // 重新创建 result 包含最佳时间
                result = EvaluationResult(
                    overallScore: result.overallScore,
                    riskLevel: result.riskLevel,
                    factorContributions: result.factorContributions,
                    recommendations: result.recommendations,
                    humanSummary: result.humanSummary,
                    bestTimeRange: bestTime
                )
            }
            
            // 5. 反向地理编码获取位置名称
            let placemark = try await geocoder.reverseGeocodeLocation(location)
            let locationName = placemark.first?.locality ?? placemark.first?.administrativeArea ?? "未知位置"
            
            // 6. 更新缓存
            self.cachedWeather = weather
            self.cachedResult = result
            self.cachedLocation = location
            self.lastFetchTime = Date()
            
            DispatchQueue.main.async {
                self.weatherData = weather
                self.evaluationResult = result
                self.locationName = locationName
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// 手动清除缓存（下拉刷新时使用）
    func clearCache() {
        cachedWeather = nil
        cachedResult = nil
        cachedLocation = nil
        lastFetchTime = nil
    }
}

struct HomeView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var locationManager: LocationManager
    @StateObject var viewModel: HomeViewModel
    
    init(viewModel: HomeViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if let result = viewModel.evaluationResult, let weather = viewModel.weatherData {
                    v2ResultView(result, weather)
                } else {
                    emptyView
                }
            }
            .padding()            
        }
        .refreshable {
            viewModel.clearCache()
            refreshData()
        }
        .onAppear {
            if locationManager.location == nil {
                locationManager.requestLocation()
            }
            refreshData()
        }
        .onChange(of: locationManager.location) { _ in
            refreshData()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func refreshData() {
        guard let baby = userSettings.babyProfile,
              let location = locationManager.location else {
            return
        }
        
        Task {
            await viewModel.loadWeatherAndEvaluate(location: location, baby: baby)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("获取天气数据中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("获取数据失败")
                .font(.title2)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                refreshData()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    // MARK: - V2 首页布局
    
    private func v2ResultView(_ result: EvaluationResult, _ weather: WeatherData) -> some View {
        VStack(spacing: 16) {
            // 1. 城市 + 当前时间
            locationAndTimeView
            
            // 2. 风险等级大标题
            riskLevelCard(result)
            
            // 3. 人话总结
            humanSummaryCard(result)
            
            // 4. 当前天气概览（移到总结下方）
            weatherOverviewCard(weather)
            
            // 5. 原因列表
            reasonsCard(result)
            
            // 6. 行动建议
            recommendationsCard(result)
            
            // 7. 最佳外出时间（P1）
            if let bestTime = result.bestTimeRange {
                bestTimeCard(bestTime)
            }
            
            // 8. 宝宝信息卡片
            if let baby = userSettings.babyProfile {
                babyInfoCard(baby)
            }
            
            // 9. 免责声明
            disclaimerView
        }
    }
    
    private var locationAndTimeView: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
                .font(.caption)
            Text(viewModel.locationName ?? "未知位置")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(currentTimeString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    private func riskLevelCard(_ result: EvaluationResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                riskLevelIcon(result.riskLevel)
                    .font(.system(size: 40))
                Text(riskLevelTitle(result.riskLevel))
                    .font(.system(size: 28, weight: .bold))
            }
            .foregroundColor(colorForRiskLevel(result.riskLevel))
            
            if result.overallScore > 0 {
                Text("风险指数: \(result.overallScore)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorForRiskLevel(result.riskLevel).opacity(0.1))
        )
    }
    
    private func riskLevelIcon(_ level: RiskLevel) -> some View {
        switch level {
        case .safe:
            return Image(systemName: "checkmark.circle.fill")
        case .caution:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .unsafe:
            return Image(systemName: "xmark.circle.fill")
        }
    }
    
    private func riskLevelTitle(_ level: RiskLevel) -> String {
        switch level {
        case .safe:
            return "适合外出"
        case .caution:
            return "谨慎外出"
        case .unsafe:
            return "不建议外出"
        }
    }
    
    private func humanSummaryCard(_ result: EvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一句话总结")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(result.humanSummary)
                .font(.body)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func reasonsCard(_ result: EvaluationResult) -> some View {
        let contributions = result.factorContributions.filter { $0.points > 0 }
        guard !contributions.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("主要原因")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(contributions.sorted { $0.points > $1.points }.prefix(3)) { contribution in
                        if let reason = contribution.reasons.first {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        )
    }
    
    private func recommendationsCard(_ result: EvaluationResult) -> some View {
        guard !result.recommendations.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("建议")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(recommendation)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        )
    }
    
    private func bestTimeCard(_ timeRange: TimeRange) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日较适合外出时间")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.green)
                Text(formatTimeRange(timeRange))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text(timeRange.reason)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func formatTimeRange(_ timeRange: TimeRange) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: timeRange.start)) - \(formatter.string(from: timeRange.end))"
    }
    
    private func babyInfoCard(_ baby: BabyProfile) -> some View {
        let ageMonths = baby.ageInMonths
        let stage = ageMonths <= 3 ? "新生儿" : (ageMonths <= 6 ? "小婴儿" : "婴儿")
        let sensitivity = ageMonths <= 3 ? "高敏感" : (ageMonths <= 6 ? "中高敏感" : "中等敏感")
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("宝宝信息")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "face.smiling.fill")
                    .foregroundColor(.pink)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ageMonths)个月 · \(stage)阶段")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("(\(sensitivity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func weatherOverviewCard(_ weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前天气")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                weatherItem(title: "温度", value: "\(Int(weather.temperature))°C", icon: "thermometer")
                weatherItem(title: "体感", value: "\(Int(weather.feelsLike))°C", icon: "thermometer.sun")
                weatherItem(title: "紫外线", value: "\(Int(weather.uvIndex))", icon: "sun.max")
                weatherItem(title: "AQI", value: "\(weather.aqi)", icon: "wind")
                weatherItem(title: "风速", value: "\(Int(weather.windSpeed)) km/h", icon: "wind")
                weatherItem(title: "湿度", value: "\(Int(weather.humidity))%", icon: "drop")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func weatherItem(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
    }
    
    private var disclaimerView: some View {
        Text("本建议仅供参考，不能替代专业医疗意见。如有疑虑，请咨询儿科医生。")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
    
    // MARK: - 其他视图
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.largeTitle)
                .foregroundColor(.blue)
            Text("正在获取位置...")
                .foregroundColor(.secondary)
            if let status = locationManager.authorizationStatus {
                if status == .denied || status == .restricted {
                    Text("需要位置权限才能获取天气，请在设置中开启")
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    private func colorForRiskLevel(_ level: RiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .caution: return .orange
        case .unsafe: return .red
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView(viewModel: HomeViewModel())
                .environmentObject(UserSettings.shared)
        }
    }
}
