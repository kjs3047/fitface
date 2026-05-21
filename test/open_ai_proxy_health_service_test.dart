import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitface/domain/services/open_ai_proxy_health_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenAiProxyHealthService checks /health and normalizes URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    addTearDown(() async => server.close(force: true));
    unawaited(
      server.forEach((request) async {
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'ok': true}));
        await request.response.close();
      }),
    );

    final baseUrl = 'http://${server.address.address}:${server.port}/';
    final result = await OpenAiProxyHealthService(
      timeout: const Duration(seconds: 2),
    ).check(baseUrl);

    expect(paths, ['/health']);
    expect(result.proxyUrl, baseUrl.substring(0, baseUrl.length - 1));
    expect(result.message, 'OpenAI 프록시 연결이 확인되었습니다.');
  });

  test('OpenAiProxyHealthService rejects unsupported URL schemes', () async {
    expect(
      () => OpenAiProxyHealthService().check('ftp://127.0.0.1:8787'),
      throwsFormatException,
    );
  });
}
