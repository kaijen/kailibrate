# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.7.0-beta.7] - 2026-03-07

### Fixed
- Factual prediction type missing from type filter chips (#93)
- Overdue filter chip had no effect on the resolved tab (#93)

## [1.7.0-beta.6] - 2026-03-07

### Added
- Manual import shows full checkbox list with per-question selection;
  duplicates are pre-deselected, struck through, and non-selectable (#94)
- Import button and post-import success card show actual imported
  question count for both manual and AI import (#94)

## [1.7.0-beta.5] - 2026-03-07

### Added
- Overdue filter chip cycles through three states: no filter,
  overdue only, not overdue only

## [1.7.0-beta.4] - 2026-03-07

### Added
- Category (Epistemisch/Aleatorisch) and prediction type
  (Wahrscheinlichkeit, Ja/Nein, Intervall) filter chips in the
  prediction list; chips appear only when relevant (#93)

## [1.7.0-beta.3] - 2026-03-07

### Fixed
- Back navigation from a Winkler Score prediction detail now returns
  to the fullscreen chart in its previous zoom state (#91)

## [1.7.0-beta.2] - 2026-03-07

### Added
- Fullscreen charts support x-axis zoom and pan via pinch gesture;
  double-tap resets the view; axis labels recalculate for the
  visible range (#91)

## [1.6.0] - 2026-03-07

### Fixed
- Winkler Score data point links now active only in the fullscreen
  detail view, not on the summary chart; any tap on the summary
  chart opens fullscreen, consistent with Brier and Log Loss (#90)

## [1.5.0] - 2026-03-07

### Added
- Winkler Score chart: tapping a data point opens the corresponding
  prediction detail; back navigation returns to statistics (#90)

## [1.4.2] - 2026-03-06

### Fixed
- Winkler Score chart y-axis is now logarithmic; scores spanning
  multiple orders of magnitude are readable without visual compression
  of small values (#89)

## [1.4.1] - 2026-03-06

### Fixed
- Replace misleading Winkler Score mean card with a per-estimate
  scatter chart; dots coloured green (hit) and red (miss) (#88)

## [1.4.0] - 2026-03-06

### Added
- Winkler Score for interval predictions on the statistics screen;
  shows mean interval score and hit rate (#88)

### Fixed
- Template share buttons now write to a temporary file before
  sharing; `XFile.fromData()` produced no valid URI for Android
  share intents (#81)

## [1.3.0] - 2026-03-06

### Added
- AES-256-GCM encrypted full backup with PBKDF2-SHA256 key derivation;
  create and restore `.kbak` files from Settings (#85)
- Delete button in prediction detail screen AppBar with confirmation
  dialog (#87)
- Per-tab sort direction persisted via SharedPreferences; each tab
  remembers its own sort order across sessions (#86)
- Skip duplicate questions by default on import; configurable toggle
  in the import screen (#84)
- Full multi-select list in AI generator preview, all pre-selected;
  replaces the static "first 5" preview (#83)
- YAML template buttons for each prediction type in import screen
- Share button in prediction list view; exports the active tab as JSON
- Tag chip selector on new-prediction screen
- Preselect existing tags in the bulk-edit dialog
- "Ohne Tag" filter chip in statistics screen
- Exact 5 % steps in calibration chart x-axis

### Fixed
- Invalid confidence values (< 0.5) in documentation examples (#82)

## [1.2.0] - 2026-03-05

### Breaking Changes

- Database schema updated; migration runs automatically on first launch.
  Downgrading to v1.0.0 is not supported without data loss.

### Added

- Overdue indicator on home screen stat cards; cards turn red with a
  warning icon when unresolved predictions have passed their deadline (#54)
- "Überfällig" filter chip in prediction list to show only overdue
  predictions across open and pending tabs (#55)
- Delete button in resolve screen AppBar with confirmation dialog (#56)
- Sort order toggle in prediction list; reverses per-tab default
  (open/pending: oldest first; resolved: newest first) (#57)
- Tag selection via FilterChips in the AI generator (#68)
- Calendar toggle in pending tab AppBar to sort by deadline;
  entries without a deadline stay at the end regardless of direction
- Global tag manager in Settings to delete tags from all predictions
  at once, with per-tag confirmation dialog (#70)
- "Ohne Tag" filter chip in prediction list; visible only when untagged
  entries exist, visually distinct via secondary-color border (#72)
- Rename action in global tag manager; inline dialog with pre-filled
  name, updates all predictions at once (#73)
- Confidence slider snaps to 5 % steps from 50 to 100 % (#71)

### Fixed

- Interval confidence slider minimum raised to 50 % (#67)
- Calibration dot size scaled proportionally to the most-populated
  bin instead of a hard clamp (#69)
- Type cast error in v3 schema migration (#73)

## [1.2.0-beta.1] - 2026-03-05

### Added
- "Ohne Tag" filter chip in prediction list; visible only when untagged
  entries exist, visually distinct via secondary-color border (#72)
- Rename action in the global tag manager; inline dialog with
  pre-filled name, updates all predictions at once (#73)
- Confidence slider now snaps to 5 % steps from 50 to 100 %;
  one-time startup migration rounds existing values (#71)

### Fixed
- Type cast error in v3 schema migration (`addColumn` expected
  `GeneratedColumn<Object>`) (#73)

## [1.1.1-beta.1] - 2026-03-05

### Added
- Calendar toggle in the pending tab AppBar to sort by deadline;
  entries without a deadline stay at the end regardless of direction
- Global tag manager in Settings to delete tags from all predictions
  at once, with per-tag confirmation dialog (#70)

## [1.1.0-beta.1] - 2026-03-05

### Added
- Overdue indicator on home screen stat cards; cards turn red with a
  warning icon when unresolved predictions have passed their deadline (#54)
- "Überfällig" filter chip in prediction list to show only overdue
  predictions across open and pending tabs (#55)
- Delete button in resolve screen AppBar with confirmation dialog (#56)
- Sort order toggle in prediction list; reverses per-tab default
  (open/pending: oldest first; resolved: newest first) (#57)
- Tag selection via FilterChips in the AI generator, sourced from
  existing database tags (#68)

### Fixed
- Interval confidence slider minimum raised to 50 %; calibration bins
  restructured to cover 50–100 % range (#67)
- Calibration dot size scaled proportionally to the most-populated
  bin instead of a hard clamp (#69)

## [1.0.0] - 2026-03-04

First stable release of Kailibrate. All features from the v0.20–v0.28
beta cycle are considered production-ready. The database schema (v5),
import/export format (v2), and public API surface are now stable;
breaking changes will follow semver and require a major version bump.

## [0.28.0] - 2026-03-04

### Added
- AI-powered question catalog generator via OpenRouter; configurable
  prompt templates, question count (5/10/15/20), and model selection
- API key for OpenRouter stored securely; write-only after saving (#40)
- Preview screen before AI import with share-as-obfuscated-JSON option
- Tags input in AI generator restricts LLM-assigned labels (#36)
- Generation cost and token count shown after each AI run (#39, #50)
- Configurable model list (one per line); selection persists per session
- Aleatory AI templates for binary and interval predictions (#46)
- `{date}` placeholder in aleatory templates for future-only deadlines
- Warning and exclusion checkbox for past-deadline questions in preview
- New `factual` prediction type for epistemic Wahr/Falsch questions (#43)
- Wahr/Falsch UI in estimate, resolve, feedback, card, and detail views (#43)
- Deadline shown on prediction cards with color-coded urgency (#48)
- Deadline editing from detail view for open/pending predictions (#47)
- "Überfällig" badge for overdue predictions (#47)
- Binary confidence slider restricted to 50–99 % (#33)
- Default prompt templates can be deleted and recovered (#34)

### Changed
- `probability` type replaced by `binary` (aleatory) and `factual`
  (epistemic); import parser remaps legacy entries; schema migrated to v5 (#45)
- Tapping any prediction card opens detail view; primary action via FAB (#47)
- Mixed AI template removed in favour of focused aleatory templates (#46)
- Docs restructured with why/what/how narrative and new concept pages

### Fixed
- Calibration scores use directional confidence for binary/factual
  predictions; correct "99 % FALSCH" appears in 99 % bin, not 1 % (#52)
- Resolution outcome hidden in detail view until user has estimated (#51)
- Generation cost shown prominently on AI import success screen (#50)
- Settings navigation in AI generator corrected (#31)
- AI import preview no longer reveals resolution icons (#32)
- Yes/no prompts set predictionType "binary" correctly (#35)
- Binary feedback shows actual Ja/Nein answer below verdict (#42)
- Binary correctness based on binaryChoice == outcome (#41)

## [0.28.0-beta.1] - 2026-03-04

### Fixed
- Calibration curve and scores now use directional confidence for
  binary/factual predictions; a "99 % FALSCH" estimate that was
  correct now appears in the 99 % bin, not the 1 % bin (#52)

## [0.27.0-beta.1] - 2026-03-04

### Fixed
- Generation cost and token count now shown prominently above the
  success icon after AI import (#50)
- Resolution outcome hidden in detail view until user has estimated;
  shows locked indicator instead (#51)

## [0.26.0-beta.1] - 2026-03-04

### Changed
- Restructured docs with why/what/how narrative flow
- New Konzepte page covering calibration, categories, types, and states
- New KI-Generator page with step-by-step usage guide
- Removed deprecated probability type from examples
- Fixed stale navigation description in prediction workflow

## [0.25.0-beta.1] - 2026-03-04

### Added
- Warning in AI generator preview when questions have past deadlines
- Checkbox to exclude past-deadline questions before import
- `{date}` placeholder in aleatory prompt templates so the model
  generates future-only deadlines

## [0.24.0-beta.1] - 2026-03-04

### Added
- Deadline shown on prediction cards with color-coded urgency:
  red for overdue, orange for due within 7 days (#48)

## [0.23.0-beta.1] - 2026-03-04

### Added
- Deadline can be set, changed, or cleared from the detail view
  for open and pending predictions (#47)
- Overdue open/pending predictions flagged with "Überfällig" badge
  in the overview (#47)

### Changed
- Tapping any prediction card now opens the detail view; primary
  action (Schätzen/Auflösen) surfaced via FAB for non-resolved
  predictions (#47)

## [0.22.0-beta.1] - 2026-03-04

### Added
- Aleatory AI templates for binary (Ja/Nein) and interval predictions
  on future events without known answers (#46)

### Changed
- `probability` prediction type removed; replaced by `binary` (aleatory)
  and `factual` (epistemic) throughout the app (#45)
- Import parser remaps legacy `probability` entries to `binary`/`factual`
  based on category; schema migrated to v5 (#45)
- Stats and feedback screens updated to reflect new type set (#44, #45)
- Mixed AI template removed in favour of the two focused aleatory
  templates (#46)
- LLM prompt docs and type reference updated (#45, #46)

## [0.21.0-beta.5] - 2026-03-04

### Added
- New 'factual' predictionType for epistemic Wahr/Falsch questions,
  distinct from 'binary' (Ja/Nein) used for aleatory events (#43)
- Wahr/Falsch buttons in estimate, resolve, feedback, card, and detail
  views for factual questions (#43)

### Changed
- DB migration v4 converts existing epistemic binary entries to factual (#43)
- New-prediction screen shows Wahr/Falsch segment only for epistemic
  category; Ja/Nein stays for aleatory (#43)
- Default AI prompt template updated to use predictionType "factual" (#43)

### Fixed
- Binary feedback banner now shows actual Ja/Nein answer below
  Richtig/Falsch verdict (#42)

## [0.21.0-beta.4] - 2026-03-04

### Fixed
- Yes/no questions now show green for a correct "Nein" prediction;
  color and icon are based on binaryChoice == outcome instead of
  outcome alone (feedback banner, prediction card, detail view) (#41)

## [0.21.0-beta.3] - 2026-03-04

### Added
- Tags input in AI generator: restricts which labels the LLM assigns
  to generated questions, for consistent in-app filtering (#36)
- Generation cost and token count shown in the preview after each
  run (#39)
- Info icon in model settings links to openrouter.ai/models (#37)
- Clipboard copy button for the model list (#37)

### Changed
- Model list editor replaced with a multiline text field (one model
  per line); easier to manage and paste from (#37)
- Selected model is persisted and restored on next session (#38)
- API key is now write-only: after saving, only bullet placeholders
  are shown with an "Ändern" button (#40)

### Fixed
- Yes/no question prompts (default and mixed templates) now correctly
  set predictionType: "binary" so the binary estimate UI is shown
  after import (#35)

## [0.21.0-beta.2] - 2026-03-03

### Added
- Default prompt templates can now be deleted; they are hidden via
  a per-device suppression list and remain recoverable from source
  code (#34)

## [0.21.0-beta.1] - 2026-03-03

### Added
- Configurable model list in Settings: add/remove OpenRouter models,
  first entry used as default (#34)
- Model dropdown in AI generator form, pre-filled with the first
  configured model; selection persists per session (#34)
- Binary confidence slider now spans 50–99 % (50 % = maximum
  uncertainty / guessing); below 50 % the answer direction should
  be flipped instead (#33)

### Fixed
- "Einstellungen" button in the missing-API-key card now navigates
  correctly with go_router (`context.push` instead of
  `Navigator.pushNamed`) (#31)
- Import preview in AI generator no longer reveals correct/incorrect
  icons for questions with embedded resolutions (#32)

## [0.20.0-beta.1] - 2026-03-03

### Added
- Generate epistemic quiz questions via OpenRouter AI; supports
  custom prompt templates (editable and deletable) and a
  configurable question count (5 / 10 / 15 / 20)
- API key for OpenRouter stored securely via flutter_secure_storage;
  configurable in Settings
- Preview screen before import: category, source, question count,
  first 5 questions with resolution indicators
- Share generated catalog as obfuscated v2 JSON directly from the
  preview screen, without importing first
- `ImportParser.obfuscateResolution()` as public static method for
  encoding resolutions outside the database layer

## [0.18.2] - 2026-03-03

### Fixed
- "Select all" button now toggles: first tap selects all visible predictions
  in the active tab, second tap deselects all (#29)
- Button icon and tooltip reflect current state (`select_all` ↔ `deselect`)

## [0.18.1] - 2026-03-03

### Changed
- Project renamed from Calibrate to Kailibrate: package name,
  applicationId (`dev.kailibrate.app`), database filename (`kailibrate.db`),
  notification channel ID, and app title

### Fixed
- Release workflow: APK filename in `files:` parameter corrected
  (`calibrate-` → `kailibrate-`); `fail_on_unmatched_files: true` added

## [0.18.0] - 2026-03-03

### Changed
- Project renamed from Calibrate to Kailibrate: package name, applicationId
  (`dev.kailibrate.app`), database filename (`kailibrate.db`), notification
  channel ID, app title, and all documentation updated accordingly

## [0.17.4] - 2026-03-03

### Fixed
- Interval unit (e.g. "Liter", "km") is now stored in the Questions
  table (schema v3) instead of only in Estimates; previously the unit
  was lost for imported questions without bounds, causing the estimate
  screen to ask for it again
- Estimate screen shows a read-only label instead of an editable text
  field when the unit is already known from the question or an
  existing estimate

## [0.17.3] - 2026-03-03

### Fixed
- Unit field in v2 interval imports now read from question level as
  fallback when absent from the estimate sub-object; data from
  callibrate-gen and similar tools was silently dropped (#28)
- `exportForSharing` now includes `unit` for interval predictions so
  the unit survives re-import (#28)

## [0.17.2] - 2026-03-03

### Fixed
- Unit (e.g. km, °C) now persisted and shown when estimating interval
  predictions via the estimate screen; previously lost on every save (#28)
- Prediction card shows numeric outcome with unit for resolved interval
  predictions instead of plain "Ja"/"Nein" (#28)

## [0.17.1] - 2026-03-03

### Fixed
- Tapping anywhere on a chart now opens the fullscreen view; previously
  only the bottom-left blank area responded because fl_chart's internal
  GestureDetector consumed touch events across most of the surface (#27)

## [0.17.0] - 2026-03-03

### Added
- Tap any chart on the statistics screen to open it fullscreen in
  landscape orientation for easier reading (#27)

## [0.16.1] - 2026-03-03

### Fixed
- Redundant floating action button for new prediction removed from
  home screen; the navigation tile serves as the single entry point (#26)

## [0.16.0] - 2026-03-02

### Added
- Brier Score and Log Loss history charts on the statistics screen;
  each chart shows the cumulative average after every resolved
  estimate, sorted chronologically, with a dashed coin-flip reference
  line (0.25 / ln 2) and a segmented button to limit the view to the
  last 25, 50, or 100 estimates

## [0.15.6] - 2026-03-02

### Fixed
- Interval bounds and numeric outcomes now display as integers when
  the stored value has no fractional part (e.g. "45 km" instead of
  "45.0 km"); unit is also shown in the feedback sheet's outcome row

## [0.15.5] - 2026-03-02

### Fixed
- Feedback sheet after estimating a pre-resolved question now displays
  resolution notes and the numeric outcome stored with the import (#24)

## [0.15.4] - 2026-03-02

### Fixed
- Resolve screen now shows the known answer for questions imported
  with an embedded answer (e.g. trivia catalogues) (#24)

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

[Unreleased]: https://github.com/kaijen/kailibrate/compare/v1.7.0-beta.7...HEAD
[1.7.0-beta.7]: https://github.com/kaijen/kailibrate/compare/v1.7.0-beta.6...v1.7.0-beta.7
[1.7.0-beta.6]: https://github.com/kaijen/kailibrate/compare/v1.7.0-beta.5...v1.7.0-beta.6
[1.7.0-beta.5]: https://github.com/kaijen/kailibrate/compare/v1.7.0-beta.4...v1.7.0-beta.5
[1.7.0-beta.4]: https://github.com/kaijen/kailibrate/compare/v1.7.0-beta.3...v1.7.0-beta.4
[1.7.0-beta.3]: https://github.com/kaijen/kailibrate/compare/v1.7.0-beta.2...v1.7.0-beta.3
[1.7.0-beta.2]: https://github.com/kaijen/kailibrate/compare/v1.7.0-beta.1...v1.7.0-beta.2
[1.6.0]: https://github.com/kaijen/kailibrate/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/kaijen/kailibrate/compare/v1.4.2...v1.5.0
[1.4.2]: https://github.com/kaijen/kailibrate/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/kaijen/kailibrate/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/kaijen/kailibrate/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kaijen/kailibrate/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/kaijen/kailibrate/compare/v1.0.0...v1.2.0
[1.2.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v1.1.1-beta.1...v1.2.0-beta.1
[1.1.1-beta.1]: https://github.com/kaijen/kailibrate/compare/v1.1.0-beta.1...v1.1.1-beta.1
[1.1.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v1.0.0...v1.1.0-beta.1
[1.0.0]: https://github.com/kaijen/kailibrate/compare/v0.28.0...v1.0.0
[0.28.0]: https://github.com/kaijen/kailibrate/compare/v0.19.0...v0.28.0
[0.28.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.27.0-beta.1...v0.28.0-beta.1
[0.27.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.26.0-beta.1...v0.27.0-beta.1
[0.26.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.25.0-beta.1...v0.26.0-beta.1
[0.25.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.24.0-beta.1...v0.25.0-beta.1
[0.24.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.23.0-beta.1...v0.24.0-beta.1
[0.23.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.22.0-beta.1...v0.23.0-beta.1
[0.22.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.21.0-beta.5...v0.22.0-beta.1
[0.21.0-beta.5]: https://github.com/kaijen/kailibrate/compare/v0.21.0-beta.4...v0.21.0-beta.5
[0.21.0-beta.4]: https://github.com/kaijen/kailibrate/compare/v0.21.0-beta.3...v0.21.0-beta.4
[0.21.0-beta.3]: https://github.com/kaijen/kailibrate/compare/v0.21.0-beta.2...v0.21.0-beta.3
[0.21.0-beta.2]: https://github.com/kaijen/kailibrate/compare/v0.21.0-beta.1...v0.21.0-beta.2
[0.21.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.20.0-beta.1...v0.21.0-beta.1
[0.20.0-beta.1]: https://github.com/kaijen/kailibrate/compare/v0.19.0...v0.20.0-beta.1
[0.18.2]: https://github.com/kaijen/kailibrate/compare/v0.18.1...v0.18.2
[0.18.1]: https://github.com/kaijen/kailibrate/compare/v0.18.0...v0.18.1
[0.18.0]: https://github.com/kaijen/kailibrate/compare/v0.17.4...v0.18.0
[0.17.4]: https://github.com/kaijen/kailibrate/compare/v0.17.3...v0.17.4
[0.17.3]: https://github.com/kaijen/kailibrate/compare/v0.17.2...v0.17.3
[0.17.2]: https://github.com/kaijen/kailibrate/compare/v0.17.1...v0.17.2
[0.17.1]: https://github.com/kaijen/kailibrate/compare/v0.17.0...v0.17.1
[0.17.0]: https://github.com/kaijen/kailibrate/compare/v0.16.1...v0.17.0
[0.16.1]: https://github.com/kaijen/kailibrate/compare/v0.16.0...v0.16.1
[0.16.0]: https://github.com/kaijen/kailibrate/compare/v0.15.6...v0.16.0
[0.15.6]: https://github.com/kaijen/kailibrate/compare/v0.15.5...v0.15.6
[0.15.5]: https://github.com/kaijen/kailibrate/compare/v0.15.4...v0.15.5
[0.15.4]: https://github.com/kaijen/kailibrate/compare/v0.15.3...v0.15.4
[0.15.3]: https://github.com/kaijen/kailibrate/compare/v0.15.2...v0.15.3
[0.15.2]: https://github.com/kaijen/kailibrate/compare/v0.15.1...v0.15.2
[0.15.1]: https://github.com/kaijen/kailibrate/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/kaijen/kailibrate/compare/v0.14.1...v0.15.0
[0.14.1]: https://github.com/kaijen/kailibrate/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/kaijen/kailibrate/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/kaijen/kailibrate/compare/v0.12.2...v0.13.0
[0.12.2]: https://github.com/kaijen/kailibrate/compare/v0.12.1...v0.12.2
[0.12.1]: https://github.com/kaijen/kailibrate/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/kaijen/kailibrate/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/kaijen/kailibrate/compare/v0.10.1...v0.11.0
[0.10.1]: https://github.com/kaijen/kailibrate/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/kaijen/kailibrate/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/kaijen/kailibrate/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/kaijen/kailibrate/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/kaijen/kailibrate/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/kaijen/kailibrate/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/kaijen/kailibrate/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kaijen/kailibrate/compare/v0.4.3...v0.5.0
[0.4.3]: https://github.com/kaijen/kailibrate/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/kaijen/kailibrate/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/kaijen/kailibrate/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/kaijen/kailibrate/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/kaijen/kailibrate/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/kaijen/kailibrate/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/kaijen/kailibrate/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/kaijen/kailibrate/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/kaijen/kailibrate/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/kaijen/kailibrate/releases/tag/v0.1.0
