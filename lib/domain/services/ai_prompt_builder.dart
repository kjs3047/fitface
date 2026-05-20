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
      '출력: score, comment, tags, strengths, concerns, suggestions, confidence를 포함한 JSON.',
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
      '출력: bestSnapshotId, candidateScores, candidateComments, comment를 포함한 JSON.',
    );
    return lines.join('\n');
  }
}
