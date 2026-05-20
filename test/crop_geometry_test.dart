import 'dart:ui';

import 'package:fitface/core/utils/crop_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source crop follows the same guide rect used by the viewport', () {
    final layout = CropGeometry.buildLayout(
      viewportSize: const Size(300, 500),
      imageSize: const Size(600, 1000),
      scale: 1,
      offset: Offset.zero,
    );

    final crop = CropGeometry.sourceRectForGuide(layout);

    expect(crop.width / crop.height, closeTo(0.72, 0.02));
    expect(crop.x, greaterThanOrEqualTo(0));
    expect(crop.y, greaterThanOrEqualTo(0));
    expect(crop.x + crop.width, lessThanOrEqualTo(600));
    expect(crop.y + crop.height, lessThanOrEqualTo(1000));
  });

  test('source crop changes when the user moves the visible image', () {
    final centered = CropGeometry.buildLayout(
      viewportSize: const Size(300, 500),
      imageSize: const Size(600, 1000),
      scale: 1.4,
      offset: Offset.zero,
    );
    final moved = CropGeometry.buildLayout(
      viewportSize: const Size(300, 500),
      imageSize: const Size(600, 1000),
      scale: 1.4,
      offset: const Offset(30, -40),
    );

    final centeredCrop = CropGeometry.sourceRectForGuide(centered);
    final movedCrop = CropGeometry.sourceRectForGuide(moved);

    expect(movedCrop.x, isNot(centeredCrop.x));
    expect(movedCrop.y, isNot(centeredCrop.y));
  });

  test('offset is clamped so the guide remains covered by the image', () {
    final layout = CropGeometry.buildLayout(
      viewportSize: const Size(300, 500),
      imageSize: const Size(600, 1000),
      scale: 1.2,
      offset: const Offset(10000, -10000),
    );

    expect(layout.imageRect.left, lessThanOrEqualTo(layout.guideRect.left));
    expect(
      layout.imageRect.right,
      greaterThanOrEqualTo(layout.guideRect.right),
    );
    expect(layout.imageRect.top, lessThanOrEqualTo(layout.guideRect.top));
    expect(
      layout.imageRect.bottom,
      greaterThanOrEqualTo(layout.guideRect.bottom),
    );
  });
}
