import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/models/ai_analysis_result.dart';
import 'ai_engine_adapter.dart';

class LocalGemmaAnalysisService implements AiEngineAdapter {
  LocalGemmaAnalysisService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('fitface/local_gemma');

  final MethodChannel _channel;

  @override
  String get engineName => 'localGemma';

  @override
  Future<AiAnalysisResult> analyzeSnapshot(
    AiSnapshotAnalysisRequest request,
  ) async {
    final response = await _channel.invokeMethod<String>(
      request.includeImage ? 'analyzeSnapshot' : 'analyzeText',
      {
        'imagePath': request.includeImage ? request.snapshot.imagePath : null,
        'prompt': request.prompt,
        'features': request.features?.toJson(),
      },
    );
    return _decode(response, request.includeImage);
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    AiCompareAnalysisRequest request,
  ) async {
    final response = await _channel.invokeMethod<String>(
      request.includeImages ? 'compareSnapshots' : 'compareText',
      {
        'imagePaths': request.includeImages
            ? request.snapshots.map((snapshot) => snapshot.imagePath).toList()
            : const <String>[],
        'snapshotIds':
            request.snapshots.map((snapshot) => snapshot.id).toList(),
        'prompt': request.prompt,
        'featuresBySnapshotId': request.featuresBySnapshotId.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      },
    );
    return _decode(response, request.includeImages);
  }

  AiAnalysisResult _decode(String? response, bool usedImage) {
    if (response == null || response.trim().isEmpty) {
      throw const FormatException('Local Gemma 응답이 비어 있습니다.');
    }
    final json = jsonDecode(response) as Map<String, dynamic>;
    return AiAnalysisResult.fromJson(json).copyWith(
      engine: engineName,
      analysisMode: usedImage ? 'imageAndFeatures' : 'featuresOnly',
      createdAt: DateTime.now(),
    );
  }
}
