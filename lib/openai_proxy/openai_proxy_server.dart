import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OpenAiProxyConfig {
  const OpenAiProxyConfig({
    required this.apiKey,
    this.model = 'gpt-5.4-mini',
    this.imageModel = 'gpt-image-2',
    this.host = '127.0.0.1',
    this.port = 8787,
    this.maxBodyBytes = 12 * 1024 * 1024,
    this.maxImages = 3,
    this.authToken,
  });

  factory OpenAiProxyConfig.fromEnvironmentFiles(
    Map<String, String> env, {
    List<String> paths = const ['.env', '.env.local'],
  }) {
    final merged = <String, String>{};
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        merged.addAll(_parseEnvFile(file.readAsStringSync()));
      }
    }
    merged.addAll(env);
    return OpenAiProxyConfig.fromEnvironment(merged);
  }

  factory OpenAiProxyConfig.fromEnvironment(Map<String, String> env) {
    final apiKey = _envValue(env, 'OPENAI_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      throw const OpenAiProxyException(
        'MISSING_OPENAI_API_KEY',
        'OPENAI_API_KEY is required.',
        HttpStatus.internalServerError,
      );
    }
    final model = _envValue(env, 'OPENAI_MODEL');
    final imageModel = _envValue(env, 'OPENAI_IMAGE_MODEL');
    final host = _envValue(env, 'FITFACE_PROXY_HOST');
    final port = _envValue(env, 'FITFACE_PROXY_PORT');
    final maxBodyBytes = _envValue(env, 'FITFACE_PROXY_MAX_BODY_BYTES');
    final maxImages = _envValue(env, 'FITFACE_PROXY_MAX_IMAGES');
    final authToken = _envValue(env, 'FITFACE_PROXY_AUTH_TOKEN');

    return OpenAiProxyConfig(
      apiKey: apiKey,
      model: model?.isNotEmpty == true ? model! : 'gpt-5.4-mini',
      imageModel:
          imageModel?.isNotEmpty == true ? imageModel! : 'gpt-image-2',
      host: host?.isNotEmpty == true ? host! : '127.0.0.1',
      port: int.tryParse(port ?? '') ?? 8787,
      maxBodyBytes: int.tryParse(maxBodyBytes ?? '') ?? 12 * 1024 * 1024,
      maxImages: int.tryParse(maxImages ?? '') ?? 3,
      authToken: authToken?.isNotEmpty == true ? authToken : null,
    );
  }

  final String apiKey;
  final String model;

  /// 가상착장 이미지 생성/편집 모델. 기본 gpt-image-2(정확도·일관성 우선).
  final String imageModel;
  final String host;
  final int port;
  final int maxBodyBytes;
  final int maxImages;

  /// 설정 시 AI 엔드포인트는 X-FitFace-Token 헤더로 이 값을 요구한다.
  /// null이면 인증을 강제하지 않는다(로컬 개발 호환).
  final String? authToken;
}

/// 앱과 프록시가 공유하는 인증 헤더 이름.
const fitFaceProxyAuthHeader = 'x-fitface-token';

/// 퍼스널 컬러 12계절 유형의 정식 문자열.
///
/// 앱 측 단일 소스(`lib/domain/personal_color/personal_color_type.dart`)의
/// `PersonalColorTypes.labels`와 글자까지 동일해야 한다. 프록시는 Dart 코드를
/// 공유하지 않으므로 여기에 별도로 둔다. 한쪽을 고치면 반드시 다른 쪽도 고친다.
const personalColorTypeLabels = <String>[
  '봄 웜 라이트',
  '봄 웜 트루',
  '봄 웜 브라이트',
  '여름 쿨 라이트',
  '여름 쿨 트루',
  '여름 쿨 뮤트',
  '가을 웜 뮤트',
  '가을 웜 트루',
  '가을 웜 딥',
  '겨울 쿨 브라이트',
  '겨울 쿨 트루',
  '겨울 쿨 딥',
];

String? _envValue(Map<String, String> env, String key) {
  final value = env[key]?.trim();
  return value == null ? null : _stripEnvQuotes(value);
}

Map<String, String> _parseEnvFile(String contents) {
  final values = <String, String>{};
  for (final line in const LineSplitter().convert(contents)) {
    var trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    if (trimmed.startsWith('export ')) {
      trimmed = trimmed.substring('export '.length).trimLeft();
    }
    final separator = trimmed.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final key = trimmed.substring(0, separator).trim();
    if (key.isEmpty) {
      continue;
    }
    values[key] = _stripEnvQuotes(trimmed.substring(separator + 1).trim());
  }
  return values;
}

