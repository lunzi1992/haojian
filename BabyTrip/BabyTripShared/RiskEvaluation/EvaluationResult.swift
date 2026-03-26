//
//  EvaluationResult.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation

public struct EvaluationResult: Codable, Equatable {
    /// 整体风险等级
    public let riskLevel: RiskLevel
    
    /// 各因素评分 (0-100，分数越高越安全)
    public let factorScores: [FactorScore]
    
    /// 建议文本
    public let recommendation: String
    
    /// 总体安全分数
    public var overallScore: Int {
        let total = factorScores.map { $0.score }.reduce(0, +)
        return factorScores.isEmpty ? 0 : total / factorScores.count
    }
    
    public init(
        riskLevel: RiskLevel,
        factorScores: [FactorScore],
        recommendation: String
    ) {
        self.riskLevel = riskLevel
        self.factorScores = factorScores
        self.recommendation = recommendation
    }
}

public struct FactorScore: Codable, Equatable, Identifiable {
    public let id = UUID()
    public let factor: RiskFactor
    public let score: Int // 0-100
    public let message: String
    
    public init(factor: RiskFactor, score: Int, message: String) {
        self.factor = factor
        self.score = score
        self.message = message
    }
}

public enum RiskLevel: Int, Codable, CaseIterable {
    case safe          // 安全，可以外出
    case caution       // 谨慎出行
    case unsafe        // 不建议外出
    
    public var description: String {
        switch self {
        case .safe:
            return "安全"
        case .caution:
            return "谨慎"
        case .unsafe:
            return "不建议"
        }
    }
    
    public var color: String {
        switch self {
        case .safe:
            return "green"
        case .caution:
            return "yellow"
        case .unsafe:
            return "red"
        }
    }
}

public enum RiskFactor: String, Codable, CaseIterable {
    case temperature
    case uv
    case aqi
    case wind
    
    public var displayName: String {
        switch self {
        case .temperature:
            return "温度"
        case .uv:
            return "紫外线"
        case .aqi:
            return "空气质量"
        case .wind:
            return "风速"
        }
    }
}
