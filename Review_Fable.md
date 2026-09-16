# Projekt-Review kailibrate

**Datum:** 2026-06-09
**Stand:** Branch `main` (d68c64a), App-Version laut CHANGELOG 1.7.1-beta.1
**Umfang:** Gesamter Dart-Code (`lib/`, ~10.600 Zeilen), Tests, Android-Konfiguration, CI-Workflows, Doku (CLAUDE.md, docs/), Beispieldaten

Fokus: Fehler, Inkonsistenzen, Best-Practice-Verstöße, Security, Verbesserungspotenzial.
Jedes Finding hat eine ID (z. B. `H1`), damit es später als Arbeitsgrundlage referenzierbar ist.

---

## Zusammenfassung

Der Code ist insgesamt gut strukturiert (Feature-Ordner, klare Service-Schicht, durchdachte
UX-Details wie Spoiler-Schutz und Duplikat-Erkennung beim Import). Die Backup-Verschlüsselung
ist solide aufgebaut (PBKDF2 200k + AES-256-GCM, `Random.secure`). Es gibt aber eine Handvoll
echter Korrektheitsfehler – zwei davon betreffen den Kern der App (Scoring und Erinnerungen) –
sowie systematische Doku-Drift und fehlende CI-Absicherung.

| Priorität | Anzahl | Schwerpunkte |
|-----------|--------|--------------|
| Hoch | 5 | Winkler-Score fachlich falsch, Notifications in UTC, inkonsistente Brier-Berechnung, Datenverlust-Risiko bei Restore, kein CI |
| Mittel | 10 | DB-Constraints, Stream-Watching, Import-Bugs/-Validierung, OpenRouter-Parsing, Notification-Lifecycle, Doku-Drift |
| Niedrig | 9 | Manifest-Permissions, Fehlerbehandlung, Testlücken, Kleinigkeiten |

---

## Priorität HOCH

### H1 – Winkler-Score: α invertiert, Anreizstruktur falsch herum

**Ort:** `lib/core/utils/calibration_math.dart` (`WinklerStats.compute`, `computeHistory`),
`lib/features/stats/presentation/stats_screen.dart:454` (`alpha: e.confidenceLevel`),
`docs/statistiken.md`

Der Standard-Winkler/Interval-Score (Gneiting & Raftery) bestraft verfehlte Intervalle mit
`2·Distanz/α`, wobei **α die Fehlertoleranz** ist (`α = 1 − Konfidenzniveau`, z. B. 0.1 bei
einem 90 %-Intervall). Der Code übergibt stattdessen das **Konfidenzniveau selbst** als α:

```dart
winklerInputs.add((..., alpha: e.confidenceLevel, ...));  // 0.9 statt 0.1
```

Folgen:
- Die Strafe für ein verfehltes 90 %-Intervall ist `2·d/0.9 ≈ 2.2·d` statt korrekt `2·d/0.1 = 20·d` – um Faktor ~9 zu mild.
- **Die Anreizrichtung ist invertiert:** Wer mit 95 % Konfidenz danebenliegt, wird *milder*
  bestraft als wer mit 55 % danebenliegt. Korrekt wäre das Gegenteil.
