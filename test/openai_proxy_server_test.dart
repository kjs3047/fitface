import 'dart:convert';

import 'package:fitface/openai_proxy/openai_proxy_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
          'candidateScores': {'snapshot_1': 72, 'snapshot_2': 88},
          'candidateComments': {'snapshot_2': '대비와 색감이 안정적입니다.'},
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
  });

  test('personal color endpoint supports features-only requests', () async {
    late Map<String, dynamic> captured;
    final proxy = FitFaceOpenAiProxy(
      config: const OpenAiProxyConfig(apiKey: 'test-key', model: 'gpt-test'),
      client: _FakeResponsesClient((body) {
        captured = body;
        return _openAiOutput({
          'type': '여름 쿨',
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

    expect((response['result'] as Map)['type'], '여름 쿨');
    expect(captured['model'], 'gpt-test');
    final user = (captured['input'] as List)[1] as Map;
    final content = user['content'] as List;
    expect(
      content.any((item) => item is Map && item['type'] == 'input_image'),
      isFalse,
    );
    expect(
      (((captured['text'] as Map)['format'] as Map)['name']),
      'fitface_personal_color',
    );
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
