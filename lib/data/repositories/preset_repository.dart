import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/storage_keys.dart';
import '../local/local_file_storage.dart';
import '../models/overlay_preset.dart';

class PresetRepository {
  PresetRepository(this._storage);

  final LocalFileStorage _storage;
  final _uuid = const Uuid();

  Future<OverlayPreset?> loadPreset() async {
    final json = await _storage.readJsonMap(StorageKeys.presetJson);
    if (json == null) {
      return null;
    }
    return OverlayPreset.fromJson(json);
  }

  Future<OverlayPreset> savePreset(OverlayPreset preset) async {
    await _storage.writeJsonMap(StorageKeys.presetJson, preset.toJson());
    return preset;
  }

  Future<OverlayPreset> saveDefaultPreset() {
    final now = DateTime.now();
    return savePreset(
      OverlayPreset(
        id: _uuid.v4(),
        positionX: 0,
        positionY: 0,
        scale: AppConstants.defaultOverlayScale,
        opacity: AppConstants.defaultOverlayOpacity,
        updatedAt: now,
      ),
    );
  }

  Future<void> clearPreset() async {
    await _storage.deleteMetadata(StorageKeys.presetJson);
  }
}
