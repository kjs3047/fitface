import '../../data/models/ai_analysis_result.dart';
import '../../data/models/image_feature_summary.dart';
import '../../data/models/outfit_snapshot.dart';

class RuleBasedAiAnalysisService {
  const RuleBasedAiAnalysisService();

  AiAnalysisResult analyzeSnapshot({
    required OutfitSnapshot snapshot,
    required ImageFeatureSummary? features,
    required String reason,
  }) {
    final score = _score(features);
    final qualityNote = _qualityNote(features);
    return AiAnalysisResult(
      score: score,
      comment: '모델 분석을 완료하지 못해 색상정보 기준으로 판단했습니다. '
          '$qualityNote 점수는 밝기, 대비, 채도 균형을 기준으로 한 참고값입니다.',
      tags: _tags(features),
      strengths: [
        '로컬 색상정보로 후보의 밝기와 대비 균형을 확인했습니다.',
        if (features != null) '대표 색상은 ${features.averageHex} 계열입니다.',
      ],
      concerns: [
        '이미지 맥락을 직접 본 결과가 아니므로 실루엣과 소재감 판단은 제한됩니다.',
        reason,
      ],
      suggestions: [
        '비슷한 색감의 옷은 매장 조명 아래에서 한 번 더 비교해보세요.',
      ],
      confidence: features == null ? 0.32 : 0.48,
      engine: 'ruleBased',
      analysisMode: features == null ? 'fallback' : 'featuresOnly',
      createdAt: DateTime.now(),
      rawFeatureSummary: features?.toJson(),
    );
  }

  AiAnalysisResult compareSnapshots({
    required List<OutfitSnapshot> snapshots,
    required Map<String, ImageFeatureSummary> featuresBySnapshotId,
    required String reason,
  }) {
    if (snapshots.isEmpty) {
      return AiAnalysisResult(
        score: 0,
        comment: '비교할 후보를 먼저 저장해주세요.',
        engine: 'ruleBased',
        analysisMode: 'fallback',
        createdAt: DateTime.now(),
      );
    }
    final scores = <String, int>{};
    final comments = <String, String>{};
    for (final snapshot in snapshots) {
      final features = featuresBySnapshotId[snapshot.id];
      scores[snapshot.id] = _score(features);
      comments[snapshot.id] = _shortComment(features);
    }
    final best = scores.entries
        .reduce((current, next) => current.value >= next.value ? current : next)
        .key;
    final bestIndex = snapshots.indexWhere((snapshot) => snapshot.id == best);
    return AiAnalysisResult(
      score: scores[best]!,
      bestSnapshotId: best,
      candidateScores: scores,
      candidateComments: comments,
      comment: '모델 비교를 완료하지 못해 색상정보 기준으로 후보 ${bestIndex + 1}을 선택했습니다. '
          '밝기, 대비, 채도 균형이 가장 안정적인 후보입니다.',
      tags: const ['색상정보기준', 'fallback', '참고판단'],
      concerns: [reason],
      suggestions: const ['BEST 후보도 실제 매장 조명에서 한 번 더 확인하는 편이 좋습니다.'],
      confidence: 0.45,
      engine: 'ruleBased',
      analysisMode: 'featuresOnly',
      createdAt: DateTime.now(),
    );
  }

  int _score(ImageFeatureSummary? features) {
    if (features == null) {
      return 62;
    }
    final brightnessFit = 1 - (features.brightness - 0.62).abs();
    final contrastFit = 1 - (features.contrast - 0.22).abs() * 2.2;
    final saturationFit = 1 - (features.saturation - 0.38).abs() * 1.4;
    final qualityPenalty = features.imageQualityHints.length * 4;
    final score = 45 +
        brightnessFit.clamp(0.0, 1.0) * 22 +
        contrastFit.clamp(0.0, 1.0) * 18 +
        saturationFit.clamp(0.0, 1.0) * 15 -
        qualityPenalty;
    return score.round().clamp(40, 92);
  }

  List<String> _tags(ImageFeatureSummary? features) {
    if (features == null) {
      return const ['분석제한', '참고판단'];
    }
    final tone = features.warmCoolBias > 0.08
        ? '웜톤경향'
        : features.warmCoolBias < -0.08
            ? '쿨톤경향'
            : '뉴트럴';
    return [
      tone,
      features.brightness >= 0.55 ? '밝은색감' : '차분한색감',
      features.contrast >= 0.2 ? '대비있음' : '부드러운대비',
    ];
  }

  String _qualityNote(ImageFeatureSummary? features) {
    if (features == null || features.imageQualityHints.isEmpty) {
      return '이미지 품질 경고는 없습니다.';
    }
    return '품질 참고: ${features.imageQualityHints.join(', ')}.';
  }

  String _shortComment(ImageFeatureSummary? features) {
    if (features == null) {
      return '이미지 색상정보를 읽지 못해 기본 점수로 계산했습니다.';
    }
    return '대표색 ${features.averageHex}, 밝기 ${features.brightness.toStringAsFixed(2)}, '
        '대비 ${features.contrast.toStringAsFixed(2)} 기준입니다.';
  }
}
