import '../../data/models/ai_analysis_result.dart';
import '../../data/models/ai_settings.dart';
import '../../data/models/image_feature_summary.dart';
import '../../data/models/outfit_snapshot.dart';
import 'ai_analysis_service.dart';
import 'ai_engine_adapter.dart';
import 'ai_prompt_builder.dart';
import 'image_feature_extractor.dart';
import 'mock_ai_analysis_service.dart';
import 'open_ai_analysis_service.dart';
import 'rule_based_ai_analysis_service.dart';

class AiAnalysisCoordinator implements AiAnalysisService {
  AiAnalysisCoordinator({
    required this.settings,
    required this.featureExtractor,
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
  final AiPromptBuilder _promptBuilder;
  final RuleBasedAiAnalysisService _ruleBasedService;
  final MockAiAnalysisService _mockService;
  final AiEngineAdapter? _localGemmaService;
  final AiEngineAdapter? _openAiService;

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

    final features = await _tryExtract(snapshot.imagePath);
    final engine = _engineForSettings();
    if (engine == null) {
      return _ruleBasedService.analyzeSnapshot(
        snapshot: snapshot,
        features: features,
        reason: '선택한 AI 엔진이 준비되지 않았습니다.',
      );
    }

    try {
      return await engine.analyzeSnapshot(
        AiSnapshotAnalysisRequest(
          snapshot: snapshot,
          features: features,
          includeImage: true,
          prompt: _promptBuilder.buildSnapshotPrompt(
            snapshot: snapshot,
            features: features,
            includeImage: true,
          ),
        ),
      );
    } catch (visionError) {
      if (features != null) {
        try {
          return await engine.analyzeSnapshot(
            AiSnapshotAnalysisRequest(
              snapshot: snapshot,
              features: features,
              includeImage: false,
              prompt: _promptBuilder.buildSnapshotPrompt(
                snapshot: snapshot,
                features: features,
                includeImage: false,
              ),
            ),
          );
        } catch (_) {
          return _ruleBasedService.analyzeSnapshot(
            snapshot: snapshot,
            features: features,
            reason: visionError.toString(),
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

    try {
      return await engine.compareSnapshots(
        AiCompareAnalysisRequest(
          snapshots: snapshots,
          featuresBySnapshotId: featuresBySnapshotId,
          includeImages: true,
          prompt: _promptBuilder.buildComparePrompt(
            snapshots: snapshots,
            featuresBySnapshotId: featuresBySnapshotId,
            includeImages: true,
          ),
        ),
      );
    } catch (visionError) {
      if (featuresBySnapshotId.isNotEmpty) {
        try {
          return await engine.compareSnapshots(
            AiCompareAnalysisRequest(
              snapshots: snapshots,
              featuresBySnapshotId: featuresBySnapshotId,
              includeImages: false,
              prompt: _promptBuilder.buildComparePrompt(
                snapshots: snapshots,
                featuresBySnapshotId: featuresBySnapshotId,
                includeImages: false,
              ),
            ),
          );
        } catch (_) {
          return _ruleBasedService.compareSnapshots(
            snapshots: snapshots,
            featuresBySnapshotId: featuresBySnapshotId,
            reason: visionError.toString(),
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
        return _openAiService ?? OpenAiAnalysisService(settings: settings);
      case AiEngineMode.off:
      case AiEngineMode.mock:
        return null;
    }
  }
}
