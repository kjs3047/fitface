import 'package:uuid/uuid.dart';

import '../../core/constants/storage_keys.dart';
import '../local/local_file_storage.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._storage);

  final LocalFileStorage _storage;
  final _uuid = const Uuid();

  Future<UserProfile?> loadProfile() async {
    final json = await _storage.readJsonMap(StorageKeys.profileJson);
    if (json == null) {
      return null;
    }
    return UserProfile.fromJson(json);
  }

  Future<UserProfile> saveFace({
    required String originalFaceImagePath,
    required String croppedFaceImagePath,
    required String overlayFaceImagePath,
  }) async {
    final now = DateTime.now();
    final current = await loadProfile();
    final profile = (current ??
            UserProfile(
              id: _uuid.v4(),
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      originalFaceImagePath: originalFaceImagePath,
      croppedFaceImagePath: croppedFaceImagePath,
      overlayFaceImagePath: overlayFaceImagePath,
      clearPersonalColorType: true,
      updatedAt: now,
    );
    await saveProfile(profile);
    return profile;
  }

  Future<UserProfile> savePersonalColorType(String personalColorType) async {
    final current = await loadProfile();
    if (current == null) {
      throw StateError('등록된 얼굴 프로필이 없습니다.');
    }
    final profile = current.copyWith(
      personalColorType: personalColorType,
      updatedAt: DateTime.now(),
    );
    await saveProfile(profile);
    return profile;
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _storage.writeJsonMap(StorageKeys.profileJson, profile.toJson());
  }

  Future<void> clearProfile({bool deleteImages = true}) async {
    final profile = await loadProfile();
    if (deleteImages) {
      await _storage.deleteFileSafely(profile?.originalFaceImagePath);
      await _storage.deleteFileSafely(profile?.croppedFaceImagePath);
      await _storage.deleteFileSafely(profile?.overlayFaceImagePath);
    }
    await _storage.deleteMetadata(StorageKeys.profileJson);
  }
}
