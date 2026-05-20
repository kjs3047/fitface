import '../../core/constants/storage_keys.dart';
import '../local/local_file_storage.dart';
import '../models/ai_settings.dart';

class AiSettingsRepository {
  AiSettingsRepository(this._storage);

  final LocalFileStorage _storage;

  Future<AiSettings> loadSettings() async {
    final json = await _storage.readJsonMap(StorageKeys.aiSettingsJson);
    if (json == null) {
      return AiSettings.defaults();
    }
    return AiSettings.fromJson(json);
  }

  Future<AiSettings> saveSettings(AiSettings settings) async {
    final next = settings.copyWith(updatedAt: DateTime.now());
    await _storage.writeJsonMap(StorageKeys.aiSettingsJson, next.toJson());
    return next;
  }

  Future<void> clearSettings() async {
    await _storage.deleteMetadata(StorageKeys.aiSettingsJson);
  }
}
