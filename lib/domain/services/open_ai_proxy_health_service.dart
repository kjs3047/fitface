import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OpenAiProxyHealthCheck {
  const OpenAiProxyHealthCheck({
    required this.proxyUrl,
    required this.message,
  });

  final String proxyUrl;
  final String message;
}

class OpenAiProxyHealthService {
  OpenAiProxyHealthService({
    HttpClient? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client;

  final HttpClient? _client;
  final Duration timeout;

  Future<OpenAiProxyHealthCheck> check(String proxyUrl) async {
    final normalized = proxyUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw const FormatException('OpenAI 프록시 주소를 입력하세요.');
    }
    final baseUri = Uri.tryParse(normalized);
    if (baseUri == null || !baseUri.hasScheme || !baseUri.hasAuthority) {
      throw const FormatException('http:// 또는 https://로 시작하는 프록시 주소를 입력하세요.');
    }
    if (baseUri.scheme != 'http' && baseUri.scheme != 'https') {
      throw const FormatException('http:// 또는 https://로 시작하는 프록시 주소를 입력하세요.');
    }
    final client = _client ?? HttpClient();
    try {
      final healthUri =
          baseUri.replace(path: _joinPath(baseUri.path, 'health'));
      final request = await client.getUrl(healthUri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final text = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'OpenAI 프록시 연결 실패: ${response.statusCode} $text',
          uri: healthUri,
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
        throw FormatException('OpenAI 프록시 상태 응답이 올바르지 않습니다: $text');
      }
      return OpenAiProxyHealthCheck(
        proxyUrl: normalized,
        message: 'OpenAI 프록시 연결이 확인되었습니다.',
      );
    } finally {
      if (_client == null) {
        client.close(force: true);
      }
    }
  }

  String _joinPath(String basePath, String child) {
    final trimmed = basePath.trim();
    if (trimmed.isEmpty || trimmed == '/') {
      return '/$child';
    }
    return '${trimmed.replaceAll(RegExp(r'/+$'), '')}/$child';
  }
}
