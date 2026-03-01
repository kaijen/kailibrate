# CLAUDE.md

Dieses Dokument ist in zwei Teile gegliedert:

- **Teil 1** – Allgemeine Muster und Boilerplate für Flutter-Android-Projekte
  dieser Bauart; wiederverwendbar für ähnliche Apps.
- **Teil 2** – Projektspezifische Rahmenbedingungen für Callibrate.

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
    final file = File(p.join(dir.path, 'callibrate.db'));
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
      "text": "War Albert Einstein Linkshänder?",
      "tags": ["history", "science"],
      "answer": false,
      "deadline": null
    },
    {
      "text": "Liegt Santiago de Chile östlich von New York?",
      "tags": ["geography"],
      "answer": true
    }
  ]
}
```

```yaml
version: 1
category: aleatory
source: Wetterprognosen März 2026
questions:
  - text: Regnet es am 15. März in Berlin?
    tags: [weather, daily]
    deadline: "2026-03-15"
  - text: Überschreitet der DAX am 31. März 22000 Punkte?
    tags: [finance]
    deadline: "2026-03-31"
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

Callibrate ist eine Android-App (Flutter) zum Kalibrieren persönlicher
Wahrscheinlichkeitsschätzungen. Nutzer erfassen Vorhersagen zu beliebigen
Ereignissen, schätzen deren Eintrittswahrscheinlichkeit und lösen sie auf.
Statistiken zeigen, ob 70 %-Vorhersagen wirklich zu 70 % eintreten.

Zusätzlich zum manuellen Erfassen können Fragenkataloge als JSON oder YAML
importiert werden – nützlich für Trivia-Sammlungen (epistemisch) oder
strukturierte Prognoseübungen (aleatorisch).

---

## Projektstruktur (aktuell)

```
callibrate/
├── CLAUDE.md
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── justfile
├── .gitignore
├── android/
│   └── app/
│       ├── build.gradle
│       └── src/main/AndroidManifest.xml
├── assets/
│   └── sample_data/
│       ├── sample_epistemic.json   # Beispiel-Trivia für epistemische Kalibrierung
│       └── sample_aleatory.yaml    # Beispiel für aleatorische Schätzungen
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart   # Drift-Schema
│   │   │   ├── app_database.g.dart # generiert
│   │   │   └── daos/
│   │   │       ├── questions_dao.dart
│   │   │       ├── estimates_dao.dart
│   │   │       └── resolutions_dao.dart
│   │   ├── models/
│   │   │   ├── question.dart       # Freezed
│   │   │   ├── estimate.dart       # Freezed
│   │   │   └── resolution.dart     # Freezed
│   │   └── utils/
│   │       ├── import_parser.dart  # JSON/YAML → Question-Liste
│   │       └── calibration_math.dart
│   ├── features/
│   │   ├── predictions/
│   │   │   ├── data/
│   │   │   │   └── predictions_repository.dart
│   │   │   └── presentation/
│   │   │       ├── predictions_provider.dart
│   │   │       ├── predictions_screen.dart
│   │   │       └── prediction_card.dart
│   │   ├── estimate/
│   │   │   └── presentation/
│   │   │       ├── estimate_provider.dart
│   │   │       └── estimate_screen.dart
│   │   ├── resolve/
│   │   │   └── presentation/
│   │   │       ├── resolve_provider.dart
│   │   │       └── resolve_screen.dart
│   │   ├── stats/
│   │   │   └── presentation/
│   │   │       ├── stats_provider.dart
│   │   │       └── stats_screen.dart
│   │   ├── import_data/
│   │   │   └── presentation/
│   │   │       ├── import_provider.dart
│   │   │       └── import_screen.dart
│   │   └── settings/
│   │       └── presentation/
│   │           └── settings_screen.dart
│   └── shared/
│       ├── widgets/
│       │   ├── probability_slider.dart
│       │   └── calibration_chart.dart
│       └── theme/
│           └── app_theme.dart
├── test/
│   ├── unit/
│   │   ├── calibration_math_test.dart
│   │   └── import_parser_test.dart
│   └── widget/
│       └── estimate_screen_test.dart
└── integration_test/
    └── app_test.dart
```

---

## Datenmodell

### Datenbanktabellen (Drift)

```dart
// Frage / Vorhersage-Gegenstand
class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get text => text()();
  TextColumn get category => text()();        // 'epistemic' | 'aleatory'
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON-Array
  TextColumn get source => text().nullable()(); // Herkunft beim Import
  BoolColumn get hasKnownAnswer => boolean().withDefault(const Constant(false))();
  BoolColumn get knownAnswer => boolean().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Schätzung (Wahrscheinlichkeitsbewertung)
class Estimates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id)();
  RealColumn get probability => real()();    // 0.0–1.0
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Auflösung (tatsächliches Ergebnis)
class Resolutions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id)();
  BoolColumn get outcome => boolean()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().withDefault(currentDateAndTime)();
}

// Importprotokoll
class ImportBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filename => text()();
  TextColumn get source => text().nullable()();
  IntColumn get questionCount => integer()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
}
```

### Freezed-Domänenmodelle

```dart
@freezed
class Prediction with _$Prediction {
  const factory Prediction({
    required int id,
    required String text,
    required String category,    // 'epistemic' | 'aleatory'
    required List<String> tags,
    double? probability,         // null = noch nicht geschätzt
    bool? outcome,               // null = noch nicht aufgelöst
    DateTime? deadline,
    DateTime? resolvedAt,
  }) = _Prediction;
}
```

---

## Screens und Navigation

