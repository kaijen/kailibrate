import 'dart:convert';
import 'package:yaml/yaml.dart';

class ImportQuestion {
  final String text;
  final List<String> tags;
  final bool? answer;
  final DateTime? deadline;
  // Schätzfelder (optional)
  final String predictionType;   // 'probability' | 'binary' | 'interval'
  final double? probability;     // für probability-Typ
  final bool? binaryChoice;      // für binary-Typ
  final double? confidenceLevel; // für binary + interval
  final double? lowerBound;      // für interval
  final double? upperBound;      // für interval
  final String? unit;            // für interval (z.B. "km", "°C")

  const ImportQuestion({
    required this.text,
    this.tags = const [],
    this.answer,
    this.deadline,
    this.predictionType = 'probability',
    this.probability,
    this.binaryChoice,
    this.confidenceLevel,
    this.lowerBound,
    this.upperBound,
    this.unit,
  });

  bool get hasEstimateData {
    return (predictionType == 'probability' && probability != null) ||
        (predictionType == 'binary' && binaryChoice != null) ||
        (predictionType == 'interval' &&
            lowerBound != null &&
            upperBound != null);
  }
}

class ImportFile {
  final int version;
  final String category;
  final String? source;
  final List<ImportQuestion> questions;

  const ImportFile({
    required this.version,
    required this.category,
    this.source,
    required this.questions,
  });
}

class ImportParseException implements Exception {
  final String message;
  const ImportParseException(this.message);

  @override
  String toString() => 'ImportParseException: $message';
}

class ImportParser {
  static ImportFile parse(String content, String filename) {
    Map<String, dynamic> data;

    if (filename.endsWith('.yaml') || filename.endsWith('.yml')) {
      final yaml = loadYaml(content);
      data = _yamlToMap(yaml);
    } else if (filename.endsWith('.json')) {
      data = jsonDecode(content) as Map<String, dynamic>;
    } else {
      throw ImportParseException(
          'Unbekanntes Format: $filename. Nur .json und .yaml werden unterstützt.');
    }

    return _parseMap(data);
  }

  /// Erkennt das Format automatisch – zuerst JSON, dann YAML.
  static ImportFile parseAutoDetect(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ImportParseException('Inhalt ist leer.');
    }

    if (trimmed.startsWith('{')) {
      try {
        final data = jsonDecode(trimmed) as Map<String, dynamic>;
        return _parseMap(data);
      } on FormatException catch (e) {
        throw ImportParseException('Ungültiges JSON: ${e.message}');
      }
    }

    try {
      final yaml = loadYaml(trimmed);
      final data = _yamlToMap(yaml);
      return _parseMap(data);
    } on ImportParseException {
      rethrow;
    } catch (e) {
      throw ImportParseException('Inhalt konnte nicht als JSON oder YAML geparst werden: $e');
    }
  }

  static ImportFile _parseMap(Map<String, dynamic> data) {
    final version = data['version'];
    if (version == null) {
      throw const ImportParseException('Pflichtfeld "version" fehlt.');
    }

    final category = data['category'] as String?;
    if (category == null ||
        (category != 'epistemic' && category != 'aleatory')) {
      throw const ImportParseException(
          'Pflichtfeld "category" muss "epistemic" oder "aleatory" sein.');
    }

    final rawQuestions = data['questions'];
    if (rawQuestions == null || rawQuestions is! List) {
      throw const ImportParseException(
          'Pflichtfeld "questions" muss eine Liste sein.');
    }

    final questions = <ImportQuestion>[];
    for (var i = 0; i < rawQuestions.length; i++) {
      final q = rawQuestions[i];
      if (q is! Map) {
        throw ImportParseException('Frage $i ist kein Objekt.');
      }
      final qMap = Map<String, dynamic>.from(q);

      final text = qMap['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw ImportParseException('Frage $i: "text" fehlt oder ist leer.');
      }

      final rawTags = qMap['tags'];
      final tags = rawTags is List
          ? rawTags.map((t) => t.toString()).toList()
          : <String>[];

      final answer = qMap['answer'] as bool?;

      DateTime? deadline;
      final rawDeadline = qMap['deadline'];
      if (rawDeadline != null) {
        deadline = DateTime.tryParse(rawDeadline.toString());
      }

      // Vorhersagetyp – unbekannte Werte fallen auf 'probability' zurück
      final rawType = qMap['predictionType'] as String?;
      final predictionType =
          {'probability', 'binary', 'interval'}.contains(rawType)
              ? rawType!
              : 'probability';

      // Schätzfelder
      final probability = (qMap['probability'] as num?)?.toDouble();
      final binaryChoice = qMap['binaryChoice'] as bool?;
      final confidenceLevel = (qMap['confidenceLevel'] as num?)?.toDouble();
      final lowerBound = (qMap['lowerBound'] as num?)?.toDouble();
      final upperBound = (qMap['upperBound'] as num?)?.toDouble();
      final unit = qMap['unit'] as String?;

      questions.add(ImportQuestion(
        text: text,
        tags: tags,
        answer: answer,
        deadline: deadline,
        predictionType: predictionType,
        probability: probability,
        binaryChoice: binaryChoice,
        confidenceLevel: confidenceLevel,
        lowerBound: lowerBound,
        upperBound: upperBound,
        unit: unit,
      ));
    }

    return ImportFile(
      version: (version as num).toInt(),
      category: category,
      source: data['source'] as String?,
      questions: questions,
    );
  }

  static Map<String, dynamic> _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return yaml.map((k, v) => MapEntry(k.toString(), _convertYaml(v)));
    }
    throw const ImportParseException('YAML-Datei ist kein Objekt.');
  }

  static dynamic _convertYaml(dynamic value) {
    if (value is YamlMap) {
      return value.map((k, v) => MapEntry(k.toString(), _convertYaml(v)));
    }
    if (value is YamlList) {
      return value.map(_convertYaml).toList();
    }
    return value;
  }
}
