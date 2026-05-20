import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/utils/date_utils.dart';
import '../../core/utils/face_cutout_geometry.dart';
import 'background_removal_service.dart';

class FaceNeckCutoutService implements BackgroundRemovalService {
  @override
  Future<String> removeBackground(String inputImagePath) async {
    final inputFile = File(inputImagePath);
    final bytes = await inputFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('이미지를 읽을 수 없습니다.');
    }

    final output = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 4,
    );

    for (var y = 0; y < decoded.height; y++) {
      final ny = decoded.height == 1 ? 0.0 : y / (decoded.height - 1);
      for (var x = 0; x < decoded.width; x++) {
        final nx = decoded.width == 1 ? 0.0 : x / (decoded.width - 1);
        final pixel = decoded.getPixel(x, y);
        final alpha = FaceCutoutGeometry.maskAlpha(nx, ny);
        output.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          alpha,
        );
      }
    }

    final outputPath = p.join(
      inputFile.parent.path,
      'face_neck_cutout_${FitFaceDateUtils.fileStamp(DateTime.now())}.png',
    );
    await File(outputPath).writeAsBytes(img.encodePng(output), flush: true);
    return outputPath;
  }
}
