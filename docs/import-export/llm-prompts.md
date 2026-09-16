# Fragenkataloge mit einem LLM erstellen

Ein LLM wie Claude oder GPT-4 kann in Sekunden Dutzende Trivia-Fragen mit versteckten Antworten erzeugen. Der Trick: Die Antworten stecken als `resolution`-Feld in der Importdatei, aber ohne vorausgefüllte Schätzung. kailibrate zeigt dann „Lösung vorhanden" – und wendet die Auflösung erst an, nachdem der Nutzer seine Schätzung abgegeben hat.

**Ablauf:**

1. Prompt an LLM schicken → JSON/YAML kopieren
2. In kailibrate importieren (Zwischenablage oder Datei)
3. Jede Frage schätzen, ohne die Antwort zu kennen
4. Nach der Schätzung löst kailibrate automatisch auf und wertet aus

---

## Prompt: Epistemisches Trivia (Wahr/Falsch-Fragen)

Geeignet für Faktfragen, bei denen eine klare richtige Antwort existiert.

```
Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: [THEMA, z.B. "Europäische Geografie" oder "Wissenschaftsgeschichte"]
Anzahl: [ANZAHL, z.B. 15]

Regeln:
- Jede Frage ist eine Wahr/Falsch-Frage mit eindeutiger, verifizierbarer Antwort.
- Schwierigkeitsgrad: gemischt – einige überraschend wahr, einige überraschend falsch.
- predictionType ist immer "factual".
- Kein Schätzfeld – der Nutzer schätzt selbst.
- "resolution.outcome" enthält die korrekte Antwort (true = Wahr, false = Falsch).
- "resolution.notes" enthält eine kurze Erklärung oder Quelle.
- Tags: 1–3 thematische Schlagworte auf Englisch.

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

Format:
{
  "version": 1,
  "category": "epistemic",
  "source": "[THEMA]",
  "questions": [
    {
      "text": "Frage?",
      "tags": ["tag1", "tag2"],
      "predictionType": "factual",
      "resolution": {
        "outcome": true,
        "notes": "Kurze Erklärung."
      }
    }
  ]
}
```

---

## Prompt: Epistemisches Trivia (Intervall-Fragen)

Geeignet für numerische Schätzfragen: Jahreszahlen, Entfernungen, Bevölkerungszahlen.

```
Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: [THEMA, z.B. "Historische Jahreszahlen" oder "Weltrekorde"]
Anzahl: [ANZAHL, z.B. 10]

Regeln:
- Jede Frage fragt nach einer konkreten Zahl (Jahr, Entfernung, Gewicht, …).
- Formulierung: "In welchem Jahr …?", "Wie viele km …?", "Wie hoch ist …?"
- predictionType: "interval" – der Nutzer gibt Unter- und Obergrenze an.
- Kein Schätzfeld (keine lowerBound/upperBound) – der Nutzer schätzt selbst.
- "resolution.numericOutcome" enthält den tatsächlichen Wert.
- "resolution.outcome" immer true (wird automatisch gesetzt, wenn Schätzintervall
  den Wert einschließt).
- "resolution.notes" enthält den Wert mit Quelle.
- "unit" enthält die Einheit (z.B. "km", "Jahre", "Mio.").

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

Format:
{
  "version": 1,
  "category": "epistemic",
  "source": "[THEMA]",
  "questions": [
    {
      "text": "Wie viele km ist die Chinesische Mauer lang?",
      "tags": ["history", "china"],
      "predictionType": "interval",
      "unit": "km",
      "resolution": {
        "outcome": true,
        "numericOutcome": 21196,
        "notes": "Gesamtlänge aller Abschnitte laut chinesischer Archäologiebehörde 2012."
      }
    }
  ]
}
```

---

## Prompt: Aleatorische Ja/Nein-Prognosen

Geeignet für zukunftsbezogene Ereignisse, bei denen die Antwort noch unbekannt ist. Kein `resolution`-Feld – der Nutzer löst später selbst auf.

