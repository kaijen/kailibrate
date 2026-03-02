# Import & Export

## Import

Fragenkataloge lassen sich als JSON oder YAML importieren – per Dateiauswahl oder direkt aus der Zwischenablage. Die App erkennt das Format automatisch und extrahiert den Inhalt bei Bedarf aus einem Markdown-Code-Block (` ```json ` oder ` ```yaml `), sodass sich LLM-generierte Antworten direkt einfügen lassen.

**Ablauf:**

1. Im Menü **Import** wählen.
2. Datei auswählen oder Text aus Zwischenablage einfügen.
3. Vorschau prüfen: Anzahl der Fragen, Kategorie, enthaltene Schätzungen.
4. **Importieren** bestätigen.

Enthält eine Frage bereits Schätzfelder, speichert die App sie sofort. Enthält sie eine Auflösung, wird die Vorhersage direkt als aufgelöst markiert.

Bei Duplikaten (identischer Fragentext) kann konfiguriert werden, ob vorhandene Fragen übersprungen oder ersetzt werden.

Fehler bei ungültigem Schema führen zu einem Fehlerdialog mit Zeilennummer. Es wird kein partieller Import durchgeführt.

---

## Export

### Datensicherung

**Einstellungen → Daten exportieren** erzeugt ein vollständiges JSON-Backup aller Vorhersagen, Schätzungen und Auflösungen. Das Backup wird per Android-Share-Sheet geteilt und lässt sich auf einem anderen Gerät vollständig wiederherstellen.

### Aufgaben teilen

**Einstellungen → Aufgaben teilen** exportiert aufgelöste Vorhersagen, aber ohne die eigenen Schätzungen. So können andere dieselben Fragen selbst kalibrieren, ohne die eigenen Einschätzungen zu sehen.

Ablauf:

1. **Einstellungen → Aufgaben teilen** antippen.
2. Im Dialog optional eine Kategorie wählen (Alle / Epistemisch / Aleatorisch).
3. Optional einen oder mehrere Tags wählen – es werden nur Fragen exportiert, die mindestens einen der gewählten Tags tragen. Kein Tag gewählt bedeutet: alle Tags.
4. **Exportieren** bestätigen – die Datei wird per Share-Sheet geteilt.

Die exportierte Datei enthält die Auflösungen obfuskiert. Calibrate zeigt beim Empfänger „Lösung vorhanden" und löst die Vorhersage nach der Schätzung automatisch auf.

Mehr zum Format unter [Format-Referenz](format.md).
