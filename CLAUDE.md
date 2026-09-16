# CLAUDE.md

Dieses Dokument ist in zwei Teile gegliedert:

- **Teil 1** – Allgemeine Muster und Boilerplate für Flutter-Android-Projekte
  dieser Bauart; wiederverwendbar für ähnliche Apps.
- **Teil 2** – Projektspezifische Rahmenbedingungen für kailibrate.

---

# Teil 1: Allgemeine Muster

## Flutter-App-Skeleton

Minimale Struktur für eine feature-basierte Flutter-App:

```
my-app/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── justfile
├── .gitignore
├── android/                    # Android-nativer Code und Konfiguration
├── assets/
│   └── sample_data/            # Beispiel-JSON/YAML für Import
├── lib/
│   ├── main.dart               # Entry-Point: ProviderScope + App
│   ├── app.dart                # MaterialApp + go_router-Konfiguration
│   ├── core/
│   │   ├── database/           # Drift-Schema, DAOs, Datenbankinstanz
│   │   ├── models/             # Freezed-Datenmodelle (domain-agnostisch)
│   │   └── utils/              # Hilfsfunktionen (Datum, Farbe, Formatierung)
│   ├── features/
│   │   └── <feature>/
│   │       ├── data/           # Repository-Implementierungen, DAOs
│   │       ├── domain/         # Entities, Repository-Interfaces
│   │       └── presentation/   # Screens, Widgets, Riverpod-Provider
│   └── shared/
│       ├── widgets/            # Wiederverwendbare UI-Komponenten
│       └── theme/              # AppTheme, Farben, Typografie
├── test/
│   ├── unit/
│   └── widget/
└── integration_test/
```

---

## pubspec.yaml-Minimalvorlage

```yaml
name: my_app
description: Eine Flutter-App.

publish_to: 'none'

version: 1.0.0+1        # semver+build-number; build-number für Play Store

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Persistenz
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.4
  path: ^1.9.0

  # Datenmodelle
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Navigation
  go_router: ^14.6.2

  # Import
  file_picker: ^8.1.4
  yaml: ^3.1.2

  # Diagramme
  fl_chart: ^0.69.0

  # Sonstiges
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.13
  drift_dev: ^2.21.0
  riverpod_generator: ^2.6.1
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  mockito: ^5.4.4
```

**Versionsstrategie:** `version: MAJOR.MINOR.PATCH+BUILD`. Den Build-Code
bei jedem Release inkrementieren. Für CI: `flutter build apk
--build-number=$CI_BUILD_NUMBER`.

---

## Persistenz mit Drift (SQLite)

Drift ist typsicheres reaktives SQLite für Flutter. Tabellen als Dart-Klassen
definieren, Drift generiert DAOs und Queries.

```dart
// lib/core/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get text => text()();
  TextColumn get category => text()();     // 'epistemic' | 'aleatory'
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deadline => dateTime().nullable()();
}

@DriftDatabase(tables: [Questions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kailibrate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

Migrationen über `MigrationStrategy` in `AppDatabase` – keine manuelle
SQL-Migration schreiben.

---

## State Management mit Riverpod

Riverpod-Provider nah an der Feature-Grenze halten. Code-Generierung via
`@riverpod`-Annotation nutzen.

```dart
// lib/features/predictions/presentation/predictions_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'predictions_provider.g.dart';

