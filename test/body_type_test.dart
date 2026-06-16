import 'package:fitface/domain/profile/body_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BodyType / Gender enum', () {
    test('체형은 6종이다', () {
      expect(BodyType.values.length, 6);
    });

    test('성별은 2종이다', () {
      expect(Gender.values.length, 2);
    });

    test('기본값은 보통형/여성', () {
      expect(defaultBodyType, BodyType.normal);
      expect(defaultGender, Gender.female);
    });

    test('모든 체형에 한국어 라벨이 있다', () {
      for (final t in BodyType.values) {
        expect(t.label.isNotEmpty, isTrue, reason: t.name);
      }
    });

    test('fromName 왕복', () {
      for (final t in BodyType.values) {
        expect(BodyType.fromName(t.name), t);
      }
      for (final g in Gender.values) {
        expect(Gender.fromName(g.name), g);
      }
      expect(BodyType.fromName('없음'), isNull);
      expect(Gender.fromName(null), isNull);
    });

    test('애셋 경로 규약', () {
      expect(
        bodyTypeAsset(Gender.female, BodyType.slim),
        'assets/body_types/female_slim.png',
      );
      expect(
        bodyTypeAsset(Gender.male, BodyType.bottomHeavy),
        'assets/body_types/male_bottom_heavy.png',
      );
    });

    test('프롬프트 묘사: 키/몸무게 있으면 포함, 없으면 생략', () {
      final full = bodyDescriptionForPrompt(
        gender: Gender.male,
        bodyType: BodyType.muscular,
        heightCm: 178,
        weightKg: 74,
      );
      expect(full, contains('man'));
      expect(full, contains('178cm'));
      expect(full, contains('74kg'));

      final minimal = bodyDescriptionForPrompt(
        gender: Gender.female,
        bodyType: BodyType.slim,
      );
      expect(minimal, contains('woman'));
      expect(minimal, isNot(contains('cm')));
      expect(minimal, isNot(contains('kg')));
    });
  });
}
