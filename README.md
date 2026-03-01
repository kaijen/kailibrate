# Callibrate

Android-App zum Kalibrieren persönlicher Wahrscheinlichkeitsschätzungen.

Wer sagt „70 % Wahrscheinlichkeit", sollte damit in 70 % der Fälle recht behalten. Callibrate misst, ob das stimmt – und zeigt, wo Schätzungen systematisch zu hoch oder zu niedrig ausfallen.

---

## Was die App kann

- **Vorhersagen erfassen** – manuell oder per JSON/YAML-Import (Datei oder Zwischenablage)
- **Wahrscheinlichkeit schätzen** – direkt beim Erfassen oder nachträglich; drei Eingabeformen: Slider, Ja/Nein mit Konfidenz, Intervall
- **Ergebnis auflösen** – nach Eintreten oder Nicht-Eintreten des Ereignisses
- **Statistiken auswerten** – Brier Score, Log Loss, Kalibrierungskurve
- **Nach Tags filtern** – horizontaler FilterChip-Streifen in der Vorhersagenliste
- **Daten exportieren** – vollständiges JSON-Backup per Android-Share-Sheet

Zwei Kategorien:

| Kategorie | Bedeutung | Beispiele |
|-----------|-----------|-----------|
| `epistemic` | Unkenntnis reduzierbar durch Information | Trivia, Historisches, Faktfragen |
| `aleatory` | Inhärente Zufälligkeit | Wetter, Börsenkurse, Sportergebnisse |

---

## Statistiken

**Brier Score** – mittlerer quadratischer Fehler der Schätzungen (0 = perfekt, 1 = maximal falsch):

```
BS = (1/N) × Σ (pᵢ - oᵢ)²
```

**Log Loss** – empfindlicher gegenüber extremen Fehlschätzungen:

```
LL = -(1/N) × Σ [oᵢ × log(pᵢ) + (1-oᵢ) × log(1-pᵢ)]
```

**Kalibrierungskurve** – Schätzungen in 10-%-Bins gruppiert, Bin-Mitte gegen tatsächliche Trefferquote. Gut kalibriert: Punkte auf der Diagonale.

---

## Import-Format

Fragenkataloge lassen sich als JSON oder YAML importieren – per Dateiauswahl oder direkt aus der Zwischenablage. Schätzungen können direkt in der Importdatei mitgeliefert werden und werden beim Import automatisch gespeichert.

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

Felder pro Frage:

| Feld | Pflicht | Beschreibung |
|------|---------|--------------|
| `text` | ja | Fragentext |
| `tags` | nein | Liste von Schlagworten |
| `answer` | nein | Bekannte Antwort (für Trivia) |
| `deadline` | nein | ISO-8601-Datum der Auflösung |
| `predictionType` | nein | `probability` (Standard), `binary`, `interval` |
| `probability` | nein | Schätzwert 0–1 (für `probability`-Typ) |
| `binaryChoice` | nein | `true`/`false` – Ja oder Nein (für `binary`) |
| `confidenceLevel` | nein | Konfidenz 0–1 (für `binary` und `interval`, Standard: 0.9) |
| `lowerBound` | nein | Untergrenze (für `interval`) |
| `upperBound` | nein | Obergrenze (für `interval`) |
| `unit` | nein | Einheit des Intervalls, z.B. `km`, `°C` |

---

## Tech-Stack

- **Flutter** – Android-App
- **Drift** (SQLite) – Persistenz mit typsicheren Queries und Aggregationen
- **Riverpod** – State Management
- **go_router** – Navigation
- **fl_chart** – Diagramme
- **share_plus** – Datei-Export via Android-Share-Sheet

---

## Entwicklung

Voraussetzungen: Flutter SDK, `just`

```sh
just install    # flutter pub get
just gen        # Code generieren (Drift + build_runner)
just run        # App auf Gerät starten
just test       # Tests ausführen
just lint       # Analyse
just apk        # Debug-APK bauen
just release    # Release-APK bauen
```

Der erste Build benötigt `just gen`, da `app_database.g.dart` nicht eingecheckt ist.

---

## Lizenz

MIT
