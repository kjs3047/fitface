import '../../data/models/personal_color_result.dart';
import 'personal_color_service.dart';

class MockPersonalColorService implements PersonalColorService {
  @override
  Future<PersonalColorResult> analyze({String? faceImagePath}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const PersonalColorResult(
      type: '여름 쿨 트루',
      recommendedColors: [
        PersonalColorSwatch(name: '라벤더', hex: '#B8A9E6'),
        PersonalColorSwatch(name: '소프트 블루', hex: '#9DB7D5'),
        PersonalColorSwatch(name: '로즈 핑크', hex: '#D6809E'),
        PersonalColorSwatch(name: '민트', hex: '#9ED8C3'),
        PersonalColorSwatch(name: '화이트', hex: '#F7F4EE'),
      ],
      avoidColors: [
        PersonalColorSwatch(name: '강한 오렌지', hex: '#F2600C'),
        PersonalColorSwatch(name: '탁한 브라운', hex: '#6B5141'),
        PersonalColorSwatch(name: '네온 옐로', hex: '#DFFF00'),
        PersonalColorSwatch(name: '레드', hex: '#C83E3A'),
        PersonalColorSwatch(name: '블랙', hex: '#171412'),
      ],
      comment: '밝은 자연광 사진을 기준으로 참고하기 좋은 스타일링 결과입니다.',
    );
  }
}
