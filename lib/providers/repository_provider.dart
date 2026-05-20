import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ai_settings_repository.dart';
import '../data/repositories/personal_color_repository.dart';
import '../data/repositories/preset_repository.dart';
import '../data/repositories/snapshot_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import 'storage_provider.dart';

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  return AiSettingsRepository(ref.watch(localFileStorageProvider));
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(localFileStorageProvider));
});

final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  return PresetRepository(ref.watch(localFileStorageProvider));
});

final snapshotRepositoryProvider = Provider<SnapshotRepository>((ref) {
  return SnapshotRepository(ref.watch(localFileStorageProvider));
});

final personalColorRepositoryProvider =
    Provider<PersonalColorRepository>((ref) {
  return PersonalColorRepository(ref.watch(localFileStorageProvider));
});