- `docs/statistiken.md` dokumentiert dieselbe falsche Formel („Konfidenzniveau α") – Code und
  Doku sind konsistent zueinander, aber beide weichen von der Fachliteratur ab.

**Empfehlung:**
1. `alpha: (1 - e.confidenceLevel)` übergeben; bei `confidenceLevel == 1.0` auf ein Minimum
   klemmen (z. B. 0.01), um Division durch 0 zu vermeiden.
2. Formel in `docs/statistiken.md` korrigieren (α = 1 − Konfidenz).
3. Unit-Tests für `WinklerStats` ergänzen (gibt es bisher nicht, siehe L8) – inkl. des Falls
   „höhere Konfidenz ⇒ härtere Strafe bei Miss".
4. In den Release Notes erwähnen, dass sich historische Winkler-Werte ändern (reine
   Anzeige-Größe, keine Datenmigration nötig).

### H2 – Notifications werden in UTC geplant statt in lokaler Zeit

**Ort:** `lib/main.dart:12`, `lib/core/services/notification_service.dart:48`

`tz.initializeTimeZones()` lädt nur die Datenbank; `tz.local` bleibt ohne
`tz.setLocalLocation(...)` auf dem Default **UTC**. `scheduleDeadlineNotifications` baut
`TZDateTime(tz.local, …, 9)` – die „9:00 Uhr"-Erinnerung feuert also um 9:00 UTC
(in Deutschland 10:00/11:00 Uhr, je nach Sommerzeit; in anderen Zonen ggf. mitten in der
Nacht oder am falschen Tag). Auch die Vergleiche `dayBefore.isAfter(now)` arbeiten mit der
falschen Zone.

**Empfehlung:** Paket `flutter_timezone` aufnehmen und in `main()`:

```dart
tz.initializeTimeZones();
final name = await FlutterTimezone.getLocalTimezone();
tz.setLocalLocation(tz.getLocation(name));
```

### H3 – Drei verschiedene Brier-Score-Berechnungen in der App

**Ort:** `lib/features/stats/presentation/stats_screen.dart:782` (`_calibrationPair`),
`lib/features/home/presentation/home_screen.dart:59`,
`lib/features/resolve/presentation/resolve_screen.dart:152`,
`lib/features/estimate/presentation/estimate_screen.dart:280`

Der Stats-Screen nutzt bewusst die „Richtungs-Semantik" (`probability = confidenceLevel`,
`outcome = Richtung korrekt?`) – mit ausführlich begründetem Doc-Kommentar. Home-Screen,
Resolve-Feedback und Estimate-Feedback nutzen dagegen die rohen Paare
(`estimate.probability`, `resolution.outcome`). Konsequenz: **Der Brier Score auf dem
Dashboard und im Feedback-Sheet stimmt nicht mit dem im Statistik-Screen überein** – für
eine Kalibrierungs-App ein Glaubwürdigkeitsproblem. Beispiel: „99 % FALSCH" korrekt
geschätzt ergibt im Stats-Screen einen Beitrag von ~0, im Feedback-Sheet von ~0.98
(p=0.01, o=0… je nach outcome) – die Zahlen widersprechen sich sichtbar direkt
nacheinander (Feedback-Sheet → Stats-Screen).

**Empfehlung:** `_calibrationPair` aus dem Stats-Screen nach
`lib/core/utils/calibration_math.dart` verschieben (z. B. als
`CalibrationStats.pairFor(PredictionView)`) und in allen vier Aufrufstellen verwenden.
Den `Brier-Beitrag` im Feedback-Sheet (`_brierContribution`) ebenfalls darauf umstellen.

### H4 – Backup-Restore nicht atomar: Datenverlust bei fehlschlagender Wiederherstellung

**Ort:** `lib/core/database/app_database.dart:425` (`restoreFromBackup`)

```dart
await resetDatabase();          // eigene Transaktion – sofort committed
await transaction(() async {    // Inserts in zweiter Transaktion
  ...
  questionText: qMap['text'] as String,   // wirft bei defektem Backup
```

Schlägt ein Insert fehl (defektes/manipuliertes Backup, unerwarteter Feldtyp – die Casts
sind hart), ist die alte Datenbank bereits unwiderruflich gelöscht, das Backup aber nicht
eingespielt. Der Nutzer verliert alle Daten, obwohl der Dialog nur vor dem Überschreiben
„durch das Backup" warnt.

**Empfehlung:** `resetDatabase()`-Logik und die Inserts in **eine** Transaktion ziehen
(Drift rollt bei Exception alles zurück). Zusätzlich die Pflichtfeld-Casts defensiv machen
(`as String?` + Validierung mit verständlicher `BackupException`).

### H5 – Keine CI für Tests und Analyse

