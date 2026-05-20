import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../data/models/image_feature_summary.dart';

class ImageFeatureExtractor {
  const ImageFeatureExtractor();

  Future<ImageFeatureSummary> extract(String imagePath) async {
    if (imagePath.isEmpty) {
      throw const FormatException('분석할 이미지 경로가 없습니다.');
    }
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('이미지를 읽을 수 없습니다.');
    }

    final source = decoded.width > 96 || decoded.height > 96
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 96 : null,
            height: decoded.height > decoded.width ? 96 : null,
          )
        : decoded;

    var count = 0;
    var rSum = 0.0;
    var gSum = 0.0;
    var bSum = 0.0;
    var brightnessSum = 0.0;
    var saturationSum = 0.0;
    var warmCoolSum = 0.0;
    final brightnessValues = <double>[];
    final buckets = <String, _ColorBucket>{};

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final alpha = pixel.a.toInt();
        if (alpha <= 10) {
          continue;
        }
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final normalizedR = r / 255;
        final normalizedG = g / 255;
        final normalizedB = b / 255;
        final brightness =
            0.2126 * normalizedR + 0.7152 * normalizedG + 0.0722 * normalizedB;
        final maxChannel = math.max(
          normalizedR,
          math.max(normalizedG, normalizedB),
        );
        final minChannel = math.min(
          normalizedR,
          math.min(normalizedG, normalizedB),
        );
        final saturation =
            maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
        final warmCool = (normalizedR - normalizedB).clamp(-1.0, 1.0);

        count++;
        rSum += r;
        gSum += g;
        bSum += b;
        brightnessSum += brightness;
        saturationSum += saturation;
        warmCoolSum += warmCool;
        brightnessValues.add(brightness);

        final qr = (r ~/ 32) * 32 + 16;
        final qg = (g ~/ 32) * 32 + 16;
        final qb = (b ~/ 32) * 32 + 16;
        final key = _hex(qr, qg, qb);
        buckets.putIfAbsent(key, () => _ColorBucket(key)).add();
      }
    }

    if (count == 0) {
      throw const FormatException('분석할 수 있는 이미지 픽셀이 없습니다.');
    }

    final averageBrightness = brightnessSum / count;
    final contrast = _standardDeviation(brightnessValues, averageBrightness);
    final averageSaturation = saturationSum / count;
    final warmCoolBias = warmCoolSum / count;
    final dominantColors = buckets.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final hints = <String>[];
    if (averageBrightness < 0.28) {
      hints.add('어두운 이미지');
    } else if (averageBrightness > 0.86) {
      hints.add('밝기가 높은 이미지');
    }
    if (contrast < 0.08) {
      hints.add('대비가 낮은 이미지');
    }
    if (averageSaturation < 0.12) {
      hints.add('채도가 낮은 이미지');
    } else if (averageSaturation > 0.72) {
      hints.add('채도가 강한 이미지');
    }

    return ImageFeatureSummary(
      averageHex: _hex(
        (rSum / count).round(),
        (gSum / count).round(),
        (bSum / count).round(),
      ),
      dominantColors: dominantColors
          .take(5)
          .map(
            (bucket) => ColorSwatchSummary(
              hex: bucket.hex,
              ratio: bucket.count / count,
            ),
          )
          .toList(),
      brightness: averageBrightness.clamp(0.0, 1.0),
      contrast: contrast.clamp(0.0, 1.0),
      saturation: averageSaturation.clamp(0.0, 1.0),
      warmCoolBias: warmCoolBias.clamp(-1.0, 1.0),
      imageQualityHints: hints,
    );
  }

  static double _standardDeviation(List<double> values, double mean) {
    if (values.isEmpty) {
      return 0;
    }
    final variance = values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  static String _hex(int r, int g, int b) {
    final safeR = r.clamp(0, 255).toInt();
    final safeG = g.clamp(0, 255).toInt();
    final safeB = b.clamp(0, 255).toInt();
    return '#'
            '${safeR.toRadixString(16).padLeft(2, '0')}'
            '${safeG.toRadixString(16).padLeft(2, '0')}'
            '${safeB.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
}

class _ColorBucket {
  _ColorBucket(this.hex);

  final String hex;
  int count = 0;

  void add() {
    count++;
  }
}
