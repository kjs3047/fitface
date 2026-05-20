import '../../data/models/ai_settings.dart';
import '../../data/models/image_feature_summary.dart';
import '../../data/models/personal_color_result.dart';
import 'image_feature_extractor.dart';
import 'local_gemma_personal_color_service.dart';
import 'mock_personal_color_service.dart';
import 'open_ai_personal_color_service.dart';
import 'personal_color_engine_adapter.dart';
import 'personal_color_prompt_builder.dart';
import 'personal_color_service.dart';
import 'rule_based_personal_color_service.dart';

class AiPersonalColorService implements PersonalColorService {
  AiPersonalColorService({
    required this.settings,
    required this.featureExtractor,
    PersonalColorPromptBuilder promptBuilder =
        const PersonalColorPromptBuilder(),
    RuleBasedPersonalColorService ruleBasedService =
        const RuleBasedPersonalColorService(),
    MockPersonalColorService? mockService,
    PersonalColorEngineAdapter? localGemmaService,
    PersonalColorEngineAdapter? openAiService,
  })  : _promptBuilder = promptBuilder,
        _ruleBasedService = ruleBasedService,
        _mockService = mockService ?? MockPersonalColorService(),
        _localGemmaService = localGemmaService,
        _openAiService = openAiService;

  final AiSettings settings;
  final ImageFeatureExtractor featureExtractor;
  final PersonalColorPromptBuilder _promptBuilder;
  final RuleBasedPersonalColorService _ruleBasedService;
  final MockPersonalColorService _mockService;
  final PersonalColorEngineAdapter? _localGemmaService;
  final PersonalColorEngineAdapter? _openAiService;

  @override
  Future<PersonalColorResult> analyze({String? faceImagePath}) async {
    if (settings.mode == AiEngineMode.mock) {
      return _mockService.analyze(faceImagePath: faceImagePath);
    }

    final normalizedPath = faceImagePath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return _ruleBasedService.analyze(
        features: null,
        reason: '등록된 얼굴 이미지가 없습니다.',
      );
    }

    final features = await _tryExtract(normalizedPath);
    if (settings.mode == AiEngineMode.off) {
      return _ruleBasedService.analyze(
        features: features,
        reason: 'AI 기능이 꺼져 있습니다.',
      );
    }

    final engine = _engineForSettings();
    if (engine == null) {
      return _ruleBasedService.analyze(
        features: features,
        reason: '선택한 AI 엔진이 준비되지 않았습니다.',
      );
    }

    try {
      return await engine.analyze(
        PersonalColorAnalysisRequest(
          faceImagePath: normalizedPath,
          features: features,
          includeImage: true,
          prompt: _promptBuilder.buildPrompt(
            features: features,
            includeImage: true,
          ),
        ),
      );
    } catch (visionError) {
      if (features != null) {
        try {
          return await engine.analyze(
            PersonalColorAnalysisRequest(
              faceImagePath: normalizedPath,
              features: features,
              includeImage: false,
              prompt: _promptBuilder.buildPrompt(
                features: features,
                includeImage: false,
              ),
            ),
          );
        } catch (_) {
          return _ruleBasedService.analyze(
            features: features,
            reason: visionError.toString(),
          );
        }
      }
      return _ruleBasedService.analyze(
        features: features,
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

  PersonalColorEngineAdapter? _engineForSettings() {
    switch (settings.mode) {
      case AiEngineMode.localGemma:
        return _localGemmaService ??
            LocalGemmaPersonalColorService(settings: settings);
      case AiEngineMode.openAi:
        return _openAiService ?? OpenAiPersonalColorService(settings: settings);
      case AiEngineMode.off:
      case AiEngineMode.mock:
        return null;
    }
  }
}