**Ort:** `.github/workflows/` (nur `release.yml` und `docs.yml`)

Es gibt keinen Workflow, der bei Push/PR `flutter analyze` und `flutter test` ausführt.
Fehler (inkl. nicht kompilierender Code nach Drift-Schema-Änderungen) fallen erst beim
Release-Tag auf – genau das ist laut `kanban/tasks/001-android-release-build-reparieren-ci.md`
bereits passiert.

**Empfehlung:** `ci.yml` ergänzen:

```yaml
on: [push, pull_request]
steps:
  - checkout, setup-java, flutter-action (mit cache)
  - flutter pub get
  - dart run build_runner build --delete-conflicting-outputs
  - flutter analyze
  - flutter test
```

Optional zusätzlich `flutter build apk --debug`, um Android-Build-Brüche früh zu erkennen.

---

## Priorität MITTEL

### M1 – Foreign Keys werden nicht erzwungen; tote `deleteQuestion()` würde Waisen erzeugen

**Ort:** `lib/core/database/app_database.dart`

SQLite erzwingt `REFERENCES` nur mit `PRAGMA foreign_keys = ON`; Drift aktiviert das nicht
automatisch. Es fehlt ein `beforeOpen`-Callback. Aktuell schützt nur Disziplin im Code
(`deleteQuestions` löscht manuell kaskadierend). Die ungenutzte Methode
`deleteQuestion(int id)` (Zeile 160) löscht dagegen **nur** die Frage und würde verwaiste
Estimates/Resolutions hinterlassen – verwaiste Datensätze verfälschen keine Statistik
(JOIN über Question), sind aber Datenmüll.

**Empfehlung:**

```dart
MigrationStrategy(
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
  ...
)
```

`deleteQuestion(int)` entfernen oder auf die kaskadierende Variante umleiten.

### M2 – `Resolutions` ohne Unique-Constraint: Duplikate führen zu Crash

**Ort:** `lib/core/database/app_database.dart:52`, `resolve_screen.dart:122`

