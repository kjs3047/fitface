import 'dart:ui';

class ImageCropRect {
  const ImageCropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

class CropLayout {
  const CropLayout({
    required this.viewportSize,
    required this.imageSize,
    required this.baseImageSize,
    required this.guideRect,
    required this.imageRect,
    required this.minScale,
    required this.scale,
    required this.offset,
  });

  final Size viewportSize;
  final Size imageSize;
  final Size baseImageSize;
  final Rect guideRect;
  final Rect imageRect;
  final double minScale;
  final double scale;
  final Offset offset;

  double get horizontalRange =>
      ((imageRect.width - guideRect.width) / 2).clamp(0, double.infinity);

  double get verticalRange =>
      ((imageRect.height - guideRect.height) / 2).clamp(0, double.infinity);
}

class CropGeometry {
  static const guideAspectRatio = 0.72;
  static const guideMargin = 24.0;
  static const maxScale = 4.0;

  static Size containSize({
    required Size imageSize,
    required Size viewportSize,
  }) {
    final scale = (viewportSize.width / imageSize.width)
        .clamp(0, viewportSize.height / imageSize.height);
    return Size(imageSize.width * scale, imageSize.height * scale);
  }

  static Rect buildGuideRect(Size viewportSize) {
    final maxWidth = (viewportSize.width - guideMargin * 2).clamp(
      1,
      double.infinity,
    );
    final maxHeight = (viewportSize.height - guideMargin * 2).clamp(
      1,
      double.infinity,
    );
    var height = maxHeight.toDouble();
    var width = height * guideAspectRatio;
    if (width > maxWidth) {
      width = maxWidth.toDouble();
      height = width / guideAspectRatio;
    }
    final left = (viewportSize.width - width) / 2;
    final top = (viewportSize.height - height) / 2;
    return Rect.fromLTWH(left, top, width, height);
  }

  static double minimumScale({
    required Size imageSize,
    required Size viewportSize,
  }) {
    final baseSize = containSize(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    final guide = buildGuideRect(viewportSize);
    return [
      1.0,
      guide.width / baseSize.width,
      guide.height / baseSize.height,
    ].reduce((a, b) => a > b ? a : b);
  }

  static CropLayout buildLayout({
    required Size viewportSize,
    required Size imageSize,
    required double scale,
    required Offset offset,
  }) {
    final baseSize = containSize(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    final guide = buildGuideRect(viewportSize);
    final minScale = minimumScale(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    final safeScale = scale.clamp(minScale, maxScale).toDouble();
    final safeOffset = clampOffset(
      viewportSize: viewportSize,
      imageSize: imageSize,
      scale: safeScale,
      offset: offset,
    );
    final imageWidth = baseSize.width * safeScale;
    final imageHeight = baseSize.height * safeScale;
    final center = Offset(
      viewportSize.width / 2 + safeOffset.dx,
      viewportSize.height / 2 + safeOffset.dy,
    );
    final imageRect = Rect.fromCenter(
      center: center,
      width: imageWidth,
      height: imageHeight,
    );
    return CropLayout(
      viewportSize: viewportSize,
      imageSize: imageSize,
      baseImageSize: baseSize,
      guideRect: guide,
      imageRect: imageRect,
      minScale: minScale,
      scale: safeScale,
      offset: safeOffset,
    );
  }

  static Offset clampOffset({
    required Size viewportSize,
    required Size imageSize,
    required double scale,
    required Offset offset,
  }) {
    final baseSize = containSize(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    final guide = buildGuideRect(viewportSize);
    final safeScale = scale.clamp(0.01, maxScale).toDouble();
    final horizontalRange =
        ((baseSize.width * safeScale - guide.width) / 2).clamp(
      0,
      double.infinity,
    );
    final verticalRange =
        ((baseSize.height * safeScale - guide.height) / 2).clamp(
      0,
      double.infinity,
    );
    return Offset(
      offset.dx.clamp(-horizontalRange, horizontalRange).toDouble(),
      offset.dy.clamp(-verticalRange, verticalRange).toDouble(),
    );
  }

  static Offset offsetFromNormalized({
    required CropLayout layout,
    required double horizontal,
    required double vertical,
  }) {
    return Offset(
      layout.horizontalRange * horizontal.clamp(-1.0, 1.0),
      layout.verticalRange * vertical.clamp(-1.0, 1.0),
    );
  }

  static double normalizedHorizontal(CropLayout layout) {
    if (layout.horizontalRange == 0) {
      return 0;
    }
    return (layout.offset.dx / layout.horizontalRange).clamp(-1.0, 1.0);
  }

  static double normalizedVertical(CropLayout layout) {
    if (layout.verticalRange == 0) {
      return 0;
    }
    return (layout.offset.dy / layout.verticalRange).clamp(-1.0, 1.0);
  }

  static ImageCropRect sourceRectForGuide(CropLayout layout) {
    final guide = layout.guideRect;
    final image = layout.imageRect;
    final sourceLeft =
        ((guide.left - image.left) / image.width * layout.imageSize.width)
            .clamp(0, layout.imageSize.width);
    final sourceTop =
        ((guide.top - image.top) / image.height * layout.imageSize.height)
            .clamp(0, layout.imageSize.height);
    final sourceRight =
        ((guide.right - image.left) / image.width * layout.imageSize.width)
            .clamp(0, layout.imageSize.width);
    final sourceBottom =
        ((guide.bottom - image.top) / image.height * layout.imageSize.height)
            .clamp(0, layout.imageSize.height);

    final x = sourceLeft.floor();
    final y = sourceTop.floor();
    final right =
        sourceRight.ceil().clamp(x + 1, layout.imageSize.width).toInt();
    final bottom =
        sourceBottom.ceil().clamp(y + 1, layout.imageSize.height).toInt();

    return ImageCropRect(
      x: x,
      y: y,
      width: right - x,
      height: bottom - y,
    );
  }
}