String _stripEnvQuotes(String value) {
  if (value.length < 2) {
    return value;
  }
  final first = value[0];
  final last = value[value.length - 1];
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1).trim();
  }
  return value;
}

class OpenAiProxyException implements Exception {
  const OpenAiProxyException(
    this.code,
    this.message, [
    this.statusCode = HttpStatus.badRequest,
  ]);

  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => '$code: $message';
}

abstract class OpenAiResponsesClient {
  Future<Map<String, dynamic>> createResponse(Map<String, dynamic> body);
}

/// 가상착장용 입력 이미지 한 장(원본 바이트 + MIME).
class OpenAiEditImage {
  const OpenAiEditImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final List<int> bytes;
  final String mimeType;
  final String fileName;
}

/// `/v1/images/edits`(gpt-image류) 호출 클라이언트. 분석용 Responses API와
/// 달리 multipart/form-data로 보내고 data[0].b64_json을 받는다.
abstract class OpenAiImageEditsClient {
  /// 편집 결과 이미지의 base64 문자열을 반환한다.
  Future<String> editImage({
    required String model,
    required String prompt,
    required List<OpenAiEditImage> images,
    String size,
    String quality,
  });
}

class HttpOpenAiImageEditsClient implements OpenAiImageEditsClient {
  HttpOpenAiImageEditsClient({
    required String apiKey,
    HttpClient? httpClient,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 120),
  })  : _apiKey = apiKey,
        _httpClient = (httpClient ?? HttpClient())
          ..connectionTimeout = const Duration(seconds: 10),
        _endpoint =
            endpoint ?? Uri.parse('https://api.openai.com/v1/images/edits');

  final String _apiKey;
  final HttpClient _httpClient;
  final Uri _endpoint;

  /// 생성은 분석보다 오래 걸리므로 타임아웃을 넉넉히 잡는다.
  final Duration requestTimeout;

  @override
  Future<String> editImage({
    required String model,
    required String prompt,
    required List<OpenAiEditImage> images,
    String size = '1024x1536',
    String quality = 'medium',
  }) async {
    if (images.isEmpty) {
      throw const OpenAiProxyException(
        'TRYON_NO_INPUT_IMAGE',
        'At least one input image is required.',
      );
    }
    final boundary = '----fitface${DateTime.now().microsecondsSinceEpoch}';
    final body = _buildMultipartBody(
      boundary: boundary,
      fields: {
        'model': model,
        'prompt': prompt,
        'size': size,
        'quality': quality,
        'n': '1',
      },
      images: images,
    );
    try {
      final request =
          await _httpClient.postUrl(_endpoint).timeout(requestTimeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      request.add(body);
      final response = await request.close().timeout(requestTimeout);
      final text = await utf8.decodeStream(response).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenAiProxyException(
          'OPENAI_IMAGE_REQUEST_FAILED',
          'OpenAI image edit failed: ${response.statusCode} $text',
          HttpStatus.badGateway,
        );
      }
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) {
        throw const OpenAiProxyException(
          'OPENAI_IMAGE_EMPTY',
          'OpenAI image edit returned no data.',
          HttpStatus.badGateway,
        );
      }
      final b64 = (data.first as Map<String, dynamic>)['b64_json'] as String?;
      if (b64 == null || b64.isEmpty) {
        throw const OpenAiProxyException(
          'OPENAI_IMAGE_EMPTY',
          'OpenAI image edit returned no image.',
          HttpStatus.badGateway,
        );
      }
      return b64;
    } on TimeoutException {
      throw const OpenAiProxyException(
        'OPENAI_TIMEOUT',
        'OpenAI image edit timed out.',
        HttpStatus.gatewayTimeout,
      );
    }
  }

  /// multipart/form-data 본문을 직접 조립한다.
  /// 이미지는 `image[]` 필드로 반복 첨부(gpt-image edits 규약).
  List<int> _buildMultipartBody({
    required String boundary,
    required Map<String, String> fields,
    required List<OpenAiEditImage> images,
  }) {
    final chunks = <int>[];
    void writeAscii(String s) => chunks.addAll(ascii.encode(s));

    fields.forEach((name, value) {
      writeAscii('--$boundary\r\n');
      writeAscii('Content-Disposition: form-data; name="$name"\r\n\r\n');
      chunks.addAll(utf8.encode(value));
      writeAscii('\r\n');
    });

    for (final image in images) {
      writeAscii('--$boundary\r\n');
      writeAscii(
        'Content-Disposition: form-data; name="image[]"; '
        'filename="${image.fileName}"\r\n',
      );
      writeAscii('Content-Type: ${image.mimeType}\r\n\r\n');
      chunks.addAll(image.bytes);
      writeAscii('\r\n');
    }

    writeAscii('--$boundary--\r\n');
    return chunks;
  }
}

