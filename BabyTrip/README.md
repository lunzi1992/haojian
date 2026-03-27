# BabyTrip - 宝宝出行助手

一个基于 Swift + SwiftUI 的原生 iOS + watchOS 应用，帮助家长判断当前天气环境是否适合带宝宝外出。

## 功能特性

- 📱 支持 iOS 17+ 和 watchOS 10+ 双平台
- 🌤 根据宝宝年龄（月龄）和当前天气数据给出智能出行建议
- 📍 自动定位获取当前位置天气，支持手动选择城市
- 🧮 基于**温度、紫外线、空气质量、风速**四个维度的综合风险评估
- ⚖️ 年龄敏感算法：年龄越小的宝宝，安全阈值越严格
- 💾 数据全部本地存储，无需登录，保护隐私
- 🔄 下拉刷新快速更新天气数据
- ⚙️ 设置向导，初次使用一键配置宝宝信息

## 项目结构

```
BabyTrip/
├── BabyTrip.xcodeproj          # Xcode 项目文件
├── project.yml                 # 项目配置 (XcodeGen)
├── BabyTrip/                   # iOS App 主目标
│   ├── App/
│   │   ├── BabyTripApp.swift
│   │   └── BabyTripApp.entitlements
│   ├── Views/
│   │   ├── HomeView.swift          # 主页 - 展示评估结果
│   │   ├── SetupProfileView.swift  # 初次设置向导
│   │   ├── SettingsView.swift      # 设置页
│   │   └── ContentView.swift
│   ├── Info.plist
├── BabyTripWatch/              # watchOS App 目标
│   ├── BabyTripWatchApp.swift
│   ├── Views/
│   │   └── ContentView.swift  # 手表端主页，快速查看结论
│   └── Info.plist
├── BabyTripShared/             # 共享逻辑 Framework
│   ├── RiskEvaluation/        # 🧮 核心风险评估引擎
│   │   ├── RiskEvaluator.swift     # 主评估逻辑
│   │   ├── WeatherData.swift       # 天气数据结构
│   │   ├── BabyProfile.swift       # 宝宝信息 & 年龄分类
│   │   └── EvaluationResult.swift  # 评估结果结构
│   ├── Location/
│   │   └── LocationManager.swift   # 定位管理
│   ├── Network/
│   │   └── WeatherAPIClient.swift  # OpenWeatherMap API 客户端
│   └── Storage/
│       └── UserSettings.swift      # 用户设置存储
├── DEBUG.md                    # 调试运行手册
└── README.md
```

## 环境要求

- Xcode 15+
- Swift 5.9+
- iOS 17.0+ 模拟器/设备
- watchOS 10.0+ 模拟器/设备

## 快速开始

### 1. 获取代码

```bash
git clone https://github.com/lunzi1992/haojian.git
cd haojian/BabyTrip
```

### 2. 配置 API Key

项目使用 [OpenWeatherMap](https://openweathermap.org/) 免费 API：

1. 注册账号并获取你的 API Key
2. 分别打开 `BabyTrip/Info.plist` 和 `BabyTripWatch/Info.plist`
3. 将 `OpenWeatherAPIKey` 字段的值 `YOUR_API_KEY_HERE` 替换为你的 API Key

### 3. 编译运行

```bash
open BabyTrip.xcodeproj
```
选择 iOS 17+ 模拟器或真机，点击运行。

更详细的调试步骤和常见问题排查请看 [DEBUG.md](./DEBUG.md)

## MVP 评估规则

风险评估基于四个环境因素，**并会根据宝宝年龄自动调整安全阈值**：年龄越小，敏感度越高，安全范围越严格。

| 因素 | 标准安全范围（1岁以上） | 说明 |
|------|------------------------|------|
| 温度 | 18-26°C | 新生儿可接受范围会收窄，对温度变化更敏感 |
| 紫外线 | UV指数 < 5 | 6个月以下宝宝阈值更低，更需避免强光 |
| 空气质量 | AQI < 50 | 随着月龄增大逐渐放宽，污染天缩短外出时间 |
| 风速 | 风速 < 15km/h | 大风对新生儿呼吸道刺激较大 |

最终输出三个等级：
- 🟢 **适合外出** (≥70分)
- 🟡 **谨慎外出** (40-69分)
- 🔴 **不建议外出** (<40分)

## API 说明

当前使用 [OpenWeatherMap](https://openweathermap.org/api) API 获取天气数据，需要:
- 注册免费账号获取 API Key
- 支持获取当前温度、紫外线指数、空气质量指数等数据

## 作者

李进 (@lunzi1992)

## 许可证

MIT
