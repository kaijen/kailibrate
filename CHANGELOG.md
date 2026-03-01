# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-03-01

### Added
- Optional inline estimation when creating a new prediction; saves the
  separate estimate step for users who already know their probability
- Estimate fields in JSON/YAML import files: `predictionType`,
  `probability`, `binaryChoice`, `confidenceLevel`, `lowerBound`,
  `upperBound`, and `unit` — imported estimates are saved automatically
- Sample data updated with embedded estimate examples for all three
  prediction types

### Changed
- Estimate form logic extracted to `shared/widgets/estimate_inputs.dart`
  (`EstimateFormState`, `EstimateFormNotifier`, `BinaryEstimateInput`,
  `IntervalEstimateInput`, `ConfidenceSlider`) and reused across
  `EstimateScreen` and `NewPredictionScreen`

## [0.2.1] - 2026-03-01

### Fixed
- Enable core library desugaring in `android/app/build.gradle` so that
  `flutter_local_notifications` builds on all supported Android runtimes;
  resolves `checkReleaseAarMetadata` failure in CI

## [0.2.0] - 2026-03-01

### Added
- Binary prediction type: choose Yes/No and set confidence level;
  probability is derived as `confidence` (Yes) or `1 − confidence` (No)
- Interval prediction type: define a numeric range with confidence level;
  resolves as true when the measured value falls within the interval
- Optional unit field on interval predictions (e.g. m, °C, kg)
- Local deadline notifications: reminded the day before and on the
  deadline day at 09:00; rescheduled automatically on app start
  to survive device reboots (flutter_local_notifications, timezone)
- Type-selector (SegmentedButton) on the new prediction screen
- Type-aware estimate screen: slider for probability, Yes/No buttons
  plus confidence slider for binary, numeric fields plus confidence
  slider for interval
- Type-aware resolve screen: numeric input for interval resolutions;
  outcome computed automatically from the stored bounds

## [0.1.2] - 2026-03-01

### Fixed
- Add mipmap launcher icons (mdpi–xxxhdpi) and adaptive icon for API 26+;
  resolves AAPT build error "resource mipmap/ic_launcher not found"

## [0.1.1] - 2026-03-01

### Fixed
- Drift column name conflict (`Questions.text` shadowed inherited `text()`
  method); renamed to `questionText` with `.named('text')`
- Replace `SharePlus.instance`/`ShareParams` with stable `Share.shareXFiles`
  API (share_plus 10.x)
- Bump `compileSdk`/`targetSdk` to 36 (required by path_provider and
  flutter_plugin_android_lifecycle)
- Upgrade Gradle wrapper to 8.10.2, AGP to 8.7.0, Kotlin to 2.1.0

## [0.1.0] - 2026-03-01

### Added
- Core app: probability estimation, resolution, calibration stats, and JSON/YAML import
- Settings screen, tag filter, and clipboard import for question sets
- GitHub Actions release workflow for tag-triggered APK builds

[Unreleased]: https://github.com/kaijen/callibrate/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/kaijen/callibrate/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/kaijen/callibrate/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/kaijen/callibrate/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/kaijen/callibrate/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/kaijen/callibrate/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/kaijen/callibrate/releases/tag/v0.1.0
