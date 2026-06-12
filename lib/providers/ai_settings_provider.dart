import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_settings.dart';
import '../data/repositories/ai_settings_repository.dart';
import 'repository_provider.dart';

final aiSettingsProvider =
    StateNotifierProvider<AiSettingsNotifier, AsyncValue<AiSettings>>((ref) {
  return AiSettingsNotifier(ref.watch(aiSettingsRepositoryProvider));
});

class AiSettingsNotifier extends StateNotifier<AsyncValue<AiSettings>> {
  AiSettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final AiSettingsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadSettings);
  }

  Future<void> setMode(AiEngineMode mode) async {
    final current = state.value ?? await _repository.loadSettings();
    state = AsyncValue.data(
      await _repository.saveSettings(current.copyWith(mode: mode)),
    );
  }

  Future<void> setCloudConsent(bool value) async {
    final current = state.value ?? await _repository.loadSettings();
    state = AsyncValue.data(
      await _repository.saveSettings(
        current.copyWith(allowCloudAnalysis: value),
      ),
    );
  }

  Future<void> setOpenAiProxyUrl(String? value) async {
    final current = state.value ?? await _repository.loadSettings();
    final normalized = value == null || value.trim().isEmpty
        ? null
        : value.trim().replaceAll(RegExp(r'/+$'), '');
    state = AsyncValue.data(
      await _repository.saveSettings(
        current.copyWith(
          openAiProxyUrl: normalized,
          clearOpenAiProxyUrl: normalized == null,
        ),
      ),
    );
  }

  Future<void> setOpenAiProxyToken(String? value) async {
    final current = state.value ?? await _repository.loadSettings();
    final normalized = value == null || value.trim().isEmpty ? null : value.trim();
    state = AsyncValue.data(
      await _repository.saveSettings(
        current.copyWith(
          openAiProxyToken: normalized,
          clearOpenAiProxyToken: normalized == null,
        ),
      ),
    );
  }

  Future<void> setLocalModel({
    String? path,
    String? name,
  }) async {
    final current = state.value ?? await _repository.loadSettings();
    final normalizedPath =
        path == null || path.trim().isEmpty ? null : path.trim();
    final normalizedName =
        name == null || name.trim().isEmpty ? null : name.trim();
    state = AsyncValue.data(
      await _repository.saveSettings(
        current.copyWith(
          localModelPath: normalizedPath,
          localModelName: normalizedName,
          clearLocalModelPath: normalizedPath == null,
          clearLocalModelName: normalizedName == null,
        ),
      ),
    );
  }
}
