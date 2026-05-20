import 'dart:convert';

import 'package:flutter/services.dart';

class LocalGemmaModelImport {
  const LocalGemmaModelImport({
    required this.path,
    required this.name,
    required this.bytes,
  });

  final String path;
  final String name;
  final int bytes;

  factory LocalGemmaModelImport.fromMap(Map<dynamic, dynamic> map) {
    return LocalGemmaModelImport(
      path: map['path'] as String,
      name: map['name'] as String,
      bytes: (map['bytes'] as num).round(),
    );
  }
}

class LocalGemmaModelCheck {
  const LocalGemmaModelCheck({
    required this.message,
    this.score,
  });

  final String message;
  final int? score;
}

class LocalGemmaModelService {
  const LocalGemmaModelService({
    MethodChannel channel = const MethodChannel('fitface/local_gemma'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<LocalGemmaModelImport?> importModel() async {
    final imported = await _channel.invokeMapMethod<dynamic, dynamic>(
      'importModel',
    );
    if (imported == null) {
      return null;
    }
    return LocalGemmaModelImport.fromMap(imported);
  }

  Future<LocalGemmaModelCheck> testModel({
    required String modelPath,
    String? modelName,
  }) async {
    final response = await _channel.invokeMethod<String>(
      'analyzeText',
      {
        'modelPath': modelPath,
        'modelName': modelName,
        'prompt': _diagnosticPrompt,
        'features': const <String, dynamic>{
          'diagnostic': true,
          'inputMode': 'textOnly',
        },
      },
    );
    if (response == null || response.trim().isEmpty) {
      throw const FormatException('Local Gemma 진단 응답이 비어 있습니다.');
    }
    final json = jsonDecode(response) as Map<String, dynamic>;
    final comment = json['comment'] as String? ?? 'Local Gemma 응답을 확인했습니다.';
    return LocalGemmaModelCheck(
      message: comment,
      score: (json['score'] as num?)?.round(),
    );
  }

  static final _diagnosticPrompt = [
    '역할: FitFace Local Gemma 연결 진단.',
    '목표: 모델 로드와 JSON 응답 가능 여부만 확인한다.',
    '출력은 반드시 JSON 객체 하나만 사용한다.',
    '필드: score, comment, tags, strengths, concerns, suggestions, confidence.',
    'comment는 "Local Gemma 연결 테스트가 완료되었습니다."로 시작한다.',
  ].join('\n');
}
