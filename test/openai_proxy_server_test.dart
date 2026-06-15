import 'dart:convert';
import 'dart:io';

import 'package:fitface/openai_proxy/openai_proxy_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('environment config strips shell-style quotes', () {
    final config = OpenAiProxyConfig.fromEnvironment({
      'OPENAI_API_KEY': '"test-key"',
      'OPENAI_MODEL': "'gpt-test'",
      'FITFACE_PROXY_HOST': '"0.0.0.0"',
      'FITFACE_PROXY_PORT': '"8787"',
      'FITFACE_PROXY_MAX_BODY_BYTES': "'4096'",
      'FITFACE_PROXY_MAX_IMAGES': '"2"',
    });

    expect(config.apiKey, 'test-key');
    expect(config.model, 'gpt-test');
    expect(config.host, '0.0.0.0');
    expect(config.port, 8787);
    expect(config.maxBodyBytes, 4096);
    expect(config.maxImages, 2);
  });

  test('environment config loads .env files before process environment',
      () async {
    final root = await Directory.systemTemp.createTemp('fitface_proxy_env_');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/.env').writeAsString('''
OPENAI_API_KEY=from-file
OPENAI_MODEL=file-model
FITFACE_PROXY_HOST=127.0.0.1
FITFACE_PROXY_PORT=1111
''');
    await File('${root.path}/.env.local').writeAsString('''
FITFACE_PROXY_HOST="0.0.0.0"
FITFACE_PROXY_PORT='8787'
FITFACE_PROXY_AUTH_TOKEN=local-token
''');

    final config = OpenAiProxyConfig.fromEnvironmentFiles(
      {
        'OPENAI_MODEL': 'runtime-model',
        'FITFACE_PROXY_MAX_IMAGES': '5',
      },
      paths: ['${root.path}/.env', '${root.path}/.env.local'],
    );

    expect(config.apiKey, 'from-file');
    expect(config.model, 'runtime-model');
    expect(config.host, '0.0.0.0');
    expect(config.port, 8787);
    expect(config.maxImages, 5);
    expect(config.authToken, 'local-token');
  });

  test('snapshot endpoint builds a Responses API image request', () async {
    late Map<String, dynamic> captured;
    final proxy = FitFaceOpenAiProxy(
      config: const OpenAiProxyConfig(apiKey: 'test-key'),
      client: _FakeResponsesClient((body) {
        captured = body;
        return _openAiOutput({
          'score': 82,
          'comment': '색감과 얼굴 주변 밝기가 안정적입니다.',
          'bestSnapshotId': null,
          'candidateScores': <String, int>{},
          'candidateComments': <String, String>{},
          'tags': ['쿨톤추천'],
          'strengths': ['밝기가 안정적입니다.'],
          'concerns': ['매장 조명에 따라 달라질 수 있습니다.'],
          'suggestions': ['소프트 블루 계열을 확인해보세요.'],
          'confidence': 0.78,
        });
      }),
    );

    final response = await proxy.handleJson('/ai/snapshot/analyze', {
      'snapshotId': 'snapshot_1',
      'imageBase64': 'abc123',
      'imageMimeType': 'image/jpeg',
      'prompt': 'snapshot prompt',
      'features': {'averageHex': '#AABBCC'},
      'mode': 'imageAndFeatures',
    });

    expect(response['result'], isA<Map>());
    expect((response['result'] as Map)['score'], 82);
    expect(captured['model'], 'gpt-5.4-mini');
    expect(captured['store'], isFalse);
    final user = (captured['input'] as List)[1] as Map;
    final content = user['content'] as List;
    expect(
      content.any(
        (item) =>
            item is Map &&
            item['type'] == 'input_image' &&
            item['image_url'] == 'data:image/jpeg;base64,abc123',
      ),
      isTrue,
    );
    expect(
      (((captured['text'] as Map)['format'] as Map)['name']),
      'fitface_snapshot_analysis',
    );
  });

  test('compare endpoint limits images and returns candidate maps', () async {
    late Map<String, dynamic> captured;
    final proxy = FitFaceOpenAiProxy(
      config: const OpenAiProxyConfig(apiKey: 'test-key', maxImages: 2),
      client: _FakeResponsesClient((body) {
        captured = body;
        return _openAiOutput({
          'score': 88,
          'comment': '두 번째 후보가 가장 안정적입니다.',
          'bestSnapshotId': 'snapshot_2',
          'candidateResults': [
            {
              'snapshotId': 'snapshot_1',
              'score': 72,
              'comment': '조명 대비가 조금 약합니다.',
            },
            {
              'snapshotId': 'snapshot_2',
              'score': 88,
              'comment': '대비와 색감이 안정적입니다.',
            },
          ],
          'tags': ['BEST'],
          'strengths': ['비교 결과가 명확합니다.'],
          'concerns': <String>[],
          'suggestions': ['실제 조명에서 한 번 더 보세요.'],
          'confidence': 0.74,
        });
      }),
    );

    final response = await proxy.handleJson('/ai/snapshots/compare', {
      'snapshotIds': ['snapshot_1', 'snapshot_2', 'snapshot_3'],
      'images': [
        {
          'snapshotId': 'snapshot_1',
          'imageBase64': 'one',
          'imageMimeType': 'image/jpeg',
        },
        {
          'snapshotId': 'snapshot_2',
          'imageBase64': 'two',
          'imageMimeType': 'image/jpeg',
        },
        {
          'snapshotId': 'snapshot_3',
          'imageBase64': 'three',
          'imageMimeType': 'image/jpeg',
        },
      ],
      'prompt': 'compare prompt',
      'featuresBySnapshotId': <String, dynamic>{},
      'mode': 'imageAndFeatures',
    });

    expect((response['result'] as Map)['bestSnapshotId'], 'snapshot_2');
    expect(
      ((response['result'] as Map)['candidateScores'] as Map)['snapshot_2'],
      88,
    );
    expect(
      ((response['result'] as Map)['candidateComments'] as Map)['snapshot_2'],
      '대비와 색감이 안정적입니다.',
    );
    final user = (captured['input'] as List)[1] as Map;
    final content = user['content'] as List;
    expect(
      content.where((item) => item is Map && item['type'] == 'input_image'),
      hasLength(2),
    );
    expect(
      (((captured['text'] as Map)['format'] as Map)['name']),
      'fitface_snapshot_compare',
    );
    final schema = (((captured['text'] as Map)['format'] as Map)['schema']
        as Map<String, dynamic>);
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.containsKey('candidateResults'), isTrue);
    expect(properties.containsKey('candidateScores'), isFalse);
    final candidateResults =
        properties['candidateResults'] as Map<String, dynamic>;
    final candidateItem = candidateResults['items'] as Map<String, dynamic>;
    final candidateProperties =
        candidateItem['properties'] as Map<String, dynamic>;
    expect(
      candidateProperties.keys,
      containsAll(['snapshotId', 'score', 'comment']),
    );
  });

  test('personal color endpoint supports features-only requests', () async {
    late Map<String, dynamic> captured;
    final proxy = FitFaceOpenAiProxy(
      config: const OpenAiProxyConfig(apiKey: 'test-key', model: 'gpt-test'),
      client: _FakeResponsesClient((body) {
        captured = body;
        return _openAiOutput({
          'type': '여름 쿨 트루',
          'recommendedColors': ['라벤더', '소프트 블루'],
          'avoidColors': ['강한 오렌지'],
          'comment': '색상정보 기준 분석입니다.',
        });
      }),
    );

    final response = await proxy.handleJson('/ai/personal-color', {
      'prompt': 'personal prompt',
      'features': {'warmCoolBias': -0.2},
      'mode': 'featuresOnly',
    });

    expect((response['result'] as Map)['type'], '여름 쿨 트루');
    expect(captured['model'], 'gpt-test');
    final user = (captured['input'] as List)[1] as Map;
    final content = user['content'] as List;
    expect(
      content.any((item) => item is Map && item['type'] == 'input_image'),
      isFalse,
    );
    final format = (captured['text'] as Map)['format'] as Map;
    expect(format['name'], 'fitface_personal_color');

    // type 필드는 12계절 유형 enum으로 제약된다.
    final schema = format['schema'] as Map<String, dynamic>;
    final typeSchema =
        (schema['properties'] as Map)['type'] as Map<String, dynamic>;
    final typeEnum = (typeSchema['enum'] as List).cast<String>();
    expect(typeEnum.length, 12);
    expect(typeEnum, contains('여름 쿨 트루'));
    expect(typeEnum, contains('봄 웜 라이트'));
    expect(typeEnum, contains('겨울 쿨 딥'));
    // 옛 6유형 표기는 enum에 없어야 한다.
    expect(typeEnum, isNot(contains('여름 쿨')));
  });

  test('personal color schema enum matches the canonical 12 type labels', () {
    expect(personalColorTypeLabels.length, 12);
    expect(personalColorTypeLabels.toSet().length, 12);
    expect(personalColorTypeLabels.first, '봄 웜 라이트');
    expect(personalColorTypeLabels.last, '겨울 쿨 딥');
  });

  test('unknown endpoint returns standardized proxy exception', () async {
    final proxy = FitFaceOpenAiProxy(
      config: const OpenAiProxyConfig(apiKey: 'test-key'),
      client: _FakeResponsesClient((_) => _openAiOutput({})),
    );

    expect(
      () => proxy.handleJson('/missing', const {}),
      throwsA(
        isA<OpenAiProxyException>().having(
          (error) => error.code,
          'code',
          'NOT_FOUND',
        ),
      ),
    );
  });

  test('auth token rejects AI requests without a matching header', () async {
    final proxy = FitFaceOpenAiProxy(
      config: const OpenAiProxyConfig(
        apiKey: 'test-key',
        authToken: 'secret-token',
      ),
      client: _FakeResponsesClient(
        (_) => _openAiOutput({
          'type': '여름 쿨 트루',
          'recommendedColors': <String>[],
          'avoidColors': <String>[],
          'comment': 'ok',
        }),
      ),
    );
    final server = await proxy.start(address: '127.0.0.1', port: 0);
    addTearDown(() => server.close(force: true));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final base = 'http://127.0.0.1:${server.port}';

    // /health stays open without a token.
    final health = await _get(client, '$base/health');
    expect(health.statusCode, 200);

    // No token -> 401.
    final unauthorized = await _postJson(
      client,
      '$base/ai/personal-color',
      {'prompt': 'p', 'mode': 'featuresOnly'},
    );
    expect(unauthorized.statusCode, HttpStatus.unauthorized);
    expect(jsonDecode(unauthorized.body)['error']['code'], 'UNAUTHORIZED');

    // Wrong token -> 401.
    final wrong = await _postJson(
      client,
      '$base/ai/personal-color',
      {'prompt': 'p', 'mode': 'featuresOnly'},
      token: 'nope',
    );
    expect(wrong.statusCode, HttpStatus.unauthorized);

    // Correct token -> 200.
    final ok = await _postJson(
      client,
      '$base/ai/personal-color',
      {'prompt': 'p', 'mode': 'featuresOnly'},
      token: 'secret-token',
    );
    expect(ok.statusCode, 200);
    expect(jsonDecode(ok.body)['result']['type'], '여름 쿨 트루');
  });

  test('requests are served without an auth token when none is configured',
      () async {
    final proxy = FitFaceOpenAiProxy(
      config: const OpenAiProxyConfig(apiKey: 'test-key'),
      client: _FakeResponsesClient(
        (_) => _openAiOutput({
          'type': '봄 웜 라이트',
          'recommendedColors': <String>[],
          'avoidColors': <String>[],
          'comment': 'ok',
        }),
      ),
    );
    final server = await proxy.start(address: '127.0.0.1', port: 0);
    addTearDown(() => server.close(force: true));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final base = 'http://127.0.0.1:${server.port}';

    final ok = await _postJson(
      client,
      '$base/ai/personal-color',
      {'prompt': 'p', 'mode': 'featuresOnly'},
    );
    expect(ok.statusCode, 200);
    expect(jsonDecode(ok.body)['result']['type'], '봄 웜 라이트');
  });
}

class _HttpResult {
  const _HttpResult(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

Future<_HttpResult> _get(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  final body = await utf8.decodeStream(response);
  return _HttpResult(response.statusCode, body);
}

Future<_HttpResult> _postJson(
  HttpClient client,
  String url,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final request = await client.postUrl(Uri.parse(url));
  request.headers.contentType = ContentType.json;
  if (token != null) {
    request.headers.set('X-FitFace-Token', token);
  }
  request.write(jsonEncode(body));
  final response = await request.close();
  final responseBody = await utf8.decodeStream(response);
  return _HttpResult(response.statusCode, responseBody);
}

Map<String, dynamic> _openAiOutput(Map<String, dynamic> result) {
  return {
    'output': [
      {
        'type': 'message',
        'content': [
          {
            'type': 'output_text',
            'text': jsonEncode(result),
          },
        ],
      },
    ],
  };
}

class _FakeResponsesClient implements OpenAiResponsesClient {
  const _FakeResponsesClient(this.handler);

  final Map<String, dynamic> Function(Map<String, dynamic> body) handler;

  @override
  Future<Map<String, dynamic>> createResponse(
    Map<String, dynamic> body,
  ) async {
    return handler(body);
  }
}
