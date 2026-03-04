# Fragenkataloge mit einem LLM erstellen

Ein LLM wie Claude oder GPT-4 kann in Sekunden Dutzende Trivia-Fragen mit versteckten Antworten erzeugen. Der Trick: Die Antworten stecken als `resolution`-Feld in der Importdatei, aber ohne vorausgefüllte Schätzung. Kailibrate zeigt dann „Lösung vorhanden" – und wendet die Auflösung erst an, nachdem der Nutzer seine Schätzung abgegeben hat.

**Ablauf:**

1. Prompt an LLM schicken → JSON/YAML kopieren
2. In Kailibrate importieren (Zwischenablage oder Datei)
3. Jede Frage schätzen, ohne die Antwort zu kennen
4. Nach der Schätzung löst Kailibrate automatisch auf und wertet aus

---

## Prompt: Epistemisches Trivia (Ja/Nein-Fragen)

Geeignet für Faktfragen, bei denen eine klare richtige Antwort existiert.

```
Erstelle einen Fragenkatalog für die App Kailibrate im JSON-Format.
Thema: [THEMA, z.B. "Europäische Geografie" oder "Wissenschaftsgeschichte"]
Anzahl: [ANZAHL, z.B. 15]

Regeln:
- Jede Frage ist eine Ja/Nein-Frage mit eindeutiger, verifizierbarer Antwort.
- Schwierigkeitsgrad: gemischt – einige überraschend wahr, einige überraschend falsch.
- Kein Schätzfeld (kein "probability") – der Nutzer schätzt selbst.
- "resolution.outcome" enthält die korrekte Antwort (true = Ja, false = Nein).
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
Erstelle einen Fragenkatalog für die App Kailibrate im JSON-Format.
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

## Prompt: Gemischter Katalog (Ja/Nein + Intervall)

Für abwechslungsreichere Übungen mit verschiedenen Fragetypen.

```
Erstelle einen gemischten Fragenkatalog für die App Kailibrate im JSON-Format.
Thema: [THEMA]
Anzahl: [ANZAHL] Fragen, davon etwa die Hälfte Ja/Nein, die Hälfte Intervall.

Regeln für Ja/Nein-Fragen:
- predictionType: "binary"
- "resolution.outcome": true oder false
- "resolution.notes": kurze Erklärung

Regeln für Intervall-Fragen:
- predictionType: "interval"
- "unit" angeben
- "resolution.numericOutcome": tatsächlicher Wert
- "resolution.outcome": true
- "resolution.notes": Wert mit Quelle

Für alle Fragen:
- Kein Schätzfeld – der Nutzer schätzt selbst.
- Tags: 1–3 Schlagworte auf Englisch.
- Schwierigkeitsgrad: gemischt.

Ausgabe ausschließlich als valides JSON.

{
  "version": 1,
  "category": "epistemic",
  "source": "[THEMA]",
  "questions": [ ... ]
}
```

---

## In-App-Generator

Der integrierte KI-Generator (KI-Generator-Tab) erledigt Schritt 1–2 automatisch:
Thema, Anzahl und optionale Tags eingeben, Modell wählen, generieren – fertig.
Die erzeugten Fragen lassen sich direkt importieren oder als JSON-Datei teilen.

**Tags:** Im Feld „Tags (optional)" können kommagetrennte Schlagworte vorgegeben
werden. Der Generator verwendet dann ausschließlich diese Tags, was nützlich ist,
wenn der importierte Katalog in Kailibrate gezielt nach Tags gefiltert werden soll.

---

## Hinweise zur Qualität

**Auf Überprüfbarkeit achten:** LLMs halluzinieren gelegentlich Fakten. Bei wichtigen Zahlen und Daten die `resolution.notes` nach dem Import kurz prüfen.

**Schwierigkeitsgrad steuern:** Der Zusatz „Wähle Fragen, bei denen die Antwort überraschend ist" oder „Vermeide triviale Fragen" verbessert den Kalibrierungseffekt.

**Themenbreite:** Enge Themen (nur deutsche Hauptstädte) erzeugen homogene Schwierigkeit. Breite Themen (Weltgeografie, Naturwissenschaften, Geschichte) fordern das Kalibrierungsgefühl stärker.

**Datei teilen ohne Spoiler:** Wer einen Katalog mit Auflösungen an andere weitergeben will, exportiert erst in Kailibrate und teilt den Export – die App obfuskiert die Auflösungen automatisch mit ROT13 + Base64.
