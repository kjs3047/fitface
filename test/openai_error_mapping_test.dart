import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitface/data/models/ai_settings.dart';
import 'package:fitface/data/models/outfit_snapshot.dart';
import 'package:fitface/domain/services/ai_engine_adapter.dart';
import 'package:fitface/domain/services/open_ai_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 프록시/OpenAI 오류 응답이 사용자가 원인을 알 수 있는 한국어 메시지로
/// 변환되는지 검증한다. (잘못된 키, 인증 실패 등)
void main() {
  AiSettings cloudSettings() => AiSettings.defaults().copyWith(
        mode: AiEngineMode.openAi,
        allowCloudAnalysis: true,
        openAiProxyUrl: 'http://127.0.0.1:8787',
      );

  test('invalid_api_key 401 응답을 키 안내 메시지로 바꾼다', () async {
    final service = OpenAiAnalysisService(
      settings: cloudSettings(),
      client: _ErrorHttpClient(
        statusCode: 502,
        body: jsonEncode({
          'error': {
            'code': 'OPENAI_REQUEST_FAILED',
            'message': 'OpenAI request failed: 401 '
                '{"error":{"code":"invalid_api_key",'
                '"message":"Incorrect API key provided: sk-proj-xxx"}}',
          },
        }),
      ),
    );

    await expectLater(
      () => service.analyzeSnapshot(_request()),
      throwsA(
        isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('OpenAI API 키가 올바르지 않습니다'),
        ),
      ),
    );
  });

  test('UNAUTHORIZED 코드를 토큰 안내 메시지로 바꾼다', () async {
    final service = OpenAiAnalysisService(
      settings: cloudSettings(),
      client: _ErrorHttpClient(
        statusCode: 401,
        body: jsonEncode({
          'error': {
            'code': 'UNAUTHORIZED',
            'message': 'Missing or invalid auth token.',
          },
        }),
      ),
    );

    await expectLater(
      () => service.analyzeSnapshot(_request()),
      throwsA(
        isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('프록시 인증 토큰'),
        ),
      ),
    );
  });

  test('raw 401(파싱 불가)도 인증 실패 메시지로 바꾼다', () async {
    final service = OpenAiAnalysisService(
      settings: cloudSettings(),
      client: _ErrorHttpClient(statusCode: 401, body: 'not json'),
    );

    await expectLater(
      () => service.analyzeSnapshot(_request()),
      throwsA(
        isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('프록시 인증에 실패'),
        ),
      ),
    );
  });

  // analyzeSnapshot은 이미지를 읽으려 하므로, 이미지 없이도 _postJson 경로를
  // 타도록 includeImage=false 요청을 직접 만든다.
}

AiSnapshotAnalysisRequest _request() {
  return AiSnapshotAnalysisRequest(
    snapshot: OutfitSnapshot(
      id: 's1',
      imagePath: '/tmp/none.png',
      createdAt: DateTime(2026),
    ),
    features: null,
    includeImage: false,
    prompt: 'test',
  );
}

class _ErrorHttpClient extends Fake implements HttpClient {
  _ErrorHttpClient({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _ErrorHttpClientRequest(url, statusCode, body);
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorHttpClientRequest extends Fake implements HttpClientRequest {
  _ErrorHttpClientRequest(this.uri, this.statusCode, this.body);

  @override
  final Uri uri;
  final int statusCode;
  final String body;
  final _ErrorHttpHeaders _headers = _ErrorHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async {
    return _ErrorHttpClientResponse(statusCode: statusCode, body: body);
  }
}

class _ErrorHttpHeaders extends Fake implements HttpHeaders {
  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) => _contentType = value;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _ErrorHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ErrorHttpClientResponse({required this.statusCode, required String body})
      : _bytes = utf8.encode(body);

  @override
  final int statusCode;

  final List<int> _bytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
