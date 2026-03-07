# Statistiken

Kailibrate berechnet vier Kennzahlen, um die Qualität von Schätzungen zu messen. Nur aufgelöste Vorhersagen fließen ein.

## Brier Score

Mittlerer quadratischer Fehler der Schätzungen:

```
BS = (1/N) × Σ (pᵢ - oᵢ)²
```

- `pᵢ` – geschätzte Wahrscheinlichkeit (0,5–1)
- `oᵢ` – tatsächliches Ergebnis (0 oder 1)
- Wertebereich: 0 (perfekt) bis 1 (maximal falsch)

Ein Brier Score von 0,25 entspricht dem Ergebnis, das man durch blindes Schätzen von 50 % erreicht. Je niedriger, desto besser.

---

## Log Loss

Empfindlicher gegenüber extremen Fehlschätzungen als der Brier Score:

```
LL = -(1/N) × Σ [oᵢ × log(pᵢ) + (1-oᵢ) × log(1-pᵢ)]
```

Wer ein eingetretenes Ereignis mit 1 % schätzt, wird stärker bestraft als beim Brier Score. Gut für alle, die Überkorrektur vermeiden wollen.

---

## Winkler Score

Bewertet Intervallschätzungen. Für jeden Schätzbereich `[L, U]` mit Konfidenzniveau `α` gilt:

```
W = (U − L)                            falls Actual ∈ [L, U]
W = (U − L) + 2·(L − Actual) / α      falls Actual < L
W = (U − L) + 2·(Actual − U) / α      falls Actual > U
```

Je enger das Intervall und je häufiger der tatsächliche Wert darin liegt, desto besser (niedriger). Kailibrate zeigt die Einzelwerte jeder Schätzung als Punkt-Diagramm über die Zeit – Treffer grün, Ausreißer rot. Ein Durchschnitt über alle Fragen hinweg wäre irreführend, da der Score einheitenabhängig ist: Ein guter Wert bei Körpergrößen (z. B. 5 cm) und ein guter Wert bei Einwohnerzahlen (z. B. 200.000) lassen sich nicht vergleichen.

---

## Kalibrierungskurve

Schätzungen werden in 10-%-Bins gruppiert (50–60 %, 60–70 %, …). Pro Bin zeigt die Kurve:

- **X-Achse** – Mitte des Bins (erwartete Trefferquote)
- **Y-Achse** – tatsächliche Trefferquote in diesem Bin

Eine perfekt kalibrierte Person liegt auf der Diagonale: Wer 70 % sagt, hat in 70 % der Fälle recht.

Abweichungen nach oben zeigen Unterschätzung (zu bescheiden), Abweichungen nach unten Überschätzung (zu selbstsicher).

Die **Punktgröße** zeigt die relative Datenmenge: Der Bin mit den meisten Schätzungen erscheint am größten, alle anderen skalieren proportional dazu.

---

## Diagramme in der App

| Diagramm | Inhalt |
|----------|--------|
| Kalibrierungskurve | Bin-Mitte vs. Trefferquote, Diagonale als Referenz |
| Brier-Score-Verlauf | Kumulativer Durchschnitt nach jeder aufgelösten Schätzung |
| Log-Loss-Verlauf | Kumulativer Durchschnitt nach jeder aufgelösten Schätzung |
| Winkler-Score-Verlauf | Einzelwerte je Intervallschätzung – grün: Treffer, rot: verfehlt |

Die Verlaufsdiagramme zeigen, wie sich die Scores mit jeder weiteren Auflösung entwickeln. Die gestrichelte Linie markiert das Münzwurf-Niveau (0,25 bzw. ≈ 0,69). Mit dem Selektor oben rechts lässt sich der sichtbare Ausschnitt auf die letzten 25, 50 oder 100 Schätzungen einschränken.

Ein Tipp auf ein Diagramm öffnet es als Vollbild-Ansicht im Querformat. In der Vollbild-Ansicht lässt sich die X-Achse per Pinch-to-Zoom vergrößern und verschieben; ein Doppeltipp setzt den Zoom zurück. Beim Winkler-Score-Verlauf öffnet ein Tipp auf einen Datenpunkt die zugehörige Schätzung; zurück führt zur Vollbild-Ansicht im selben Zoom-Zustand.

---

## Filter

Die Statistiken lassen sich mit drei kombinierbaren Filtern eingrenzen:

| Filter | Optionen |
|--------|----------|
| Kategorie | Alle · Epistemisch · Aleatorisch (Einfachauswahl) |
| Vorhersagetyp | Wahr/Falsch · Ja/Nein · Intervall (Mehrfachauswahl) |
| Tags | Chips aus vorhandenen Tags, OR-verknüpft |

Alle drei Filter wirken gleichzeitig: Nur Vorhersagen, die allen aktiven Kriterien entsprechen, fließen in die Berechnung ein.
