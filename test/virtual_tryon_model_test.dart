import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/data/models/user_profile.dart';
import 'package:fitface/domain/profile/body_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile 신체정보', () {
    test('신체정보 직렬화 왕복', () {
      final now = DateTime.parse('2026-06-16T00:00:00.000');
      final profile = UserProfile(
        id: 'p1',
        gender: Gender.male,
        bodyType: BodyType.topHeavy,
        heightCm: 180,
        weightKg: 78,
        createdAt: now,
        updatedAt: now,
      );
      final round = UserProfile.fromJson(profile.toJson());
      expect(round.gender, Gender.male);
      expect(round.bodyType, BodyType.topHeavy);
      expect(round.heightCm, 180);
      expect(round.weightKg, 78);
      expect(round.hasBodyInfo, isTrue);
    });

    test('신체정보 없는 옛 JSON도 로드된다 (마이그레이션 불필요)', () {
      final legacy = {
        'id': 'p0',
        'originalFaceImagePath': 'a.png',
        'personalColorType': '여름 쿨',
        'createdAt': '2026-06-01T00:00:00.000',
        'updatedAt': '2026-06-01T00:00:00.000',
      };
      final profile = UserProfile.fromJson(legacy);
      expect(profile.gender, isNull);
      expect(profile.bodyType, isNull);
      expect(profile.heightCm, isNull);
      expect(profile.hasBodyInfo, isFalse);
      // 기존 필드는 유지.
      expect(profile.personalColorType, '여름 쿨');
    });
  });

  group('OutfitSnapshot 가상착장 필드', () {
    test('rawImagePath/tryOn 필드 직렬화 왕복', () {
      final now = DateTime.parse('2026-06-16T00:00:00.000');
      final snapshot = OutfitSnapshot(
        id: 's1',
        imagePath: 'overlay.png',
        rawImagePath: 'raw.png',
        tryOnImagePath: 'tryon.png',
        tryOnBodyType: BodyType.normal.name,
        tryOnRegenCount: 2,
        createdAt: now,
      );
      final round = OutfitSnapshot.fromJson(snapshot.toJson());
      expect(round.rawImagePath, 'raw.png');
      expect(round.hasRawImage, isTrue);
      expect(round.tryOnImagePath, 'tryon.png');
      expect(round.hasTryOnImage, isTrue);
      expect(round.tryOnBodyType, 'normal');
      expect(round.tryOnRegenCount, 2);
    });

    test('가상착장 필드 없는 옛 JSON도 로드된다', () {
      final legacy = {
        'id': 's0',
        'imagePath': 'overlay.png',
        'createdAt': '2026-06-01T00:00:00.000',
      };
      final snapshot = OutfitSnapshot.fromJson(legacy);
      expect(snapshot.rawImagePath, isNull);
      expect(snapshot.hasRawImage, isFalse);
      expect(snapshot.tryOnImagePath, isNull);
      expect(snapshot.tryOnRegenCount, 0);
    });

    test('clearTryOn은 tryOn 관련 필드를 비운다', () {
      final now = DateTime.parse('2026-06-16T00:00:00.000');
      final snapshot = OutfitSnapshot(
        id: 's2',
        imagePath: 'o.png',
        tryOnImagePath: 't.png',
        tryOnBodyType: 'normal',
        createdAt: now,
      ).copyWith(clearTryOn: true);
      expect(snapshot.tryOnImagePath, isNull);
      expect(snapshot.tryOnBodyType, isNull);
    });
  });
}
