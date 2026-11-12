import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../domain/ai/ai_models.dart';
import '../../ai/application/ai_providers.dart';
import 'ai_settings_providers.dart';

enum AiSettingsField {
  baseUrl,
  model,
  apiKey,
  temperature,
  maxTokens,
  systemPrompt,
}

enum AiSettingsOperation {
  idle,
  saving,
  savingForTest,
  testing,
  toggling,
  clearing,
}

enum AiSettingsFeedbackKind { info, success, error }

final class AiSettingsFeedback {
  const AiSettingsFeedback(this.message, this.kind);

  final String message;
  final AiSettingsFeedbackKind kind;
}

final class AiSettingsFormState {
  AiSettingsFormState({
    this.saved,
    required Map<AiSettingsField, String> values,
    required this.streaming,
    required this.confirmBeforeRequest,
    this.operation = AiSettingsOperation.idle,
    Map<AiSettingsField, String> errors = const {},
    this.feedback,
  }) : values = Map.unmodifiable(values),
       errors = Map.unmodifiable(errors);

  factory AiSettingsFormState.fromSettings(AiSettings? saved) {
    final settings = saved ?? const AiSettings();
    return AiSettingsFormState(
      saved: saved,
      values: {
        AiSettingsField.baseUrl: settings.baseUrl,
        AiSettingsField.model: settings.model,
        AiSettingsField.apiKey: '',
        AiSettingsField.temperature: '${settings.temperature}',
        AiSettingsField.maxTokens: '${settings.maxTokens}',
        AiSettingsField.systemPrompt: settings.systemPrompt,
      },
      streaming: settings.streaming,
      confirmBeforeRequest: settings.confirmBeforeRequest,
    );
  }

  final AiSettings? saved;
  final Map<AiSettingsField, String> values;
  final bool streaming;
  final bool confirmBeforeRequest;
  final AiSettingsOperation operation;
  final Map<AiSettingsField, String> errors;
  final AiSettingsFeedback? feedback;

  bool get isInitialized => saved != null;
  bool get enabled => saved?.enabled ?? false;
  bool get isBusy => operation != AiSettingsOperation.idle;
  String value(AiSettingsField field) => values[field] ?? '';

  bool get isDirty {
    final baseline = saved;
    if (baseline == null) return false;
    final persisted = AiSettingsFormState.fromSettings(baseline);
    return AiSettingsField.values.any(
          (field) => value(field).trim() != persisted.value(field).trim(),
        ) ||
        streaming != baseline.streaming ||
        confirmBeforeRequest != baseline.confirmBeforeRequest;
  }

  bool get hasAdvancedErrors =>
      errors.containsKey(AiSettingsField.temperature) ||
      errors.containsKey(AiSettingsField.maxTokens);

  AiSettingsFormState copyWith({
    AiSettings? saved,
    Map<AiSettingsField, String>? values,
    bool? streaming,
    bool? confirmBeforeRequest,
    AiSettingsOperation? operation,
    Map<AiSettingsField, String>? errors,
    AiSettingsFeedback? feedback,
    bool clearFeedback = false,
  }) {
    return AiSettingsFormState(
      saved: saved ?? this.saved,
      values: values ?? this.values,
      streaming: streaming ?? this.streaming,
      confirmBeforeRequest: confirmBeforeRequest ?? this.confirmBeforeRequest,
      operation: operation ?? this.operation,
      errors: errors ?? this.errors,
      feedback: clearFeedback ? null : feedback ?? this.feedback,
    );
  }
}

final aiSettingsFormProvider =
    NotifierProvider.autoDispose<AiSettingsFormController, AiSettingsFormState>(
      AiSettingsFormController.new,
    );

final class AiSettingsFormController extends Notifier<AiSettingsFormState> {
  int _generation = 0;
  final Map<String, AiSettingsFormState> _drafts = {};

  String _draftKey(String? profileId) => profileId ?? '';

  @override
  AiSettingsFormState build() {
    ref.listen(aiSettingsProvider, (previous, next) {
      if (next.isLoading || next.hasError) return;
      final settings = next.asData?.value;
      if (settings != null) _mergeSaved(settings);
    });
    final initial = ref.read(aiSettingsProvider).asData?.value;
    final state = AiSettingsFormState.fromSettings(initial);
    if (initial != null) {
      _drafts[_draftKey(initial.activeProfileId)] = state;
    }
    return state;
  }

  void edit(AiSettingsField field, String value) {
    if (state.isBusy) return;
    state = state.copyWith(
      values: {...state.values, field: value},
      errors: {...state.errors}..remove(field),
      clearFeedback: true,
    );
  }

  void setStreaming(bool value) {
    if (!state.isBusy) {
      state = state.copyWith(streaming: value, clearFeedback: true);
    }
  }

  void setConfirmBeforeRequest(bool value) {
    if (!state.isBusy) {
      state = state.copyWith(confirmBeforeRequest: value, clearFeedback: true);
    }
  }