@riverpod
class PredictionsNotifier extends _$PredictionsNotifier {
  @override
  Future<List<Prediction>> build() async {
    final db = ref.watch(appDatabaseProvider);
    return db.allPredictions();
  }
}
```

Code generieren: `dart run build_runner build --delete-conflicting-outputs`

---

## Navigation mit go_router

```dart
// lib/app.dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/estimate/:id', builder: (_, state) =>
        EstimateScreen(id: int.parse(state.pathParameters['id']!))),
    GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
    GoRoute(path: '/import', builder: (_, __) => const ImportScreen()),
  ],
);
```

---

## Import-Format (JSON/YAML)

Fragen lassen sich als JSON oder YAML importieren. Beide Formate werden
schema-identisch behandelt.

```json
{
  "version": 1,
  "category": "epistemic",
  "source": "Meine Trivia-Sammlung 2026",
  "questions": [
    {
      "text": "Liegt Santiago de Chile östlich von New York?",
      "tags": ["geography"],
      "answer": true,
      "probability": 0.35
    }
  ]
}
```

```yaml
version: 1
category: aleatory
source: Alltagsprognosen
questions:
  - text: Wird es morgen regnen?
    tags: [weather]
    predictionType: binary
    binaryChoice: true
    confidenceLevel: 0.65
  - text: Wie viele Kilometer werde ich im März laufen?
    tags: [health]
    predictionType: interval
    lowerBound: 20
    upperBound: 45
    confidenceLevel: 0.8
    unit: km
```

Felder:

| Feld | Pflicht | Beschreibung |
|------|---------|--------------|
| `version` | ja | Schema-Version (aktuell: 1) |
| `category` | ja | `epistemic` oder `aleatory` |
| `source` | nein | Herkunftsbezeichnung der Fragensammlung |
| `questions[].text` | ja | Fragentext |
| `questions[].tags` | nein | Liste von Schlagworten |
| `questions[].answer` | nein | Bekannte Antwort (für Trivia/Historisches) |
| `questions[].deadline` | nein | ISO-8601-Datum, wann die Frage auflöst |
| `questions[].predictionType` | nein | `binary`, `factual`, `interval` (Standard: `factual` bei `epistemic`, sonst `binary`) |
| `questions[].probability` | nein | Schätzwert 0–1; wird beim Import in Richtung (`binaryChoice`) + Konfidenz umgerechnet |
| `questions[].binaryChoice` | nein | `true`/`false` – Ja/Nein bzw. Wahr/Falsch (für `binary`/`factual`) |
| `questions[].confidenceLevel` | nein | Konfidenz 0–1 (für `binary`, `factual` und `interval`, Standard: 0.9) |
| `questions[].lowerBound` | nein | Untergrenze (für `interval`) |
| `questions[].upperBound` | nein | Obergrenze (für `interval`) |
| `questions[].unit` | nein | Einheit des Intervalls, z.B. `km`, `°C` |

---

## just Task-Runner

```just
# Requires: flutter SDK, dart

# Code generieren (Drift, Riverpod, Freezed)
gen:
    dart run build_runner build --delete-conflicting-outputs

# Kontinuierlich generieren (Entwicklung)
gen-watch:
    dart run build_runner watch --delete-conflicting-outputs

# Tests ausführen
test:
    flutter test

# Analyse
lint:
    flutter analyze

# Debug-APK bauen
apk:
    flutter build apk

# Release-APK bauen
release:
    flutter build apk --release

# App auf angeschlossenem Gerät starten
run:
    flutter run

# Abhängigkeiten installieren
install:
    flutter pub get

# Alle generierten Dateien löschen
clean:
    flutter clean
    dart run build_runner clean