`Estimates` hat `uniqueKeys = [{questionId}]`, `Resolutions` nicht. `insertResolution`
kann mehrfach für dieselbe Frage aufgerufen werden (z. B. Doppel-Tap auf den
Auflösen-Button vor dem `setState`, oder künftige Codepfade). Danach wirft
`getResolutionForQuestion(...).getSingleOrNull()` einen `StateError` („Too many elements")
– die Detail-/Statistik-Screens crashen für diese Frage dauerhaft.

**Empfehlung:** `uniqueKeys => [{questionId}]` auch für `Resolutions` (Schema-Migration v6:
neue Tabelle anlegen, Daten dedupliziert kopieren) und `insertOnConflictUpdate` analog zu
`upsertEstimate` verwenden.

### M3 – `watchAllPredictionViews()` beobachtet nur die Questions-Tabelle + N+1-Queries

**Ort:** `lib/core/database/app_database.dart:272`

Der Stream basiert auf `watchAllQuestions()`; Änderungen an `Estimates`/`Resolutions`
lösen **keine** Emission aus. Das wird derzeit überall durch manuelles
`ref.invalidate(predictionsStreamProvider)` kompensiert (8+ Aufrufstellen) – jeder neue
Schreibpfad, der das vergisst, zeigt stille UI-Stale-Daten. Zusätzlich macht die Methode
pro Frage zwei Einzelqueries (N+1): bei großen Katalogen (Import von hunderten Fragen)
unnötig langsam, und sie läuft bei jedem Question-Update komplett neu.

**Empfehlung:** Eine JOIN-basierte Drift-Query verwenden, z. B.

```dart
select(questions)
  .join([
    leftOuterJoin(estimates, estimates.questionId.equalsExp(questions.id)),
    leftOuterJoin(resolutions, resolutions.questionId.equalsExp(questions.id)),
  ]).watch()
```

Damit triggern alle drei Tabellen den Stream, die `invalidate`-Aufrufe können entfallen,
und es ist eine einzige Query.

### M4 – Import-Screen: Nach Fehler bleibt der Import-Button dauerhaft gesperrt

**Ort:** `lib/features/import_data/presentation/import_screen.dart:62` (`setError`), `:349` (`_doImport`)

`_doImport` setzt `importing = true`; im `catch` wird `notifier.setError(...)` aufgerufen,
dessen `copyWith` `importing` **nicht** zurücksetzt. Der Button zeigt dann dauerhaft
„Importiere…" und ist deaktiviert – der Nutzer muss den Screen verlassen.

**Empfehlung:** In `setError` `importing: false` setzen (Feld im `copyWith` explizit
übergeben).

### M5 – `probability`-Feld wird beim Import stillschweigend verworfen (eigene Beispieldatei betroffen)

**Ort:** `lib/core/utils/import_parser.dart` (`hasEstimateData`),
`import_screen.dart:395`, `assets/sample_data/sample_epistemic.json`, `CLAUDE.md`

CLAUDE.md und die mitgelieferte `sample_epistemic.json` dokumentieren/nutzen
`"probability": 0.35` als eingebettete Schätzung. Der Parser liest das Feld, aber
`hasEstimateData` verlangt `binaryChoice` bzw. Intervallgrenzen – die Schätzung wird beim
Import **ohne Hinweis verworfen**. Die eigene Beispieldatei verhält sich also anders als
dokumentiert.

**Empfehlung:** Entweder (a) `probability` in eine Schätzung ableiten
(`binaryChoice = p >= 0.5`, `confidenceLevel = max(p, 1-p)` auf 5 %-Schritt gerundet)
oder (b) das Feld konsequent aus CLAUDE.md, Docs und Samples entfernen und beim Parsen
eine Warnung in die Vorschau aufnehmen. Variante (a) erhält Abwärtskompatibilität.

### M6 – Import-Validierung lückenhaft

**Ort:** `lib/core/utils/import_parser.dart`

- Keine Bereichsprüfung: `confidenceLevel: 7`, `probability: -2`, `lowerBound > upperBound`
  werden anstandslos übernommen und verfälschen später Statistik und UI (Slider clampt nur
  die Anzeige).
- `(version as num).toInt()` wirft einen unbehandelten `TypeError`, wenn `version` als
  String (`"1"`) geliefert wird – statt einer `ImportParseException` mit Klartext.
- Dateiendungs-Check ist case-sensitive: `FRAGEN.JSON` → „Unbekanntes Format".
- CLAUDE.md verspricht „Fehlermeldung mit Zeilennummer" – nicht implementiert (zumindest
  Fragen-Index ist vorhanden; Anspruch in der Doku senken oder umsetzen).

**Empfehlung:** Validierungsfunktion im Parser bündeln (Ranges, `lower < upper`,
robuste `num`-Konvertierung via `num.tryParse(value.toString())`), Endung mit
`toLowerCase()` prüfen.

### M7 – OpenRouter-Antwort-Parsing fragil; volle Response-Bodies in der UI

**Ort:** `lib/core/services/openrouter_service.dart:85`, `:73`

- `body['choices']?[0]` wirft bei leerer `choices`-Liste (kommt bei Moderation/Upstream-
  Fehlern mit HTTP 200 vor) einen `RangeError`, der nicht als `OpenRouterException`
  gefangen wird → „Unbekannter Fehler: RangeError…" in der UI.
- Bei `statusCode != 200` wird `response.body` ungekürzt in die Fehlermeldung übernommen
  (kann sehr lang sein bzw. interne Details enthalten).
- Es wird kein `max_tokens` gesetzt – ein fehlgeleitetes Modell kann beliebig lange (und
  teure) Antworten erzeugen.

**Empfehlung:** `choices` als Liste prüfen (`isNotEmpty`), Body in der Fehlermeldung auf
z. B. 300 Zeichen kürzen, `max_tokens` (z. B. 8000) im Request setzen.

