import 'package:fitface/data/models/personal_color_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonalColorSwatch.fromJson', () {
    test('객체 {name, hex}를 그대로 보존한다', () {
      final swatch = PersonalColorSwatch.fromJson({
        'name': '테라코타',
        'hex': '#C66E4E',
      });
      expect(swatch.name, '테라코타');
      expect(swatch.hex, '#C66E4E');
    });

    test('옛 문자열은 이름만, hex는 null (하위호환)', () {
      final swatch = PersonalColorSwatch.fromJson('라벤더');
      expect(swatch.name, '라벤더');
      expect(swatch.hex, isNull);
    });

    test('hex가 빈 문자열이면 null로 정규화', () {
      final swatch = PersonalColorSwatch.fromJson({'name': '코랄', 'hex': ''});
      expect(swatch.hex, isNull);
    });
  });

  group('PersonalColorResult JSON 왕복', () {
    test('객체 배열 응답을 파싱하고 hex를 유지한다', () {
      final result = PersonalColorResult.fromJson({
        'type': '가을 웜 뮤트',
        'recommendedColors': [
          {'name': '테라코타', 'hex': '#C66E4E'},
          {'name': '올리브', 'hex': '#808000'},
        ],
        'avoidColors': [
          {'name': '형광 핑크', 'hex': '#FF4FA3'},
        ],
        'comment': '분석 결과',
      });
      expect(result.recommendedColors.length, 2);
      expect(result.recommendedColors.first.name, '테라코타');
      expect(result.recommendedColors.first.hex, '#C66E4E');
      expect(result.recommendedColorNames, ['테라코타', '올리브']);

      // 직렬화 왕복에서 hex가 보존된다.
      final round = PersonalColorResult.fromJson(result.toJson());
      expect(round.recommendedColors.first.hex, '#C66E4E');
    });

    test('옛 문자열 배열 저장값도 로드된다 (마이그레이션 불필요)', () {
      final result = PersonalColorResult.fromJson({
        'type': '여름 쿨',
        'recommendedColors': ['소프트 블루', '라벤더'],
        'avoidColors': ['강한 오렌지'],
        'comment': '옛 저장값',
      });
      expect(result.recommendedColorNames, ['소프트 블루', '라벤더']);
      expect(result.recommendedColors.first.hex, isNull);
    });
  });
}
