//
//  RiskEvaluator.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation

public final class RiskEvaluator {
    public init() {}
    
    /// 根据宝宝信息和天气数据评估出行风险
    public func evaluate(
        baby: BabyProfile,
        weather: WeatherData
    ) -> EvaluationResult {
        var factorScores: [FactorScore] = []
        
        // 评估温度
        let temperatureScore = evaluateTemperature(
            temperature: weather.temperature,
            ageFactor: baby.ageCategory.sensitivityFactor
        )
        factorScores.append(temperatureScore)
        
        // 评估紫外线
        let uvScore = evaluateUV(
            uvIndex: weather.uvIndex,
            ageFactor: baby.ageCategory.sensitivityFactor
        )
        factorScores.append(uvScore)
        
        // 评估空气质量
        let aqiScore = evaluateAQI(
            aqi: weather.aqi,
            ageFactor: baby.ageCategory.sensitivityFactor
        )
        factorScores.append(aqiScore)
        
        // 评估风速
        let windScore = evaluateWind(
            windSpeed: weather.windSpeed,
            ageFactor: baby.ageCategory.sensitivityFactor
        )
        factorScores.append(windScore)
        
        // 计算总体风险等级
        let overallScore = factorScores.map { $0.score }.reduce(0, +) / factorScores.count
        let riskLevel = determineRiskLevel(from: overallScore)
        
        // 生成建议
        let recommendation = generateRecommendation(
            riskLevel: riskLevel,
            factorScores: factorScores,
            babyAge: baby.ageCategory
        )
        
        return EvaluationResult(
            riskLevel: riskLevel,
            factorScores: factorScores,
            recommendation: recommendation
        )
    }
    
    // MARK: - 各个因素评估
    
    private func evaluateTemperature(
        temperature: Double,
        ageFactor: Double
    ) -> FactorScore {
        let idealMin = 18.0
        let idealMax = 26.0
        
        // 根据年龄调整可接受范围，年龄越小范围越窄
        let adjustedMin = idealMin - (5.0 / ageFactor)
        let adjustedMax = idealMax + (5.0 / ageFactor)
        
        let message: String
        let score: Int
        
        if temperature >= adjustedMin && temperature <= adjustedMax {
            score = 100
            message = "温度适宜(\(String(format: "%.1f°C", temperature))"
        } else {
            let deviation = abs(temperature - ((idealMin + idealMax) / 2))
            let adjustedDeviation = deviation * ageFactor
            score = max(0, 100 - Int(adjustedDeviation * 5))
            
            if temperature < adjustedMin {
                message = "温度偏低(\(String(format: "%.1f°C", temperature))，注意保暖"
            } else {
                message = "温度偏高(\(String(format: "%.1f°C", temperature))，注意降温补水"
            }
        }
        
        return FactorScore(
            factor: .temperature,
            score: score,
            message: message
        )
    }
    
    private func evaluateUV(
        uvIndex: Double,
        ageFactor: Double
    ) -> FactorScore {
        // 安全阈值会随着敏感度提高而降低
        let safeThreshold = 5.0 / ageFactor
        let moderateThreshold = 8.0 / ageFactor
        
        let message: String
        let score: Int
        
        if uvIndex <= safeThreshold {
            score = 100
            message = "紫外线强度正常(UV \(String(format: "%.1f", uvIndex))"
        } else if uvIndex <= moderateThreshold {
            score = 50
            message = "紫外线偏强(UV \(String(format: "%.1f", uvIndex))，注意防晒"
        } else {
            score = 0
            message = "紫外线过强(UV \(String(format: "%.1f", uvIndex))，避免长时间露天活动"
        }
        
        return FactorScore(
            factor: .uv,
            score: score,
            message: message
        )
    }
    
    private func evaluateAQI(
        aqi: Int,
        ageFactor: Double
    ) -> FactorScore {
        // 年龄越小，对空气质量要求越高
        let goodThreshold = 50 / Int(ageFactor)
        let moderateThreshold = 100 / Int(ageFactor)
        
        let message: String
        let score: Int
        
        if aqi <= goodThreshold {
            score = 100
            message = "空气质量优(AQI \(aqi))"
        } else if aqi <= moderateThreshold {
            score = 60
            message = "空气质量良(AQI \(aqi))，影响不大"
        } else if aqi <= 150 {
            score = 30
            message = "空气质量轻度污染(AQI \(aqi))，缩短外出时间"
        } else {
            score = 0
            message = "空气质量较差(AQI \(aqi))，不建议外出"
        }
        
        return FactorScore(
            factor: .aqi,
            score: score,
            message: message
        )
    }
    
    private func evaluateWind(
        windSpeed: Double,
        ageFactor: Double
    ) -> FactorScore {
        // 单位：公里/小时
        let safeThreshold = 15.0 / ageFactor
        let moderateThreshold = 25.0 / ageFactor
        
        let message: String
        let score: Int
        
        if windSpeed <= safeThreshold {
            score = 100
            message = "风速适宜(\(String(format: "%.1f", windSpeed)) km/h)"
        } else if windSpeed <= moderateThreshold {
            score = 50
            message = "风速偏大(\(String(format: "%.1f", windSpeed)) km/h)，注意避风"
        } else {
            score = 0
            message = "风力过大(\(String(format: "%.1f", windSpeed)) km/h)，不建议外出"
        }
        
        return FactorScore(
            factor: .wind,
            score: score,
            message: message
        )
    }
    
    // MARK: - 辅助方法
    
    private func determineRiskLevel(from overallScore: Int) -> RiskLevel {
        if overallScore >= 70 {
            return .safe
        } else if overallScore >= 40 {
            return .caution
        } else {
            return .unsafe
        }
    }
    
    private func generateRecommendation(
        riskLevel: RiskLevel,
        factorScores: [FactorScore],
        babyAge: BabyProfile.AgeCategory
    ) -> String {
        let poorFactors = factorScores.filter { $0.score < 40 }
        
        switch riskLevel {
        case .safe:
            return "✅ 当前环境适宜带宝宝\(babyAge == .newborn ? "出门散步" : "外出活动")，享受美好的户外时光吧！"
        case .caution:
            let prefix = "⚠️ 当前环境存在一定风险，"
            if !poorFactors.isEmpty {
                let factors = poorFactors.map { $0.factor.displayName }.joined(separator: "、")
                return "\(prefix)\(factors)不太理想，建议缩短外出时间，并做好防护措施。"
            } else {
                return "\(prefix)建议谨慎出行，密切关注宝宝状态。"
            }
        case .unsafe:
            let prefix = "❌ 当前环境不适合带宝宝外出，"
            if !poorFactors.isEmpty {
                let factors = poorFactors.map { $0.factor.displayName }.joined(separator: "、")
                return "\(prefix)主要问题是\(factors)，建议改为室内活动。"
            } else {
                return "\(prefix)建议改为室内活动。"
            }
        }
    }
}