```

---

## Android-Konfiguration

Minimale Anpassungen in `android/app/build.gradle`:

```groovy
android {
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.example.my_app"
        minSdk = 24          // Android 7.0 – breite Abdeckung
        targetSdk = 35
        versionCode = 1      // Bei jedem Release inkrementieren
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}
```

Signing-Konfiguration nie einchecken – via Umgebungsvariablen oder
lokale `key.properties` (in `.gitignore`).

---

---

# Teil 2: Projektspezifisch

## Projektziel

kailibrate ist eine Android-App (Flutter) zum Kalibrieren persönlicher
Wahrscheinlichkeitsschätzungen. Nutzer erfassen Vorhersagen zu beliebigen
Ereignissen, schätzen deren Eintrittswahrscheinlichkeit und lösen sie auf.
Statistiken zeigen, ob 70 %-Vorhersagen wirklich zu 70 % eintreten.

Zusätzlich zum manuellen Erfassen können Fragenkataloge als JSON oder YAML
importiert werden – nützlich für Trivia-Sammlungen (epistemisch) oder
strukturierte Prognoseübungen (aleatorisch). Ein KI-Generator erzeugt
Fragenkataloge über die OpenRouter-API.

---

## Architektur-Realität (Abweichungen von Teil 1)

Teil 1 beschreibt generische Muster. Dieses Projekt weicht bewusst ab:

- **Kein Freezed, keine DAOs, kein Riverpod-Codegen.** Datenmodelle sind
  die von Drift generierten Row-Klassen (`Question`, `Estimate`,
  `Resolution`) plus das handgeschriebene View-Model `PredictionView`.
  State-Management läuft über klassische `Provider`/`StateNotifierProvider`
  ohne `@riverpod`-Annotationen.
- **Generierte Dateien sind nicht eingecheckt.** Vor Analyse/Test/Build
  immer `just gen` (build_runner) ausführen – sonst fehlt
  `app_database.g.dart`.
- **Release-Build:** `minifyEnabled false`, `shrinkResources false`
  (Aktivierung ist als #63 offen). Java/Kotlin-Target ist 17.

---

## Projektstruktur (aktuell)

```
kailibrate/
├── CLAUDE.md / DEVELOPER.md / CHANGELOG.md / Review_Fable.md
├── pubspec.yaml / analysis_options.yaml / justfile
├── mkdocs.yml / requirements-docs.txt
├── .github/workflows/
│   ├── ci.yml              # Analyse + Tests + Debug-APK bei Push/PR
│   ├── release.yml         # Release-APK bei v*-Tags
│   └── docs.yml            # Docs-Deploy bei v*-Tags (ohne Prereleases)
├── android/
│   └── app/build.gradle    # minSdk 24, target/compileSdk 36, Java 17
├── assets/sample_data/     # sample_epistemic.json, sample_aleatory.yaml
├── docs/                   # MkDocs-Benutzerdoku (siehe unten)
├── lib/
│   ├── main.dart           # Entry-Point: Zeitzonen-Init, Fehler-Handler
│   ├── app.dart            # MaterialApp + go_router + Startup-Tasks
│   ├── core/
│   │   ├── database/
│   │   │   └── app_database.dart   # Drift-Schema v6 + alle Queries
│   │   ├── providers.dart          # appDatabaseProvider, predictionsStreamProvider
│   │   ├── services/
│   │   │   ├── api_key_service.dart        # OpenRouter-Key (flutter_secure_storage)
│   │   │   ├── backup_service.dart         # Verschlüsseltes Backup (AES-GCM/PBKDF2)
│   │   │   ├── notification_service.dart   # Deadline-Erinnerungen
│   │   │   ├── openrouter_service.dart     # LLM-API-Client
│   │   │   └── prompt_template_service.dart
│   │   └── utils/
│   │       ├── calibration_math.dart   # Brier, LogLoss, Bins, Winkler, pairFor
│   │       ├── import_parser.dart      # JSON/YAML → ImportFile (+ Validierung)
│   │       ├── obfuscation.dart        # ROT13+Base64 Spoiler-Schutz
│   │       └── format_utils.dart
│   ├── features/           # je <feature>/presentation/
│   │   ├── home/  predictions/  estimate/  resolve/  stats/
│   │   ├── import_data/  new_prediction/  settings/  ai_generator/
│   └── shared/
│       ├── widgets/        # estimate_inputs, feedback_sheet,
│       │                   # calibration_chart, score_history_chart,
│       │                   # winkler_history_chart
│       └── theme/app_theme.dart
└── test/unit/              # calibration_math, import_parser, backup_service
```

Es gibt (noch) keine Widget- oder Integrationstests.

---

## Datenmodell

### Datenbanktabellen (Drift)

Schemaversion: **6** (Migrationen via `MigrationStrategy.onUpgrade`;
`beforeOpen` aktiviert `PRAGMA foreign_keys = ON`).

```dart
class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get questionText => text().named('text')();
  TextColumn get category => text()();        // 'epistemic' | 'aleatory'
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON-Array
  TextColumn get source => text().nullable()(); // Herkunft beim Import
  BoolColumn get hasKnownAnswer => boolean().withDefault(const Constant(false))();
  BoolColumn get knownAnswer => boolean().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // 'binary' | 'factual' | 'interval'
  TextColumn get predictionType =>
      text().withDefault(const Constant('binary'))();
  TextColumn get unit => text().nullable()(); // v3: Einheit für interval
}

