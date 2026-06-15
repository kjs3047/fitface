import 'dart:async';
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
    this.requestTimeout = const Duration(seconds: 60),
  })  : _settings = settings,
        _client = (client ?? HttpClient())
          ..connectionTimeout = const Duration(seconds: 10);

  final AiSettings _settings;
  final HttpClient _client;

  /// 프록시가 OpenAI를 다시 호출하므로 앱→프록시 요청은 넉넉하게 잡는다.
  final Duration requestTimeout;

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
    try {
      final request = await _client.postUrl(uri).timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      final token = _settings.openAiProxyToken?.trim();
      if (token != null && token.isNotEmpty) {
        request.headers.set('X-FitFace-Token', token);
      }
      request.write(jsonEncode(body));
      final response = await request.close().timeout(requestTimeout);
      final text = await utf8.decodeStream(response).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          _friendlyProxyError(response.statusCode, text),
          uri: uri,
        );
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on TimeoutException {
      throw HttpException(
        'OpenAI 프록시 응답이 지연되어 요청을 중단했습니다.',
        uri: uri,
      );
    }
  }

  /// 프록시/OpenAI 오류를 사용자가 원인을 알 수 있는 한국어 메시지로 바꾼다.
  /// 프록시는 {"error":{"code":...,"message":...}} 형태로 응답한다.
  String _friendlyProxyError(int statusCode, String body) {
    String? code;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        code = (decoded['error'] as Map)['code']?.toString();
      }
    } catch (_) {
      // 파싱 불가 시 상태코드 기반으로만 판단한다.
    }
    if (body.contains('invalid_api_key') ||
        body.contains('Incorrect API key')) {
      return 'OpenAI API 키가 올바르지 않습니다. 프록시 서버의 OPENAI_API_KEY를 확인하세요.';
    }
    switch (code) {
      case 'UNAUTHORIZED':
        return '프록시 인증 토큰이 일치하지 않습니다. 설정의 토큰을 확인하세요.';
      case 'OPENAI_TIMEOUT':
        return 'OpenAI 응답이 지연되어 요청이 중단됐습니다.';
      case 'MISSING_OPENAI_API_KEY':
        return '프록시 서버에 OpenAI API 키가 설정되지 않았습니다.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return '프록시 인증에 실패했습니다($statusCode). 토큰/키 설정을 확인하세요.';
    }
    return 'OpenAI 프록시 요청 실패($statusCode).';
  }

  /// keep-alive 소켓이 누적되지 않도록 더 이상 쓰지 않을 때 호출한다.
  void dispose() {
    _client.close(force: true);
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
