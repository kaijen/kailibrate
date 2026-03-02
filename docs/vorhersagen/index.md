# Vorhersagen

Eine Vorhersage besteht aus einer Frage und durchläuft drei Schritte: Erfassen, Schätzen, Auflösen.

## Ablauf

```
Erfassen → Schätzen → Auflösen
```

**Erfassen** – Frage formulieren, Kategorie und Typ festlegen. Optional direkt schätzen.

**Schätzen** – Wahrscheinlichkeit eingeben. Je nach Typ: Slider (0–100 %), Ja/Nein mit Konfidenz, oder Intervall mit Konfidenz.

**Auflösen** – Tatsächliches Ergebnis eintragen. Die App zeigt danach ein Feedback-Sheet mit dem Brier-Beitrag dieser Schätzung sowie dem aktuellen Brier Score und Log Loss über alle aufgelösten Vorhersagen.

## Navigation

| Aktion | Geste |
|--------|-------|
| Neue Vorhersage | **+**-Symbol tippen |
| Schätzen | Offene Karte tippen |
| Auflösen | Ausstehende Karte tippen |
| Detail-Ansicht | Aufgelöste Karte tippen |
| Mehrere auswählen | Karte lang drücken |

## Tags

Jede Vorhersage kann beliebig viele Tags tragen. In der Vorhersagenliste filtert ein horizontaler Chip-Streifen nach Tags.

## Mehrfachauswahl und Tag-Bearbeitung

Durch langes Drücken auf eine Karte wechselt die Liste in den Auswahlmodus. Im Auswahlmodus:

- Antippen einer Karte wählt sie aus oder ab.
- **Alle auswählen** (Symbol in der AppBar) markiert alle aktuell sichtbaren Einträge des aktiven Tabs – bestehende Tag- und Tab-Filter bleiben dabei wirksam.
- **Tags bearbeiten** (Label-Symbol) öffnet einen Dialog zum Setzen neuer Tags. Die eingegebenen Tags ersetzen die bisherigen Tags aller ausgewählten Vorhersagen. Vorhandene Tags werden als Vorschläge angeboten.
- Das **×**-Symbol in der AppBar oder ein Antippen einer nicht ausgewählten Karte hebt die Auswahl auf.
