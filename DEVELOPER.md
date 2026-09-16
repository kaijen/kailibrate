# Entwicklerdokumentation – kailibrate

Diese Dokumentation richtet sich an Entwickler, die an kailibrate mitarbeiten
oder den Aufbau verstehen wollen. Sie beginnt mit einem allgemeinen Überblick
darüber, wie Android-Apps mit Flutter entstehen, erklärt anschließend die
konkrete Architektur dieses Projekts, beschreibt jede Quelldatei einzeln und
schließt mit Build-Prozess und Deployment ab.

> Benutzerorientierte Dokumentation (Bedienung, Konzepte, Import-Format) liegt
> unter `docs/` und wird als MkDocs-Site veröffentlicht. Diese Datei beschreibt
> ausschließlich die **technische** Innensicht.

---

## Inhaltsverzeichnis

1. [Flutter & Android – Grundlagen](#1-flutter--android--grundlagen)
2. [Umsetzung der Projektziele in der aktuellen Architektur](#2-umsetzung-der-projektziele-in-der-aktuellen-architektur)
3. [Dateibeschreibung in sinnvoller Reihenfolge](#3-dateibeschreibung-in-sinnvoller-reihenfolge)
4. [Build-Prozess – lokal und als GitHub-Workflow](#4-build-prozess--lokal-und-als-github-workflow)
5. [Deployment](#5-deployment)

---

## 1. Flutter & Android – Grundlagen

### Was ist Flutter?

Flutter ist ein UI-Toolkit von Google, mit dem aus **einer** Codebasis in der
Sprache **Dart** native Apps für Android, iOS, Web und Desktop gebaut werden.
kailibrate nutzt davon ausschließlich das **Android**-Ziel.

Die zentralen Bausteine:

- **Widgets** sind die Grundeinheit der Oberfläche. *Alles* ist ein Widget –
  Text, Button, Padding, ganze Bildschirme. Widgets werden zu einem Baum
  zusammengesetzt (Composition statt Vererbung). Es gibt zwei Hauptarten:
  - `StatelessWidget` – unveränderlich, rendert nur aus seinen Eingabe-Properties.
  - `StatefulWidget` – hält veränderlichen lokalen Zustand und baut sich bei
    `setState()` neu auf.
- **Deklaratives UI:** Statt die Oberfläche imperativ zu manipulieren,
  beschreibt eine `build()`-Methode, *wie die UI für den aktuellen Zustand
  aussieht*. Ändert sich der Zustand, ruft Flutter `build()` erneut auf und
  gleicht den Widget-Baum effizient ab.
- **Rendering:** Flutter zeichnet jedes Pixel selbst über die Skia/Impeller-Engine
  und benutzt **keine** nativen Android-Views. Dadurch sieht die App auf jedem
  Gerät identisch aus. Material 3 liefert das Design-System.

### Wie wird daraus eine Android-App?

Ein Flutter-Projekt enthält ein vollständiges Gradle-Android-Projekt unter
`android/`. Beim Build kompiliert Flutter den Dart-Code (im Release zu nativem
ARM-Maschinencode, AOT) und bettet ihn in eine Standard-Android-App ein:

- Einstiegspunkt auf Android-Seite ist eine `FlutterActivity`
  (siehe `MainActivity.kt`), die die Flutter-Engine hostet.
- Das `AndroidManifest.xml` deklariert Berechtigungen, Activities und Receiver.
- `android/app/build.gradle` definiert `applicationId`, SDK-Versionen und
  Signierung.
- Das Endprodukt ist eine `.apk` (oder `.aab`), die installiert oder verteilt
  werden kann.

### Wiederkehrende Muster in einer Flutter-App

| Aufgabe | Übliche Lösung | In kailibrate |
|---------|----------------|---------------|
| Zustandsverwaltung | Provider/Riverpod/Bloc | **Riverpod** |
| Navigation | Navigator / go_router | **go_router** |
| Persistenz | SQLite/Drift, Hive, Isar | **Drift (SQLite)** |
| Asynchronität | `Future`, `Stream`, `async/await` | durchgängig |
| Diagramme | fl_chart, charts_flutter | **fl_chart** |
| Code-Generierung | `build_runner` | für **Drift** |
| Paketverwaltung | `pubspec.yaml` + `pub` | siehe Abschnitt 4 |

### Asynchronität und Reaktivität

Dart ist single-threaded mit einer Event-Loop. Langlaufende Arbeit (Datenbank,
Netzwerk, Krypto) wird `await`-et oder – bei CPU-intensiver Arbeit – per
`compute()` in einen **Isolate** (separater Thread mit eigenem Speicher)
ausgelagert. `Stream`s liefern Werte über die Zeit; Drift stellt Tabellen als
`Stream` bereit, sodass die UI bei jeder Datenbankänderung automatisch neu
rendert.

---

## 2. Umsetzung der Projektziele in der aktuellen Architektur

### Das Produktziel

kailibrate hilft, persönliche Wahrscheinlichkeitsschätzungen zu **kalibrieren**:
Wer „70 %" sagt, sollte in 70 % der Fälle recht behalten. Der Kernzyklus ist:

```
Frage erfassen  →  Schätzen  →  Auflösen  →  Statistik auswerten
   (Question)      (Estimate)   (Resolution)   (CalibrationStats)
```

Fragen können manuell erfasst, aus JSON/YAML importiert oder per LLM
(OpenRouter) generiert werden.

### Schichtenarchitektur

Das Projekt folgt einer **feature-basierten Clean-Architecture-Light**-Struktur.
Statt globaler `data/domain/presentation`-Trennung pro Feature wird pragmatisch
gegliedert:

```
┌─────────────────────────────────────────────────────────────┐
│  features/<feature>/presentation/                            │
│     Screens (Widgets) + lokale Riverpod-Notifier             │
├─────────────────────────────────────────────────────────────┤
│  shared/widgets/         shared/theme/                       │
│     wiederverwendbare UI-Komponenten & Diagramme             │
├─────────────────────────────────────────────────────────────┤
│  core/services/          core/utils/                         │
│     Notification, OpenRouter, Backup, Krypto, Parser, Mathe  │
├─────────────────────────────────────────────────────────────┤
│  core/database/                                              │
│     Drift-Schema, DAOs, Migrationen, Export/Import           │
└─────────────────────────────────────────────────────────────┘
                          ▲
              core/providers.dart  (globale Riverpod-Provider)
```

**Designentscheidungen, die das Projekt prägen:**

1. **Drift (SQLite) als Single Source of Truth.** Kalibrierungsstatistiken
   erfordern Aggregationen über aufgelöste Schätzungen. SQL passt dazu besser
   als Key-Value-Stores. Die `AppDatabase` enthält neben den DAO-Methoden auch
   die Export-/Import-Logik.

2. **Ein gemeinsames View-Modell `PredictionView`** verbindet die drei
   Lebenszyklus-Tabellen (`Questions` → `Estimates` → `Resolutions`) zu einem
   Objekt mit abgeleitetem `status` (pending → needsResolution → resolved). Die
   gesamte UI arbeitet gegen dieses View-Modell statt gegen rohe Tabellenzeilen.

3. **Reaktiver Datenfluss über einen einzigen Stream.** Der
   `predictionsStreamProvider` liefert `Stream<List<PredictionView>>`. Fast alle
   Screens beobachten diesen Stream; jede Datenbankänderung propagiert
   automatisch in alle Ansichten.

4. **`probability` als kanonischer Kalibrierwert.** Unabhängig vom Eingabetyp
   (Ja/Nein, Wahr/Falsch, Intervall) wird jede Schätzung auf eine
   Wahrscheinlichkeit 0–1 reduziert. Damit funktionieren Brier Score und Log
   Loss einheitlich über alle Typen hinweg.

5. **Lokale, screen-private Notifier** für komplexe Formulare (Schätzung,
   Import, KI-Generator). Globaler Zustand bleibt minimal (`core/providers.dart`).

### Drei Vorhersagetypen

Der Typ steht in `Questions.predictionType`:

| Typ | Bedeutung | Eingabe | Kanonischer `probability`-Wert |
|-----|-----------|---------|-------------------------------|
| `binary` | aleatorisches Ja/Nein-Ereignis | Wahl + Konfidenz | `choice ? conf : 1-conf` |
| `factual` | epistemische Wahr/Falsch-Aussage | Wahl + Konfidenz | `choice ? conf : 1-conf` |
| `interval` | numerischer Wert | Unter-/Obergrenze + Konfidenz | `confidenceLevel` |

`interval`-Schätzungen werden zusätzlich über den **Winkler-Score** bewertet
(siehe `calibration_math.dart`), weil reine Trefferquote die Intervallbreite
ignorieren würde.

---

## 3. Dateibeschreibung in sinnvoller Reihenfolge

Die Reihenfolge folgt dem Datenfluss: Einstiegspunkt → Datenbank → Services →
Utilities → geteilte Widgets → Feature-Screens → Tests → Android → Konfiguration.

### 3.1 Einstieg & App-Gerüst

#### `lib/main.dart`
Der Programmstart. Läuft in `runZonedGuarded`, um **alle** unbehandelten
Exceptions zentral zu loggen (statt Absturz). Initialisiert vor dem ersten
Frame die Zeitzonendaten (`timezone`) und den `NotificationService`, dann startet
`runApp(ProviderScope(child: KailibrateApp()))`. Der `ProviderScope` ist die
Wurzel des Riverpod-Zustandsbaums – ohne ihn wäre kein Provider erreichbar.

#### `lib/app.dart`
Definiert `KailibrateApp` (ein `ConsumerStatefulWidget`) und die gesamte
go_router-Konfiguration. Wichtige Aspekte:
- **Routing-Tabelle** `_router` mit allen Pfaden (`/`, `/predictions`,
  `/estimate/:id`, `/resolve/:id`, `/prediction/:id`, `/stats`, `/import`,
  `/new`, `/settings`, `/ai-generator`). Pfadparameter werden via
  `state.pathParameters` geparst; `/predictions` liest zusätzlich einen
  `filter`-Query-Parameter und mappt ihn auf `FilterTab`.
- **`initState`-Hooks:** `_rescheduleNotifications()` plant beim App-Start alle
  Deadline-Benachrichtigungen neu (nötig nach Reboot/Update), und
  `_runConfidenceRoundingMigration()` führt eine einmalige Datenmigration aus
  (rundet alte Konfidenzwerte auf 5 %-Schritte, geschützt über einen
  `SharedPreferences`-Flag).
- Baut `MaterialApp.router` mit hellem/dunklem Theme und `ThemeMode.system`.

#### `lib/core/providers.dart`
Die globalen Riverpod-Provider:
- `appDatabaseProvider` – stellt die `AppDatabase`-Singleton-Instanz bereit und
  schließt sie via `ref.onDispose` sauber.
- `predictionsStreamProvider` – der zentrale `StreamProvider`, der
  `watchAllPredictionViews()` weiterreicht. Dies ist die Hauptdatenquelle der UI.

### 3.2 Datenbank-Schicht

#### `lib/core/database/app_database.dart`
Das Herzstück der Persistenz – Drift-Schema **und** Datenzugriffslogik in einer
Datei.

- **Tabellen:** `Questions`, `Estimates`, `Resolutions`, `ImportBatches`.
  Spalten werden als getypte Getter deklariert; Drift generiert daraus
  `app_database.g.dart`. `Estimates` hat einen `uniqueKey` auf `questionId`
  (max. eine Schätzung pro Frage), wodurch `insertOnConflictUpdate` als Upsert
  funktioniert.
- **`PredictionView`** (Plain-Dart-Klasse, keine Tabelle): bündelt
  `Question + Estimate? + Resolution?` und berechnet `status` sowie `tagList`
  (JSON-dekodierte Tags).
- **`schemaVersion = 5`** mit `MigrationStrategy.onUpgrade`. Die Migrationen
  sind kumulativ (`if (from < 2) … if (from < 5) …`): Spalten hinzufügen sowie
  per `customStatement` Datenbestände umschlüsseln (z. B. der entfernte Typ
  `probability` wird je nach Kategorie auf `binary`/`factual` gemappt). Manuelles
  SQL nur dort, wo `addColumn` nicht reicht.
- **DAO-Methoden:** gegliedert nach Tabelle (Questions, Estimates, Resolutions,
  ImportBatches) plus „Combined queries" wie `getAllPredictionViews()` und
  `watchAllPredictionViews()`. Letztere mappen den Fragen-Stream per `asyncMap`
  auf zusammengesetzte Views. `deleteQuestions` läuft in einer `transaction`,
  um referentielle Integrität zu wahren.
- **Tag-Operationen** (`updateQuestionTags`, `deleteTagGlobally`,
  `renameTagGlobally`) arbeiten auf dem JSON-Array in `Questions.tags`.
- **Export-Varianten** mit unterschiedlichem Zweck:
  - `exportForBackup()` – vollständig, **unverschleiert** (für verschlüsseltes Backup).
  - `exportForSharing()` / `exportViewsForSharing()` – aufgelöste Vorhersagen
    *ohne* eigene Schätzung; Auflösungen werden per `_obfuscateResolution`
    (ROT13 → Base64) verschleiert, damit geteilte Dateien keine Spoiler enthalten.
  - `exportAll()` – kompletter Datenexport mit verschleierten Auflösungen.
  - `restoreFromBackup()` – setzt die DB zurück und schreibt alle Daten neu.
- **`roundAllConfidenceLevels()`** – die in `app.dart` getriggerte Datenmigration.

#### `lib/core/database/app_database.g.dart` *(generiert)*
Von `drift_dev` erzeugter Code: typsichere Tabellen-/Companion-Klassen
(`Question`, `QuestionsCompanion`, …) und Query-Infrastruktur. **Nicht von Hand
bearbeiten** – wird durch `dart run build_runner build` neu erzeugt.

### 3.3 Services (`lib/core/services/`)

#### `notification_service.dart`
Singleton (`NotificationService.instance`) um `flutter_local_notifications`.
Legt beim `initialize()` den Android-Benachrichtigungskanal an und fragt die
`POST_NOTIFICATIONS`-Berechtigung (Android 13+). `scheduleDeadlineNotifications`
plant zwei Erinnerungen pro Frage (Vortag 9:00 und Deadline-Tag 9:00) über
`zonedSchedule` mit zeitzonenbewussten `tz.TZDateTime`. Notification-IDs werden
deterministisch aus `questionId` abgeleitet (`id*2` und `id*2+1`), damit
`cancelNotificationsForQuestion` sie gezielt löschen kann. `rescheduleAll`
storniert alles und plant für jede offene, zukünftige Deadline neu.

#### `openrouter_service.dart`
Statischer HTTP-Client für die OpenRouter Chat-Completions-API. `generate()`
sendet den fertigen Prompt, setzt einen 90-s-Timeout und übersetzt
HTTP-Statuscodes in aussagekräftige `OpenRouterException`s (401 = Key ungültig,
402 = Guthaben aufgebraucht). Extrahiert Antworttext sowie optional Kosten/Tokens
aus dem `usage`-Objekt und liefert ein `GenerateResult`.

#### `api_key_service.dart`
Dünne Hülle um `flutter_secure_storage` (Android Keystore). Speichert API-Key,
gewähltes Modell und die Modell-Liste verschlüsselt auf dem Gerät. Die
Modell-Liste wird als JSON serialisiert. Sensible Daten landen **nie** in
`SharedPreferences`.

#### `backup_service.dart`
Verschlüsseltes Voll-Backup. Bemerkenswert:
- **Krypto:** PBKDF2-HMAC-SHA256 (200 000 Iterationen) leitet aus dem
  Nutzerpasswort einen 256-Bit-Schlüssel ab; verschlüsselt wird mit AES-256-GCM.
- **Isolate-Auslagerung:** Die teuren Krypto-Operationen (`_encryptPayload`,
  `_decryptPayload`) sind **Top-Level-Funktionen** und laufen via `compute()` in
  einem separaten Isolate, damit die UI nicht einfriert.
- **Format:** Äußeres JSON (Version 1) mit `kdf`-Parametern, `nonce`, `mac`,
  `ciphertext` (alle Base64). Die Klartext-Payload enthält den DB-Export plus
  Konfiguration (API-Key, Modelle, Prompt-Templates, ausgeblendete Defaults).
- Falsches Passwort wird über `SecretBoxAuthenticationError` erkannt und als
  `BackupException` mit klarer Meldung weitergereicht.

#### `prompt_template_service.dart`
Verwaltet Prompt-Vorlagen für den KI-Generator. Enthält vier eingebaute
`defaults` (Wahr/Falsch, Intervall epistemisch, Ja/Nein aleatorisch, Intervall
aleatorisch) mit Platzhaltern `{topic}`, `{count}`, `{date}`. Default-Vorlagen
sind unveränderlich, lassen sich aber „ausblenden" (Suppression-Liste in
`SharedPreferences`); benutzerdefinierte Vorlagen werden als JSON persistiert.
`loadAll()` liefert sichtbare Defaults zuerst, dann eigene Vorlagen.

### 3.4 Utilities (`lib/core/utils/`)

#### `calibration_math.dart`
Reine, UI-freie Statistik – die mathematische Grundlage der App.
- `CalibrationStats.compute(pairs)` berechnet **Brier Score** und **Log Loss**
  (mit Clamping gegen `log(0)`) und gruppiert Schätzungen in elf 5 %-Bins von
  50 % bis 100 % für die Kalibrierungskurve.
- `computeHistory()` liefert den **kumulativen** Verlauf beider Scores für den
  Zeitreihen-Chart.
- `WinklerStats` bewertet **Intervall**-Schätzungen: Trefferbreite plus
  Strafterm bei Verfehlung, skaliert mit `alpha` (= 1 − Konfidenz). Niedriger ist
  besser. `computeHistory` erzeugt Einzelpunkte mit Hit/Miss-Flag und
  `questionId` für die Chart-Navigation.
- Hilfsklassen `ScorePoint`, `WinklerPoint`, `CalibrationBin`.

#### `import_parser.dart`
Wandelt JSON/YAML-Text in `ImportFile`/`ImportQuestion`-Objekte.
- `parse()` wählt anhand der Dateiendung; `parseAutoDetect()` erkennt das Format
  selbst (JSON → Markdown-Codeblock → YAML) – wichtig für aus LLM-Chats
  kopierten Text. Ein Regex extrahiert ```json/```yaml-Blöcke.
- Unterscheidet **v1** (Felder direkt auf der Frage, Top-Level-`category`) und
  **v2** (App-Export: `category` pro Frage, Schätzfelder im `estimate`-Objekt,
  Antwort via `hasKnownAnswer`/`knownAnswer`).
- Mappt unbekannte/alte `predictionType`-Werte anhand der Kategorie auf
  `binary`/`factual`. Verschleierte Auflösungen (ROT13+Base64) werden
  deobfuskiert.
- Klare `ImportParseException` mit Fragenindex bei Schemafehlern – kein
  partieller Import.

#### `format_utils.dart`
Eine einzige Funktion `formatNum`: zeigt ganze Zahlen ohne Nachkommastellen
(`45` statt `45.0`), Dezimalzahlen auf max. zwei Stellen ohne Endnullen, `null`
als `?`. Wird überall für numerische Anzeige benutzt.

### 3.5 Geteiltes Theme & Widgets (`lib/shared/`)

#### `theme/app_theme.dart`
`AppTheme.light()`/`dark()` mit Material 3 und einer `ColorScheme.fromSeed`
(Seed-Blau `#4A90D9`). Bewusst minimal – Material 3 generiert das restliche
Farbschema.

#### `widgets/estimate_inputs.dart`
Die wiederverwendbaren Schätz-Eingabe-Bausteine und ihr lokaler State:
- `EstimateFormState` + `EstimateFormNotifier` (Riverpod `StateNotifier`) halten
  `binaryChoice`, `confidenceLevel`, `lowerBoundText`, `upperBoundText`. Ein
  `_sentinel`-Objekt erlaubt explizites Setzen auf `null` im `copyWith`.
- `computeEstimateProbability()` reduziert den Formzustand auf den kanonischen
  `probability`-Wert (siehe Abschnitt 2).
- `BinaryEstimateInput` (Ja/Nein), `FactualEstimateInput` (Wahr/Falsch) und
  `IntervalEstimateInput` (zwei Zahlenfelder + Einheit) bauen auf den geteilten
  Bausteinen `ChoiceButton` und `ConfidenceSlider` auf. Der Slider arbeitet in
  5 %-Schritten ab 50 % (50 % = Raten).

#### `widgets/calibration_chart.dart`
fl_chart-`LineChart` der Kalibrierungskurve: gestrichelte Diagonale als
Perfekt-Referenz plus die tatsächlichen Bin-Punkte. Die Punktradien skalieren
mit der Anzahl Schätzungen pro Bin (mehr Daten = größerer Punkt). `expand`
schaltet zwischen quadratischer Inline-Ansicht und Vollbild.

#### `widgets/score_history_chart.dart`
Zeitreihe des kumulativen Brier Score **oder** Log Loss (`isBrier`-Flag). Zeigt
eine gestrichelte „Münzwurf"-Referenzlinie (0,25 bzw. `ln 2`). Achsenintervalle
werden dynamisch aus dem sichtbaren X-Bereich (`visibleMinX/MaxX`, für
Zoom/Pan) berechnet. Punkte werden nur bei ≤ 25 Werten gezeichnet.

#### `widgets/winkler_history_chart.dart`
Einzelne Winkler-Scores **logarithmisch** dargestellt (Scores spannen oft mehrere
Größenordnungen). Achsenbeschriftung an Dekadengrenzen. Punkte sind grün (Treffer)
oder rot (Verfehlung) eingefärbt. `lineTouchData` ist auf manuelle Treffer
geschaltet: Tap auf einen Punkt ruft `onPointTap(questionId)` für die Navigation,
Tap daneben `onBackgroundTap`.

#### `widgets/feedback_sheet.dart`
`CalibrationFeedbackSheet` – das Bottom-Sheet, das nach jeder Auflösung
erscheint. Zeigt ein farbiges Richtig/Falsch-Banner (Korrektheit bei binary/factual
hängt davon ab, ob `binaryChoice == outcome`), den Brier-Beitrag dieser
Schätzung, optionale Auflösungsnotizen/Messwerte sowie Gesamt- und
typspezifische Kalibrierung. Hilfs-Widgets `FeedbackSectionCard` und
`FeedbackStatRow` strukturieren die Anzeige.

### 3.6 Feature-Screens (`lib/features/`)

#### `home/presentation/home_screen.dart`
Dashboard und Einstiegspunkt (`ConsumerWidget`). Beobachtet
`predictionsStreamProvider`, zählt offene/ausstehende/aufgelöste/überfällige
Vorhersagen und berechnet einen Gesamt-Brier-Score via `CalibrationStats.compute`
(nur wenn Auflösungen existieren). UI: `_StatCard`-Kacheln, die per go_router auf
gefilterte Listen verlinken, plus ein Navigations-Grid (`_NavGrid`) zu allen
Features.

#### `predictions/presentation/predictions_screen.dart`
Die zentrale, filterbare Liste (`ConsumerStatefulWidget`, ~790 Zeilen).
- Vier Tabs (Alle/Offen/Ausstehend/Aufgelöst) über einen `TabController`.
- Lokaler Zustand für Tag-Auswahl, Mehrfachauswahl (`_selectedIds`), Sortierung
  (nach Erstellung oder Deadline, umkehrbar); Sortierpräferenzen werden in
  `SharedPreferences` persistiert.
- `_filteredForTab()` kombiniert Status-, Tag-, Kategorie-, Typ- und
  Fälligkeitsfilter. Tag-Filter als horizontal scrollbare `FilterChip`s.
- Batch-Operationen (Löschen, Tags bearbeiten via `_TagEditDialog`) und Teilen
  ausgewählter Vorhersagen über `db.exportViewsForSharing` + `share_plus`.

#### `predictions/presentation/prediction_card.dart`
Wiederverwendbare `StatelessWidget`-Listenkarte. Bekommt eine `PredictionView`
und optional Auswahlzustand/Callbacks. Zeigt Frage, `_StatusBadge` (farbig),
Tags, `_DeadlineChip` (mit Überfällig-/Bald-Warnung über lokale Datumslogik) und
– bei Auflösung – Ergebnis mit ✓/✗ in grün/rot. Intervall-Auflösungen zeigen
`numericOutcome` mit Einheit.

#### `predictions/presentation/prediction_detail_screen.dart`
Detailansicht einer Vorhersage (`ConsumerStatefulWidget`). Lädt die
`PredictionView` per `_load()` lokal. Zeigt Frage, bearbeitbare Deadline
(DatePicker + Neuplanung der Notification), Schätzung und – nur nach eigener
Schätzung – Auflösung in separaten Cards. Der FAB führt je nach Status zum
`EstimateScreen` oder `ResolveScreen` und lädt danach neu.

#### `estimate/presentation/estimate_screen.dart`
Eingabe einer Schätzung. `ConsumerWidget` mit `FutureBuilder` lädt Frage und ggf.
bestehende Schätzung. Nutzt einen **screen-privaten** `autoDispose`-`StateNotifierProvider`
um `EstimateFormNotifier`. Wählt je nach `predictionType` den passenden Input
(`BinaryEstimateInput`/`FactualEstimateInput`/`IntervalEstimateInput`). Beim
Speichern wird `probability` via `computeEstimateProbability` berechnet und per
`upsertEstimate` geschrieben; danach zeigt `_showFeedback()` das
`CalibrationFeedbackSheet`.

#### `resolve/presentation/resolve_screen.dart`
Auflösung erfassen. `FutureBuilder` lädt Frage + Schätzung; `_ResolveBody`
(`ConsumerStatefulWidget`) hält Notiz-/Zahlenfeld und Speicherzustand. Bei
binary/factual zwei farbige Buttons; bei interval ein gefiltertes Zahlenfeld,
dessen `outcome` automatisch gegen `[lowerBound, upperBound]` berechnet wird.
Nach `insertResolution` erscheint das Feedback-Sheet.

#### `stats/presentation/stats_screen.dart`
Auswertung (`ConsumerStatefulWidget`, ~800 Zeilen). Filtert aufgelöste
Vorhersagen nach Kategorie, Typ, Tags. `_calibrationPair()` mappt jede Schätzung
auf `(probability, outcome)` (bei binary/factual Konfidenz vs. Korrektheit).
Zeigt `CalibrationChart`, `ScoreHistoryChart`, `WinklerHistoryChart` in Cards mit
Vollbild-Dialog. Vollbild unterstützt Zoom/Pan per `GestureDetector`
(`_scaleUpdate`); `_WindowSelector` blendet ein rollierendes Fenster (25/50/100/Alle)
ein. Eine Bin-Tabelle listet Geschätzt/Anzahl/Trefferquote.

#### `import_data/presentation/import_screen.dart`
Import aus Datei oder Zwischenablage (`~680` Zeilen). `_pickFile()` (FilePicker)
und `_pasteFromClipboard()` rufen `ImportParser.parseAutoDetect()`. Ein lokaler
`_ImportNotifier`/`_ImportState` hält Parse-Ergebnis/Fehler. Dubletten werden
über `questionText` erkannt, vorab abgewählt, durchgestrichen und nicht
auswählbar dargestellt. `_doImport()` schreibt in einer `transaction` Fragen,
ggf. Schätzungen und Auflösungen und protokolliert den Batch. Eine
`_TemplateSection` zeigt kopierbare Format-Vorlagen.

#### `new_prediction/presentation/new_prediction_screen.dart`
Manuelles Erfassen (`ConsumerStatefulWidget`). Formular mit Validierung für
Frage, Kategorie, Typ, Tags und optionale Deadline. Kategoriewechsel passt den
Typ automatisch an (epistemic → factual, aleatory → binary). Tags per Chips oder
kommagetrenntem Feld, mit Vorschlägen aus dem `predictionsStreamProvider`.
Optional kann direkt geschätzt werden (`_newEstimateProvider` + Estimate-Inputs).
Bei Deadline wird die Notification geplant.

#### `settings/presentation/settings_screen.dart`
Einstellungen und Datenverwaltung (~920 Zeilen). Bündelt: Voll-Export
(`db.exportAll` → Share), verschlüsseltes Backup/Restore (`BackupService` mit
Passwort-Dialog), OpenRouter-API-Key und Modell-Liste (`ApiKeyService`),
Prompt-Template-Verwaltung (`_TemplateManagerDialog`), globale Tag-Verwaltung
(`_TagManagerDialog` mit `renameTagGlobally`/`deleteTagGlobally`),
Datenbank-Reset, Debug-Info-Sharing (`PackageInfo` + `device_info_plus`) und den
Doku-Link.

#### `ai_generator/presentation/ai_generator_provider.dart`
Zustandslogik des KI-Generators. `AiGeneratorNotifier` (`StateNotifier`) mit
`AiGeneratorState` und vier Phasen (`form` → `loading` → `preview` → `imported`).
`generate(topic)` ersetzt die Platzhalter in der gewählten Vorlage, hängt
optionale Tag-Vorgaben an, ruft `OpenRouterService.generate`, parst das Ergebnis
mit `parseAutoDetect` und übersetzt Fehler (API/Parse) in nutzbare Meldungen.
Zusätzliche `autoDispose`-Provider: `templatesProvider`, `modelListProvider`,
`initialModelProvider` (zuletzt genutztes Modell, sonst erstes).

#### `ai_generator/presentation/ai_generator_screen.dart`
Die UI dazu (~1000 Zeilen). Rendert pro Phase eine andere Ansicht:
`_buildForm` (Template-/Modell-/Themen-/Anzahl-/Tag-Auswahl, Template-Editor),
Lade-Indikator, `_buildPreview` (Checkbox-Liste der generierten Fragen mit
„vergangene Deadlines ausschließen"-Toggle) und Erfolgsansicht. Import läuft wie
im Import-Screen über eine `transaction`; Ergebnisse lassen sich als JSON teilen.

### 3.7 Tests (`test/`)

#### `test/unit/calibration_math_test.dart`
Unit-Tests der Statistik: Brier Score (perfekt ≈ 0, schlechtest ≈ 1, Zufall ≈ 0,25),
Log Loss (nicht-negativ), Bin-Zentren, Trefferquoten und Bin-Akkumulation. Reine
Logiktests ohne Flutter-Binding.

#### `test/unit/import_parser_test.dart`
Umfangreiche Tests (~620 Zeilen) des Parsers: JSON- und YAML-Eingaben, v1/v2-Schema,
Auto-Detect inkl. Markdown-Codeblöcken, Verschleierungs-Roundtrip und
Fehlerfälle mit Fragenindex.

### 3.8 Android-Projekt (`android/`)

#### `android/app/src/main/kotlin/.../MainActivity.kt`
Minimal: leitet von `FlutterActivity` ab. Die gesamte Logik liegt in Dart;
Android hostet nur die Flutter-Engine.

#### `android/app/src/main/AndroidManifest.xml`
Deklariert Berechtigungen (`INTERNET` für OpenRouter, `POST_NOTIFICATIONS`,
`RECEIVE_BOOT_COMPLETED` für Notification-Reschedule nach Reboot, Medien-Lesen
für FilePicker), die `MainActivity` (`singleTop`) und die Boot-Receiver von
`flutter_local_notifications`, die geplante Benachrichtigungen nach einem Neustart
wiederherstellen.

#### `android/app/build.gradle`
- `applicationId`/`namespace` = `dev.kailibrate.app`, `minSdk 24`,
  `compileSdk/targetSdk 36`. `versionCode`/`versionName` kommen aus Flutter
  (`flutter.versionCode`/`versionName`), gespeist aus `--build-number`/`--build-name`.
- **Signierung:** liest `key.properties` (lokal) **oder** Umgebungsvariablen
  (CI: `KEY_ALIAS`, `KEY_PASSWORD`, `KEY_STORE_PATH`, `STORE_PASSWORD`). Keystore
  und `key.properties` sind per `.gitignore` ausgeschlossen.
- `coreLibraryDesugaringEnabled` ist aktiv (nötig für
  `flutter_local_notifications` auf älteren API-Levels). `minifyEnabled`/
  `shrinkResources` sind aus, um Release-Buildprobleme zu vermeiden.

#### `android/settings.gradle` & `android/build.gradle`
Plugin-Versionen: Android Gradle Plugin 8.11.1, Kotlin 2.1.0, Flutter-Plugin-Loader.
Lädt das Flutter-Gradle-Tooling aus dem SDK-Pfad in `local.properties`.

### 3.9 Projektkonfiguration

#### `pubspec.yaml`
Manifest des Dart-Projekts: Name, Version (`MAJOR.MINOR.PATCH+BUILD`),
SDK-Constraint und alle Abhängigkeiten. Laufzeit u. a. `flutter_riverpod`,
`drift` + `sqlite3_flutter_libs`, `go_router`, `fl_chart`, `file_picker`,
`flutter_local_notifications` + `timezone`, `http`, `flutter_secure_storage`,
`cryptography`, `share_plus`. Dev u. a. `build_runner` + `drift_dev` (Codegen)
und `flutter_lints`. Unter `flutter.assets` ist `assets/sample_data/` registriert.

> Hinweis: Das `pubspec.yaml`-Versionsfeld steht auf `0.1.0+1`; die
> ausgelieferte Version wird im CI über `--build-name`/`--build-number` aus dem
> Git-Tag bzw. der Run-Nummer gesetzt (siehe Abschnitt 4/5).

#### `analysis_options.yaml`
Aktiviert die `flutter_lints`-Regeln für `flutter analyze`.

#### `assets/sample_data/`
`sample_epistemic.json` und `sample_aleatory.yaml` als Beispiel-Importe.

#### `justfile`
Task-Runner – die zentrale Befehlssammlung (siehe Abschnitt 4).

#### `mkdocs.yml`, `requirements-docs.txt`, `docs/`
Benutzerdokumentation als MkDocs-Material-Site mit `mike`-Versionierung
(siehe Abschnitt 5).

---

## 4. Build-Prozess – lokal und als GitHub-Workflow

### 4.1 Voraussetzungen

- **Flutter SDK** (stable; Dart ≥ 3.4) – installiert und im `PATH`.
- **JDK 17** für die Android-Toolchain.
- **Android SDK** mit `compileSdk 36`.
- **just** (optional, aber empfohlen) als Task-Runner.
- Für die Doku zusätzlich **Python 3.12**.

### 4.2 Lokaler Build über `just`

Der `justfile` kapselt alle wiederkehrenden Befehle:

```bash
just install     # flutter pub get – Abhängigkeiten holen
just gen         # build_runner: Drift-Code generieren (app_database.g.dart)
just gen-watch   # build_runner im Watch-Modus (während der Entwicklung)
just run         # App auf Gerät/Emulator starten (Hot Reload)
just test        # flutter test (Unit-Tests)
just lint        # flutter analyze
just apk         # Debug-APK
just release     # Release-APK
just clean       # flutter clean + build_runner clean
```

**Typischer Erstaufbau:**

```bash
just install     # Pakete laden
just gen         # generierten Drift-Code erzeugen – PFLICHT vor erstem Build,
                 # sonst fehlt app_database.g.dart und der Build schlägt fehl
just run         # App starten
```

Der Schritt `just gen` (bzw. `dart run build_runner build --delete-conflicting-outputs`)
ist essentiell: Die `*.g.dart`-Dateien sind **nicht eingecheckt** und müssen aus
den Drift-Tabellendefinitionen erzeugt werden. Bei Schemaänderungen erneut
ausführen.

### 4.3 Signierung lokal

Für einen lokalen *Release*-Build wird eine `android/app/key.properties`
angelegt (nicht eingecheckt):

```properties
keyAlias=...
keyPassword=...
storeFile=/absoluter/pfad/zu/kailibrate-release.jks
storePassword=...
```

`build.gradle` bevorzugt diese Datei, fällt sonst auf Umgebungsvariablen zurück.

### 4.4 GitHub-Workflow: Release-Build (`.github/workflows/release.yml`)

Ausgelöst durch **Push eines `v*`-Tags**. Schritte:

1. **Checkout** des Repos.
2. **JDK 17** (Temurin) und **Flutter** (stable, mit Cache) einrichten.
3. `flutter pub get`.
4. **Code generieren:** `dart run build_runner build --delete-conflicting-outputs`
   – derselbe Schritt wie lokal `just gen`.
5. **Keystore bereitstellen:** `secrets.KEYSTORE_BASE64` wird Base64-dekodiert
   nach `android/app/kailibrate-release.jks` geschrieben.
6. **Release-APK bauen:**
   `flutter build apk --release --build-name="${github.ref_name}" --build-number="${github.run_number}"`.
   Die Versionsangaben kommen also aus **Git-Tag** und **CI-Run-Nummer**, die
   Signier-Geheimnisse aus GitHub Secrets (`KEY_ALIAS`, `KEY_PASSWORD`,
   `KEY_STORE_PATH`, `STORE_PASSWORD`).
7. **APK umbenennen** zu `kailibrate-<tag>.apk`.
8. **GitHub Release erstellen** (`softprops/action-gh-release`) mit
   automatischen Release-Notes; Tags mit Bindestrich (z. B. `-beta.1`) werden als
   **Prerelease** markiert. Die APK wird als Release-Asset angehängt.

### 4.5 Versionsstrategie

Releases werden ausschließlich über Tags gesteuert. Bequem über just:

```bash
just tag v1.7.1     # setzt das Tag und pusht es – löst beide CI-Workflows aus
```

`versionName` = Tag-Name, `versionCode` = CI-Run-Nummer (monoton steigend, vom
Play Store/Installer gefordert). Das `pubspec.yaml`-Feld dient nur als lokaler
Default.

---

## 5. Deployment

kailibrate wird **nicht** über den Play Store verteilt. Es gibt zwei
Deployment-Stränge, beide getriggert durch denselben `v*`-Tag-Push und parallel
laufend:

### 5.1 App-Auslieferung (APK über GitHub Releases)

Der Release-Workflow (Abschnitt 4.4) baut die signierte APK und veröffentlicht
sie als Asset eines GitHub Release unter
`https://github.com/kaijen/kailibrate/releases`. Nutzer laden die
`kailibrate-<version>.apk` herunter und installieren sie direkt (Sideloading).
Prereleases (`-beta`, `-rc` …) werden entsprechend gekennzeichnet.

**Voraussetzungen im Repo (einmalig):** GitHub Secrets `KEYSTORE_BASE64`,
`KEY_ALIAS`, `KEY_PASSWORD`, `KEY_STORE_PATH`, `STORE_PASSWORD` hinterlegen.

### 5.2 Dokumentations-Deployment (`.github/workflows/docs.yml`)

Ausgelöst durch denselben `v*`-Tag. Veröffentlicht die MkDocs-Site:

1. Checkout mit voller History (`fetch-depth: 0` – `mike` braucht den
   `gh-pages`-Branch).
2. Python 3.12 einrichten, `pip install -r requirements-docs.txt`
   (`mkdocs-material`, `mike`).
3. Git-Bot-Identität setzen.
4. **Version aus Tag extrahieren:** `VERSION=${GITHUB_REF_NAME#v}` (Tag ohne `v`).
5. `CHANGELOG.md` nach `docs/changelog.md` kopieren (damit der Changelog Teil der
   Site ist).
6. **Mit `mike` deployen:**
   ```bash
   mike deploy --push --update-aliases <VERSION> latest
   mike set-default --push latest
   ```
   `mike` verwaltet **versionierte** Doku im `gh-pages`-Branch; jede Release-Version
   erhält ihre eigene Doku, `latest` zeigt auf die neueste.

**Lokale Vorschau der Doku:**

```bash
just docs        # mkdocs serve → http://127.0.0.1:8000
just docs-build  # statisch nach site/ bauen
```

### 5.3 Einmalige Einrichtung von GitHub Pages

Damit die Doku öffentlich erreichbar wird, muss Pages einmalig manuell aktiviert
werden:

> **Settings → Pages → Source: Deploy from branch → `gh-pages` / `/ (root)`**

Danach ist die Site unter `https://kaijen.github.io/kailibrate/` erreichbar; der
`mike`-Versionsselektor erscheint oben in der Navigation.

### 5.4 Release-Checkliste

1. `CHANGELOG.md` aktualisieren (Abschnitt `[Unreleased]` → neue Version).
2. Lokal `just test` und `just lint` grün.
3. `just tag vX.Y.Z` – pusht das Tag.
4. CI baut APK (Release-Workflow) **und** deployt Doku (Docs-Workflow) parallel.
5. GitHub Release + Doku-Version prüfen.
