import '../../data/models/image_feature_summary.dart';
import '../personal_color/personal_color_type.dart';

class PersonalColorPromptBuilder {
  const PersonalColorPromptBuilder();

  String buildPrompt({
    required ImageFeatureSummary? features,
    required bool includeImage,
  }) {
    return [
      '역할: FitFace 퍼스널 컬러 스타일링 보조 AI.',
      '목표: 얼굴 외모를 평가하지 않고, 등록 얼굴 이미지의 색상 경향과 조명 상태를 참고해 쇼핑용 컬러 팔레트를 제안한다.',
      if (includeImage) '입력 이미지: 사용자가 등록한 얼굴 사진 1장.',
      if (features != null) '앱 사전 색상분석: ${features.toPromptText()}',
      '분석 기준: 웜/쿨 경향, 밝기, 채도, 대비, 사진 품질 힌트를 함께 고려한다.',
      _typeGuide(),
      '금지: 얼굴 외모, 피부 품질, 미모, 결점 평가. 절대적 진단처럼 단정하지 않는다.',
      '출력은 반드시 JSON 객체 하나만 사용한다. 설명 문장이나 markdown은 쓰지 않는다.',
      '필수 JSON 필드: type, recommendedColors, avoidColors, comment.',
      'type은 위 12유형 목록 중 정확히 하나를 한 글자도 바꾸지 말고 그대로 쓴다.',
      'recommendedColors와 avoidColors는 각각 한국어 색상명 5개 이내 배열로 작성한다.',
    ].join('\n');
  }

  String buildLocalPrompt({
    required ImageFeatureSummary? features,
  }) {
    return [
      '역할: FitFace Local Gemma 퍼스널 컬러 보조.',
      '입력: 이미지 사전 색상정보만 사용한다.',
      '색상정보: ${_compactFeatureText(features)}',
      _typeGuide(),
      '금지: 얼굴 외모, 피부 품질, 미모, 결점 평가.',
      '출력은 JSON 객체 하나만 사용한다.',
      '필드: type, recommendedColors, avoidColors, comment.',
      'type은 위 12유형 목록 중 정확히 하나를 한 글자도 바꾸지 말고 그대로 쓴다.',
      'recommendedColors와 avoidColors는 각각 한국어 색상명 배열로 작성한다.',
      'comment는 쇼핑용 컬러 조언 한 문장으로 작성한다.',
    ].join('\n');
  }

  /// 12계절 유형 목록과 판정 축을 모델에 명시해 답안을 객관식으로 고정한다.
  String _typeGuide() {
    final list = PersonalColorTypes.labels.join(', ');
    return [
      '판정 체계: 12계절. 축은 온도(웜/쿨) × 명도(라이트=밝음/트루=중간/딥=어두움) '
          '× 채도(브라이트=맑음/뮤트=탁함)이다.',
      '웜=봄·가을, 쿨=여름·겨울. 봄=밝은 웜, 가을=어두운 웜, 여름=밝은 쿨, 겨울=어두운 쿨.',
      'type은 다음 12개 중 하나여야 한다: $list.',
    ].join('\n');
  }

  String _compactFeatureText(ImageFeatureSummary? features) {
    if (features == null) {
      return 'missing';
    }
    final colors = features.dominantColors
        .take(3)
        .map((color) => '${color.hex} ${(color.ratio * 100).round()}%')
        .join(', ');
    final tone = features.warmCoolBias > 0.08
        ? 'warm'
        : features.warmCoolBias < -0.08
            ? 'cool'
            : 'neutral';
    final quality = features.imageQualityHints.isEmpty
        ? 'none'
        : features.imageQualityHints.join(',');
    return 'avg ${features.averageHex}; colors [$colors]; '
        'brightness ${features.brightness.toStringAsFixed(2)}; '
        'contrast ${features.contrast.toStringAsFixed(2)}; '
        'saturation ${features.saturation.toStringAsFixed(2)}; '
        'tone $tone; quality $quality';
  }
}