```
Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: [THEMA, z.B. "Bundesliga-Saison 2025/26" oder "Wirtschaft 2026"]
Anzahl: [ANZAHL, z.B. 10]
Heutiges Datum: [DATUM, z.B. "2026-03-04"]

Regeln:
- Jede Frage ist eine zukunftsbezogene Aussage, die eintreten kann oder nicht.
- Formulierung als Aussagesatz im Präsens oder Futur (z.B. "Deutschland gewinnt die Fußball-WM 2026.").
- predictionType: "binary" – der Nutzer schätzt Ja oder Nein.
- Die Antwort ist noch nicht bekannt – KEIN "resolution"-Feld.
- Alle Ereignisse und Deadlines liegen nach dem [DATUM].
- "deadline": ISO-8601-Datum, bis wann die Frage spätestens aufgelöst werden kann.
- Tags: 1–3 thematische Schlagworte auf Englisch.
- Schwierigkeitsgrad: gemischt – einige wahrscheinlicher, einige weniger.

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

{
  "version": 1,
  "category": "aleatory",
  "source": "[THEMA]",
  "questions": [
    {
      "text": "Aussage, die eintreten kann oder nicht.",
      "tags": ["tag1", "tag2"],
      "predictionType": "binary",
      "deadline": "2026-12-31"
    }
  ]
}
```

---

## Prompt: Aleatorische Intervall-Prognosen

Geeignet für zukünftige Messwerte, die noch nicht feststehen. Kein `resolution`-Feld.

```
Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: [THEMA, z.B. "Wirtschaftsindikatoren 2026" oder "Wetter im Sommer 2026"]
Anzahl: [ANZAHL, z.B. 10]
Heutiges Datum: [DATUM, z.B. "2026-03-04"]

Regeln:
- Jede Frage fragt nach einem zukünftigen messbaren Wert, der noch nicht feststeht.
- Formulierung als Aussagesatz über eine konkrete Messgröße (z.B. "Der DAX schließt am 31.12.2026 bei X Punkten.").
- predictionType: "interval" – der Nutzer gibt Unter- und Obergrenze an.
- Die Antwort ist noch nicht bekannt – KEIN "resolution"-Feld.
- Alle Ereignisse und Deadlines liegen nach dem [DATUM].
- "deadline": ISO-8601-Datum, ab dem der Wert bekannt ist.
- "unit": Einheit des Messwertes (z.B. "Punkte", "°C", "%", "Mrd. €").
- Tags: 1–3 thematische Schlagworte auf Englisch.

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

{
  "version": 1,
  "category": "aleatory",
  "source": "[THEMA]",
  "questions": [
    {
      "text": "Der DAX schließt am 31.12.2026 bei X Punkten.",
      "tags": ["finance", "dax"],
      "predictionType": "interval",
      "unit": "Punkte",
      "deadline": "2026-12-31"
    }
  ]
}
```

---

## In-App-Generator

Der integrierte KI-Generator (KI-Generator-Tab) erledigt Schritt 1–2 automatisch:
Thema, Anzahl und optionale Tags eingeben, Modell wählen, generieren – fertig.
Die erzeugten Fragen lassen sich direkt importieren oder als JSON-Datei teilen.

**Tags:** Im Feld „Tags (optional)" können kommagetrennte Schlagworte vorgegeben
werden. Der Generator verwendet dann ausschließlich diese Tags, was nützlich ist,
wenn der importierte Katalog in kailibrate gezielt nach Tags gefiltert werden soll.

---

## Hinweise zur Qualität

**Auf Überprüfbarkeit achten:** LLMs halluzinieren gelegentlich Fakten. Bei wichtigen Zahlen und Daten die `resolution.notes` nach dem Import kurz prüfen.

**Schwierigkeitsgrad steuern:** Der Zusatz „Wähle Fragen, bei denen die Antwort überraschend ist" oder „Vermeide triviale Fragen" verbessert den Kalibrierungseffekt.

**Themenbreite:** Enge Themen (nur deutsche Hauptstädte) erzeugen homogene Schwierigkeit. Breite Themen (Weltgeografie, Naturwissenschaften, Geschichte) fordern das Kalibrierungsgefühl stärker.

**Datei teilen ohne Spoiler:** Wer einen Katalog mit Auflösungen an andere weitergeben will, exportiert erst in kailibrate und teilt den Export – die App obfuskiert die Auflösungen automatisch mit ROT13 + Base64.
