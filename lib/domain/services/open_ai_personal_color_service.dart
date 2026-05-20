import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import '../../data/models/ai_settings.dart';
import '../../data/models/personal_color_result.dart';
import 'personal_color_engine_adapter.dart';

class OpenAiPersonalColorService implements PersonalColorEngineAdapter {
  OpenAiPersonalColorService({
    required AiSettings settings,
    HttpClient? client,
  })  : _settings = settings,
        _client = client ?? HttpClient();

  final AiSettings _settings;
  final HttpClient _client;

  @override
  String get engineName => 'openAi';

  @override
  Future<PersonalColorResult> analyze(
    PersonalColorAnalysisRequest request,
  ) async {
    final response = await _postJson(
      '/ai/personal-color',
      {
        'imageBase64': request.includeImage
            ? await _readSanitizedImageBase64(request.faceImagePath)
            : null,
        'imageMimeType': request.includeImage ? 'image/jpeg' : null,
        'prompt': request.prompt,
        'features': request.features?.toJson(),
        'mode': request.includeImage ? 'imageAndFeatures' : 'featuresOnly',
      },
    );
    final rawResult = (response['result'] as Map<String, dynamic>?) ?? response;
    return PersonalColorResult.fromJson(rawResult);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (!_settings.allowCloudAnalysis) {
      throw StateError('클라우드 AI 사용 동의가 필요합니다.');
    }
    final baseUrl = _settings.openAiProxyUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('OpenAI API 프록시 주소가 설정되지 않았습니다.');
    }
    final uri = Uri.parse('$baseUrl$path');
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'OpenAI 프록시 요청 실패: ${response.statusCode} $text',
        uri: uri,
      );
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<String> _readSanitizedImageBase64(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('OpenAI 전송용 이미지를 읽을 수 없습니다.');
    }
    final maxSide = _max(decoded.width, decoded.height);
    final sanitized = maxSide > 1024
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 1024 : null,
            height: decoded.height > decoded.width ? 1024 : null,
          )
        : decoded;
    return base64Encode(img.encodeJpg(sanitized, quality: 86));
  }

  int _max(int a, int b) {
    return a >= b ? a : b;
  }
}
