import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

import '../../data/models/ai_analysis_result.dart';
import '../../data/models/ai_settings.dart';
import 'ai_engine_adapter.dart';

class OpenAiAnalysisService implements AiEngineAdapter {
  OpenAiAnalysisService({
    required AiSettings settings,
    HttpClient? client,
  })  : _settings = settings,
        _client = client ?? HttpClient();

  final AiSettings _settings;
  final HttpClient _client;

  @override
  String get engineName => 'openAi';

  @override
  Future<AiAnalysisResult> analyzeSnapshot(
    AiSnapshotAnalysisRequest request,
  ) async {
    final response = await _postJson(
      '/ai/snapshot/analyze',
      {
        'snapshotId': request.snapshot.id,
        'imageBase64': request.includeImage
            ? await _readSanitizedImageBase64(request.snapshot.imagePath)
            : null,
        'imageMimeType': request.includeImage ? 'image/jpeg' : null,
        'memo': request.snapshot.memo,
        'prompt': request.prompt,
        'features': request.features?.toJson(),
        'mode': request.includeImage ? 'imageAndFeatures' : 'featuresOnly',
      },
    );
    return _resultFromResponse(response, request.includeImage);
  }

  @override
  Future<AiAnalysisResult> compareSnapshots(
    AiCompareAnalysisRequest request,
  ) async {
    final images = <Map<String, dynamic>>[];
    if (request.includeImages) {
      for (final snapshot in request.snapshots) {
        images.add({
          'snapshotId': snapshot.id,
          'imageBase64': await _readSanitizedImageBase64(snapshot.imagePath),
          'imageMimeType': 'image/jpeg',
        });
      }
    }
    final response = await _postJson(
      '/ai/snapshots/compare',
      {
        'snapshotIds':
            request.snapshots.map((snapshot) => snapshot.id).toList(),
        'images': images,
        'prompt': request.prompt,
        'featuresBySnapshotId': request.featuresBySnapshotId.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'mode': request.includeImages ? 'imageAndFeatures' : 'featuresOnly',
      },
    );
    return _resultFromResponse(response, request.includeImages);
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

  AiAnalysisResult _resultFromResponse(
    Map<String, dynamic> response,
    bool usedImage,
  ) {
    final rawResult = (response['result'] as Map<String, dynamic>?) ?? response;
    return AiAnalysisResult.fromJson(rawResult).copyWith(
      engine: engineName,
      analysisMode: usedImage ? 'imageAndFeatures' : 'featuresOnly',
      createdAt: DateTime.now(),
    );
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