### M8 – Notification-Lifecycle: kein Cancel bei Löschen/Auflösen

**Ort:** `prediction_detail_screen.dart:69`, `predictions_screen.dart:274`,
`resolve_screen.dart:45` (Delete-Pfade), `resolve_screen.dart:116` (Auflösen)

`deleteQuestions(...)` und das Auflösen einer Frage canceln die geplanten Erinnerungen
nicht. Bis zum nächsten App-Start (`rescheduleAll`) feuern Notifications für gelöschte
bzw. bereits aufgelöste Vorhersagen. Da Frage-IDs per `autoIncrement` nicht wiederverwendet
werden, gibt es immerhin keine ID-Kollisionen.

**Empfehlung:** In `deleteQuestions` (oder den drei Aufrufstellen) und nach
`insertResolution` `NotificationService.instance.cancelNotificationsForQuestion(id)`
aufrufen.

### M9 – Backup-Restore: KDF-Parameter ungeprüft aus der Datei übernommen

**Ort:** `lib/core/services/backup_service.dart:199`

`iterations` wird unvalidiert aus dem (untrusted) Backup gelesen. Eine manipulierte Datei
mit `iterations: 2147483647` friert die Wiederherstellung praktisch ein (DoS im
compute-Isolate); `iterations: 1` schwächt die KDF unbemerkt. Kein kritisches Risiko
(lokale, nutzerinitiierte Aktion), aber leicht zu härten.

**Empfehlung:** `iterations.clamp(100000, 1000000)` bzw. außerhalb des Bereichs mit
`BackupException` ablehnen. Positiv anzumerken: Salt/Nonce-Erzeugung (`Random.secure`),
AES-GCM und die Passwortbehandlung sind korrekt umgesetzt; der OpenRouter-API-Key liegt
nur verschlüsselt im Backup.

### M10 – Massive Doku-Drift: CLAUDE.md beschreibt ein anderes Projekt als das real existierende

**Ort:** `CLAUDE.md`, `pubspec.yaml`, `android/app/build.gradle`

Konkrete Widersprüche:

| CLAUDE.md | Realität |
|---|---|
| Schemaversion **2** | `schemaVersion => 5` |
| `predictionType`: `'probability' \| 'binary' \| 'interval'`, Default `'probability'` | `'binary' \| 'factual' \| 'interval'`, Default `'binary'` |
| Freezed-Modelle (`core/models/question.dart` …), DAOs (`daos/`), Provider-Dateien, `riverpod_annotation`, `freezed`, `mockito`, `json_serializable` | Existieren nicht; State-Management läuft über klassische `StateNotifierProvider` ohne Codegen |
| `Estimates.unit`-Beispiel `"m", "°C"` in Questions fehlt | `Questions.unit` existiert (v3) – CLAUDE.md-Tabelle veraltet |
| `test/widget/estimate_screen_test.dart`, `integration_test/` | Existieren nicht |
| `minifyEnabled true` + Proguard im Release-Build | `minifyEnabled false`, `shrinkResources false` |
| pubspec-Vorlage mit go_router etc. | `go_router` ist drin, aber `flutter_secure_storage`, `cryptography`, `http`, `flutter_local_notifications`, `timezone`, … fehlen in der CLAUDE.md-Liste |
| – | `pubspec.yaml` steht auf `0.1.0+1`, CHANGELOG auf `1.7.1-beta.1`; die echte Version kommt nur über den CI-Tag (`--build-name`). Lokale Builds melden 0.1.0, und `_launchDocs` verlinkt dann auf nicht existierende Docs-Version `0.1.0` |

Da CLAUDE.md explizit als verbindliche Arbeitsgrundlage (auch für KI-Agenten) dient, ist
diese Drift besonders schädlich – sie produziert falsche Annahmen in jeder künftigen Session.

