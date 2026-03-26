# BabyTrip - 宝宝出行助手

一个基于 Swift + SwiftUI 的原生 iOS + watchOS 应用，帮助家长判断当前天气环境是否适合带宝宝外出。

## 功能特性

- 📱 支持 iOS 17+ 和 watchOS 10+
- 🌤 根据宝宝年龄和当前天气数据给出出行建议
- 📍 自动定位获取当前天气
- 🧮 基于温度、紫外线、空气质量、风速的综合风险评估
- 💾 数据本地存储，无需登录

## 项目结构

```
BabyTrip/
├── BabyTrip.xcodeproj          # Xcode 项目文件
├── BabyTrip/                   # iOS App 主目标
│   ├── App/
│   │   ├── BabyTripApp.swift
│   │   └── BabyTripApp.entitlements
│   ├── Views/
│   │   ├── HomeView.swift
│   │   └── SettingsView.swift
│   ├── ViewModels/
│   ├── Models/
│   ├── Resources/
│   └── Info.plist
├── BabyTripWatch/              # watchOS App 目标
│   ├── BabyTripWatchApp.swift
│   ├── Views/
│   │   └── ContentView.swift
│   └── Info.plist
├── BabyTripShared/             # 共享逻辑
│   ├── RiskEvaluation/        # 风险评估引擎
│   │   ├── RiskEvaluator.swift
│   │   ├── WeatherData.swift
│   │   ├── BabyProfile.swift
│   │   └── EvaluationResult.swift
│   ├── Location/
│   │   └── LocationManager.swift
│   ├── Network/
│   │   └── WeatherAPIClient.swift
│   └── Storage/
│       └── UserSettings.swift
└── README.md
```

## 环境要求

- Xcode 15+
- Swift 5.9+
- iOS 17.0+ 模拟器/设备
- watchOS 10.0+ 模拟器/设备

## 设置说明

1. 克隆项目
```bash
git clone https://github.com/lunzi1992/haojian.git
cd haojian/BabyTrip
```

2. 使用 Xcode 打开 `BabyTrip.xcodeproj`

3. 在 `BabyTrip/Network/WeatherAPIClient.swift` 中配置你的天气 API Key（当前使用 OpenWeatherMap）

4. 选择合适的模拟器/设备，构建并运行

## MVP 评估规则

风险评估基于四个因素，并根据宝宝年龄进行调整：

| 因素 | 安全范围 | 注意事项 |
|------|---------|---------|
| 温度 | 18-26°C | 新生儿对温度变化更敏感 |
| 紫外线 | UV指数 < 3 | 6个月以下宝宝避免强光 |
| 空气质量 | AQI < 100 | 空气质量差时减少外出 |
| 风速 | 风速 < 15km/h | 大风对新生儿影响较大 |

## API 说明

当前使用 [OpenWeatherMap](https://openweathermap.org/api) API 获取天气数据，需要:
- 注册免费账号获取 API Key
- 支持获取当前温度、紫外线指数、空气质量指数等数据

## 作者

李进 (@lunzi1992)

## 许可证

MIT
