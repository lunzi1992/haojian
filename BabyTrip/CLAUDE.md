# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BabyTrip (宝宝出行助手) is a Swift + SwiftUI iOS and watchOS app that helps parents determine if current weather conditions are safe for taking their baby outside.

## Project Structure

This is a multi-target Xcode project:

- **BabyTrip** (iOS app): Main app target with SwiftUI views
- **BabyTripWatch** (watchOS app): Watch companion app
- **BabyTripShared** (Framework): Shared code between iOS and watchOS

Key directories:
```
BabyTrip/
├── BabyTrip/                  # iOS app
│   ├── App/                   # App entry point
│   ├── Views/                 # SwiftUI views
│   └── Info.plist             # Contains API key
├── BabyTripWatch/             # watchOS app
│   └── Views/
└── BabyTripShared/            # Shared framework
    ├── RiskEvaluation/        # Core evaluation logic
    ├── Network/               # Weather API client
    ├── Location/              # Location manager
    └── Storage/               # User settings
```

## Development Environment

- **Xcode**: 15+ (required for SwiftUI features used)
- **Swift**: 5.9+
- **Minimum iOS**: 17.0+
- **Minimum watchOS**: 10.0+

## Build and Run

1. Open `BabyTrip.xcodeproj` in Xcode
2. Select a target simulator or device
3. Build and run (Cmd+R)

For watchOS:
- Change scheme to `BabyTripWatch` in Xcode menu `Product > Scheme`

## API Configuration

The app uses OpenWeatherMap API for weather data.

1. Get a free API key from https://openweathermap.org/api
2. Add the key to both Info.plist files:
   - `BabyTrip/Info.plist` → `WeatherAPIKey`
   - `BabyTripWatch/Info.plist` → `WeatherAPIKey`

## Core Architecture

### Risk Evaluation Engine

The heart of the app is `BabyTripShared/RiskEvaluation/RiskEvaluator.swift`. It evaluates four weather factors:

1. **Temperature**: Ideal range 18-26°C, adjusted by age sensitivity
2. **UV Index**: Safe threshold < 3 for babies, adjusted by age
3. **Air Quality (AQI)**: Safe < 100, stricter for younger babies
4. **Wind Speed**: Safe < 15 km/h, adjusted by age

Age sensitivity factor (from `BabyProfile.AgeCategory`):
- Newborn (0-3mo): 1.5x stricter thresholds
- 3-6 months: 1.3x
- 6-12 months: 1.1x
- 1+ year: 1.0x (baseline)

### Data Flow

```
LocationManager → WeatherAPIClient → RiskEvaluator → EvaluationResult
                                                      ↓
                                               HomeView Display
```

### State Management

- `UserSettings`: Singleton for baby profile persistence via UserDefaults
- `LocationManager`: Publishes location updates for weather fetching
- ViewModels (e.g., `HomeViewModel`): Handle async data loading and state

## Testing

Currently there are no automated tests. When adding tests:
- Use XCTest framework
- Test `RiskEvaluator` with various weather/baby age combinations
- Mock `WeatherAPIClient` for testing

## Key Files Reference

| File | Purpose |
|------|---------|
| `RiskEvaluator.swift` | Core risk calculation logic |
| `WeatherAPIClient.swift` | OpenWeatherMap API integration |
| `BabyProfile.swift` | Age categories and sensitivity factors |
| `UserSettings.swift` | Profile persistence |
| `HomeView.swift` | Main UI with ViewModel |
| `Info.plist` | API key configuration |
