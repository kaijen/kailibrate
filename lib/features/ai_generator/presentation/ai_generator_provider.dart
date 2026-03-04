import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/services/openrouter_service.dart';
import '../../../core/services/prompt_template_service.dart';
import '../../../core/utils/import_parser.dart';

enum AiGeneratorPhase { form, loading, preview, imported }

const _sentinel = Object();

class AiGeneratorState {
  final AiGeneratorPhase phase;
  final PromptTemplate? selectedTemplate;
  final String? selectedModel;
  final int count;
  final String tags;
  final ImportFile? result;
  final String? errorMessage;
  final double? generationCost;
  final int? generationTokens;

  const AiGeneratorState({
    this.phase = AiGeneratorPhase.form,
    this.selectedTemplate,
    this.selectedModel,
    this.count = 10,
    this.tags = '',
    this.result,
    this.errorMessage,
    this.generationCost,
    this.generationTokens,
  });

  AiGeneratorState copyWith({
    AiGeneratorPhase? phase,
    PromptTemplate? selectedTemplate,
    String? selectedModel,
    int? count,
    String? tags,
    ImportFile? result,
    String? errorMessage,
    bool clearError = false,
    bool clearResult = false,
    Object? generationCost = _sentinel,
    Object? generationTokens = _sentinel,
  }) {
    return AiGeneratorState(
      phase: phase ?? this.phase,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      selectedModel: selectedModel ?? this.selectedModel,
      count: count ?? this.count,
      tags: tags ?? this.tags,
      result: clearResult ? null : (result ?? this.result),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      generationCost: generationCost == _sentinel
          ? this.generationCost
          : generationCost as double?,
      generationTokens: generationTokens == _sentinel
          ? this.generationTokens
          : generationTokens as int?,
    );
  }
}

class AiGeneratorNotifier extends StateNotifier<AiGeneratorState> {
  AiGeneratorNotifier() : super(const AiGeneratorState());

  void selectTemplate(PromptTemplate template) {
    state = state.copyWith(selectedTemplate: template, clearError: true);
  }

  void setModel(String model) {
    state = state.copyWith(selectedModel: model);
    unawaited(ApiKeyService.saveModel(model));
  }

  void setCount(int count) {
    state = state.copyWith(count: count);
  }

  void setTags(String tags) {
    state = state.copyWith(tags: tags);
  }

  void reset() {
    state = AiGeneratorState(
      selectedTemplate: state.selectedTemplate,
      selectedModel: state.selectedModel,
      count: state.count,
      tags: state.tags,
    );
  }

  Future<void> generate(String topic) async {
    if (state.selectedTemplate == null) return;
    if (topic.trim().isEmpty) return;

    final model = state.selectedModel;
    if (model == null) return;

    state = state.copyWith(
      phase: AiGeneratorPhase.loading,
      clearError: true,
      clearResult: true,
      generationCost: null,
      generationTokens: null,
    );

    try {
      final apiKey = await ApiKeyService.getKey();
      if (apiKey == null || apiKey.isEmpty) {
        state = state.copyWith(
          phase: AiGeneratorPhase.form,
          errorMessage: 'Kein API-Key gesetzt. Bitte in Einstellungen hinterlegen.',
        );
        return;
      }

      String prompt = state.selectedTemplate!.body
          .replaceAll('{topic}', topic.trim())
          .replaceAll('{count}', '${state.count}');

      final tagsStr = state.tags.trim();
      if (tagsStr.isNotEmpty) {
        prompt += '\n\nWichtig: Verwende ausschließlich diese Tags (keine anderen): $tagsStr';
      }

      final result = await OpenRouterService.generate(
        apiKey: apiKey,
        model: model,
        prompt: prompt,
      );

      debugPrint('[AI] raw response:\n${result.text}');

      final importFile = ImportParser.parseAutoDetect(result.text);

      state = state.copyWith(
        phase: AiGeneratorPhase.preview,
        result: importFile,
        generationCost: result.cost,
        generationTokens: result.totalTokens,
      );
    } on OpenRouterException catch (e) {
      String message;
      if (e.statusCode == 401) {
        message = 'API-Key ungültig – Einstellungen prüfen.';
      } else if (e.statusCode == 402) {
        message = 'OpenRouter-Guthaben aufgebraucht.';
      } else {
        message = 'API-Fehler: ${e.message}';
      }
      state = state.copyWith(
        phase: AiGeneratorPhase.form,
        errorMessage: message,
      );
    } on ImportParseException catch (e) {
      state = state.copyWith(
        phase: AiGeneratorPhase.form,
        errorMessage: 'Parse-Fehler: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        phase: AiGeneratorPhase.form,
        errorMessage: 'Unbekannter Fehler: $e',
      );
    }
  }

  void setImported() {
    state = state.copyWith(phase: AiGeneratorPhase.imported);
  }
}

final aiGeneratorProvider = StateNotifierProvider.autoDispose<
    AiGeneratorNotifier, AiGeneratorState>(
  (_) => AiGeneratorNotifier(),
);

final templatesProvider =
    FutureProvider.autoDispose<List<PromptTemplate>>((ref) {
  return PromptTemplateService.loadAll();
});

final modelListProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ApiKeyService.getModelList();
});

/// Resolves the model to pre-select: last used model if still in list,
/// otherwise first model in list (or null if list is empty).
final initialModelProvider = FutureProvider.autoDispose<String?>((ref) async {
  final models = await ref.watch(modelListProvider.future);
  if (models.isEmpty) return null;
  final last = await ApiKeyService.getModel();
  if (last != null && models.contains(last)) return last;
  return models.first;
});