class HttpOpenAiResponsesClient implements OpenAiResponsesClient {
  HttpOpenAiResponsesClient({
    required String apiKey,
    HttpClient? httpClient,
    Uri? endpoint,
    this.requestTimeout = const Duration(seconds: 45),
  })  : _apiKey = apiKey,
        _httpClient = (httpClient ?? HttpClient())
          ..connectionTimeout = const Duration(seconds: 10),
        _endpoint =
            endpoint ?? Uri.parse('https://api.openai.com/v1/responses');

  final String _apiKey;
  final HttpClient _httpClient;
  final Uri _endpoint;
  final Duration requestTimeout;

  @override
  Future<Map<String, dynamic>> createResponse(Map<String, dynamic> body) async {
    try {
      final request =
          await _httpClient.postUrl(_endpoint).timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      request.write(jsonEncode(body));
      final response = await request.close().timeout(requestTimeout);
      final text = await utf8.decodeStream(response).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenAiProxyException(
          'OPENAI_REQUEST_FAILED',
          'OpenAI request failed: ${response.statusCode} $text',
          HttpStatus.badGateway,
        );
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on TimeoutException {
      throw const OpenAiProxyException(
        'OPENAI_TIMEOUT',
        'OpenAI request timed out.',
        HttpStatus.gatewayTimeout,
      );
    }
  }
}

class FitFaceOpenAiProxy {
  FitFaceOpenAiProxy({
    required this.config,
    OpenAiResponsesClient? client,
    OpenAiImageEditsClient? imageClient,
  })  : _client = client ?? HttpOpenAiResponsesClient(apiKey: config.apiKey),
        _imageClient =
            imageClient ?? HttpOpenAiImageEditsClient(apiKey: config.apiKey);

  final OpenAiProxyConfig config;
  final OpenAiResponsesClient _client;
  final OpenAiImageEditsClient _imageClient;

  Future<HttpServer> start({
    Object address = '127.0.0.1',
    int port = 8787,
  }) async {
    final server = await HttpServer.bind(address, port);
    // forEach는 콜백을 직렬로 await해 한 요청(수 초 걸리는 OpenAI 호출)이
    // 끝날 때까지 /health조차 막힌다. listen으로 각 요청을 동시에 처리한다.
    // 핸들러가 자체적으로 모든 예외를 잡으므로 unawaited가 안전하다.
    server.listen((request) {
      unawaited(handleHttpRequest(request));
    });
    return server;
  }

