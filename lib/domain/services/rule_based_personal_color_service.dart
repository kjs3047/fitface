import '../../data/models/image_feature_summary.dart';
import '../../data/models/personal_color_result.dart';
import '../personal_color/personal_color_type.dart';

class RuleBasedPersonalColorService {
  const RuleBasedPersonalColorService();

  PersonalColorResult analyze({
    required ImageFeatureSummary? features,
    required String reason,
  }) {
    if (features == null) {
      // 색상정보가 없으면 가장 중립적인 여름 쿨 트루 팔레트로 안내한다.
      final fallback = PersonalColorTypes.summerTrue;
      return PersonalColorResult(
        type: fallback.label,
        recommendedColors: fallback.recommendedColors,
        avoidColors: fallback.avoidColors,
        comment:
            '이미지 색상정보를 읽지 못해 기본 팔레트로 안내합니다. 밝은 자연광 사진으로 다시 분석하면 결과를 더 참고하기 좋습니다. $reason',
      );
    }

    final type = PersonalColorTypes.classify(
      warmCoolBias: features.warmCoolBias,
      brightness: features.brightness,
      saturation: features.saturation,
    );
    return PersonalColorResult(
      type: type.label,
      recommendedColors: type.recommendedColors,
      avoidColors: type.avoidColors,
      comment: '모델 분석을 완료하지 못해 사진의 밝기, 채도, 웜/쿨 경향 기준으로 계산했습니다. '
          '대표 색상은 ${features.averageHex}이고, ${_qualityNote(features)} '
          '결과는 쇼핑 색상 선택을 위한 참고용입니다.',
    );
  }

  String _qualityNote(ImageFeatureSummary features) {
    if (features.imageQualityHints.isEmpty) {
      return '품질 경고는 없습니다.';
    }
    return '품질 참고: ${features.imageQualityHints.join(', ')}.';
  }
}
