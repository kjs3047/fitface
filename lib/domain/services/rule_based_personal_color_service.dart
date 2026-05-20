import '../../data/models/image_feature_summary.dart';
import '../../data/models/personal_color_result.dart';

class RuleBasedPersonalColorService {
  const RuleBasedPersonalColorService();

  PersonalColorResult analyze({
    required ImageFeatureSummary? features,
    required String reason,
  }) {
    if (features == null) {
      return PersonalColorResult(
        type: '뉴트럴',
        recommendedColors: const ['아이보리', '소프트 블루', '그레이', '로즈 베이지', '민트'],
        avoidColors: const ['네온 옐로', '강한 오렌지', '형광 핑크', '탁한 브라운', '고채도 레드'],
        comment:
            '이미지 색상정보를 읽지 못해 기본 팔레트로 안내합니다. 밝은 자연광 사진으로 다시 분석하면 결과를 더 참고하기 좋습니다. $reason',
      );
    }

    final type = _type(features);
    return PersonalColorResult(
      type: type,
      recommendedColors: _recommendedColors(type),
      avoidColors: _avoidColors(type),
      comment: '모델 분석을 완료하지 못해 사진의 밝기, 채도, 웜/쿨 경향 기준으로 계산했습니다. '
          '대표 색상은 ${features.averageHex}이고, ${_qualityNote(features)} '
          '결과는 쇼핑 색상 선택을 위한 참고용입니다.',
    );
  }

  String _type(ImageFeatureSummary features) {
    if (features.warmCoolBias > 0.08) {
      return features.brightness >= 0.55 ? '봄 웜' : '가을 웜';
    }
    if (features.warmCoolBias < -0.08) {
      return features.brightness >= 0.55 ? '여름 쿨' : '겨울 쿨';
    }
    return features.saturation >= 0.38 ? '뉴트럴 브라이트' : '뉴트럴 소프트';
  }

  List<String> _recommendedColors(String type) {
    switch (type) {
      case '봄 웜':
        return const ['크림', '코랄', '피치', '라이트 카멜', '애플 그린'];
      case '가을 웜':
        return const ['카멜', '올리브', '테라코타', '웜 베이지', '브릭'];
      case '여름 쿨':
        return const ['라벤더', '소프트 블루', '로즈 핑크', '민트', '라이트 그레이'];
      case '겨울 쿨':
        return const ['네이비', '차콜', '버건디', '퓨어 화이트', '쿨 레드'];
      case '뉴트럴 브라이트':
        return const ['화이트', '클리어 블루', '로즈', '라이트 그레이', '민트'];
      default:
        return const ['아이보리', '소프트 그레이', '더스티 핑크', '세이지', '데님 블루'];
    }
  }

  List<String> _avoidColors(String type) {
    switch (type) {
      case '봄 웜':
        return const ['차콜', '블랙', '버건디', '쿨 퍼플', '네온 블루'];
      case '가을 웜':
        return const ['형광 핑크', '아이스 블루', '실버 그레이', '쿨 민트', '쨍한 화이트'];
      case '여름 쿨':
        return const ['강한 오렌지', '탁한 브라운', '네온 옐로', '카멜', '토마토 레드'];
      case '겨울 쿨':
        return const ['탁한 베이지', '카키 브라운', '머스터드', '웜 오렌지', '흐린 파스텔'];
      case '뉴트럴 브라이트':
        return const ['탁한 브라운', '머스터드', '카키', '딥 오렌지', '먹색'];
      default:
        return const ['네온 옐로', '강한 오렌지', '형광 핑크', '탁한 브라운', '고채도 레드'];
    }
  }

  String _qualityNote(ImageFeatureSummary features) {
    if (features.imageQualityHints.isEmpty) {
      return '품질 경고는 없습니다.';
    }
    return '품질 참고: ${features.imageQualityHints.join(', ')}.';
  }
}