class Estimates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id)();
  RealColumn get probability => real()();   // 0.0–1.0 – kanonischer Kalibrierwert
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get lowerBound => real().nullable()();
  RealColumn get upperBound => real().nullable()();
  TextColumn get unit => text().nullable()();
  RealColumn get confidenceLevel => real().withDefault(const Constant(0.9))();
  BoolColumn get binaryChoice => boolean().nullable()(); // true=JA/WAHR

  @override
  List<Set<Column>> get uniqueKeys => [{questionId}]; // max. eine Schätzung pro Frage
}

class Resolutions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id)();
  BoolColumn get outcome => boolean()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get numericOutcome => real().nullable()(); // für interval-Typ

  @override
  List<Set<Column>> get uniqueKeys => [{questionId}]; // v6: max. eine Auflösung
}

class ImportBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filename => text()();
  TextColumn get source => text().nullable()();
  IntColumn get questionCount => integer()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
}
```

### Vorhersagetypen

| Typ | Bedeutung | Schätz-UI |
|-----|-----------|-----------|
| `binary` | Tritt das Ereignis ein? (aleatorisch) | Ja/Nein + Konfidenz 50–100 % |
| `factual` | Ist die Aussage wahr? (epistemisch) | Wahr/Falsch + Konfidenz 50–100 % |
| `interval` | Numerische Schätzung | Unter-/Obergrenze + Konfidenz |

Der frühere Typ `probability` wurde mit Schema v5 entfernt und wird beim
Import/bei Migrationen anhand der Kategorie auf `binary`/`factual` gemappt.

### View-Model

`PredictionView` (in `app_database.dart`) bündelt `Question` + optionale
`Estimate`/`Resolution` und leitet daraus `PredictionStatus`
(`pending` → `needsResolution` → `resolved`) und `tagList` ab.
`watchAllPredictionViews()` ist eine JOIN-basierte Drift-Query, die auf
Änderungen aller drei Tabellen reagiert – kein manuelles
`ref.invalidate(predictionsStreamProvider)` nötig.

---

## Screens und Navigation

| Route | Screen | Beschreibung |
|-------|--------|--------------|
| `/` | HomeScreen | Dashboard mit Statuskarten und Navigation |
| `/predictions` | PredictionsScreen | Liste mit Tabs/Filtern, Mehrfachauswahl, Teilen |
| `/new` | NewPredictionScreen | Manuelle Erfassung einer neuen Vorhersage |
| `/estimate/:id` | EstimateScreen | Schätzung abgeben (Ja/Nein, Wahr/Falsch, Intervall) |
| `/resolve/:id` | ResolveScreen | Ergebnis eintragen |
| `/prediction/:id` | PredictionDetailScreen | Detail-Ansicht einer Vorhersage |
| `/stats` | StatsScreen | Kalibrierungsstatistiken und Diagramme |
| `/import` | ImportScreen | JSON/YAML laden bzw. aus Zwischenablage einfügen |
| `/ai-generator` | AiGeneratorScreen | Fragenkataloge per LLM (OpenRouter) erzeugen |
| `/settings` | SettingsScreen | Export/Backup, KI-Konfiguration, Tags, Reset |

Ungültige `:id`-Parameter leiten auf `/` um; unbekannte Routen zeigt der
`errorBuilder` des Routers.

---

## Kalibrierungsstatistiken

Implementiert in `core/utils/calibration_math.dart`; die Paar-Bildung
(`CalibrationStats.pairFor`) ist die einzige Quelle für alle
Brier-/Log-Loss-Anzeigen (Stats-Screen, Dashboard, Feedback-Sheets).

### Richtungs-Semantik

Für `binary`/`factual` wird nicht die rohe `probability` verwendet,
sondern `confidenceLevel` vs. „war die gewählte Richtung korrekt?“ –
das beantwortet die Frage „Wenn ich mir zu X % sicher bin, wie oft habe
ich recht?“. Für `interval` gilt: Konfidenz vs. „lag der Messwert im
Intervall?“.

### Brier Score

```
BS = (1/N) × Σ (pᵢ - oᵢ)²
```

0 = perfekt, 0.25 = Münzwurf-Niveau, 1 = maximal falsch.

### Log Loss

```
LL = -(1/N) × Σ [oᵢ × log(pᵢ) + (1-oᵢ) × log(1-pᵢ)]
```

Empfindlicher gegenüber extremen Fehlschätzungen als Brier.

### Winkler-Score (Intervalle)

Standard-Interval-Score nach Gneiting & Raftery mit Fehlertoleranz
`α = 1 − Konfidenzniveau`; Treffer kosten die Intervallbreite, Misses
zusätzlich `2·Distanz/α`. Anzeige als Einzelwerte über die Zeit (keine
Mittelung, da einheitenabhängig).

### Kalibrierungskurve

Schätzungen werden auf 5-%-Punkte zwischen 50 % und 100 % gerastet
(50, 55, …, 100). Pro Punkt: Konfidenz vs. tatsächliche Trefferquote;
gut kalibriert = Punkte auf der Diagonale. Legacy-Werte < 50 % werden
gespiegelt.

### Diagramme (fl_chart)

| Diagramm | Inhalt |
|----------|--------|
| Kalibrierungskurve | Konfidenzpunkt vs. Trefferquote; Diagonale als Referenz |
| Brier/Log-Loss-Verlauf | Kumulativer Durchschnitt über die Auflösungen |
| Winkler-Verlauf | Einzelwerte je Intervallschätzung (grün/rot) |

---

## Kategoriensemantik

| Kategorie | Bedeutung | Beispiele |
|-----------|-----------|-----------|
| `epistemic` | Unkenntnis reduzierbar durch Information; richtige Antwort existiert | Trivia, Historisches, Faktfragen |
| `aleatory` | Inhärente Zufälligkeit; kein Zusatzwissen hilft | Wetter, Börsenkurse, Sportergebnisse |

Die Kategorie beeinflusst die Darstellung, den Default-Vorhersagetyp
(`factual` vs. `binary`) und kann separat ausgewertet werden.

---

## Paket-Setup (pubspec.yaml)

```yaml
name: kailibrate
description: Kalibriere deine Wahrscheinlichkeitsschätzungen.
publish_to: 'none'
version: 0.1.0+1   # Platzhalter – echte Version kommt aus dem Git-Tag (CI)

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.4
  path: ^1.9.0
  go_router: ^14.6.2
  file_picker: ^8.1.4
  yaml: ^3.1.2
  fl_chart: ^0.69.0
  intl: ^0.19.0
  share_plus: ^10.1.4
  url_launcher: ^6.3.0
  package_info_plus: ^8.0.0
  flutter_local_notifications: ^18.0.0
  timezone: ^0.9.0
  flutter_timezone: ^5.1.0
  device_info_plus: ^12.3.0
  http: ^1.2.0
  flutter_secure_storage: ^9.2.0
  shared_preferences: ^2.3.0
  cryptography: ^2.7.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.13
  drift_dev: ^2.21.0