  void discardChanges() {
    if (state.isBusy) return;
    state = AiSettingsFormState.fromSettings(state.saved);
    _drafts[_draftKey(state.saved?.activeProfileId)] = state;
  }

  Future<void> save({bool testConnection = false}) async {
    final baseline = state.saved;
    if (state.isBusy ||
        baseline == null ||
        (testConnection && !baseline.enabled)) {
      return;
    }
    if (!testConnection && !state.isDirty) return;
    final errors = _validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(
        errors: errors,
        feedback: const AiSettingsFeedback(
          '请检查标出的配置项后重试',
          AiSettingsFeedbackKind.error,
        ),
      );
      return;
    }
    final next = baseline.copyWith(
      baseUrl: state.value(AiSettingsField.baseUrl).trim(),
      model: state.value(AiSettingsField.model).trim(),
      temperature: double.parse(
        state.value(AiSettingsField.temperature).trim(),
      ),
      maxTokens: int.parse(state.value(AiSettingsField.maxTokens).trim()),
      systemPrompt: state.value(AiSettingsField.systemPrompt).trim(),
      streaming: state.streaming,
      confirmBeforeRequest: state.confirmBeforeRequest,
    );
    final apiKey = state.value(AiSettingsField.apiKey).trim();
    final generation = ++_generation;
    state = state.copyWith(
      operation: testConnection
          ? AiSettingsOperation.savingForTest
          : AiSettingsOperation.saving,
      errors: const {},
      clearFeedback: true,
    );
    var saved = next;
    try {
      await ref
          .read(aiSettingsControllerProvider)
          .save(next, apiKey: apiKey.isEmpty ? null : apiKey);
      if (!_isCurrent(generation)) return;
      saved = await ref.read(aiSettingsRepositoryProvider).getSettings();
    } catch (error) {
      if (_isCurrent(generation)) {
        state = state.copyWith(
          operation: AiSettingsOperation.idle,
          feedback: AiSettingsFeedback(
            error is AiProfileException
                ? '${error.message}；输入已保留'
                : 'AI 设置保存失败，输入已保留，请重试',
            AiSettingsFeedbackKind.error,
          ),
        );
        try {
          final latest = await ref
              .read(aiSettingsRepositoryProvider)
              .getSettings();
          if (_isCurrent(generation) &&
              (state.saved?.activeProfileId == null ||
                  latest.activeProfileId == state.saved?.activeProfileId)) {
            state = state.copyWith(saved: latest);
          }
        } catch (_) {
          if (_isCurrent(generation)) {
            ref.invalidate(aiSettingsProvider);
          }
        }
      }
      return;
    }
    if (!_isCurrent(generation)) return;
    state = AiSettingsFormState.fromSettings(saved).copyWith(
      operation: testConnection
          ? AiSettingsOperation.testing
          : AiSettingsOperation.idle,
      feedback: testConnection
          ? null
          : const AiSettingsFeedback(
              'AI 设置已保存',
              AiSettingsFeedbackKind.success,
            ),
    );
    _drafts[_draftKey(saved.activeProfileId)] = state;
    ref.invalidate(aiSettingsProvider);
    if (!testConnection) return;
    try {
      final status = await ref.read(aiChatServiceProvider).testConnection();
      if (!_isCurrent(generation)) return;
      final ready = status == AiProviderStatus.ready;
      state = state.copyWith(
        operation: AiSettingsOperation.idle,
        feedback: AiSettingsFeedback(
          switch (status) {
            AiProviderStatus.ready => '连接测试成功，当前配置已保存',
            AiProviderStatus.missingConfiguration => '配置已保存，请检查接口地址和模型',
            AiProviderStatus.missingApiKey => '配置已保存，请先保存 API Key',
            AiProviderStatus.unavailable => '配置已保存，但连接不可用，请检查地址、模型和密钥',
          },
          ready ? AiSettingsFeedbackKind.success : AiSettingsFeedbackKind.error,
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        operation: AiSettingsOperation.idle,
        feedback: AiSettingsFeedback(
          error is AiChatException
              ? '配置已保存；${error.message}'
              : '配置已保存，但连接测试失败，请重试',
          AiSettingsFeedbackKind.error,
        ),
      );
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final baseline = state.saved;
    if (state.isBusy || baseline == null || enabled == baseline.enabled) return;
    final generation = ++_generation;
    state = state.copyWith(
      operation: AiSettingsOperation.toggling,
      clearFeedback: true,
    );
    try {
      await ref.read(aiSettingsControllerProvider).setEnabled(enabled);
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        saved: baseline.copyWith(enabled: enabled),
        operation: AiSettingsOperation.idle,
      );
      _drafts[_draftKey(baseline.activeProfileId)] = state;
      ref.invalidate(aiSettingsProvider);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        operation: AiSettingsOperation.idle,
        feedback: const AiSettingsFeedback(
          '无法保存 AI 开关，请重试',
          AiSettingsFeedbackKind.error,
        ),
      );
    }
  }

  Future<void> clearApiKey() async {
    final baseline = state.saved;
    if (state.isBusy || baseline == null || !baseline.hasApiKey) return;
    final generation = ++_generation;
    state = state.copyWith(
      operation: AiSettingsOperation.clearing,
      clearFeedback: true,
    );
    try {
      await ref.read(aiSettingsControllerProvider).clearApiKey();
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        saved: baseline.copyWith(hasApiKey: false),
        values: {...state.values, AiSettingsField.apiKey: ''},
        operation: AiSettingsOperation.idle,
        feedback: const AiSettingsFeedback(
          '密钥已清除，请保存新密钥后再使用 AI',
          AiSettingsFeedbackKind.info,
        ),
      );
      _drafts[_draftKey(baseline.activeProfileId)] = state;
      ref.invalidate(aiSettingsProvider);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        operation: AiSettingsOperation.idle,
        feedback: const AiSettingsFeedback(
          '密钥清除失败，请重试',
          AiSettingsFeedbackKind.error,
        ),
      );
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _mergeSaved(AiSettings incoming) {
    final incomingKey = _draftKey(incoming.activeProfileId);
    final currentKey = _draftKey(state.saved?.activeProfileId);
    if (state.saved != null && currentKey != incomingKey) {
      if (currentKey.isEmpty &&
          (state.operation == AiSettingsOperation.saving ||
              state.operation == AiSettingsOperation.savingForTest)) {
        return;
      }
      _generation += 1;
      _drafts[currentKey] = state.copyWith(
        operation: AiSettingsOperation.idle,
        clearFeedback: true,
      );
      final draft = _drafts[incomingKey];
      state = draft == null
          ? AiSettingsFormState.fromSettings(incoming)
          : _mergeState(draft, incoming);
      _drafts[incomingKey] = state;
      return;
    }
    state = _mergeState(state, incoming);
    _drafts[incomingKey] = state;
  }

  AiSettingsFormState _mergeState(
    AiSettingsFormState current,
    AiSettings incoming,
  ) {
    final previous = current.saved;
    if (previous == null) {
      return AiSettingsFormState.fromSettings(incoming);
    }
    if (current.isBusy && current.operation != AiSettingsOperation.testing) {
      return current;
    }
    final previousValues = AiSettingsFormState.fromSettings(previous);
    final incomingValues = AiSettingsFormState.fromSettings(incoming);
    final connectionChanged =
        previous.baseUrl != incoming.baseUrl ||
        previous.model != incoming.model ||
        previous.hasApiKey != incoming.hasApiKey ||
        previous.enabled != incoming.enabled;
    final staleTest =
        current.operation == AiSettingsOperation.testing && connectionChanged;
    if (staleTest) _generation += 1;
    return current.copyWith(
      saved: incoming,
      values: {
        for (final field in AiSettingsField.values)
          field:
              field != AiSettingsField.apiKey &&
                  current.value(field) == previousValues.value(field)
              ? incomingValues.value(field)
              : current.value(field),
      },
      streaming: current.streaming == previous.streaming
          ? incoming.streaming
          : current.streaming,
      confirmBeforeRequest:
          current.confirmBeforeRequest == previous.confirmBeforeRequest
          ? incoming.confirmBeforeRequest
          : current.confirmBeforeRequest,
      operation: staleTest ? AiSettingsOperation.idle : current.operation,
      clearFeedback: connectionChanged && !staleTest,
      feedback: staleTest
          ? const AiSettingsFeedback(
              '连接配置已变更，请重新测试',
              AiSettingsFeedbackKind.info,
            )
          : null,
    );
  }

  Map<AiSettingsField, String> _validate() {
    final errors = <AiSettingsField, String>{};
    final baseUrl = state.value(AiSettingsField.baseUrl).trim();
    final uri = Uri.tryParse(baseUrl);
    if (baseUrl.isEmpty) {
      errors[AiSettingsField.baseUrl] = '请输入 Base URL';
    } else if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      errors[AiSettingsField.baseUrl] = '请输入完整的 http(s) 地址';
    }
    if (state.value(AiSettingsField.model).trim().isEmpty) {
      errors[AiSettingsField.model] = '请输入模型名称';
    }
    final temperature = double.tryParse(
      state.value(AiSettingsField.temperature).trim(),
    );
    if (temperature == null || !temperature.isFinite) {
      errors[AiSettingsField.temperature] = '请输入 0 到 2 之间的数字';
    } else if (temperature < 0 || temperature > 2) {
      errors[AiSettingsField.temperature] = '范围应为 0 到 2';
    }
    final maxTokens = int.tryParse(
      state.value(AiSettingsField.maxTokens).trim(),
    );
    if (maxTokens == null) {
      errors[AiSettingsField.maxTokens] = '请输入正整数';
    } else if (maxTokens <= 0) {
      errors[AiSettingsField.maxTokens] = '必须大于 0';
    }
    return errors;
  }
}
