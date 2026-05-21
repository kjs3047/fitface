import '../../data/models/image_feature_summary.dart';
import '../../data/models/outfit_snapshot.dart';

class AiPromptBuilder {
  const AiPromptBuilder();

  String buildSnapshotPrompt({
    required OutfitSnapshot snapshot,
    required ImageFeatureSummary? features,
    required bool includeImage,
  }) {
    final memo = snapshot.memo?.trim();
    return [
      '역할: FitFace 스타일링 보조 AI.',
      '목표: 얼굴 자체가 아니라 옷 색감, 매장 조명, 얼굴 오버레이와의 조화를 평가한다.',
      if (includeImage) '입력 이미지: FitFace 스냅샷 1장.',
      if (features != null) '앱 사전 색상분석: ${features.toPromptText()}',
      if (memo != null && memo.isNotEmpty) '사용자 메모: $memo',
      '금지: 얼굴 외모 평가, 피부 품질 평가, 절대적 단정.',
      '출력은 반드시 JSON 객체 하나만 사용한다. 설명 문장이나 markdown은 쓰지 않는다.',
      '필수 필드: score(0-100 정수), comment(한국어 문자열), bestSnapshotId(null), '
          'candidateScores({}), candidateComments({}), tags(문자열 배열), '
          'strengths(문자열 배열), concerns(문자열 배열), suggestions(문자열 배열), confidence(0-1 숫자).',
    ].join('\n');
  }

  String buildLocalSnapshotPrompt({
    required OutfitSnapshot snapshot,
    required ImageFeatureSummary? features,
  }) {
    final memo = snapshot.memo?.trim();
    return [
      '역할: FitFace Local Gemma 스타일 판단.',
      '입력: 이미지 사전 색상정보만 사용한다.',
      '색상정보: ${_compactFeatureText(features)}',
      if (memo != null && memo.isNotEmpty) '메모: $memo',
      '금지: 얼굴 외모, 피부 품질, 미모, 결점 평가.',
      '출력은 JSON 객체 하나만 사용한다.',
      '필드: score, comment, bestSnapshotId, candidateScores, candidateComments, tags, strengths, concerns, suggestions, confidence.',
      'score는 0부터 100까지 정수로, 옷 색감 조화가 좋을수록 높게 작성한다.',
      'bestSnapshotId는 null, candidateScores와 candidateComments는 빈 객체로 작성한다.',
      'comment는 한국어 한 문장으로 옷 색감 조화를 설명한다.',
    ].join('\n');
  }

  String buildComparePrompt({
    required List<OutfitSnapshot> snapshots,
    required Map<String, ImageFeatureSummary> featuresBySnapshotId,
    required bool includeImages,
  }) {
    final lines = <String>[
      '역할: FitFace 후보 비교 AI.',
      '목표: 저장 후보 중 옷 색감과 얼굴 오버레이 조화가 가장 안정적인 후보를 고른다.',
      if (includeImages) '입력 이미지: 후보 ${snapshots.length}장.',
      '후보별 사전 색상분석:',
    ];
    for (var index = 0; index < snapshots.length; index++) {
      final snapshot = snapshots[index];
      final features = featuresBySnapshotId[snapshot.id];
      final memo = snapshot.memo?.trim();
      lines.add(
        '- 후보 ${index + 1} id=${snapshot.id}; '
        'features=${features?.toPromptText() ?? 'missing'}; '
        'memo=${memo == null || memo.isEmpty ? 'none' : memo}',
      );
    }
    lines.add(
      '출력은 반드시 JSON 객체 하나만 사용한다. 설명 문장이나 markdown은 쓰지 않는다.',
    );
    lines.add(
      '필수 필드: score(0-100 정수), comment(한국어 문자열), bestSnapshotId(선택 후보 id), '
      'candidateScores(id별 0-100 정수 object), candidateComments(id별 한국어 문자열 object), '
      'tags(문자열 배열), strengths(문자열 배열), concerns(문자열 배열), suggestions(문자열 배열), confidence(0-1 숫자).',
    );
    return lines.join('\n');
  }

  String buildLocalComparePrompt({
    required List<OutfitSnapshot> snapshots,
    required Map<String, ImageFeatureSummary> featuresBySnapshotId,
  }) {
    final lines = <String>[
      '역할: FitFace Local Gemma 후보 비교.',
      '입력: 후보별 사전 색상정보만 사용한다.',
    ];
    for (var index = 0; index < snapshots.length; index++) {
      final snapshot = snapshots[index];
      final memo = snapshot.memo?.trim();
      lines.add(
        '후보${index + 1} id=${snapshot.id}: '
        '${_compactFeatureText(featuresBySnapshotId[snapshot.id])}; '
        'memo=${memo == null || memo.isEmpty ? 'none' : memo}',
      );
    }
    lines.add('금지: 얼굴 외모, 피부 품질, 미모, 결점 평가.');
    lines.add('출력은 JSON 객체 하나만 사용한다.');
    lines.add(
      '필드: score, comment, bestSnapshotId, candidateScores, candidateComments, tags, strengths, concerns, suggestions, confidence.',
    );
    lines.add('score와 candidateScores 값은 0부터 100까지 정수로 작성한다.');
    lines.add('bestSnapshotId는 위 후보 id 중 하나로 작성한다.');
    lines.add('candidateScores와 candidateComments에는 모든 후보 id를 포함한다.');
    return lines.join('\n');
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
