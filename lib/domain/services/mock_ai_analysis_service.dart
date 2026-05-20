import '../../data/models/ai_analysis_result.dart';
import '../../data/models/outfit_snapshot.dart';
import 'ai_analysis_service.dart';

class MockAiAnalysisService implements AiAnalysisService {
  @override
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return const AiAnalysisResult(
      score: 78,
      comment: '이 옷은 얼굴 톤을 비교적 밝게 보이게 할 가능성이 있습니다.',
      tags: ['참고판단', '색감확인', '매장조명주의'],
      strengths: ['얼굴 주변 밝기가 비교적 안정적으로 보입니다.'],
      concerns: ['Mock 결과이므로 실제 이미지 분석은 아직 반영되지 않았습니다.'],
      suggestions: ['저장 후보를 2개 이상 모아 비교하면 선택이 더 쉬워집니다.'],
      confidence: 0.5,
      engine: 'mock',
    );
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    List<OutfitSnapshot> snapshots,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    final candidateScores = <String, int>{};
    for (var index = 0; index < snapshots.length; index++) {
      candidateScores[snapshots[index].id] = (86 - index * 6).clamp(68, 92);
    }
    final best = candidateScores.entries.isEmpty
        ? null
        : candidateScores.entries
            .reduce(
              (current, next) => current.value >= next.value ? current : next,
            )
            .key;
    final bestIndex = best == null
        ? -1
        : snapshots.indexWhere((snapshot) => snapshot.id == best);
    return AiAnalysisResult(
      score: best == null ? 0 : candidateScores[best]!,
      bestSnapshotId: best,
      candidateScores: candidateScores,
      candidateComments: {
        for (final snapshot in snapshots)
          snapshot.id: snapshot.id == best
              ? '색감과 밝기 균형이 가장 안정적인 후보입니다.'
              : 'BEST 후보보다 색 대비나 밝기 균형이 조금 약합니다.',
      },
      tags: const ['후보비교', '색조화', '참고판단'],
      strengths: const ['후보별 점수를 같은 기준으로 비교했습니다.'],
      concerns: const ['Mock 결과이므로 실제 이미지 분석은 아직 반영되지 않았습니다.'],
      suggestions: const ['BEST 후보를 기준으로 비슷한 색감의 옷을 추가로 비교해보세요.'],
      confidence: 0.5,
      engine: 'mock',
      comment: snapshots.isEmpty
          ? '비교할 후보를 먼저 저장해주세요.'
          : '후보 ${bestIndex + 1}이 얼굴 톤을 가장 안정적으로 살리고 상하의 균형도 무난합니다. '
              '다른 후보들은 색 대비나 실루엣 집중도가 조금 약해 점수가 낮게 잡혔습니다. '
              '점수는 얼굴 밝기, 전체 비율, 색 조화, 매장 조명에서의 안정감을 기준으로 산정한 참고값입니다.',
    );
  }
}
