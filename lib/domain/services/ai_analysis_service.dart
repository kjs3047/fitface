import '../../data/models/ai_analysis_result.dart';
import '../../data/models/outfit_snapshot.dart';

abstract class AiAnalysisService {
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot);
  Future<AiAnalysisResult> compareSnapshots(List<OutfitSnapshot> snapshots);
}
