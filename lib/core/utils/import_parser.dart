import 'dart:convert';
import 'package:yaml/yaml.dart';

class ImportQuestion {
  final String text;
  final List<String> tags;
  final bool? answer;
  final DateTime? deadline;

  const ImportQuestion({
    required this.text,
    this.tags = const [],
    this.answer,
    this.deadline,
  });
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
      final qMap = Map<String, dynamic>.from(q as Map);

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

      questions.add(ImportQuestion(
        text: text,
        tags: tags,
        answer: answer,
        deadline: deadline,
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
