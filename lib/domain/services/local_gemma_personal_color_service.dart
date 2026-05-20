import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/models/ai_settings.dart';
import '../../data/models/personal_color_result.dart';
import 'personal_color_engine_adapter.dart';

class LocalGemmaPersonalColorService implements PersonalColorEngineAdapter {
  LocalGemmaPersonalColorService({
    required AiSettings settings,
    MethodChannel? channel,
  })  : _settings = settings,
        _channel = channel ?? const MethodChannel('fitface/local_gemma');

  final AiSettings _settings;
  final MethodChannel _channel;

  @override
  String get engineName => 'localGemma';

  @override
  Future<PersonalColorResult> analyze(
    PersonalColorAnalysisRequest request,
  ) async {
    final response = await _channel.invokeMethod<String>(
      request.includeImage
          ? 'analyzePersonalColor'
          : 'analyzePersonalColorText',
      {
        'modelPath': _settings.localModelPath,
        'modelName': _settings.localModelName,
        'imagePath': request.includeImage ? request.faceImagePath : null,
        'prompt': request.prompt,
        'features': request.features?.toJson(),
      },
    );
    return _decode(response);
  }

  PersonalColorResult _decode(String? response) {
    if (response == null || response.trim().isEmpty) {
      throw const FormatException('Local Gemma 퍼스널 컬러 응답이 비어 있습니다.');
    }
    return PersonalColorResult.fromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
  }
}
