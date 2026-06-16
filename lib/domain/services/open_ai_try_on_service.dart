import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../data/models/ai_settings.dart';

/// 가상착장 생성 서비스 — 앱 → OpenAI 프록시(`/ai/try-on`).
///
/// `OpenAiPersonalColorService` 패턴을 따른다(토큰 헤더, 넉넉한 타임아웃,
/// 클라우드 동의/프록시 주소 체크, 이미지 sanitize, dispose).
/// 분석과 달리 생성은 오래 걸리고 응답 이미지가 크므로 타임아웃을 길게 잡는다.
class OpenAiTryOnService {
  OpenAiTryOnService({
    required AiSettings settings,
    HttpClient? client,
    this.requestTimeout = const Duration(seconds: 150),
  })  : _settings = settings,
        _client = (client ?? HttpClient())
          ..connectionTimeout = const Duration(seconds: 10);

  final AiSettings _settings;
  final HttpClient _client;
  final Duration requestTimeout;

  /// 가상착장 이미지를 생성해 PNG 바이트로 반환한다.
  ///
  /// [clothImagePath]는 오버레이 없는 원본 스냅샷, [faceImagePath]는 등록 얼굴.
  Future<Uint8List> generate({
    required String clothImagePath,
    required String faceImagePath,
    required String prompt,
  }) async {
    final response = await _postJson('/ai/try-on', {
      'clothImageBase64': await _readSanitizedImageBase64(clothImagePath),
      'clothImageMimeType': 'image/jpeg',
      'faceImageBase64': await _readSanitizedImageBase64(faceImagePath),
      'faceImageMimeType': 'image/jpeg',
      'prompt': prompt,
    });
    final result = (response['result'] as Map<String, dynamic>?) ?? response;
    final b64 = result['imageBase64'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw const FormatException('가상착장 결과 이미지를 받지 못했습니다.');
    }
    return base64Decode(b64);
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
    switch (code) {
      case 'UNAUTHORIZED':
        return '프록시 인증 토큰이 일치하지 않습니다. 설정의 토큰을 확인하세요.';
      case 'OPENAI_TIMEOUT':
        return '이미지 생성이 지연되어 요청이 중단됐습니다. 잠시 후 다시 시도하세요.';
      case 'OPENAI_IMAGE_REQUEST_FAILED':
      case 'OPENAI_IMAGE_EMPTY':
        return '이미지 생성에 실패했습니다. 잠시 후 다시 시도하세요.';
      case 'MISSING_OPENAI_API_KEY':
        return '프록시 서버에 OpenAI API 키가 설정되지 않았습니다.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return '프록시 인증에 실패했습니다($statusCode). 토큰/키 설정을 확인하세요.';
    }
    return '가상착장 요청 실패($statusCode).';
  }

  /// keep-alive 소켓 누적 방지.
  void dispose() {
    _client.close(force: true);
  }

  /// 전송 전 이미지를 적당한 크기(JPEG)로 줄여 페이로드를 낮춘다.
  Future<String> _readSanitizedImageBase64(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('가상착장 전송용 이미지를 읽을 수 없습니다.');
    }
    final maxSide = decoded.width >= decoded.height
        ? decoded.width
        : decoded.height;
    final sanitized = maxSide > 1024
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 1024 : null,
            height: decoded.height > decoded.width ? 1024 : null,
          )
        : decoded;
    return base64Encode(img.encodeJpg(sanitized, quality: 88));
  }
}
