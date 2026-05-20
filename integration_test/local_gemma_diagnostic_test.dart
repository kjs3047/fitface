import 'dart:convert';
import 'dart:io';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_settings.dart';
import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/domain/services/ai_analysis_coordinator.dart';
import 'package:fitface/domain/services/ai_engine_adapter.dart';
import 'package:fitface/domain/services/ai_personal_color_service.dart';
import 'package:fitface/domain/services/image_feature_extractor.dart';
import 'package:fitface/domain/services/local_gemma_analysis_service.dart';
import 'package:fitface/domain/services/local_gemma_model_service.dart';
import 'package:fitface/domain/services/local_gemma_personal_color_service.dart';
import 'package:fitface/domain/services/personal_color_engine_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'local Gemma model loads and can analyze through native channel',
    (tester) async {
      const modelPath = String.fromEnvironment('LOCAL_GEMMA_MODEL_PATH');
      const modelName = String.fromEnvironment(
        'LOCAL_GEMMA_MODEL_NAME',
        defaultValue: 'gemma-4-E4B-it.litertlm',
      );
      const expectedModelBytes = int.fromEnvironment(
        'LOCAL_GEMMA_MODEL_BYTES',
      );

      if (modelPath.isEmpty) {
        // This test is intentionally opt-in because it needs a multi-GB model
        // already copied onto the Android test device.
        return;
      }

      final settings = AiSettings.defaults().copyWith(
        mode: AiEngineMode.localGemma,
        localModelPath: modelPath,
        localModelName: modelName,
      );

      await _waitForModelPath(
        modelPath,
        expectedBytes: expectedModelBytes > 0 ? expectedModelBytes : null,
      );

      final diagnostic = await const LocalGemmaModelService().testModel(
        modelPath: modelPath,
        modelName: modelName,
      );
      expect(diagnostic.message, isNotEmpty);
      debugPrint(
        'LOCAL_GEMMA_TEXT_DIAGNOSTIC=${jsonEncode({
              'score': diagnostic.score,
              'message': diagnostic.message,
            })}',
      );

      final storage = await LocalFileStorage.create();
      final snapshotPath = await storage.writeBytesToSubdir(
        'diagnostic',
        'local_gemma_snapshot.jpg',
        Uint8List.fromList(img.encodeJpg(_diagnosticImage(), quality: 92)),
      );
      final snapshot = OutfitSnapshot(
        id: 'local-gemma-diagnostic',
        imagePath: snapshotPath,
        memo: '로컬 Gemma 실기기 진단용 샘플',
        createdAt: DateTime.now(),
      );
      final engine = LocalGemmaAnalysisService(settings: settings);

      try {
        final visionResult = await engine.analyzeSnapshot(
          AiSnapshotAnalysisRequest(
            snapshot: snapshot,
            features: null,
            includeImage: true,
            prompt: _visionDiagnosticPrompt,
          ),
        );
        debugPrint(
          'LOCAL_GEMMA_VISION_RESULT=${jsonEncode(visionResult.toJson())}',
        );
      } catch (error) {
        debugPrint('LOCAL_GEMMA_VISION_ERROR=$error');
      }

      final coordinator = AiAnalysisCoordinator(
        settings: settings,
        featureExtractor: const ImageFeatureExtractor(),
        localGemmaService: engine,
      );
      final coordinated = await coordinator.analyzeSnapshot(snapshot);
      expect(coordinated.comment, isNotEmpty);
      expect(coordinated.score, inInclusiveRange(0, 100));
      debugPrint(
        'LOCAL_GEMMA_COORDINATOR_RESULT=${jsonEncode(coordinated.toJson())}',
      );

      final personalColorEngine = LocalGemmaPersonalColorService(
        settings: settings,
      );
      try {
        final personalColorVision = await personalColorEngine.analyze(
          PersonalColorAnalysisRequest(
            faceImagePath: snapshotPath,
            features: null,
            includeImage: true,
            prompt: _personalColorDiagnosticPrompt,
          ),
        );
        debugPrint(
          'LOCAL_GEMMA_PERSONAL_COLOR_VISION=${jsonEncode(personalColorVision.toJson())}',
        );
      } catch (error) {
        debugPrint('LOCAL_GEMMA_PERSONAL_COLOR_VISION_ERROR=$error');
      }

      final personalColor = await AiPersonalColorService(
        settings: settings,
        featureExtractor: const ImageFeatureExtractor(),
        localGemmaService: personalColorEngine,
      ).analyze(faceImagePath: snapshotPath);
      expect(personalColor.type, isNotEmpty);
      expect(personalColor.recommendedColors, isNotEmpty);
      debugPrint(
        'LOCAL_GEMMA_PERSONAL_COLOR_COORDINATOR=${jsonEncode(personalColor.toJson())}',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

img.Image _diagnosticImage() {
  final image = img.Image(width: 180, height: 240);
  img.fill(image, color: img.ColorRgb8(212, 179, 148));
  img.fillRect(
    image,
    x1: 24,
    y1: 48,
    x2: 156,
    y2: 188,
    color: img.ColorRgb8(82, 96, 132),
  );
  img.fillRect(
    image,
    x1: 54,
    y1: 84,
    x2: 126,
    y2: 156,
    color: img.ColorRgb8(238, 221, 196),
  );
  return image;
}

Future<void> _waitForModelPath(
  String modelPath, {
  required int? expectedBytes,
}) async {
  final modelFile = File(modelPath);
  for (var attempt = 0; attempt < 180; attempt++) {
    final exists = await modelFile.exists();
    final length = exists ? await modelFile.length() : 0;
    if (exists && (expectedBytes == null || length == expectedBytes)) {
      return;
    }
    if (attempt % 10 == 0) {
      debugPrint(
        'LOCAL_GEMMA_WAITING_FOR_MODEL=$modelPath bytes=$length expected=$expectedBytes',
      );
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError('Local Gemma model file did not appear: $modelPath');
}

const _visionDiagnosticPrompt = '''
역할: FitFace Local Gemma 이미지 진단.
목표: 입력 이미지가 보이면 색상 경향만 짧게 판단한다.
금지: 얼굴 외모, 피부 품질, 미모, 결점 평가.
출력은 반드시 JSON 객체 하나만 사용한다.
필드: score, comment, tags, strengths, concerns, suggestions, confidence.
''';

const _personalColorDiagnosticPrompt = '''
역할: FitFace Local Gemma 퍼스널 컬러 진단.
목표: 입력 이미지의 색상 경향을 참고해 쇼핑용 팔레트를 제안한다.
금지: 얼굴 외모, 피부 품질, 미모, 결점 평가.
출력은 반드시 JSON 객체 하나만 사용한다.
필드: type, recommendedColors, avoidColors, comment.
recommendedColors와 avoidColors는 각각 한국어 색상명 배열로 작성한다.
''';
