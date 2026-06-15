import 'package:fitface/domain/personal_color/personal_color_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonalColorTypes 목록', () {
    test('정확히 12개이고 라벨이 중복 없이 고유하다', () {
      expect(PersonalColorTypes.all.length, 12);
      final labels = PersonalColorTypes.labels;
      expect(labels.length, 12);
      expect(labels.toSet().length, 12);
    });

    test('계절별로 3개씩이다', () {
      final bySeason = <String, int>{};
      for (final t in PersonalColorTypes.all) {
        bySeason[t.season] = (bySeason[t.season] ?? 0) + 1;
      }
      expect(bySeason, {'봄': 3, '여름': 3, '가을': 3, '겨울': 3});
    });

    test('봄/가을은 웜, 여름/겨울은 쿨이다', () {
      for (final t in PersonalColorTypes.all) {
        if (t.season == '봄' || t.season == '가을') {
          expect(t.isWarm, isTrue, reason: t.label);
        } else {
          expect(t.isCool, isTrue, reason: t.label);
        }
      }
    });

    test('byLabel은 정식 라벨만 찾고 그 외엔 null', () {
      expect(PersonalColorTypes.byLabel('봄 웜 라이트'), isNotNull);
      expect(PersonalColorTypes.byLabel(' 봄 웜 라이트 '), isNotNull); // trim
      expect(PersonalColorTypes.byLabel('여름 쿨'), isNull); // 옛 표기
      expect(PersonalColorTypes.byLabel('없는유형'), isNull);
    });
  });

  group('classify (rule-based 축 → 유형)', () {
    test('웜 + 고명도 → 봄 계열', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: 0.2,
        brightness: 0.65,
        saturation: 0.4,
      );
      expect(t.season, '봄');
    });

    test('웜 + 저명도 → 가을 계열', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: 0.2,
        brightness: 0.35,
        saturation: 0.4,
      );
      expect(t.season, '가을');
    });

    test('쿨 + 고명도 → 여름 계열', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: -0.2,
        brightness: 0.65,
        saturation: 0.4,
      );
      expect(t.season, '여름');
    });

    test('쿨 + 저명도 → 겨울 계열', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: -0.2,
        brightness: 0.35,
        saturation: 0.4,
      );
      expect(t.season, '겨울');
    });

    test('웜 + 아주 밝음 → 봄 라이트', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: 0.2,
        brightness: 0.8,
        saturation: 0.4,
      );
      expect(t.label, '봄 웜 라이트');
    });

    test('웜 + 밝고 고채도 → 봄 브라이트', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: 0.2,
        brightness: 0.6,
        saturation: 0.7,
      );
      expect(t.label, '봄 웜 브라이트');
    });

    test('쿨 + 어둡고 고채도 → 겨울 브라이트', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: -0.2,
        brightness: 0.45,
        saturation: 0.7,
      );
      expect(t.label, '겨울 쿨 브라이트');
    });

    test('뉴트럴(웜/쿨 경향 미약)도 12유형 중 하나로 배정된다', () {
      final t = PersonalColorTypes.classify(
        warmCoolBias: 0.0,
        brightness: 0.5,
        saturation: 0.5,
      );
      expect(PersonalColorTypes.byLabel(t.label), isNotNull);
    });

    test('어떤 입력이든 결과는 항상 12유형 목록 안에 있다', () {
      for (final bias in [-0.3, -0.05, 0.0, 0.05, 0.3]) {
        for (final bright in [0.2, 0.5, 0.6, 0.85]) {
          for (final sat in [0.2, 0.4, 0.65]) {
            final t = PersonalColorTypes.classify(
              warmCoolBias: bias,
              brightness: bright,
              saturation: sat,
            );
            expect(
              PersonalColorTypes.byLabel(t.label),
              isNotNull,
              reason: 'bias=$bias bright=$bright sat=$sat → ${t.label}',
            );
          }
        }
      }
    });
  });

  group('closestTo (목록 밖 문자열 매핑)', () {
    test('정식 라벨은 그대로 반환', () {
      expect(PersonalColorTypes.closestTo('가을 웜 딥')?.label, '가을 웜 딥');
    });

    test('옛 6유형 표기를 가장 가까운 유형으로 매핑', () {
      // 계절만 있으면 해당 계절의 트루로.
      expect(PersonalColorTypes.closestTo('여름 쿨')?.season, '여름');
      expect(PersonalColorTypes.closestTo('봄 웜')?.season, '봄');
    });

    test('영문 표기도 매핑', () {
      expect(PersonalColorTypes.closestTo('Bright Winter')?.season, '겨울');
      expect(PersonalColorTypes.closestTo('Soft Autumn')?.season, '가을');
    });

    test('세부 단서로 정확한 유형까지 매핑', () {
      expect(PersonalColorTypes.closestTo('여름 라이트')?.label, '여름 쿨 라이트');
      expect(PersonalColorTypes.closestTo('가을 딥')?.label, '가을 웜 딥');
    });

    test('계절/온도 단서가 전혀 없으면 null', () {
      expect(PersonalColorTypes.closestTo('알수없음'), isNull);
      expect(PersonalColorTypes.closestTo(''), isNull);
    });
  });
}
