import '../../data/models/personal_color_result.dart';
import 'personal_color_service.dart';

class MockPersonalColorService implements PersonalColorService {
  @override
  Future<PersonalColorResult> analyze({String? faceImagePath}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const PersonalColorResult(
      type: '여름 쿨',
      recommendedColors: ['라벤더', '소프트 블루', '로즈 핑크', '민트', '화이트'],
      avoidColors: ['강한 오렌지', '탁한 브라운', '네온 옐로', '레드', '블랙'],
      comment: '밝은 자연광 사진을 기준으로 참고하기 좋은 스타일링 결과입니다.',
    );
  }
}
