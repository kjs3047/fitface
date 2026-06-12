import '../../data/models/ai_analysis_result.dart';
import '../../data/models/ai_settings.dart';
import '../../data/models/image_feature_summary.dart';
import '../../data/models/outfit_snapshot.dart';
import '../../data/models/personal_color_result.dart';
import 'ai_analysis_service.dart';
import 'ai_engine_adapter.dart';
import 'ai_prompt_builder.dart';
import 'image_feature_extractor.dart';
import 'mock_ai_analysis_service.dart';
import 'rule_based_ai_analysis_service.dart';

class AiAnalysisCoordinator implements AiAnalysisService {
  AiAnalysisCoordinator({
    required this.settings,
    required this.featureExtractor,
    this.personalColor,
    AiPromptBuilder promptBuilder = const AiPromptBuilder(),
    RuleBasedAiAnalysisService ruleBasedService =
        const RuleBasedAiAnalysisService(),
    MockAiAnalysisService? mockService,
    AiEngineAdapter? localGemmaService,
    AiEngineAdapter? openAiService,
  })  : _promptBuilder = promptBuilder,
        _ruleBasedService = ruleBasedService,
        _mockService = mockService ?? MockAiAnalysisService(),
        _localGemmaService = localGemmaService,
        _openAiService = openAiService;

  final AiSettings settings;
  final ImageFeatureExtractor featureExtractor;

  /// 저장된 퍼스널 컬러 진단(없으면 null). 분석 프롬프트의 참고 정보로 주입된다.
  final PersonalColorResult? personalColor;
  final AiPromptBuilder _promptBuilder;
  final RuleBasedAiAnalysisService _ruleBasedService;
  final MockAiAnalysisService _mockService;
  final AiEngineAdapter? _localGemmaService;
  final AiEngineAdapter? _openAiService;

  /// 퍼스널 컬러가 실제로 프롬프트에 반영될 수 있는 상태인지.
  bool get _hasPersonalColor =>
      _promptBuilder.personalColorPromptLine(personalColor) != null;

