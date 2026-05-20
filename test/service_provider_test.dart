import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitface/data/local/local_file_storage.dart';
import 'package:fitface/data/models/ai_analysis_result.dart';
import 'package:fitface/data/models/ai_settings.dart';
import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/data/models/personal_color_result.dart';
import 'package:fitface/core/utils/face_cutout_geometry.dart';
import 'package:fitface/domain/services/ai_analysis_coordinator.dart';
import 'package:fitface/domain/services/ai_engine_adapter.dart';
import 'package:fitface/domain/services/ai_personal_color_service.dart';
import 'package:fitface/domain/services/face_image_quality_service.dart';
import 'package:fitface/domain/services/face_neck_cutout_service.dart';
import 'package:fitface/domain/services/image_feature_extractor.dart';
import 'package:fitface/domain/services/local_gemma_analysis_service.dart';
import 'package:fitface/domain/services/local_gemma_personal_color_service.dart';
import 'package:fitface/domain/services/local_gemma_model_service.dart';
import 'package:fitface/domain/services/mock_ai_analysis_service.dart';
import 'package:fitface/domain/services/open_ai_analysis_service.dart';
import 'package:fitface/domain/services/open_ai_personal_color_service.dart';
import 'package:fitface/domain/services/personal_color_engine_adapter.dart';
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

  test('FaceImageQualityService reports low quality hints', () async {
    final tempRoot = await Directory.systemTemp.createTemp('fitface_quality_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final source = img.Image(width: 80, height: 112);
    img.fill(source, color: img.ColorRgb8(34, 34, 38));
    final sourceFile = File('${tempRoot.path}/face.png');
    await sourceFile.writeAsBytes(
      Uint8List.fromList(img.encodePng(source)),
      flush: true,
    );

    final result = await const FaceImageQualityService().evaluate(
      sourceFile.path,
    );

    expect(result.status, FaceImageQualityStatus.warning);
    expect(result.hasWarnings, isTrue);
    expect(result.hints.join(' '), contains('어두'));
    expect(result.features.averageHex, startsWith('#'));
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

  test('LocalGemmaModelService imports model metadata from native channel',
      () async {
    const channel = MethodChannel('fitface/local_gemma_import_test');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {
        'path':
            '/storage/emulated/0/Android/data/com.example.fitface/files/models/gemma-4-E4B-it.litertlm',
        'name': 'gemma-4-E4B-it.litertlm',
        'bytes': 3456789012,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    const service = LocalGemmaModelService(channel: channel);
    final imported = await service.importModel();

    expect(calls.single.method, 'importModel');
    expect(imported, isNotNull);
    expect(imported!.name, 'gemma-4-E4B-it.litertlm');
    expect(imported.path, contains('/models/gemma-4-E4B-it.litertlm'));
    expect(imported.bytes, 3456789012);
  });

  test('LocalGemmaModelService runs text-only diagnostic request', () async {
    const channel = MethodChannel('fitface/local_gemma_diagnostic_test');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return jsonEncode({
        'score': 91,
        'comment': 'Local Gemma 연결 테스트가 완료되었습니다.',
        'tags': ['diagnostic'],
      });
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    const service = LocalGemmaModelService(channel: channel);
    final check = await service.testModel(
      modelPath: '/data/local/tmp/llm/gemma-4-E4B-it.litertlm',
      modelName: 'Gemma 4 E4B-it',
    );

    expect(check.score, 91);
    expect(check.message, contains('완료'));
    expect(calls.single.method, 'analyzeText');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(
      arguments['modelPath'],
      '/data/local/tmp/llm/gemma-4-E4B-it.litertlm',
    );
    expect(arguments['modelName'], 'Gemma 4 E4B-it');
    expect(arguments['prompt'], contains('JSON'));
    expect(arguments['features'], isA<Map>());
  });

  test('OpenAiAnalysisService posts sanitized snapshot image to proxy',
      () async {
    final tempRoot =
        await Directory.systemTemp.createTemp('fitface_openai_snapshot_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final source = img.Image(width: 24, height: 18);
    img.fill(source, color: img.ColorRgb8(80, 120, 210));
    final sourceFile = File('${tempRoot.path}/snapshot.png');
    await sourceFile.writeAsBytes(
      img.encodePng(source),
      flush: true,
    );
    Uri? capturedUri;
    Map<String, dynamic>? capturedBody;
    final service = OpenAiAnalysisService(
      settings: AiSettings.defaults().copyWith(
        mode: AiEngineMode.openAi,
        allowCloudAnalysis: true,
        openAiProxyUrl: 'https://fitface.example',
      ),
      client: _FakeHttpClient((uri, body) {
        capturedUri = uri;
        capturedBody = body;
        return {
          'result': {
            'score': 84,
            'comment': 'OpenAI 스냅샷 테스트 응답입니다.',
            'tags': ['openai'],
            'strengths': ['밝기가 안정적입니다.'],
            'concerns': ['조명에 따라 달라질 수 있습니다.'],
            'suggestions': ['비슷한 색감을 비교해보세요.'],
            'confidence': 0.78,
          },
        };
      }),
    );

    final result = await service.analyzeSnapshot(
      AiSnapshotAnalysisRequest(
        snapshot: OutfitSnapshot(
          id: 'snapshot_1',
          imagePath: sourceFile.path,
          createdAt: DateTime(2026),
          memo: '후보 메모',
        ),
        prompt: 'snapshot prompt',
        includeImage: true,
      ),
    );

    expect(capturedUri?.path, '/ai/snapshot/analyze');
    expect(capturedBody?['snapshotId'], 'snapshot_1');
    expect(capturedBody?['memo'], '후보 메모');
    expect(capturedBody?['imageBase64'], isA<String>());
    expect(capturedBody?['imageMimeType'], 'image/jpeg');
    expect(capturedBody?['mode'], 'imageAndFeatures');
    expect(result.engine, 'openAi');
    expect(result.analysisMode, 'imageAndFeatures');
    expect(result.score, 84);
  });

  test('OpenAiAnalysisService posts compare payload to proxy', () async {
    final tempRoot =
        await Directory.systemTemp.createTemp('fitface_openai_compare_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final snapshots = <OutfitSnapshot>[];
    for (var index = 0; index < 2; index++) {
      final source = img.Image(width: 20, height: 20);
      img.fill(source, color: img.ColorRgb8(80 + index * 20, 120, 210));
      final sourceFile = File('${tempRoot.path}/snapshot_$index.png');
      await sourceFile.writeAsBytes(
        img.encodePng(source),
        flush: true,
      );
      snapshots.add(
        OutfitSnapshot(
          id: 'snapshot_$index',
          imagePath: sourceFile.path,
          createdAt: DateTime(2026, 5, 20, 12, index),
        ),
      );
    }
    Uri? capturedUri;
    Map<String, dynamic>? capturedBody;
    final service = OpenAiAnalysisService(
      settings: AiSettings.defaults().copyWith(
        mode: AiEngineMode.openAi,
        allowCloudAnalysis: true,
        openAiProxyUrl: 'https://fitface.example',
      ),
      client: _FakeHttpClient((uri, body) {
        capturedUri = uri;
        capturedBody = body;
        return {
          'result': {
            'score': 89,
            'comment': 'OpenAI 비교 테스트 응답입니다.',
            'bestSnapshotId': 'snapshot_1',
            'candidateScores': {'snapshot_0': 77, 'snapshot_1': 89},
            'candidateComments': {'snapshot_1': '가장 안정적입니다.'},
            'tags': ['openai'],
            'strengths': ['비교 기준이 명확합니다.'],
            'concerns': ['조명 차이를 확인하세요.'],
            'suggestions': ['두 번째 후보를 우선 보세요.'],
            'confidence': 0.8,
          },
        };
      }),
    );

    final result = await service.compareSnapshots(
      AiCompareAnalysisRequest(
        snapshots: snapshots,
        prompt: 'compare prompt',
        includeImages: true,
        featuresBySnapshotId: const {},
      ),
    );

    expect(capturedUri?.path, '/ai/snapshots/compare');
    expect(capturedBody?['snapshotIds'], ['snapshot_0', 'snapshot_1']);
    expect(capturedBody?['mode'], 'imageAndFeatures');
    final images = capturedBody?['images'] as List<dynamic>;
    expect(images, hasLength(2));
    expect((images.first as Map)['snapshotId'], 'snapshot_0');
    expect((images.first as Map)['imageMimeType'], 'image/jpeg');
    expect((images.first as Map)['imageBase64'], isA<String>());
    expect(result.engine, 'openAi');
    expect(result.bestSnapshotId, 'snapshot_1');
    expect(result.candidateScores['snapshot_1'], 89);
  });

  test('AiPersonalColorService falls back from vision to text features',
      () async {
    final tempRoot =
        await Directory.systemTemp.createTemp('fitface_personal_ai_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final source = img.Image(width: 80, height: 80);
    img.fill(source, color: img.ColorRgb8(170, 190, 225));
    final sourceFile = File('${tempRoot.path}/face.png');
    await sourceFile.writeAsBytes(
      img.encodePng(source),
      flush: true,
    );
    final service = AiPersonalColorService(
      settings: AiSettings.defaults().copyWith(mode: AiEngineMode.localGemma),
      featureExtractor: const ImageFeatureExtractor(),
      localGemmaService: const _PersonalColorVisionFailsTextSucceedsEngine(),
    );

    final result = await service.analyze(faceImagePath: sourceFile.path);

    expect(result.type, '여름 쿨');
    expect(result.recommendedColors, contains('소프트 블루'));
    expect(result.comment, contains('색상정보'));
  });

  test('LocalGemmaPersonalColorService sends model settings to native channel',
      () async {
    const channel = MethodChannel('fitface/local_gemma_personal_test');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return jsonEncode({
        'type': '여름 쿨',
        'recommendedColors': ['라벤더', '소프트 블루'],
        'avoidColors': ['강한 오렌지'],
        'comment': 'Local Gemma 퍼스널 컬러 테스트 응답입니다.',
      });
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LocalGemmaPersonalColorService(
      settings: AiSettings.defaults().copyWith(
        mode: AiEngineMode.localGemma,
        localModelPath: '/data/local/tmp/llm/gemma-4-E4B-it.litertlm',
        localModelName: 'Gemma 4 E4B-it',
      ),
      channel: channel,
    );

    final result = await service.analyze(
      const PersonalColorAnalysisRequest(
        faceImagePath: 'face.png',
        prompt: '퍼스널 컬러 prompt',
        includeImage: true,
      ),
    );

    expect(result.type, '여름 쿨');
    expect(calls.single.method, 'analyzePersonalColor');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(
      arguments['modelPath'],
      '/data/local/tmp/llm/gemma-4-E4B-it.litertlm',
    );
    expect(arguments['modelName'], 'Gemma 4 E4B-it');
    expect(arguments['imagePath'], 'face.png');
    expect(arguments['prompt'], '퍼스널 컬러 prompt');
  });

  test('OpenAiPersonalColorService posts sanitized image to proxy', () async {
    final tempRoot =
        await Directory.systemTemp.createTemp('fitface_openai_personal_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });
    final source = img.Image(width: 24, height: 24);
    img.fill(source, color: img.ColorRgb8(170, 190, 225));
    final sourceFile = File('${tempRoot.path}/face.png');
    await sourceFile.writeAsBytes(
      img.encodePng(source),
      flush: true,
    );
    Uri? capturedUri;
    Map<String, dynamic>? capturedBody;
    final service = OpenAiPersonalColorService(
      settings: AiSettings.defaults().copyWith(
        mode: AiEngineMode.openAi,
        allowCloudAnalysis: true,
        openAiProxyUrl: 'https://fitface.example',
      ),
      client: _FakeHttpClient((uri, body) {
        capturedUri = uri;
        capturedBody = body;
        return {
          'result': {
            'type': '여름 쿨',
            'recommendedColors': ['라벤더', '소프트 블루'],
            'avoidColors': ['강한 오렌지'],
            'comment': 'OpenAI 프록시 테스트 응답입니다.',
          },
        };
      }),
    );

    final result = await service.analyze(
      PersonalColorAnalysisRequest(
        faceImagePath: sourceFile.path,
        prompt: '퍼스널 컬러 prompt',
        includeImage: true,
      ),
    );

    expect(capturedUri?.path, '/ai/personal-color');
    expect(capturedBody?['imageBase64'], isA<String>());
    expect(capturedBody?['imageMimeType'], 'image/jpeg');
    expect(capturedBody?['mode'], 'imageAndFeatures');
    expect(result.type, '여름 쿨');
    expect(result.recommendedColors, contains('소프트 블루'));
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

class _PersonalColorVisionFailsTextSucceedsEngine
    implements PersonalColorEngineAdapter {
  const _PersonalColorVisionFailsTextSucceedsEngine();

  @override
  String get engineName => 'localGemma';

  @override
  Future<PersonalColorResult> analyze(
    PersonalColorAnalysisRequest request,
  ) async {
    if (request.includeImage) {
      throw StateError('vision unavailable');
    }
    return const PersonalColorResult(
      type: '여름 쿨',
      recommendedColors: ['라벤더', '소프트 블루'],
      avoidColors: ['강한 오렌지'],
      comment: '색상정보 기반 퍼스널 컬러 분석입니다.',
    );
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  _FakeHttpClient(this.handler);

  final Map<String, dynamic> Function(
    Uri uri,
    Map<String, dynamic> body,
  ) handler;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(url, handler);
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  _FakeHttpClientRequest(this.uri, this.handler);

  @override
  final Uri uri;
  final Map<String, dynamic> Function(
    Uri uri,
    Map<String, dynamic> body,
  ) handler;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();
  final StringBuffer _body = StringBuffer();

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? object) {
    _body.write(object);
  }

  @override
  Future<HttpClientResponse> close() async {
    final body = jsonDecode(_body.toString()) as Map<String, dynamic>;
    return _FakeHttpClientResponse(
      statusCode: HttpStatus.ok,
      body: jsonEncode(handler(uri, body)),
    );
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? contentType) {
    _contentType = contentType;
  }
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.statusCode,
    required String body,
  }) : _bytes = utf8.encode(body);

  @override
  final int statusCode;

  final List<int> _bytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
