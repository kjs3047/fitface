import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_profile.dart';
import '../data/repositories/user_profile_repository.dart';
import '../domain/profile/body_type.dart';
import 'repository_provider.dart';

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  return UserProfileNotifier(ref.watch(userProfileRepositoryProvider));
});

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileNotifier(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final UserProfileRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.loadProfile);
  }

  Future<UserProfile> saveFace({
    required String originalFaceImagePath,
    required String croppedFaceImagePath,
    required String overlayFaceImagePath,
  }) async {
    final profile = await _repository.saveFace(
      originalFaceImagePath: originalFaceImagePath,
      croppedFaceImagePath: croppedFaceImagePath,
      overlayFaceImagePath: overlayFaceImagePath,
    );
    state = AsyncValue.data(profile);
    return profile;
  }

  Future<UserProfile> saveBasicInfo({
    required Gender gender,
    required BodyType bodyType,
    int? heightCm,
    int? weightKg,
  }) async {
    final profile = await _repository.saveBasicInfo(
      gender: gender,
      bodyType: bodyType,
      heightCm: heightCm,
      weightKg: weightKg,
    );
    state = AsyncValue.data(profile);
    return profile;
  }

  Future<UserProfile> savePersonalColorType(String personalColorType) async {
    final profile = await _repository.savePersonalColorType(personalColorType);
    state = AsyncValue.data(profile);
    return profile;
  }

  Future<UserProfile> clearPersonalColorType() async {
    final profile = await _repository.clearPersonalColorType();
    state = AsyncValue.data(profile);
    return profile;
  }

  Future<void> clear() async {
    await _repository.clearProfile();
    state = const AsyncValue.data(null);
  }
}