  Future<void> handleHttpRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _writeJson(request.response, {'ok': true});
        return;
      }
      if (request.method != 'POST') {
        throw const OpenAiProxyException(
          'METHOD_NOT_ALLOWED',
          'Only POST is supported for AI endpoints.',
          HttpStatus.methodNotAllowed,
        );
      }
      _ensureAuthorized(request);
      if (request.headers.contentType?.mimeType != ContentType.json.mimeType) {
        throw const OpenAiProxyException(
          'UNSUPPORTED_CONTENT_TYPE',
          'Content-Type must be application/json.',
        );
      }
      final bodyText = await _readLimitedBody(request);
      final body = jsonDecode(bodyText);
      if (body is! Map<String, dynamic>) {
        throw const OpenAiProxyException(
          'INVALID_JSON',
          'Request body must be a JSON object.',
        );
      }
      final result = await handleJson(request.uri.path, body);
      await _writeJson(request.response, result);
    } on OpenAiProxyException catch (error) {
      await _writeJson(
        request.response,
        {
          'error': {
            'code': error.code,
            'message': error.message,
          },
        },
        statusCode: error.statusCode,
      );
    } catch (error) {
      await _writeJson(
        request.response,
        {
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': error.toString(),
          },
        },
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  /// authToken이 설정돼 있으면 AI 엔드포인트는 일치하는 토큰 헤더를 요구한다.
  void _ensureAuthorized(HttpRequest request) {
    final expected = config.authToken;
    if (expected == null || expected.isEmpty) {
      return;
    }
    final provided = request.headers.value(fitFaceProxyAuthHeader)?.trim();
    if (provided == null || provided != expected) {
      throw const OpenAiProxyException(
        'UNAUTHORIZED',
        'Missing or invalid auth token.',
        HttpStatus.unauthorized,
      );
    }
  }

  Future<Map<String, dynamic>> handleJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    switch (path) {
      case '/ai/snapshot/analyze':
        return _analyzeSnapshot(body);
      case '/ai/snapshots/compare':
        return _compareSnapshots(body);
      case '/ai/personal-color':
        return _analyzePersonalColor(body);
      case '/ai/try-on':
        return _generateTryOn(body);
      default:
        throw const OpenAiProxyException(
          'NOT_FOUND',
          'Unknown AI endpoint.',
          HttpStatus.notFound,
        );
    }
  }

  Future<Map<String, dynamic>> _analyzeSnapshot(
    Map<String, dynamic> body,
  ) async {
    final prompt = _requiredString(body, 'prompt');
    final content = <Map<String, dynamic>>[];
    _addImageIfPresent(
      content,
      imageBase64: body['imageBase64'] as String?,
      imageMimeType: body['imageMimeType'] as String?,
    );
    content.add(
      _inputText(
        [
          prompt,
          _jsonContext('snapshotContext', {
            'snapshotId': body['snapshotId'],
            'memo': body['memo'],
            'features': body['features'],
            'mode': body['mode'],
          }),
        ].join('\n\n'),
      ),
    );
    final openAiResponse = await _client.createResponse(
      _responseBody(
        schema: _snapshotSchema(),
        schemaName: 'fitface_snapshot_analysis',
        content: content,
      ),
    );
    return {
      'result': _normalizeSnapshotResult(
        _decodeStructuredResult(openAiResponse),
      ),
    };
  }

  Future<Map<String, dynamic>> _compareSnapshots(
    Map<String, dynamic> body,
  ) async {
    final prompt = _requiredString(body, 'prompt');
    final images = ((body['images'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .take(config.maxImages)
        .toList();
    final content = <Map<String, dynamic>>[];
    for (final image in images) {
      content.add(
        _inputText('다음 이미지는 snapshotId=${image['snapshotId']} 후보입니다.'),
      );
      _addImageIfPresent(
        content,
        imageBase64: image['imageBase64'] as String?,
        imageMimeType: image['imageMimeType'] as String?,
      );
    }
    content.add(
      _inputText(
        [
          prompt,
          _jsonContext('compareContext', {
            'snapshotIds': body['snapshotIds'],
            'featuresBySnapshotId': body['featuresBySnapshotId'],
            'mode': body['mode'],
          }),
        ].join('\n\n'),
      ),
    );
    final openAiResponse = await _client.createResponse(
      _responseBody(
        schema: _snapshotSchema(),
        schemaName: 'fitface_snapshot_compare',
        content: content,
      ),
    );
    return {
      'result': _normalizeSnapshotResult(
        _decodeStructuredResult(openAiResponse),
      ),
    };
  }

  Future<Map<String, dynamic>> _analyzePersonalColor(
    Map<String, dynamic> body,
  ) async {
    final prompt = _requiredString(body, 'prompt');
    final content = <Map<String, dynamic>>[];
    _addImageIfPresent(
      content,
      imageBase64: body['imageBase64'] as String?,
      imageMimeType: body['imageMimeType'] as String?,
    );
    content.add(
      _inputText(
        [
          prompt,
          _jsonContext('personalColorContext', {
            'features': body['features'],
            'mode': body['mode'],
          }),
        ].join('\n\n'),
      ),
    );
    final openAiResponse = await _client.createResponse(
      _responseBody(
        schema: _personalColorSchema(),
        schemaName: 'fitface_personal_color',
        content: content,
      ),
    );
    return {'result': _decodeStructuredResult(openAiResponse)};
  }

  /// 가상착장 생성. 얼굴 + 옷(원본) 이미지를 gpt-image edits로 합성한다.
  Future<Map<String, dynamic>> _generateTryOn(
    Map<String, dynamic> body,
  ) async {
    final prompt = _requiredString(body, 'prompt');
    final images = <OpenAiEditImage>[];
    // 옷(원본 스냅샷)을 먼저, 얼굴을 그 다음에 — 편집 기준 이미지가 옷이다.
    _addEditImageIfPresent(
      images,
      base64Data: body['clothImageBase64'] as String?,
      mimeType: body['clothImageMimeType'] as String?,
      fileName: 'cloth.png',
    );
    _addEditImageIfPresent(
      images,
      base64Data: body['faceImageBase64'] as String?,
      mimeType: body['faceImageMimeType'] as String?,
      fileName: 'face.png',
    );
    if (images.isEmpty) {
      throw const OpenAiProxyException(
        'MISSING_TRYON_IMAGE',
        'At least one input image (cloth or face) is required.',
      );
    }
    final size = (body['size'] as String?)?.trim();
    final quality = (body['quality'] as String?)?.trim();
    final b64 = await _imageClient.editImage(
      model: config.imageModel,
      prompt: prompt,
      images: images,
      size: (size != null && size.isNotEmpty) ? size : '1024x1536',
      // 비용 통제를 위해 기본 medium. 요청에 명시되면 그 값을 따른다.
      quality: (quality != null && quality.isNotEmpty) ? quality : 'medium',
    );
    return {
      'result': {'imageBase64': b64},
    };
  }

  void _addEditImageIfPresent(
    List<OpenAiEditImage> images, {
    required String? base64Data,
    required String? mimeType,
    required String fileName,
  }) {
    if (base64Data == null || base64Data.isEmpty) {
      return;
    }
    final mime = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim()
        : 'image/png';
    if (!mime.startsWith('image/')) {
      throw const OpenAiProxyException(
        'INVALID_IMAGE_MIME_TYPE',
        'Only image MIME types are supported.',
      );
    }
    images.add(
      OpenAiEditImage(
        bytes: base64Decode(base64Data),
        mimeType: mime,
        fileName: fileName,
      ),
    );
  }

  Map<String, dynamic> _responseBody({
    required Map<String, dynamic> schema,
    required String schemaName,
    required List<Map<String, dynamic>> content,
  }) {
    return {
      'model': config.model,
      'store': false,
      'input': [
        {
          'role': 'developer',
          'content': [
            _inputText(
              'You are FitFace style analysis middleware. Return only JSON that matches the schema. '
              'Do not evaluate facial attractiveness, skin quality, identity, age, gender, race, or protected traits. '
              'Use cautious styling language and treat results as shopping guidance.',
            ),
          ],
        },
        {
          'role': 'user',
          'content': content,
        },
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': schemaName,
          'strict': true,
          'schema': schema,
        },
      },
      'max_output_tokens': 900,
    };
  }

  Map<String, dynamic> _snapshotSchema() {
    return {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'score': {'type': 'integer', 'minimum': 0, 'maximum': 100},
        'comment': {'type': 'string'},
        'bestSnapshotId': {
          'type': ['string', 'null'],
        },
        'candidateResults': {
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'snapshotId': {'type': 'string'},
              'score': {'type': 'integer', 'minimum': 0, 'maximum': 100},
              'comment': {'type': 'string'},
            },
            'required': ['snapshotId', 'score', 'comment'],
          },
        },
        'tags': _stringArraySchema(),
        'strengths': _stringArraySchema(),
        'concerns': _stringArraySchema(),
        'suggestions': _stringArraySchema(),
        'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
      },
      'required': [
        'score',
        'comment',
        'bestSnapshotId',
        'candidateResults',
        'tags',
        'strengths',
        'concerns',
        'suggestions',
        'confidence',
      ],
    };
  }

  Map<String, dynamic> _personalColorSchema() {
    return {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'type': {'type': 'string', 'enum': personalColorTypeLabels},
        'recommendedColors': _swatchArraySchema(maxItems: 5),
        'avoidColors': _swatchArraySchema(maxItems: 5),
        'comment': {'type': 'string'},
      },
      'required': ['type', 'recommendedColors', 'avoidColors', 'comment'],
    };
  }

  /// 색상 한 개 = {name, hex}. UI가 hex를 그대로 칠하므로 모델이 색상명에
  /// 맞는 실제 #RRGGBB를 함께 반환하게 한다. strict 모드라 둘 다 required.
  Map<String, dynamic> _swatchArraySchema({int maxItems = 5}) {
    return {
      'type': 'array',
      'maxItems': maxItems,
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'name': {'type': 'string'},
          'hex': {
            'type': 'string',
            'description': 'CSS hex color like #RRGGBB',
          },
        },
        'required': ['name', 'hex'],
      },
    };
  }

  Map<String, dynamic> _stringArraySchema({int maxItems = 8}) {
    return {
      'type': 'array',
      'items': {'type': 'string'},
      'maxItems': maxItems,
    };
  }

  Map<String, dynamic> _decodeStructuredResult(
    Map<String, dynamic> openAiResponse,
  ) {
    final outputText = openAiResponse['output_text'] as String?;
    if (outputText != null && outputText.trim().isNotEmpty) {
      return jsonDecode(outputText) as Map<String, dynamic>;
    }
    final output = openAiResponse['output'] as List<dynamic>?;
    if (output != null) {
      for (final item in output.whereType<Map<String, dynamic>>()) {
        final content = item['content'] as List<dynamic>?;
        if (content == null) {
          continue;
        }
        for (final part in content.whereType<Map<String, dynamic>>()) {
          if (part['type'] == 'output_text' && part['text'] is String) {
            return jsonDecode(part['text'] as String) as Map<String, dynamic>;
          }
        }
      }
    }
    throw const OpenAiProxyException(
      'OPENAI_EMPTY_OUTPUT',
      'OpenAI response did not contain output text.',
      HttpStatus.badGateway,
    );
  }

  Map<String, dynamic> _normalizeSnapshotResult(Map<String, dynamic> result) {
    final candidateResults =
        (result['candidateResults'] as List<dynamic>?) ?? const [];
    if (candidateResults.isEmpty) {
      return result
        ..putIfAbsent('candidateScores', () => <String, int>{})
        ..putIfAbsent('candidateComments', () => <String, String>{})
        ..remove('candidateResults');
    }

    final candidateScores = <String, int>{};
    final candidateComments = <String, String>{};
    for (final item in candidateResults.whereType<Map<String, dynamic>>()) {
      final snapshotId = item['snapshotId'] as String?;
      final score = item['score'];
      final comment = item['comment'] as String?;
      if (snapshotId == null || snapshotId.isEmpty) {
        continue;
      }
      if (score is num) {
        candidateScores[snapshotId] = score.round();
      }
      if (comment != null && comment.isNotEmpty) {
        candidateComments[snapshotId] = comment;
      }
    }
    return {
      ...result,
      'candidateScores': candidateScores,
      'candidateComments': candidateComments,
    }..remove('candidateResults');
  }

  void _addImageIfPresent(
    List<Map<String, dynamic>> content, {
    required String? imageBase64,
    required String? imageMimeType,
  }) {
    if (imageBase64 == null || imageBase64.isEmpty) {
      return;
    }
    final mimeType = imageMimeType?.trim().isNotEmpty == true
        ? imageMimeType!.trim()
        : 'image/jpeg';
    if (!mimeType.startsWith('image/')) {
      throw const OpenAiProxyException(
        'INVALID_IMAGE_MIME_TYPE',
        'Only image MIME types are supported.',
      );
    }
    content.add({
      'type': 'input_image',
      'image_url': 'data:$mimeType;base64,$imageBase64',
      'detail': 'low',
    });
  }

  Map<String, dynamic> _inputText(String text) {
    return {
      'type': 'input_text',
      'text': text,
    };
  }

  String _requiredString(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw OpenAiProxyException(
      'MISSING_${key.toUpperCase()}',
      '$key is required.',
    );
  }

  String _jsonContext(String name, Map<String, dynamic> value) {
    return '$name=${jsonEncode(value)}';
  }

  Future<String> _readLimitedBody(HttpRequest request) async {
    var total = 0;
    final chunks = <List<int>>[];
    await for (final chunk in request) {
      total += chunk.length;
      if (total > config.maxBodyBytes) {
        throw const OpenAiProxyException(
          'REQUEST_TOO_LARGE',
          'Request body is too large.',
          HttpStatus.requestEntityTooLarge,
        );
      }
      chunks.add(chunk);
    }
    return utf8.decode(chunks.expand((chunk) => chunk).toList());
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, dynamic> body, {
    int statusCode = HttpStatus.ok,
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
