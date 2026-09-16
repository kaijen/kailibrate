# Vorhersage-Typen

kailibrate unterstützt drei Typen. Der Typ bestimmt, wie geschätzt und wie aufgelöst wird.

## Ja/Nein mit Konfidenz (`binary`)

Schätzung: erst Richtung wählen (Ja oder Nein), dann Konfidenz einstellen (50–99 %). 50 % steht für maximale Unsicherheit (Raten); wer unter 50 % liegt, sollte einfach die Richtung umkehren. Die interne Wahrscheinlichkeit ergibt sich aus `Konfidenz` (bei Ja) bzw. `1 − Konfidenz` (bei Nein).

**Geeignet für:** aleatorische Ereignisse, bei denen man eine klare Tendenz hat und deren Stärke ausdrücken will.

Beispiel: „Wird es morgen regnen? → Ja, 65 % sicher"

Import-Felder:

```yaml
predictionType: binary
binaryChoice: true      # true = Ja, false = Nein
confidenceLevel: 0.65
```

---

## Wahr/Falsch mit Konfidenz (`factual`)

Schätzung: erst Richtung wählen (Wahr oder Falsch), dann Konfidenz einstellen (50–99 %). Funktioniert identisch zu `binary`, verwendet aber die Semantik epistemischer Faktfragen: Die Antwort existiert bereits – der Nutzer kennt sie nur nicht.

**Geeignet für:** epistemische Fragen mit bekannter Antwort (Trivia, historische Fakten, geografische Fragen).

Beispiel: „Liegt Santiago de Chile östlich von New York? → Falsch, 65 % sicher"

Import-Felder:

```yaml
predictionType: factual
binaryChoice: false     # true = Wahr, false = Falsch
confidenceLevel: 0.65
```

---

## Intervall (`interval`)

Schätzung: Unter- und Obergrenze eines numerischen Bereichs, optionale Maßeinheit (z. B. km, °C) und Konfidenz. Auflösung: tatsächlicher Messwert. Ergebnis ist wahr, wenn der Wert im Intervall liegt.

**Geeignet für:** Mengen, Maße und andere numerische Vorhersagen.

Beispiel: „Wie viele Kilometer laufe ich im März? → 20–45 km, 80 % sicher"

Import-Felder:

```yaml
predictionType: interval
lowerBound: 20
upperBound: 45
confidenceLevel: 0.8
unit: km
```
