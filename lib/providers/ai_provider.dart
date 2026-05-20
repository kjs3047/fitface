import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_analysis_result.dart';
import '../data/models/outfit_snapshot.dart';
import 'service_provider.dart';

final analyzeSnapshotProvider =
    FutureProvider.family<AiAnalysisResult, OutfitSnapshot>((ref, snapshot) {
  return ref.watch(aiAnalysisServiceProvider).analyzeSnapshot(snapshot);
});

final compareSnapshotsProvider =
    FutureProvider.family<AiAnalysisResult, List<OutfitSnapshot>>(
        (ref, snapshots) {
  return ref.watch(aiAnalysisServiceProvider).compareSnapshots(snapshots);
});
