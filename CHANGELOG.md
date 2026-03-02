# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.15.3] - 2026-03-02

### Fixed
- Switch from exact to inexact alarm scheduling to prevent a
  PlatformException when SCHEDULE_EXACT_ALARM is not granted
  on Android 12+ (#22)

## [0.15.2] - 2026-03-02

### Fixed
- Inline estimate state (slider value, Ja/Nein selection) no longer
  resets when switching prediction type or toggling the deadline;
  root cause was ListView position-shift destroying the Consumer
  element and triggering an autoDispose provider reset (#21)

## [0.15.1] - 2026-03-02

### Fixed
- Tag filter no longer shows an empty list after all entries with a
  selected tag are deleted; stale filters are cleared on data refresh
  (#20)

## [0.15.0] - 2026-03-02

### Added
- Trash icon in selection mode AppBar to permanently delete all
  selected predictions including their estimates and resolutions;
  a confirmation dialog warns before the irreversible action (#19)

## [0.14.1] - 2026-03-02

### Fixed
- Interval outcome now recomputed from the current estimate bounds when
  estimating a pre-resolved question; previously a stale outcome from
  the original resolution could mark a wrong estimate as correct (#18)

## [0.14.0] - 2026-03-02

### Added
- Feedback sheet shown immediately after estimating a question that
  already has a resolution (e.g. trivia imports with embedded answers);
  same CalibrationFeedbackSheet as the resolve flow (#16)

## [0.13.0] - 2026-03-02

### Added
- Bottom sheet after resolving shows Brier contribution of the current
  estimate, overall Brier Score and Log Loss, and a type-specific
  section when predictions of multiple types exist (#16)

## [0.12.2] - 2026-03-02

### Fixed
- Statistics tag filter replaced with FilterChips; the previous
  autocomplete showed no options on empty input, making the filter
  undiscoverable (#9)

## [0.12.1] - 2026-03-02

### Fixed
- Tag dialog now flushes the text field before saving; typed input
  was silently discarded when "Setzen" was pressed without Enter,
  deleting all existing tags instead of replacing them (#17)

## [0.12.0] - 2026-03-02

### Added
- Multi-select mode in the predictions list; long-press activates
  selection, "Select All" covers the active tab and tag filter (#15)
- Bulk tag editing for selected predictions; the dialog replaces tags
  on all selected items at once (#15)

## [0.11.0] - 2026-03-02

### Added
- Tag filter in the sharing export dialog; select one or more tags to
  export only matching resolved predictions (#8)

## [0.10.1] - 2026-03-02

### Fixed
- Import parser now reads `resolution` fields in version 1 files;
  previously they were silently ignored, preventing auto-resolution (#14)

## [0.10.0] - 2026-03-02

### Added
- Clipboard import now recognizes \`\`\`json and \`\`\`yaml fences;
  LLM-generated output can be pasted directly without editing (#13)

## [0.9.0] - 2026-03-02

### Added
- Export resolved questions for others without own estimates;
  optional category filter (epistemic/aleatory) (#8)
- Version tile in Settings shows build number and share icon
  for JSON debug info (OS, device model, API level) (#11)

## [0.8.0] - 2026-03-02

### Added
- Statistics screen now supports three combinable filters: category
  (single-select), prediction type (multi-select), and tags
  (autocomplete, OR-linked) (#9)

## [0.7.1] - 2026-03-02

### Changed
- Import format reference restructured with per-field descriptions and
  an import behavior table explaining the "Lösung vorhanden" flow
- LLM prompt guide added to docs: three copy-ready prompts for
  generating calibration exercises with hidden answers

## [0.7.0] - 2026-03-01

### Added
- MkDocs documentation site deployed to GitHub Pages with versioned
  URLs via mike; triggered automatically on every release tag
- Settings screen links to the documentation version matching the
  installed APK (#6)

## [0.6.0] - 2026-03-01

### Added
- Tapping a resolved prediction card opens a detail view showing
  question text, category, tags, estimate, and resolution with
  outcome, notes, and numeric value (#5)

## [0.5.0] - 2026-03-01

### Added
- Import now supports resolutions: questions with estimate and resolution
  are marked resolved immediately; questions with a resolution but no
  estimate show a "Lösung vorhanden" hint and auto-resolve after estimating (#4)
- Export obfuscates resolution data with ROT13 + Base64 to prevent
  accidental spoilers when sharing question sets (#4)

## [0.4.3] - 2026-03-01

### Fixed
- Import parser now accepts version 2 export format: reads per-question
  categories, `hasKnownAnswer`/`knownAnswer`, and nested estimate objects (#2)

## [0.4.2] - 2026-03-01

### Fixed
- Add missing Java 17 (Temurin) setup step to release workflow
- Strip newlines before base64 decode to prevent keystore corruption

## [0.4.1] - 2026-03-01

### Fixed
- `FilterTab` enum was renamed from `_FilterTab` in `predictions_screen.dart`
  but the old private name remained in `app.dart`, breaking the CI build

## [0.4.0] - 2026-03-01

### Added
- Dashboard stat cards (Offen, Ausstehend, Aufgelöst) are now tappable
  and navigate directly to the predictions list on the matching tab

### Fixed
- Release APK signing: replaced machine-specific debug keystore with a
  dedicated release keystore loaded from `key.properties` or CI secrets;
  prevents "Update not installed" errors when sideloading updates

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

[Unreleased]: https://github.com/kaijen/calibrate/compare/v0.15.3...HEAD
[0.15.3]: https://github.com/kaijen/calibrate/compare/v0.15.2...v0.15.3
[0.15.2]: https://github.com/kaijen/calibrate/compare/v0.15.1...v0.15.2
[0.15.1]: https://github.com/kaijen/calibrate/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/kaijen/calibrate/compare/v0.14.1...v0.15.0
[0.14.1]: https://github.com/kaijen/calibrate/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/kaijen/calibrate/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/kaijen/calibrate/compare/v0.12.2...v0.13.0
[0.12.2]: https://github.com/kaijen/calibrate/compare/v0.12.1...v0.12.2
[0.12.1]: https://github.com/kaijen/calibrate/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/kaijen/calibrate/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/kaijen/calibrate/compare/v0.10.1...v0.11.0
[0.10.1]: https://github.com/kaijen/calibrate/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/kaijen/calibrate/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/kaijen/calibrate/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/kaijen/calibrate/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/kaijen/calibrate/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/kaijen/calibrate/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/kaijen/calibrate/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kaijen/calibrate/compare/v0.4.3...v0.5.0
[0.4.3]: https://github.com/kaijen/calibrate/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/kaijen/calibrate/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/kaijen/calibrate/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/kaijen/calibrate/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/kaijen/calibrate/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/kaijen/calibrate/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/kaijen/calibrate/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/kaijen/calibrate/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/kaijen/calibrate/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/kaijen/calibrate/releases/tag/v0.1.0
