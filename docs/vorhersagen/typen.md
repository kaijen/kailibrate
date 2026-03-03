# Vorhersage-Typen

Kailibrate unterstützt drei Typen. Der Typ bestimmt, wie geschätzt und wie aufgelöst wird.

## Wahrscheinlichkeit (`probability`)

Der Standardtyp. Schätzung: ein Schieberegler von 0 bis 100 %. Auflösung: eingetreten oder nicht eingetreten.

**Geeignet für:** beliebige Ereignisse, die mit einer einfachen Prozentzahl beschreibbar sind.

Beispiel: „Schließt der DAX am 31.03.2026 über 21 000 Punkten? → 40 %"

---

## Ja/Nein mit Konfidenz (`binary`)

Schätzung: erst Richtung wählen (Ja oder Nein), dann Konfidenz einstellen (50–99 %). 50 % steht für maximale Unsicherheit (Raten); wer unter 50 % liegt, sollte einfach die Richtung umkehren. Die interne Wahrscheinlichkeit ergibt sich aus `Konfidenz` (bei Ja) bzw. `1 − Konfidenz` (bei Nein).

**Geeignet für:** Fragen, bei denen man eine klare Tendenz hat und deren Stärke ausdrücken will.

Beispiel: „Wird es morgen regnen? → Ja, 65 % sicher"

Import-Felder:

```yaml
predictionType: binary
binaryChoice: true      # true = Ja, false = Nein
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
