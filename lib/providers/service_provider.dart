import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_settings.dart';
import '../domain/services/ai_analysis_coordinator.dart';
import '../domain/services/ai_analysis_service.dart';
import '../domain/services/background_removal_service.dart';
import '../domain/services/face_neck_cutout_service.dart';
import '../domain/services/image_feature_extractor.dart';
import '../domain/services/local_gemma_analysis_service.dart';
import '../domain/services/mock_personal_color_service.dart';
import '../domain/services/personal_color_service.dart';
import 'ai_settings_provider.dart';

final backgroundRemovalServiceProvider =
    Provider<BackgroundRemovalService>((ref) {
  return FaceNeckCutoutService();
});

final imageFeatureExtractorProvider = Provider<ImageFeatureExtractor>((ref) {
  return const ImageFeatureExtractor();
});

final aiAnalysisServiceProvider = Provider<AiAnalysisService>((ref) {
  final settings =
      ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
  return AiAnalysisCoordinator(
    settings: settings,
    featureExtractor: ref.watch(imageFeatureExtractorProvider),
    localGemmaService: LocalGemmaAnalysisService(),
  );
});

final personalColorServiceProvider = Provider<PersonalColorService>((ref) {
  return MockPersonalColorService();
});
