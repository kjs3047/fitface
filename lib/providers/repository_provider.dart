import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/preset_repository.dart';
import '../data/repositories/snapshot_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import 'storage_provider.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(localFileStorageProvider));
});

final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  return PresetRepository(ref.watch(localFileStorageProvider));
});

final snapshotRepositoryProvider = Provider<SnapshotRepository>((ref) {
  return SnapshotRepository(ref.watch(localFileStorageProvider));
});
