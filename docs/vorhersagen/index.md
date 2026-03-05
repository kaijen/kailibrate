# Vorhersagen

Eine Vorhersage besteht aus einer Frage und durchläuft drei Schritte: Erfassen, Schätzen, Auflösen.

## Ablauf

```
Erfassen → Schätzen → Auflösen
```

**Erfassen** – Frage formulieren, Kategorie und Typ festlegen. Optional direkt schätzen und Deadline setzen.

**Schätzen** – Wahrscheinlichkeit eingeben. Je nach Typ: Slider (0–100 %), Ja/Nein mit Konfidenz, oder Intervall mit Konfidenz. Hat die Frage bereits eine Auflösung (z. B. beim Import von Trivia-Katalogen mit eingebetteter Antwort), erscheint nach dem Speichern sofort das Feedback-Sheet.

**Auflösen** – Tatsächliches Ergebnis eintragen. Hat die Frage eine bekannte Antwort (z. B. aus einem importierten Trivia-Katalog), zeigt die App diese vor den Auflösen-Buttons an. Danach erscheint ein Feedback-Sheet mit dem Brier-Beitrag dieser Schätzung sowie dem aktuellen Brier Score und Log Loss über alle aufgelösten Vorhersagen.

---

## Navigation

Das Antippen einer Vorhersagenkarte öffnet immer die **Detail-Ansicht**. Von dort aus sind alle weiteren Aktionen erreichbar.

| Aktion | Weg |
|--------|-----|
| Neue Vorhersage | **+**-Symbol tippen |
| Schätzen | Karte antippen → Detail-Ansicht → **Schätzen**-Button |
| Auflösen | Karte antippen → Detail-Ansicht → **Auflösen**-Button |
| Vorhersage löschen | Auflösungsseite → **Papierkorb-Symbol** (AppBar) |
| Mehrere auswählen | Karte lang drücken |

---

## Tags

Jede Vorhersage kann beliebig viele Tags tragen. In der Vorhersagenliste filtert ein horizontaler Chip-Streifen nach Tags. Die Filterung ist OR-verknüpft: Vorhersagen mit mindestens einem der aktiven Tags werden angezeigt.

Der Chip **Überfällig** filtert zusätzlich auf Vorhersagen, deren Deadline in der Vergangenheit liegt und die noch nicht aufgelöst sind. Auf der Übersichtsseite werden die Karten „Offen" und „Ausstehend" rot hervorgehoben, sobald überfällige Einträge existieren.

---

## Mehrfachauswahl und Tag-Bearbeitung

Durch langes Drücken auf eine Karte wechselt die Liste in den Auswahlmodus. Im Auswahlmodus:

- Antippen einer Karte wählt sie aus oder ab.
- **Alle auswählen** (Symbol in der AppBar) markiert alle aktuell sichtbaren Einträge des aktiven Tabs – bestehende Tag- und Tab-Filter bleiben dabei wirksam.
- **Tags bearbeiten** (Label-Symbol) öffnet einen Dialog zum Setzen neuer Tags. Die eingegebenen Tags ersetzen die bisherigen Tags aller ausgewählten Vorhersagen. Vorhandene Tags werden als Vorschläge angeboten.
- **Löschen** (Papierkorb-Symbol) löscht alle ausgewählten Vorhersagen nach einer Bestätigung endgültig – inklusive Schätzungen und Auflösungen.
- Das **×**-Symbol in der AppBar oder ein Antippen einer nicht ausgewählten Karte hebt die Auswahl auf.

---

## Tabs in der Vorhersagenliste

Die Liste ist in vier Tabs unterteilt:

| Tab | Inhalt | Standard-Sortierung |
|-----|--------|---------------------|
| Alle | Alle Vorhersagen | Erstelldatum aufsteigend |
| Offen | Noch nicht geschätzte Vorhersagen | Erstelldatum aufsteigend |
| Ausstehend | Geschätzte, aber noch nicht aufgelöste Vorhersagen | Erstelldatum aufsteigend |
| Aufgelöst | Abgeschlossene Vorhersagen | Auflösungsdatum absteigend |

Das Pfeil-Symbol in der AppBar kehrt die Sortierung des aktiven Tabs um.
