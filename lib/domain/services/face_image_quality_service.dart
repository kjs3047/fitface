import 'dart:io';

import 'package:image/image.dart' as img;

import '../../data/models/image_feature_summary.dart';
import 'image_feature_extractor.dart';

class FaceImageQualityResult {
  const FaceImageQualityResult({
    required this.status,
    required this.summary,
    required this.hints,
    required this.features,
  });

  final FaceImageQualityStatus status;
  final String summary;
  final List<String> hints;
  final ImageFeatureSummary features;

  bool get hasWarnings => hints.isNotEmpty;
}

enum FaceImageQualityStatus {
  good,
  warning,
}

class FaceImageQualityService {
  const FaceImageQualityService({
    ImageFeatureExtractor featureExtractor = const ImageFeatureExtractor(),
  }) : _featureExtractor = featureExtractor;

  final ImageFeatureExtractor _featureExtractor;

  Future<FaceImageQualityResult> evaluate(String imagePath) async {
    final features = await _featureExtractor.extract(imagePath);
    final decoded = img.decodeImage(await File(imagePath).readAsBytes());
    if (decoded == null) {
      throw const FormatException('얼굴 이미지 품질을 확인할 수 없습니다.');
    }

    final hints = <String>{...features.imageQualityHints};
    if (features.brightness < 0.32) {
      hints.add('얼굴 이미지가 어두워 AI 분석 신뢰도가 낮아질 수 있습니다.');
    }
    if (features.contrast < 0.07) {
      hints.add('흐림 또는 낮은 대비가 감지되었습니다.');
    }
    if (features.saturation > 0.7 || features.warmCoolBias.abs() > 0.42) {
      hints.add('강한 색조명 영향이 있을 수 있습니다.');
    }
    if (!_isGuideRatio(decoded.width, decoded.height)) {
      hints.add('실루엣 가이드 비율과 다를 수 있어 정면 정렬을 다시 확인하세요.');
    }

    return FaceImageQualityResult(
      status: hints.isEmpty
          ? FaceImageQualityStatus.good
          : FaceImageQualityStatus.warning,
      summary: hints.isEmpty
          ? '밝기와 대비가 안정적입니다.'
          : '사진은 사용할 수 있지만 AI 분석 결과에 영향을 줄 수 있는 요소가 있습니다.',
      hints: hints.toList(),
      features: features,
    );
  }

  bool _isGuideRatio(int width, int height) {
    if (width <= 0 || height <= 0) {
      return false;
    }
    final ratio = width / height;
    return ratio >= 0.45 && ratio <= 1.05;
  }
}
