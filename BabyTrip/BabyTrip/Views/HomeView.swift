//
//  HomeView.swift
//  BabyTrip
//
//  Created by BabyTrip Project
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
    private let locationManager = LocationManager()
    private let geocoder = CLGeocoder()
    
    func loadWeatherAndEvaluate(location: CLLocation, baby: BabyProfile) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let weather = try await weatherAPIClient.fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            let result = riskEvaluator.evaluate(baby: baby, weather: weather)
            
            // 反向地理编码获取位置名称
            let placemark = try await geocoder.reverseGeocodeLocation(location)
            let locationName = placemark.first?.locality ?? placemark.first?.administrativeArea ?? "未知位置"
            
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
    
    func reverseGeocode(_ location: CLLocation) async -> String {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first?.locality ?? placemarks.first?.administrativeArea ?? "未知位置"
        } catch {
            return "未知位置"
        }
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
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if let result = viewModel.evaluationResult, let weather = viewModel.weatherData {
                    resultView(result, weather)
                } else {
                    emptyView
                }
            }
            .padding()
        }
        .refreshable {
            refreshData()
        }
        .onAppear {
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
    
    private func resultView(_ result: EvaluationResult, _ weather: WeatherData) -> some View {
        VStack(spacing: 20) {
            // 位置信息
            if let locationName = viewModel.locationName {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(locationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 总体结果卡片
            resultCard(result)
            
            // 当前天气概览
            weatherOverviewCard(weather)
            
            // 详细评分
            detailedScoresCard(result)
            
            // 建议文本
            recommendationCard(result)
        }
    }
    
    private func resultCard(_ result: EvaluationResult) -> some View {
        VStack(spacing: 12) {
            Text("出行评估结果")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Text(result.riskLevel.description)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(colorForRiskLevel(result.riskLevel))
                
                Text("安全评分: \(result.overallScore)/100")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorForRiskLevel(result.riskLevel).opacity(0.1))
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func weatherOverviewCard(_ weather: WeatherData) -> some View {
        VStack(spacing: 12) {
            Text("当前天气")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                weatherItem(title: "温度", value: String(format: "%.1f°C", weather.temperature), icon: "thermometer")
                weatherItem(title: "紫外线", value: String(format: "%.1f", weather.uvIndex), icon: "sun.max")
                weatherItem(title: "AQI", value: "\(weather.aqi)", icon: "wind")
                weatherItem(title: "风速", value: String(format: "%.1f km/h", weather.windSpeed), icon: "wind.snow")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func weatherItem(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
            }
            Spacer()
        }
    }
    
    private func detailedScoresCard(_ result: EvaluationResult) -> some View {
        VStack(spacing: 12) {
            Text "各项评分"
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                ForEach(result.factorScores) { factor in
                    VStack(spacing: 4) {
                        HStack {
                            Text(factor.factor.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(factor.score)/100")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(factor.score) / 100.0)
                            .tint(colorForScore(factor.score))
                        
                        Text(factor.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func recommendationCard(_ result: EvaluationResult) -> some View {
        VStack(spacing: 12) {
            Text("出行建议")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(result.recommendation)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
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
    
    private func colorForScore(_ score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
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