**Empfehlung:** CLAUDE.md Teil 2 vollständig gegen den Ist-Zustand abgleichen
(Schema v5, Typen, Struktur, Abhängigkeiten, Build-Realität). pubspec-Version beim Release
mitpflegen (z. B. im `just tag`-Rezept) **oder** den CI-only-Versionsprozess in CLAUDE.md
und DEVELOPER.md dokumentieren und `_launchDocs` mit Fallback auf `latest` versehen.

---

## Priorität NIEDRIG

### L1 – ROT13/Base64-„Obfuskierung": Code-Duplikat und Erwartungsmanagement

`_rot13` + Obfuskierungslogik existieren doppelt (`app_database.dart:518`,
`import_parser.dart:313`). In eine gemeinsame Utility ziehen (`ImportParser.obfuscateResolution`
wird von der DB-Seite gar nicht genutzt). Zudem in Doku klarstellen, dass das reiner
Spoiler-Schutz ist – `notes` (können sensible Inhalte haben) sind trivial dekodierbar und
wandern bei `exportAll`/Share mit.

### L2 – AndroidManifest: überflüssige bzw. nicht existierende Permissions

`READ_MEDIA_IMAGES` wird nicht benötigt (file_picker nutzt SAF für `FileType.custom`),
`READ_MEDIA_DOCUMENT` existiert als Android-Permission gar nicht. Beide entfernen;
`READ_EXTERNAL_STORAGE (maxSdk 32)` prüfen – mit `withData: true` über SAF vermutlich auch
verzichtbar.

### L3 – Statistik-Doku vs. Code: Bin-Beschreibung stimmt nicht

`docs/statistiken.md` beschreibt „10-%-Bins (50–60 %, …)"; der Code rastet auf
5-%-Punkte (50, 55, …, 100; Rundung auf den nächsten Punkt). Außerdem clampt
`CalibrationStats.compute` Wahrscheinlichkeiten < 0.5 in den 50 %-Bin – Legacy-Daten
(alter `probability`-Typ) verzerren so den untersten Punkt. Doku angleichen; optional
Werte < 0.5 herausfiltern oder spiegeln.

### L4 – Globale Fehlerbehandlung minimal

`main.dart` nutzt nur `runZonedGuarded` + `debugPrint`; `FlutterError.onError` /
`PlatformDispatcher.instance.onError` sind nicht gesetzt (CLAUDE.md fordert das sogar).
Framework-Fehler im Release verschwinden spurlos. Die fire-and-forget-Initialisierungen in
`app.dart` (`_rescheduleNotifications`, `_runConfidenceRoundingMigration`) haben keine
eigene Fehlerbehandlung – ein Fehler dort bleibt unsichtbar (immerhin: das Migrationsflag
wird erst nach Erfolg gesetzt, ein Retry beim nächsten Start ist also möglich).

### L5 – Router: `int.parse` auf Pfadparameter ohne Fallback

`app.dart` parst `:id` mit `int.parse` – ein ungültiger Deep-Link wirft. `int.tryParse` +
`GoRouter(errorBuilder: …)` ergänzen.

### L6 – EstimateScreen: Future im `build()` und kein Vorbefüllen bestehender Schätzungen

`FutureBuilder(future: _load(db))` erzeugt bei jedem Rebuild eine neue DB-Abfrage
(Future cachen, z. B. in `initState`/`late final`). Außerdem wird eine vorhandene
Schätzung zwar geladen, aber nur deren `unit` verwendet – Auswahl/Slider starten wieder
bei Defaults, falls der Screen für eine bereits geschätzte Frage geöffnet wird.

### L7 – Tag-Operationen ohne Transaktion und mit Duplikat-Möglichkeit

`deleteTagGlobally`, `renameTagGlobally` (app_database.dart) und die Schleife in
`_editTags` (predictions_screen.dart) schreiben pro Frage einzeln ohne Transaktion.
`renameTagGlobally` kann zudem Duplikate erzeugen, wenn der Zielname bereits als Tag an
derselben Frage hängt (`map` ersetzt, dedupliziert aber nicht). In Transaktion wrappen,
nach dem Mapping `toSet().toList()`.

