import 'dart:convert';
import 'dart:io';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_analysis_result.dart';
import 'package:fitface/data/models/ai_settings.dart';
import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/core/utils/face_cutout_geometry.dart';
import 'package:fitface/domain/services/ai_analysis_coordinator.dart';
import 'package:fitface/domain/services/ai_engine_adapter.dart';
import 'package:fitface/domain/services/face_neck_cutout_service.dart';
import 'package:fitface/domain/services/image_feature_extractor.dart';
import 'package:fitface/domain/services/local_gemma_analysis_service.dart';
import 'package:fitface/domain/services/mock_ai_analysis_service.dart';
import 'package:fitface/providers/camera_overlay_provider.dart';
import 'package:fitface/providers/storage_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FaceNeckCutoutService creates transparent PNG cutout', () async {
    final tempRoot = await Directory.systemTemp.createTemp('fitface_cutout_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final source = img.Image(width: 100, height: 140);
    img.fill(source, color: img.ColorRgb8(210, 170, 140));
    final sourceFile = File('${tempRoot.path}/face.jpg');
    await sourceFile.writeAsBytes(
      Uint8List.fromList(img.encodeJpg(source)),
      flush: true,
    );

    final outputPath = await FaceNeckCutoutService().removeBackground(
      sourceFile.path,
    );
    final output = img.decodeImage(await File(outputPath).readAsBytes());

    expect(outputPath, endsWith('.png'));
    expect(output, isNotNull);
    expect(output!.getPixel(0, 0).a, 0);
    expect(output.getPixel(output.width - 1, output.height - 1).a, 0);
    expect(output.getPixel(output.width ~/ 2, output.height ~/ 3).a, 255);
    expect(
      output.getPixel(output.width ~/ 2, (output.height * 0.68).round()).a,
      greaterThan(0),
    );
    expect(
      output.getPixel(output.width ~/ 2, (output.height * 0.78).round()).a,
      0,
    );
    expect(
      FaceCutoutGeometry.neckBottom - FaceCutoutGeometry.neckTop,
      closeTo(0.224, 0.001),
    );
  });

  test('MockAiAnalysisService returns cautious mock comments', () async {
    final service = MockAiAnalysisService();
    final result = await service.analyzeSnapshot(
      OutfitSnapshot(
        id: 'id',
        imagePath: 'snapshot.png',
        createdAt: DateTime(2026),
      ),
    );
    expect(result.comment, contains('가능성'));
  });

  test('MockAiAnalysisService scores every compared snapshot', () async {
    final service = MockAiAnalysisService();
    final snapshots = [
      for (var index = 0; index < 3; index++)
        OutfitSnapshot(
          id: 'candidate_$index',
          imagePath: 'snapshot_$index.png',
          createdAt: DateTime(2026, 5, 20, 12, index),
        ),
    ];

    final result = await service.compareSnapshots(snapshots);

    expect(result.bestSnapshotId, 'candidate_0');
    expect(result.score, 86);
    expect(result.candidateScores, {
      'candidate_0': 86,
      'candidate_1': 80,
      'candidate_2': 74,
    });
    expect(result.comment, contains('색 조화'));
    expect(result.comment, contains('얼굴 밝기'));
  });

  test('ImageFeatureExtractor returns palette and quality metrics', () async {
    final tempRoot = await Directory.systemTemp.createTemp('fitface_feature_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final source = img.Image(width: 80, height: 80);
    img.fill(source, color: img.ColorRgb8(80, 120, 210));
    final sourceFile = File('${tempRoot.path}/snapshot.png');
    await sourceFile.writeAsBytes(
      Uint8List.fromList(img.encodePng(source)),
      flush: true,
    );

    final features = await const ImageFeatureExtractor().extract(
      sourceFile.path,
    );

    expect(features.averageHex, startsWith('#'));
    expect(features.dominantColors, isNotEmpty);
    expect(features.brightness, greaterThan(0));
    expect(features.saturation, greaterThan(0));
    expect(features.toPromptText(), contains('dominant'));
  });

  test('AiAnalysisCoordinator falls back from vision to text features',
      () async {
    final tempRoot =
        await Directory.systemTemp.createTemp('fitface_ai_coordinator_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final source = img.Image(width: 80, height: 80);
    img.fill(source, color: img.ColorRgb8(180, 190, 220));
    final sourceFile = File('${tempRoot.path}/snapshot.png');
    await sourceFile.writeAsBytes(
      Uint8List.fromList(img.encodePng(source)),
      flush: true,
    );
    final coordinator = AiAnalysisCoordinator(
      settings: AiSettings.defaults().copyWith(mode: AiEngineMode.localGemma),
      featureExtractor: const ImageFeatureExtractor(),
      localGemmaService: const _VisionFailsTextSucceedsEngine(),
    );

    final result = await coordinator.analyzeSnapshot(
      OutfitSnapshot(
        id: 'candidate',
        imagePath: sourceFile.path,
        createdAt: DateTime(2026),
      ),
    );

    expect(result.engine, 'localGemma');
    expect(result.analysisMode, 'featuresOnly');
    expect(result.tags, contains('fallback-text'));
  });

  test('LocalGemmaAnalysisService sends model settings to native channel',
      () async {
    const channel = MethodChannel('fitface/local_gemma_test');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return jsonEncode({
        'score': 88,
        'comment': 'Local Gemma 테스트 응답입니다.',
        'tags': ['local'],
      });
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LocalGemmaAnalysisService(
      settings: AiSettings.defaults().copyWith(
        mode: AiEngineMode.localGemma,
        localModelPath: '/data/local/tmp/llm/gemma-4-E4B-it.litertlm',
        localModelName: 'Gemma 4 E4B-it',
      ),
      channel: channel,
    );

    final result = await service.analyzeSnapshot(
      AiSnapshotAnalysisRequest(
        snapshot: OutfitSnapshot(
          id: 'candidate',
          imagePath: 'snapshot.png',
          createdAt: DateTime(2026),
        ),
        prompt: '테스트 prompt',
        includeImage: true,
      ),
    );

    expect(result.engine, 'localGemma');
    expect(result.analysisMode, 'imageAndFeatures');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'analyzeSnapshot');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(
      arguments['modelPath'],
      '/data/local/tmp/llm/gemma-4-E4B-it.litertlm',
    );
    expect(arguments['modelName'], 'Gemma 4 E4B-it');
    expect(arguments['imagePath'], 'snapshot.png');
    expect(arguments['prompt'], '테스트 prompt');
  });

  test('CameraOverlayProvider clamps opacity and scale', () async {
    final tempRoot = await Directory.systemTemp.createTemp('fitface_provider_');
    final storage = await LocalFileStorage.create(root: tempRoot);
    final container = ProviderContainer(
      overrides: [localFileStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(() async {
      container.dispose();
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final notifier = container.read(cameraOverlayProvider.notifier);
    notifier.setOpacity(9);
    notifier.setTransform(position: const Offset(12, 18), scale: 9);

    final state = container.read(cameraOverlayProvider);
    expect(state.opacity, 1.0);
    expect(state.scale, 3.0);
    expect(state.position, const Offset(12, 18));
  });
}

class _VisionFailsTextSucceedsEngine implements AiEngineAdapter {
  const _VisionFailsTextSucceedsEngine();

  @override
  String get engineName => 'localGemma';

  @override
  Future<AiAnalysisResult> analyzeSnapshot(
    AiSnapshotAnalysisRequest request,
  ) async {
    if (request.includeImage) {
      throw StateError('vision unavailable');
    }
    return AiAnalysisResult(
      score: 81,
      comment: '색상정보 기반 분석입니다.',
      tags: const ['fallback-text'],
      engine: engineName,
      analysisMode: 'featuresOnly',
      rawFeatureSummary: request.features?.toJson(),
    );
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    AiCompareAnalysisRequest request,
  ) async {
    return AiAnalysisResult(
      score: 81,
      comment: '색상정보 기반 비교입니다.',
      engine: engineName,
      analysisMode: 'featuresOnly',
    );
  }
}
