import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OpenAiProxyConfig {
  const OpenAiProxyConfig({
    required this.apiKey,
    this.model = 'gpt-5.4-mini',
    this.maxBodyBytes = 12 * 1024 * 1024,
    this.maxImages = 3,
  });

  factory OpenAiProxyConfig.fromEnvironment(Map<String, String> env) {
    final apiKey = env['OPENAI_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const OpenAiProxyException(
        'MISSING_OPENAI_API_KEY',
        'OPENAI_API_KEY is required.',
        HttpStatus.internalServerError,
      );
    }
    return OpenAiProxyConfig(
      apiKey: apiKey,
      model: env['OPENAI_MODEL']?.trim().isNotEmpty == true
          ? env['OPENAI_MODEL']!.trim()
          : 'gpt-5.4-mini',
      maxBodyBytes: int.tryParse(env['FITFACE_PROXY_MAX_BODY_BYTES'] ?? '') ??
          12 * 1024 * 1024,
      maxImages: int.tryParse(env['FITFACE_PROXY_MAX_IMAGES'] ?? '') ?? 3,
    );
  }

  final String apiKey;
  final String model;
  final int maxBodyBytes;
  final int maxImages;
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

class HttpOpenAiResponsesClient implements OpenAiResponsesClient {
  HttpOpenAiResponsesClient({
    required String apiKey,
    HttpClient? httpClient,
    Uri? endpoint,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? HttpClient(),
        _endpoint =
            endpoint ?? Uri.parse('https://api.openai.com/v1/responses');

  final String _apiKey;
  final HttpClient _httpClient;
  final Uri _endpoint;

  @override
  Future<Map<String, dynamic>> createResponse(Map<String, dynamic> body) async {
    final request = await _httpClient.postUrl(_endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiProxyException(
        'OPENAI_REQUEST_FAILED',
        'OpenAI request failed: ${response.statusCode} $text',
        HttpStatus.badGateway,
      );
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }
}

class FitFaceOpenAiProxy {
  FitFaceOpenAiProxy({
    required this.config,
    OpenAiResponsesClient? client,
  }) : _client = client ?? HttpOpenAiResponsesClient(apiKey: config.apiKey);

  final OpenAiProxyConfig config;
  final OpenAiResponsesClient _client;

  Future<HttpServer> start({
    Object address = '127.0.0.1',
    int port = 8787,
  }) async {
    final server = await HttpServer.bind(address, port);
    unawaited(
      server.forEach((request) async {
        await handleHttpRequest(request);
      }),
    );
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
    return {'result': _decodeStructuredResult(openAiResponse)};
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
    return {'result': _decodeStructuredResult(openAiResponse)};
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
        'candidateScores': {
          'type': 'object',
          'additionalProperties': {'type': 'integer'},
        },
        'candidateComments': {
          'type': 'object',
          'additionalProperties': {'type': 'string'},
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
        'candidateScores',
        'candidateComments',
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
        'type': {'type': 'string'},
        'recommendedColors': _stringArraySchema(maxItems: 5),
        'avoidColors': _stringArraySchema(maxItems: 5),
        'comment': {'type': 'string'},
      },
      'required': ['type', 'recommendedColors', 'avoidColors', 'comment'],
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