| Route | Screen | Beschreibung |
|-------|--------|--------------|
| `/` | HomeScreen | Dashboard mit Übersicht und offenen Schätzungen |
| `/predictions` | PredictionsScreen | Liste aller Vorhersagen, filterbar |
| `/new` | NewPredictionScreen | Manuelle Erfassung einer neuen Vorhersage |
| `/estimate/:id` | EstimateScreen | Wahrscheinlichkeit schätzen (Slider 0–100 %) |
| `/resolve/:id` | ResolveScreen | Ergebnis eintragen |
| `/stats` | StatsScreen | Kalibrierungsstatistiken und Diagramme |
| `/import` | ImportScreen | JSON/YAML-Datei laden und importieren |
| `/settings` | SettingsScreen | App-Einstellungen |

---

## Kalibrierungsstatistiken

### Brier Score

```
BS = (1/N) × Σ (pᵢ - oᵢ)²
```

- `pᵢ`: geschätzte Wahrscheinlichkeit (0–1)
- `oᵢ`: tatsächliches Ergebnis (0 oder 1)
- Wertebereich: 0 (perfekt) bis 1 (maximal schlecht)

### Log Loss

```
LL = -(1/N) × Σ [oᵢ × log(pᵢ) + (1-oᵢ) × log(1-pᵢ)]
```

Empfindlicher gegenüber extremen Fehlschätzungen als Brier.

### Kalibrierungskurve

Schätzungen in Wahrscheinlichkeitsbins gruppieren (z.B. 0–10 %, 10–20 %, …).
Pro Bin: erwarteter Wert (Mitte des Bins) vs. tatsächliche Trefferquote.
Gut kalibriert: Punkte liegen auf der Diagonale.

### Diagramme (fl_chart)

| Diagramm | Inhalt |
|----------|--------|
| Kalibrierungskurve | Bin-Mitte vs. Trefferquote; Diagonale als Referenz |
| Häufigkeitshistogramm | Wie oft welche Wahrscheinlichkeit vergeben wurde |
| Brier/Log-Loss-Verlauf | Rollender Durchschnitt über Zeit |

---

## Kategoriensemantik

| Kategorie | Bedeutung | Beispiele |
|-----------|-----------|-----------|
| `epistemic` | Unkenntnis reduzierbar durch Information; richtige Antwort existiert | Trivia, Historisches, Faktfragen |
| `aleatory` | Inhärente Zufälligkeit; kein Zusatzwissen hilft | Wetter, Börsenkurse, Sportergebnisse |

Die Kategorie beeinflusst die Darstellung und kann separat ausgewertet werden.

---

## Paket-Setup (pubspec.yaml)

```yaml
name: callibrate
description: Kalibriere deine Wahrscheinlichkeitsschätzungen.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.4
  path: ^1.9.0
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  go_router: ^14.6.2
  file_picker: ^8.1.4
  yaml: ^3.1.2
  fl_chart: ^0.69.0
  intl: ^0.19.0
  share_plus: ^10.1.4

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

flutter:
  uses-material-design: true
  assets:
    - assets/sample_data/
```

---

## Import-Workflow

1. Nutzer wählt Datei über `file_picker` (JSON oder YAML) **oder** fügt Text aus der Zwischenablage ein (`parseAutoDetect()` erkennt Format automatisch).
2. `import_parser.dart` liest und validiert das Schema.
3. Vorschau: Liste der Fragen, Kategorie, Anzahl – Nutzer bestätigt.
4. Fragen werden in `Questions`-Tabelle geschrieben, Batch in `ImportBatches` protokolliert.
5. Bei Duplikaten (identischer Text): überspringen oder ersetzen – konfigurierbar.

Fehler bei ungültigem Schema → Fehlermeldung mit Zeilennummer, kein partieller Import.

---

## Build-Workflow

| Befehl | Beschreibung |
|--------|--------------|
| `just install` | `flutter pub get` |
| `just gen` | Code generieren (Drift, Riverpod, Freezed) |
| `just gen-watch` | Code kontinuierlich generieren (Entwicklung) |
| `just run` | App auf Gerät/Emulator starten |
| `just test` | Tests ausführen |
| `just lint` | Analyse |
| `just apk` | Debug-APK bauen |
| `just release` | Release-APK bauen |

Verteilung: APK-Datei direkt; kein Play Store geplant.

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

- Ungültige Import-Datei → Fehlerdialog mit Ursache; kein Absturz
- Leere Datenbank (erster Start) → Onboarding-Hinweis auf Import oder manuelle Eingabe
- Unaufgelöste Fragen nach Deadline → Badge im Dashboard
- Alle unbehandelten Exceptions → `FlutterError.onError` loggen; in Prod kein Stack-Trace anzeigen

---

## Beispiel: Epistemisches Quiz (Import)

```json
{
  "version": 1,
  "category": "epistemic",
  "source": "Geografie-Trivia",
  "questions": [
    {
      "text": "Liegt Santiago de Chile östlich von New York?",
      "tags": ["geography"],
      "answer": true
    },
    {
      "text": "Hat Australien mehr Schafe als Einwohner?",
      "tags": ["geography", "animals"],
      "answer": true
    },
    {
      "text": "Ist der Nil länger als der Amazonas?",
      "tags": ["geography"],
      "answer": false
    }
  ]
}
```

---

## Beispiel: Aleatorische Prognosen (Import)

```yaml
version: 1
category: aleatory
source: Börsenwetten Q1 2026
questions:
  - text: Schließt der DAX am 31.03.2026 über 21000 Punkten?
    tags: [finance, dax]
    deadline: "2026-03-31"
  - text: Gewinnt Bayern München die Bundesliga 2025/26?
    tags: [sport, football]
    deadline: "2026-05-31"
```
