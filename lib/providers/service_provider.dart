import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_settings.dart';
import '../data/models/personal_color_result.dart';
import '../domain/services/ai_analysis_coordinator.dart';
import '../domain/services/ai_analysis_service.dart';
import '../domain/services/ai_personal_color_service.dart';
import '../domain/services/background_removal_service.dart';
import '../domain/services/face_image_quality_service.dart';
import '../domain/services/face_neck_cutout_service.dart';
import '../domain/services/image_feature_extractor.dart';
import '../domain/services/local_gemma_analysis_service.dart';
import '../domain/services/local_gemma_chat_service.dart';
import '../domain/services/local_gemma_model_service.dart';
import '../domain/services/open_ai_analysis_service.dart';
import '../domain/services/open_ai_personal_color_service.dart';
import '../domain/services/open_ai_proxy_health_service.dart';
import '../domain/services/personal_color_service.dart';
import 'ai_settings_provider.dart';
import 'repository_provider.dart';

final backgroundRemovalServiceProvider =
    Provider<BackgroundRemovalService>((ref) {
  return FaceNeckCutoutService();
});

final imageFeatureExtractorProvider = Provider<ImageFeatureExtractor>((ref) {
  return const ImageFeatureExtractor();
});

final faceImageQualityServiceProvider =
    Provider<FaceImageQualityService>((ref) {
  return FaceImageQualityService(
    featureExtractor: ref.watch(imageFeatureExtractorProvider),
  );
});

final localGemmaModelServiceProvider = Provider<LocalGemmaModelService>((ref) {
  return const LocalGemmaModelService();
});

final openAiProxyHealthServiceProvider =
    Provider<OpenAiProxyHealthService>((ref) {
  return OpenAiProxyHealthService();
});

final localGemmaChatServiceProvider = Provider<LocalGemmaChatService>((ref) {
  final settings =
      ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
  return LocalGemmaChatService(settings: settings);
});

/// settings가 바뀌면 Provider가 재생성되며 이전 어댑터의 HttpClient를 닫는다.
final openAiAnalysisServiceProvider = Provider<OpenAiAnalysisService>((ref) {
  final settings =
      ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
  final service = OpenAiAnalysisService(settings: settings);
  ref.onDispose(service.dispose);
  return service;
});

final openAiPersonalColorServiceProvider =
    Provider<OpenAiPersonalColorService>((ref) {
  final settings =
      ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
  final service = OpenAiPersonalColorService(settings: settings);
  ref.onDispose(service.dispose);
  return service;
});

/// 저장된 퍼스널 컬러 진단을 노출한다. AI 판단 프롬프트의 참고 정보로 쓰이며,
/// 결과가 없으면 null이라 사진 정보만으로 분석한다.
final savedPersonalColorProvider =
    FutureProvider<PersonalColorResult?>((ref) async {
  return ref.watch(personalColorRepositoryProvider).loadResult();
});

final aiAnalysisServiceProvider = Provider<AiAnalysisService>((ref) {
  final settings =
      ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
  final personalColorRepository = ref.watch(personalColorRepositoryProvider);
  return AiAnalysisCoordinator(
    settings: settings,
    featureExtractor: ref.watch(imageFeatureExtractorProvider),
    personalColor: ref.watch(savedPersonalColorProvider).valueOrNull,
    personalColorLoader: personalColorRepository.loadResult,
    localGemmaService: LocalGemmaAnalysisService(settings: settings),
    openAiService: ref.watch(openAiAnalysisServiceProvider),
  );
});

final personalColorServiceProvider = Provider<PersonalColorService>((ref) {
  final settings =
      ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
  return AiPersonalColorService(
    settings: settings,
    featureExtractor: ref.watch(imageFeatureExtractorProvider),
    openAiService: ref.watch(openAiPersonalColorServiceProvider),
  );
});
