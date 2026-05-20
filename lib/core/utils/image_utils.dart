import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../data/local/local_file_storage.dart';
import '../constants/storage_keys.dart';
import 'crop_geometry.dart';
import 'date_utils.dart';

class ImageUtils {
  static Future<String> cropFaceGuide({
    required String inputPath,
    required LocalFileStorage storage,
    double zoom = 1,
    double horizontal = 0,
    double vertical = 0,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('이미지를 읽을 수 없습니다.');
    }

    final safeZoom = zoom.clamp(1.0, 2.8).toDouble();
    final cropWidth = (decoded.width * 0.72 / safeZoom)
        .round()
        .clamp(1, decoded.width)
        .toInt();
    final cropHeight = (decoded.height * 0.82 / safeZoom)
        .round()
        .clamp(1, decoded.height)
        .toInt();
    final maxX = decoded.width - cropWidth;
    final maxY = decoded.height - cropHeight;
    final x = (maxX / 2 + horizontal.clamp(-1.0, 1.0) * maxX / 2)
        .round()
        .clamp(0, maxX)
        .toInt();
    final y = (maxY * 0.36 + vertical.clamp(-1.0, 1.0) * maxY / 2)
        .round()
        .clamp(0, maxY)
        .toInt();
    final cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );
    final output = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
    return storage.writeBytesToSubdir(
      StorageKeys.profileDir,
      'face_crop_${FitFaceDateUtils.fileStamp(DateTime.now())}.jpg',
      output,
    );
  }

  static Future<String> cropImageRect({
    required String inputPath,
    required LocalFileStorage storage,
    required ImageCropRect cropRect,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('이미지를 읽을 수 없습니다.');
    }

    final x = cropRect.x.clamp(0, decoded.width - 1).toInt();
    final y = cropRect.y.clamp(0, decoded.height - 1).toInt();
    final width = cropRect.width.clamp(1, decoded.width - x).toInt();
    final height = cropRect.height.clamp(1, decoded.height - y).toInt();
    final cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    final output = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
    return storage.writeBytesToSubdir(
      StorageKeys.profileDir,
      'face_crop_${FitFaceDateUtils.fileStamp(DateTime.now())}.jpg',
      output,
    );
  }
}
