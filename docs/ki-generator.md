# KI-Generator

Der KI-Generator erzeugt Fragenkataloge zu einem beliebigen Thema – vollautomatisch per Sprachmodell. Statt Fragen manuell zu formulieren oder eine Datei zu erstellen, gibt man ein Thema ein und bekommt einen fertigen, direkt importierbaren Katalog zurück.

---

## Voraussetzung: OpenRouter-API-Key

Der Generator nutzt [OpenRouter](https://openrouter.ai) als Schnittstelle zu verschiedenen Sprachmodellen. Ein API-Key ist kostenlos erhältlich; viele Modelle bieten ein Gratis-Kontingent.

**Einmalige Einrichtung:**

1. Unter [openrouter.ai](https://openrouter.ai) registrieren und einen API-Key erstellen.
2. In kailibrate **Einstellungen → API-Key** öffnen und den Key eintragen.

---

## Fragenkatalog generieren

1. Tab **KI-Generator** öffnen.
2. **Thema** eingeben, z. B. „Europäische Geschichte", „Bundesliga 2026" oder „Weltraumforschung".
3. **Anzahl** der Fragen wählen (Standard: 10).
4. **Vorlage** auswählen – die Vorlage bestimmt, welche Art von Fragen erzeugt wird (siehe unten).
5. Optional **Tags** vergeben. Vorhandene Tags aus der Datenbank können per Chip-Auswahl übernommen werden; neue Tags lassen sich zusätzlich im Textfeld eingeben. Der Generator verwendet dann ausschließlich diese Tags, was das spätere Filtern in der App erleichtert.
6. **Modell** wählen. Die Liste zeigt die verfügbaren OpenRouter-Modelle. Das zuletzt genutzte Modell wird beim nächsten Öffnen vorausgewählt.
7. **Generieren** antippen.

---

## Vorlagen

| Vorlage | Kategorie | Typ | Beschreibung |
|---------|-----------|-----|--------------|
| Wahr/Falsch-Fragen (epistemisch) | Epistemisch | Wahr/Falsch | Trivia-Fragen mit bekannter Antwort und Quellenangabe |
| Intervall-Fragen (epistemisch) | Epistemisch | Intervall | Numerische Schätzfragen (Jahre, Entfernungen, Mengen) |
| Ja/Nein-Prognosen (aleatorisch) | Aleatorisch | Ja/Nein | Zukunftsbezogene Ereignisse ohne bekannte Antwort |
| Intervall-Prognosen (aleatorisch) | Aleatorisch | Intervall | Zukünftige Messwerte ohne bekannte Antwort |

Eigene Vorlagen können in den **Einstellungen → Vorlagen** erstellt und bearbeitet werden. Vorlagen nutzen die Platzhalter `{topic}`, `{count}` und `{date}` (heutiges Datum), die beim Generieren automatisch ersetzt werden.

---

## Vorschau und Import

Nach dem Generieren erscheint eine Vorschau mit Metadaten (Anzahl, Kosten, Tokenverbrauch) sowie allen erzeugten Fragen als Auswahlliste. Alle Fragen sind zunächst angehakt. Einzelne Fragen lassen sich durch Antippen abwählen; über „Alle" und „Keine" lässt sich die Auswahl auf einen Schlag setzen. Der Import-Button zeigt die Anzahl der aktuell ausgewählten Fragen.

### Vergangene Deadlines

Enthält der Katalog aleatorische Fragen mit einem Deadline-Datum in der Vergangenheit, erscheint eine Warnung. Das kann vorkommen, wenn das Modell trotz Anweisung veraltete Daten erzeugt. Per Checkbox lassen sich diese Fragen zusätzlich vom Import ausschließen – oder sie werden einfach manuell aus der Auswahl entfernt.

### Importieren oder Teilen

- **Importieren** – Fragen direkt in die Datenbank übernehmen.
- **Als Datei teilen** – JSON-Datei per Android-Share-Sheet exportieren, z. B. um sie an andere weiterzugeben.

---

## Kosten und Modellwahl

Unterschiedliche Modelle unterscheiden sich in Qualität und Kosten. Die Vorschau zeigt nach der Generierung den tatsächlichen Tokenverbrauch und die angefallenen Kosten in USD.

Für einfache Fragen reichen günstige Modelle (z. B. `google/gemini-flash-1.5`) aus. Komplexere Themen oder höhere Qualitätsanforderungen profitieren von leistungsstärkeren Modellen.

---

## Übermittelte Daten und App-Identifikation

Jede Anfrage an OpenRouter enthält neben dem Prompt zwei von OpenRouter
empfohlene Identifikations-Header:

| Header | Wert |
|--------|------|
| `HTTP-Referer` | `https://github.com/kaijen/kailibrate` |
| `X-Title` | `kailibrate` |

Diese Header erscheinen in den OpenRouter-Logs und ordnen die Nutzung
deines API-Keys der App kailibrate zu (u. a. für die App-Ranglisten auf
openrouter.ai). Sie enthalten keine persönlichen Daten und keine Inhalte
deiner Vorhersagen. Wer einen eigenen Fork betreibt, kann die Werte in
`lib/core/services/openrouter_service.dart` anpassen.

---

## Manuell mit einem LLM

Wer keinen API-Key einrichten möchte, kann die Prompts aus dem KI-Generator auch manuell in ein beliebiges Sprachmodell eingeben und das Ergebnis als Datei importieren oder aus der Zwischenablage einfügen.

Fertige Prompt-Vorlagen: [Manuell mit LLM erstellen](import-export/llm-prompts.md)