```

---

## Versionierung und Releases

Die **einzige verbindliche Versionsquelle ist der Git-Tag** (`v1.7.1`):

- `release.yml` baut mit `--build-name="${GITHUB_REF_NAME#v}"` und
  `--build-number=<CI-Run-Nummer>`; `build.gradle` übernimmt beides via
  `flutter.versionName`/`flutter.versionCode`.
- Das `version:`-Feld in `pubspec.yaml` bleibt bewusst auf dem
  Platzhalter `0.1.0+1` – lokale Builds melden daher 0.1.0.
  `_launchDocs` in den Einstellungen fällt in diesem Fall auf die
  `latest`-Doku zurück.
- Prerelease-Tags (`v1.7.1-beta.1`) erzeugen ein GitHub-Prerelease,
  deployen aber **keine** Doku.
- Ablauf: CHANGELOG pflegen → `just tag v<version>` → CI baut Release
  und Doku.

Verteilung: APK-Datei direkt über GitHub Releases (Sideloading);
kein Play Store geplant.

---

## Import-Workflow

1. Nutzer wählt Datei über `file_picker` (JSON oder YAML) **oder** fügt
   Text aus der Zwischenablage ein (`parseAutoDetect()` erkennt Format
   automatisch, auch in Markdown-Code-Blöcken aus LLM-Antworten).
2. `import_parser.dart` liest und validiert das Schema (Pflichtfelder,
   Wertebereiche, `lowerBound < upperBound`, robuste Zahl-Konvertierung).
3. Vorschau: Fragenliste mit Checkboxen, Duplikate (identischer Text)
   sind vorab abgewählt und durchgestrichen – Nutzer bestätigt.
4. Fragen werden in `Questions` geschrieben; enthält eine Frage
   Schätzfelder (`hasEstimateData == true`), wird sofort eine `Estimate`
   gespeichert. Ein eingebettetes `probability`-Feld wird in Richtung +
   Konfidenz umgerechnet. Mitgelieferte (ggf. obfuskierte) `resolution`
   wird als Auflösung übernommen. Batch in `ImportBatches` protokolliert.
5. Fehler bei ungültigem Schema → `ImportParseException` mit
   **Fragen-Index** in der Meldung; kein partieller Import (Transaktion).

Export: v2-Format mit pro-Frage-Metadaten; `resolution`-Felder sind
ROT13+Base64-obfuskiert (reiner Spoiler-Schutz, kein Sicherheitsfeature).

---

## Build-Workflow

| Befehl | Beschreibung |
|--------|--------------|
| `just install` | `flutter pub get` |
| `just gen` | Code generieren (Drift) – **vor erstem Build/Test nötig** |
| `just gen-watch` | Code kontinuierlich generieren (Entwicklung) |
| `just run` | App auf Gerät/Emulator starten |
| `just test` | Tests ausführen |
| `just lint` | `flutter analyze` (Infos sind fatal – Code muss lint-frei sein) |
| `just apk` | Debug-APK bauen |
| `just release` | Release-APK bauen (lokal: Version 0.1.0, siehe oben) |
| `just tag v<version>` | Release-Tag setzen und pushen (löst CI aus) |
| `just docs` | Docs lokal vorschauen (http://127.0.0.1:8000) |
| `just docs-build` | Statische Docs nach `site/` bauen |
| `just sbom` | SBOM (CycloneDX) nach `sbom.cdx.json` erzeugen (benötigt syft) |

CI (`ci.yml`) führt bei jedem Push/PR aus: `flutter pub get` →
`build_runner build` → `flutter analyze` → `flutter test` →
`flutter build apk --debug`.

---

## Benutzerdokumentation

**Tool:** MkDocs + Material for MkDocs + mike (Versionierung)

**Abhängigkeiten:** `requirements-docs.txt` (`mkdocs-material>=9.5`, `mike>=2.0`)

### Struktur der `docs/`-Seiten

| Datei | Inhalt |
|-------|--------|
| `index.md` | Übersicht, Feature-Liste, Kategorientabelle |
| `erste-schritte.md` | APK-Installation, erster Import-Flow |
| `konzepte.md` | Kategorien und Grundbegriffe |
| `vorhersagen/index.md` | Erfassen → Schätzen → Auflösen (Ablauf) |
| `vorhersagen/typen.md` | `binary`, `factual`, `interval` |
| `vorhersagen/detail-ansicht.md` | Detail-Ansicht von Vorhersagen |
| `import-export/index.md` | Import- und Export-Workflow |
| `import-export/format.md` | Vollständige Feld-Referenz |
| `import-export/beispiele.md` | JSON- und YAML-Beispiele |
| `import-export/llm-prompts.md` | Prompt-Vorlagen für LLM-generierte Kataloge |
| `ki-generator.md` | KI-Generator (OpenRouter) |
| `statistiken.md` | Brier Score, Log Loss, Winkler, Kalibrierungskurve |
| `ueber-mich.md` | Hintergrund/Werte |

### Deployment

Trigger: Push eines `v*`-Tags (ohne `-`, also keine Prereleases) →
`.github/workflows/docs.yml` läuft parallel zu `release.yml`.

Ablauf:
1. Python 3.12 + `requirements-docs.txt` installieren
2. `mike deploy --push --update-aliases <VERSION> latest`
3. `mike set-default --push latest`

URL-Schema: `https://kaijen.github.io/kailibrate/`

