import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/models/ai_settings.dart';
import '../../data/models/personal_color_result.dart';
import '../personal_color/personal_color_type.dart';
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
    final result = PersonalColorResult.fromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
    return _normalizeType(result);
  }

  /// 로컬 모델은 스키마 강제가 안 되므로 type이 12유형 목록 밖이면 가장 유사한
  /// 유형으로 매핑한다. 매핑조차 불가하면 원본 문자열을 그대로 둔다.
  PersonalColorResult _normalizeType(PersonalColorResult result) {
    if (PersonalColorTypes.byLabel(result.type) != null) {
      return result;
    }
    final mapped = PersonalColorTypes.closestTo(result.type);
    if (mapped == null) {
      return result;
    }
    return result.copyWith(type: mapped.label);
  }
}
