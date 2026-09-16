import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PromptTemplate {
  final String id;
  final String name;
  final String body;
  final bool isDefault;

  const PromptTemplate({
    required this.id,
    required this.name,
    required this.body,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'body': body,
        'isDefault': isDefault,
      };

  factory PromptTemplate.fromJson(Map<String, dynamic> json) => PromptTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        body: json['body'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  PromptTemplate copyWith({String? name, String? body}) => PromptTemplate(
        id: id,
        name: name ?? this.name,
        body: body ?? this.body,
        isDefault: isDefault,
      );
}

class PromptTemplateService {
  static const _prefsKey = 'prompt_templates_v1';
  static const _hiddenDefaultsKey = 'prompt_templates_hidden_v1';

  static const List<PromptTemplate> defaults = [
    PromptTemplate(
      id: 'default_yesno',
      name: 'Wahr/Falsch-Fragen (epistemisch)',
      isDefault: true,
      body: r'''Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: {topic}
Anzahl: {count}

Regeln:
- Jede Frage ist eine Wahr/Falsch-Frage mit eindeutiger, verifizierbarer Antwort.
- Schwierigkeitsgrad: gemischt – einige überraschend wahr, einige überraschend falsch.
- predictionType ist immer "factual".
- Kein Schätzfeld (kein "probability") – der Nutzer schätzt selbst.
- "resolution.outcome" enthält die korrekte Antwort (true = Wahr, false = Falsch).
- "resolution.notes" enthält eine kurze Erklärung oder Quelle.
- Tags: 1–3 thematische Schlagworte auf Englisch.

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

{
  "version": 1,
  "category": "epistemic",
  "source": "{topic}",
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
}''',
    ),
    PromptTemplate(
      id: 'default_interval',
      name: 'Intervall-Fragen (epistemisch)',
      isDefault: true,
      body: r'''Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: {topic}
Anzahl: {count}

Regeln:
- Jede Frage fragt nach einer konkreten Zahl (Jahr, Entfernung, Gewicht, …).
- Formulierung: "In welchem Jahr …?", "Wie viele km …?", "Wie hoch ist …?"
- predictionType: "interval" – der Nutzer gibt Unter- und Obergrenze an.
- Kein Schätzfeld (keine lowerBound/upperBound) – der Nutzer schätzt selbst.
- "resolution.numericOutcome" enthält den tatsächlichen Wert.
- "resolution.outcome" immer true.
- "resolution.notes" enthält den Wert mit Quelle.
- "unit" enthält die Einheit (z.B. "km", "Jahre", "Mio.").

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

{
  "version": 1,
  "category": "epistemic",
  "source": "{topic}",
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
}''',
    ),
    PromptTemplate(
      id: 'default_aleatory_binary',
      name: 'Ja/Nein-Prognosen (aleatorisch)',
      isDefault: true,
      body: r'''Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: {topic}
Anzahl: {count}
Heutiges Datum: {date}

Regeln:
- Jede Frage ist eine zukunftsbezogene Aussage, die eintreten kann oder nicht.
- Formulierung als Aussagesatz im Präsens oder Futur (z.B. „Deutschland gewinnt die Fußball-WM 2026.").
- predictionType: "binary" – der Nutzer schätzt Ja oder Nein.
- Die Antwort ist noch nicht bekannt – KEIN "resolution"-Feld.
- Alle Ereignisse und Deadlines liegen nach dem {date}.
- "deadline": ISO-8601-Datum, bis wann die Frage spätestens aufgelöst werden kann.
- Tags: 1–3 thematische Schlagworte auf Englisch.
- Schwierigkeitsgrad: gemischt – einige wahrscheinlicher, einige weniger.

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

{
  "version": 1,
  "category": "aleatory",
  "source": "{topic}",
  "questions": [
    {
      "text": "Aussage, die eintreten kann oder nicht.",
      "tags": ["tag1", "tag2"],
      "predictionType": "binary",
      "deadline": "2026-12-31"
    }
  ]
}''',
    ),
    PromptTemplate(
      id: 'default_aleatory_interval',
      name: 'Intervall-Prognosen (aleatorisch)',
      isDefault: true,
      body: r'''Erstelle einen Fragenkatalog für die App kailibrate im JSON-Format.
Thema: {topic}
Anzahl: {count}
Heutiges Datum: {date}

Regeln:
- Jede Frage fragt nach einem zukünftigen messbaren Wert, der noch nicht feststeht.
- Formulierung als Aussagesatz über eine konkrete Messgröße (z.B. „Der DAX schließt am 31.12.2026 bei X Punkten.").
- predictionType: "interval" – der Nutzer gibt Unter- und Obergrenze an.
- Die Antwort ist noch nicht bekannt – KEIN "resolution"-Feld.
- Alle Ereignisse und Deadlines liegen nach dem {date}.
- "deadline": ISO-8601-Datum, ab dem der Wert bekannt ist.
- "unit": Einheit des Messwertes (z.B. "Punkte", "°C", "%", "Mrd. €").
- Tags: 1–3 thematische Schlagworte auf Englisch.

Ausgabe ausschließlich als valides JSON, kein erklärender Text davor oder danach.

{
  "version": 1,
  "category": "aleatory",
  "source": "{topic}",
  "questions": [
    {
      "text": "Der DAX schließt am 31.12.2026 bei X Punkten.",
      "tags": ["finance", "dax"],
      "predictionType": "interval",
      "unit": "Punkte",
      "deadline": "2026-12-31"
    }
  ]
}''',
    ),
  ];

  /// Returns all templates: visible defaults first, then user-created ones.
  static Future<List<PromptTemplate>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final hidden = prefs.getStringList(_hiddenDefaultsKey)?.toSet() ?? {};

    List<PromptTemplate> userTemplates = [];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        userTemplates = list
            .map((e) => PromptTemplate.fromJson(e as Map<String, dynamic>))
            .where((t) => !t.isDefault)
            .toList();
      } catch (_) {
        // ignore parse errors, fall back to defaults only
      }
    }

    final visibleDefaults = defaults.where((t) => !hidden.contains(t.id));
    return [...visibleDefaults, ...userTemplates];
  }

  /// Creates or updates a template. Default templates cannot be modified.
  static Future<void> save(PromptTemplate template) async {
    if (template.isDefault) return;
    final all = await loadAll();
    final idx = all.indexWhere((t) => t.id == template.id);
    if (idx >= 0) {
      all[idx] = template;
    } else {
      all.add(template);
    }
    await _persist(all);
  }

  /// Deletes a template by id.
  /// Default templates are hidden via a suppression list; user templates are
  /// removed from persistent storage.
  static Future<void> delete(String id) async {
    final isDefault = defaults.any((t) => t.id == id);
    if (isDefault) {
      final prefs = await SharedPreferences.getInstance();
      final hidden = prefs.getStringList(_hiddenDefaultsKey)?.toSet() ?? {};
      hidden.add(id);
      await prefs.setStringList(_hiddenDefaultsKey, hidden.toList());
      return;
    }
    final all = await loadAll();
    final updated = all.where((t) => t.id != id).toList();
    await _persist(updated);
  }

  static Future<void> _persist(List<PromptTemplate> all) async {
    final prefs = await SharedPreferences.getInstance();
    final userOnly = all.where((t) => !t.isDefault).toList();
    await prefs.setString(
      _prefsKey,
      jsonEncode(userOnly.map((t) => t.toJson()).toList()),
    );
  }

  /// Generates a unique ID for a new user template.
  static String generateId() => 'tpl_${DateTime.now().millisecondsSinceEpoch}';
}
