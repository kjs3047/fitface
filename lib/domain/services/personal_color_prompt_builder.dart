import '../../data/models/image_feature_summary.dart';

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
      '금지: 얼굴 외모, 피부 품질, 미모, 결점 평가. 절대적 진단처럼 단정하지 않는다.',
      '출력 JSON 필드: type, recommendedColors, avoidColors, comment.',
      'recommendedColors와 avoidColors는 각각 한국어 색상명 5개 이내 배열로 작성한다.',
    ].join('\n');
  }
}
