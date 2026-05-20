import '../../data/models/ai_analysis_result.dart';
import '../../data/models/image_feature_summary.dart';
import '../../data/models/outfit_snapshot.dart';

class AiSnapshotAnalysisRequest {
  const AiSnapshotAnalysisRequest({
    required this.snapshot,
    required this.prompt,
    required this.includeImage,
    this.features,
  });

  final OutfitSnapshot snapshot;
  final String prompt;
  final bool includeImage;
  final ImageFeatureSummary? features;
}

class AiCompareAnalysisRequest {
  const AiCompareAnalysisRequest({
    required this.snapshots,
    required this.prompt,
    required this.includeImages,
    required this.featuresBySnapshotId,
  });

  final List<OutfitSnapshot> snapshots;
  final String prompt;
  final bool includeImages;
  final Map<String, ImageFeatureSummary> featuresBySnapshotId;
}

abstract class AiEngineAdapter {
  String get engineName;

  Future<AiAnalysisResult> analyzeSnapshot(
    AiSnapshotAnalysisRequest request,
  );

  Future<AiAnalysisResult> compareSnapshots(
    AiCompareAnalysisRequest request,
  );
}
