# Import & Export

## Import

Fragenkataloge lassen sich als JSON oder YAML importieren – per Dateiauswahl oder direkt aus der Zwischenablage. Die App erkennt das Format automatisch und extrahiert den Inhalt bei Bedarf aus einem Markdown-Code-Block (` ```json ` oder ` ```yaml `), sodass sich LLM-generierte Antworten direkt einfügen lassen.

**Ablauf:**

1. Im Menü **Import** wählen.
2. Datei auswählen oder Text aus Zwischenablage einfügen.
3. Vorschau prüfen: Anzahl der Fragen, Kategorie, enthaltene Schätzungen.
4. Optional: **Duplikate überspringen** – Fragen, die bereits mit gleichem Titel in der Datenbank existieren, werden standardmäßig übersprungen. Der Schalter lässt sich für einen Import deaktivieren.
5. **Importieren** bestätigen.

Enthält eine Frage bereits Schätzfelder, speichert die App sie sofort. Enthält sie eine Auflösung, wird die Vorhersage direkt als aufgelöst markiert.

Fehler bei ungültigem Schema führen zu einem Fehlerdialog mit Zeilennummer. Es wird kein partieller Import durchgeführt.

---

## Export

### Verschlüsseltes Backup

**Einstellungen → Verschlüsseltes Backup erstellen** sichert alle Vorhersagen, Schätzungen, Auflösungen und die App-Konfiguration (API-Key, Modelle, Vorlagen) in einer passwortgeschützten `.kbak`-Datei. Die Datei wird per Android-Share-Sheet exportiert.

Technische Details: AES-256-GCM-Verschlüsselung, Schlüsselableitung mit PBKDF2-HMAC-SHA256 (200 000 Iterationen), zufälliges Salt und Nonce pro Backup. Das Format ist versioniert – ältere Backups bleiben in zukünftigen App-Versionen importierbar.

**Einstellungen → Backup wiederherstellen** importiert eine `.kbak`-Datei. Nach Passwort-Eingabe werden alle vorhandenen Daten überschrieben.

### Daten exportieren (unverschlüsselt)

**Einstellungen → Daten exportieren** erzeugt eine unverschlüsselte JSON-Datei aller Vorhersagen, Schätzungen und Auflösungen – nützlich für die Weiterverarbeitung oder Archivierung außerhalb der App.

### Aufgaben teilen

Der Teilen-Button in der AppBar der Vorhersagenliste exportiert die aktuell sichtbaren Vorhersagen ohne eigene Schätzungen. So können andere dieselben Fragen selbst kalibrieren.

Ablauf:

1. In der **Vorhersagenliste** den gewünschten Tab wählen (z.B. „Aufgelöst") und bei Bedarf Tags oder weitere Filter setzen.
2. Das **Teilen-Symbol** in der AppBar antippen.
3. Zieldienst im Android-Share-Sheet wählen – die Datei wird übertragen.

Die exportierte Datei enthält die Auflösungen obfuskiert. Kailibrate zeigt beim Empfänger „Lösung vorhanden" und löst die Vorhersage nach der Schätzung automatisch auf.

Mehr zum Format unter [Format-Referenz](format.md).