### Einmalige Einrichtung

GitHub Pages muss einmalig manuell aktiviert werden:
**Settings → Pages → Source: Deploy from branch → `gh-pages` / `/ (root)`**

---

## Persistenzentscheidung

**Drift (SQLite)** wurde gegenüber Alternativen gewählt:

| Option | Eignung | Ausschlussgrund |
|--------|---------|-----------------|
| Drift/SQLite | Relationen, Aggregationen, typsicher | – (gewählt) |
| Hive | Einfach, kein SQL | Keine JOINs, kein COUNT GROUP BY |
| Isar | Modern, schnell | Maturity geringer, kein SQL |
| SharedPreferences | Nur Key-Value | Keine strukturierten Daten |

Kalibrierungsstatistiken erfordern GROUP BY und Aggregationen über
aufgelöste Schätzungen – das spricht klar für SQL.

---

## Fehlerbehandlung

- Ungültige Import-Datei → Fehlermeldung mit Ursache und Fragen-Index;
  kein Absturz, kein partieller Import
- Leere Datenbank (erster Start) → Onboarding-Hinweis auf Import oder
  manuelle Eingabe
- Unaufgelöste Fragen nach Deadline → Warnfarbe im Dashboard,
  Überfällig-Filter in der Liste
- `FlutterError.onError` + `PlatformDispatcher.onError` sind in `main()`
  gesetzt (Logging); Startup-Tasks in `app.dart` fangen und loggen
  eigene Fehler