### L8 – Testlücken bei den kritischsten Bausteinen

Vorhanden: 13 Tests `calibration_math` (nur Brier/Bins), 32 Tests `import_parser` – gut.
Es fehlen: `WinklerStats` (siehe H1!), `CalibrationStats.computeHistory`,
`BackupService` (Encrypt/Decrypt-Roundtrip, falsches Passwort, defekte Datei),
Drift-Migrationstests (drift_dev `schema_test`), sowie jegliche Widget-Tests. Empfehlung:
mindestens Winkler + Backup-Roundtrip kurzfristig ergänzen, Migrationstests beim nächsten
Schema-Bump.

### L9 – Kleinigkeiten

- `predictions_screen.dart`: Filter-Chip für `predictionType == 'probability'` ist nach
  der v5-Migration toter Code.
- `feedback_sheet.dart:85`: deprecated `withOpacity` (anderswo bereits `withValues`).
- `ai_generator_provider.dart:153`: `debugPrint` der kompletten LLM-Rohantwort – im
  Debug-Log ok, aber bewusst lassen oder hinter `kDebugMode` ziehen.
- Template-Löschen im Settings-Dialog hat – anders als Tags/Reset/Delete – keinen
  Bestätigungsdialog.
- `docs.yml`: Beta-Tags (`v1.7.1-beta.1`) deployen die Docs und verschieben den
  `latest`-Alias auf den Beta-Stand. Prerelease-Tags vom Docs-Deploy ausnehmen oder ohne
  `latest`-Alias deployen.
- `release.yml`: `--build-name="${{ github.ref_name }}"` enthält das `v`-Präfix
  (`versionName = "v1.7.1"`); `${GITHUB_REF_NAME#v}` wie im docs-Workflow verwenden, dann
  kann der Strip-Workaround in `_launchDocs` entfallen.
- `build.gradle`: `jvmTarget 1.8` ist mit Kotlin 2.x/AGP aktuell nur noch geduldet – bei
  Gelegenheit auf 17 heben; `minifyEnabled/shrinkResources` für kleinere APKs aktivieren
  (mit Proguard-Regeln testen).

---

## Positiv hervorzuheben

- **Backup-Krypto** handwerklich sauber: PBKDF2-HMAC-SHA256 (200k), AES-256-GCM,
  `Random.secure`, KDF-Arbeit im Isolate (`compute`), API-Key nur verschlüsselt im Backup,
  Klartext-Sentinel für falsches Passwort.
- API-Key in `flutter_secure_storage` statt SharedPreferences.
- Durchdachte UX: Spoiler-Schutz für Lösungen (Detail-Screen zeigt Auflösung erst nach
  eigener Schätzung), Duplikat-Erkennung beim Import mit Vorauswahl, Markdown-Code-Block-
  Extraktion für LLM-Antworten, Konsistenz-Neuberechnung des Intervall-Outcomes beim
  Nachschätzen.
- Import-Parser hat eine solide Testabdeckung; saubere Trennung v1/v2-Format.
- Signing-Material konsequent aus dem Repo herausgehalten (`.gitignore`, env-basierte CI).

## Empfohlene Reihenfolge der Abarbeitung

1. **H5** (CI) – schützt alle weiteren Änderungen.
2. **H1 + L8** (Winkler-Fix inkl. Tests) und **H3** (einheitliche Brier-Pairs) – Kern der App.
3. **H2** (Timezone) und **H4** (atomarer Restore) – Nutzervertrauen/Datensicherheit.
4. **M1–M4** (DB-Härtung, Stream-Refactoring, Import-Bugfix) als ein DB/Import-Paket.
5. **M5–M9** einzeln, jeweils klein.
6. **M10** (CLAUDE.md-Abgleich) – verhindert Folgefehler in künftigen Sessions.
7. L-Findings opportunistisch.
