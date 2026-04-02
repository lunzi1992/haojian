# BabyTrip - 宝宝出行助手

一个基于 Swift + SwiftUI 的原生 iOS + watchOS 应用，帮助家长判断当前天气环境是否适合带宝宝外出。

## 功能特性

> **V2 全新升级** - 从"能用"到"好用"，更贴心的决策辅助

- 📱 支持 iOS 17+ 和 watchOS 10+ 双平台
- 🌤 根据宝宝月龄自动调整风险敏感度，给出个性化出行建议
- 📍 自动定位获取当前位置天气，支持手动选择城市
- 🧮 **六维综合评估**: 温度 + 体感温度 + 紫外线 + 空气质量 + 风速 + 湿度
- 💡 **智能解读**: 人话总结 + 原因明细 + 可执行行动建议
- ⏰ 推荐**今日最佳外出时间段**，帮你选对时间出门
- ⚖️ **年龄权重算法**: 0-3个月 ×1.5倍风险权重（更敏感），月龄越小越严格
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

## V2 评估规则

### 六大环境维度

BabyTrip V2 使用**风险累加评分系统**，总分越高风险越大，最终根据宝宝月龄应用年龄权重放大风险：

| 因素 | 风险加分规则 | V2 说明 |
|------|-------------|---------|
| 温度 | >32°C +25 / <5°C +30 | 过高过低都增加风险 |
| 体感温度 | >35°C +20 / <0°C +15 | 新增维度，反应实际感受 |
| 紫外线 | ≥7 +25 / ≥4 +10 | 强烈紫外线对宝宝伤害大 |
| 空气质量 | >100 +30 / >50 +15 | 空气污染对呼吸道刺激 |
| 风速 | >25km/h +10 | 大风天气需要避风 |
| 湿度 | >90% +15 / >80% +10 / <30% +5 | 新增维度，太闷太干都不舒服 |

### 年龄权重（风险放大）

| 月龄 | 权重 | 说明 |
|------|------|------|
| 0-3个月 | ×1.5 | 新生儿，更加敏感 |
| 3-6个月 | ×1.2 | 小婴儿，中高敏感 |
| 6-12个月 | ×1.0 | 婴儿，中等敏感 |

### 最终评级

| 风险总分 | 建议等级 |
|---------|---------|
| 0-30 | 🟢 **适合外出** |
| 31-60 | 🟡 **谨慎外出** |
| >60 | 🔴 **不建议外出** |

### 输出内容

V2 不仅给结论，还给你完整的决策辅助：
1. **人话总结**：一句话说清楚今天能不能出门
2. **原因明细**：列出哪些因素拉高了风险
3. **行动建议**：每个风险点给具体防护建议
4. **最佳时段**：推荐今日评分最低的连续2小时适合外出

## API 说明

当前使用 [OpenWeatherMap](https://openweathermap.org/api) One Call API 3.0 获取天气数据，V2 需要:
- 注册免费账号获取 API Key
- 需要获取的数据：温度、体感温度、紫外线指数、空气质量指数、风速、湿度
- 免费额度足够个人开发使用

## 作者

李进 (@lunzi1992)

## 许可证

MIT