- Backup-Restore ist atomar; Entschlüsselungs-/Formatfehler erscheinen
  als verständliche `BackupException`

---

## Beispiel: Epistemisches Quiz (Import mit Schätzung)

```json
{
  "version": 1,
  "category": "epistemic",
  "source": "Geografie-Trivia",
  "questions": [
    {
      "text": "Liegt Santiago de Chile östlich von New York?",
      "tags": ["geography"],
      "answer": true,
      "probability": 0.35
    },
    {
      "text": "Hat Australien mehr Schafe als Einwohner?",
      "tags": ["geography", "animals"],
      "answer": true,
      "probability": 0.7
    },
    {
      "text": "Ist der Nil länger als der Amazonas?",
      "tags": ["geography"],
      "answer": false
    }
  ]
}
```

`probability` wird beim Import in Richtung + Konfidenz umgerechnet
(0.35 → „FALSCH mit 65 %“).

---

## Beispiel: Aleatorische Prognosen (Import mit Schätzung)

```yaml
version: 1
category: aleatory
source: Alltagsprognosen
questions:
  - text: Wird es morgen regnen?
    tags: [weather, daily]
    predictionType: binary
    binaryChoice: true
    confidenceLevel: 0.65
  - text: Wie viele Kilometer werde ich im März laufen?
    tags: [health, sport]
    predictionType: interval
    lowerBound: 20
    upperBound: 45
    confidenceLevel: 0.8
    unit: km
  - text: Schließt der DAX am 31.03.2026 über 21000 Punkten?
    tags: [finance, dax]
    deadline: "2026-03-31"
```
