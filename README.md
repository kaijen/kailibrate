# Callibrate

Android-App zum Kalibrieren persönlicher Wahrscheinlichkeitsschätzungen.

Wer sagt „70 % Wahrscheinlichkeit", sollte damit in 70 % der Fälle recht behalten. Callibrate misst, ob das stimmt – und zeigt, wo Schätzungen systematisch zu hoch oder zu niedrig ausfallen.

---

## Was die App kann

- **Vorhersagen erfassen** – manuell oder per JSON/YAML-Import (Datei oder Zwischenablage)
- **Wahrscheinlichkeit schätzen** – Slider von 0 bis 100 %
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

Fragenkataloge lassen sich als JSON oder YAML importieren – per Dateiauswahl oder direkt aus der Zwischenablage:

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
    }
  ]
}
```

```yaml
version: 1
category: aleatory
source: Börsenwetten Q1 2026
questions:
  - text: Schließt der DAX am 31.03.2026 über 21000 Punkten?
    tags: [finance]
    deadline: "2026-03-31"
```

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