  @override
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot) async {
    if (settings.mode == AiEngineMode.off) {
      return _ruleBasedService.analyzeSnapshot(
        snapshot: snapshot,
        features: null,
        reason: 'AI 기능이 꺼져 있습니다.',
      );
    }
    if (settings.mode == AiEngineMode.mock) {
      return _mockService.analyzeSnapshot(snapshot);
    }
    _ensureSelectedEngineConfigured();

    final features = await _tryExtract(snapshot.imagePath);
    final engine = _engineForSettings();
    if (engine == null) {
      return _ruleBasedService.analyzeSnapshot(
        snapshot: snapshot,
        features: features,
        reason: '선택한 AI 엔진이 준비되지 않았습니다.',
      );
    }

    final includeImage = settings.mode != AiEngineMode.localGemma;
    final prompt = settings.mode == AiEngineMode.localGemma
        ? _promptBuilder.buildLocalSnapshotPrompt(
            snapshot: snapshot,
            features: features,
            personalColor: personalColor,
          )
        : _promptBuilder.buildSnapshotPrompt(
            snapshot: snapshot,
            features: features,
            includeImage: includeImage,
            personalColor: personalColor,
          );
    try {
      final result = await engine.analyzeSnapshot(
        AiSnapshotAnalysisRequest(
          snapshot: snapshot,
          features: features,
          includeImage: includeImage,
          prompt: prompt,
        ),
      );
      return result.copyWith(usedPersonalColor: _hasPersonalColor);
    } catch (visionError) {
      if (!includeImage) {
        return _ruleBasedService.analyzeSnapshot(
          snapshot: snapshot,
          features: features,
          reason: visionError.toString(),
        );
      }
      if (features != null) {
        try {
          final result = await engine.analyzeSnapshot(
            AiSnapshotAnalysisRequest(
              snapshot: snapshot,
              features: features,
              includeImage: false,
              prompt: _promptBuilder.buildSnapshotPrompt(
                snapshot: snapshot,
                features: features,
                includeImage: false,
                personalColor: personalColor,
              ),
            ),
          );
          return result.copyWith(usedPersonalColor: _hasPersonalColor);
        } catch (textError) {
          return _ruleBasedService.analyzeSnapshot(
            snapshot: snapshot,
            features: features,
            reason:
                '${visionError.toString()} / text fallback failed: $textError',
          );
        }
      }
      return _ruleBasedService.analyzeSnapshot(
        snapshot: snapshot,
        features: features,
        reason: visionError.toString(),
      );
    }
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    List<OutfitSnapshot> snapshots,
  ) async {
    if (settings.mode == AiEngineMode.off) {
      return _ruleBasedService.compareSnapshots(
        snapshots: snapshots,
        featuresBySnapshotId: const {},
        reason: 'AI 기능이 꺼져 있습니다.',
      );
    }
    if (settings.mode == AiEngineMode.mock) {
      return _mockService.compareSnapshots(snapshots);
    }
    _ensureSelectedEngineConfigured();

    final featuresBySnapshotId = <String, ImageFeatureSummary>{};
    for (final snapshot in snapshots) {
      final features = await _tryExtract(snapshot.imagePath);
      if (features != null) {
        featuresBySnapshotId[snapshot.id] = features;
      }
    }

    final engine = _engineForSettings();
    if (engine == null) {
      return _ruleBasedService.compareSnapshots(
        snapshots: snapshots,
        featuresBySnapshotId: featuresBySnapshotId,
        reason: '선택한 AI 엔진이 준비되지 않았습니다.',
      );
    }

    final includeImages = settings.mode != AiEngineMode.localGemma;
    final prompt = settings.mode == AiEngineMode.localGemma
        ? _promptBuilder.buildLocalComparePrompt(
            snapshots: snapshots,
            featuresBySnapshotId: featuresBySnapshotId,
            personalColor: personalColor,
          )
        : _promptBuilder.buildComparePrompt(
            snapshots: snapshots,
            featuresBySnapshotId: featuresBySnapshotId,
            includeImages: includeImages,
            personalColor: personalColor,
          );
    try {
      final result = await engine.compareSnapshots(
        AiCompareAnalysisRequest(
          snapshots: snapshots,
          featuresBySnapshotId: featuresBySnapshotId,
          includeImages: includeImages,
          prompt: prompt,
        ),
      );
      return result.copyWith(usedPersonalColor: _hasPersonalColor);
    } catch (visionError) {
      if (!includeImages) {
        return _ruleBasedService.compareSnapshots(
          snapshots: snapshots,
          featuresBySnapshotId: featuresBySnapshotId,
          reason: visionError.toString(),
        );
      }
      if (featuresBySnapshotId.isNotEmpty) {
        try {
          final result = await engine.compareSnapshots(
            AiCompareAnalysisRequest(
              snapshots: snapshots,
              featuresBySnapshotId: featuresBySnapshotId,
              includeImages: false,
              prompt: _promptBuilder.buildComparePrompt(
                snapshots: snapshots,
                featuresBySnapshotId: featuresBySnapshotId,
                includeImages: false,
                personalColor: personalColor,
              ),
            ),
          );
          return result.copyWith(usedPersonalColor: _hasPersonalColor);
        } catch (textError) {
          return _ruleBasedService.compareSnapshots(
            snapshots: snapshots,
            featuresBySnapshotId: featuresBySnapshotId,
            reason:
                '${visionError.toString()} / text fallback failed: $textError',
          );
        }
      }
      return _ruleBasedService.compareSnapshots(
        snapshots: snapshots,
        featuresBySnapshotId: featuresBySnapshotId,
        reason: visionError.toString(),
      );
    }
  }

  Future<ImageFeatureSummary?> _tryExtract(String imagePath) async {
    try {
      return await featureExtractor.extract(imagePath);
    } catch (_) {
      return null;
    }
  }

  AiEngineAdapter? _engineForSettings() {
    switch (settings.mode) {
      case AiEngineMode.localGemma:
        return _localGemmaService;
      case AiEngineMode.openAi:
        return _openAiService;
      case AiEngineMode.off:
      case AiEngineMode.mock:
        return null;
    }
  }

  void _ensureSelectedEngineConfigured() {
    switch (settings.mode) {
      case AiEngineMode.localGemma:
        final modelPath = settings.localModelPath;
        if (modelPath == null || modelPath.trim().isEmpty) {
          throw StateError('Local Gemma 모델 파일을 먼저 가져오세요.');
        }
        return;
      case AiEngineMode.openAi:
        if (!settings.allowCloudAnalysis) {
          throw StateError('OpenAI API 사용을 위해 클라우드 AI 사용 동의가 필요합니다.');
        }
        final proxyUrl = settings.openAiProxyUrl;
        if (proxyUrl == null || proxyUrl.trim().isEmpty) {
          throw StateError('OpenAI API 프록시 주소를 먼저 설정하세요.');
        }
        return;
      case AiEngineMode.off:
      case AiEngineMode.mock:
        return;
    }
  }
}
