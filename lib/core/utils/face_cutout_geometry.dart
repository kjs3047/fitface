import 'dart:math' as math;
import 'dart:ui';

class FaceCutoutGeometry {
  static const faceCenterX = 0.5;
  static const faceCenterY = 0.32;
  static const faceRadiusX = 0.37;
  static const faceRadiusY = 0.34;
  static const faceFeather = 0.16;

  static const neckTop = 0.50;
  static const neckBottom = 0.724;
  static const neckTopHalfWidth = 0.18;
  static const neckBottomHalfWidth = 0.12;
  static const neckFeather = 0.24;

  static int maskAlpha(double nx, double ny) {
    final face = _ellipseMask(
      nx: nx,
      ny: ny,
      centerX: faceCenterX,
      centerY: faceCenterY,
      radiusX: faceRadiusX,
      radiusY: faceRadiusY,
      feather: faceFeather,
    );
    final neck = _neckMask(nx, ny);
    final alpha = math.max(face, neck);
    return (alpha * 255).round().clamp(0, 255);
  }

  static Rect faceOvalRectFor(Rect bounds) {
    return Rect.fromCenter(
      center: _point(bounds, faceCenterX, faceCenterY),
      width: bounds.width * faceRadiusX * 2,
      height: bounds.height * faceRadiusY * 2,
    );
  }

  static Path neckPathFor(Rect bounds) {
    final leftTop = _point(bounds, 0.5 - neckTopHalfWidth, neckTop);
    final rightTop = _point(bounds, 0.5 + neckTopHalfWidth, neckTop);
    final rightBottom = _point(bounds, 0.5 + neckBottomHalfWidth, neckBottom);
    final leftBottom = _point(bounds, 0.5 - neckBottomHalfWidth, neckBottom);
    final bottomCenter = _point(bounds, 0.5, neckBottom);
    final topCenter = _point(bounds, 0.5, neckTop);

    return Path()
      ..moveTo(leftTop.dx, leftTop.dy)
      ..quadraticBezierTo(
        topCenter.dx - bounds.width * 0.08,
        topCenter.dy + bounds.height * 0.08,
        leftBottom.dx,
        leftBottom.dy,
      )
      ..quadraticBezierTo(
        bottomCenter.dx,
        bottomCenter.dy + bounds.height * 0.02,
        rightBottom.dx,
        rightBottom.dy,
      )
      ..quadraticBezierTo(
        topCenter.dx + bounds.width * 0.08,
        topCenter.dy + bounds.height * 0.08,
        rightTop.dx,
        rightTop.dy,
      )
      ..close();
  }

  static Path cutoutPathFor(Rect bounds) {
    return Path()
      ..addOval(faceOvalRectFor(bounds))
      ..addPath(neckPathFor(bounds), Offset.zero);
  }

  static Offset _point(Rect bounds, double nx, double ny) {
    return Offset(
      bounds.left + bounds.width * nx,
      bounds.top + bounds.height * ny,
    );
  }

  static double _ellipseMask({
    required double nx,
    required double ny,
    required double centerX,
    required double centerY,
    required double radiusX,
    required double radiusY,
    required double feather,
  }) {
    final dx = (nx - centerX) / radiusX;
    final dy = (ny - centerY) / radiusY;
    final distance = math.sqrt(dx * dx + dy * dy);
    return _smoothInside(distance, feather);
  }

  static double _neckMask(double nx, double ny) {
    if (ny < neckTop || ny > neckBottom) {
      return 0;
    }
    final t = ((ny - neckTop) / (neckBottom - neckTop)).clamp(0.0, 1.0);
    final halfWidth = _lerp(neckTopHalfWidth, neckBottomHalfWidth, t);
    final horizontal = ((nx - 0.5).abs() / halfWidth).clamp(0.0, 2.0);
    final verticalTop = ((ny - neckTop) / 0.05).clamp(0.0, 1.0);
    final verticalBottom = ((neckBottom - ny) / 0.06).clamp(0.0, 1.0);
    return _smoothInside(horizontal, neckFeather) *
        verticalTop *
        verticalBottom;
  }

  static double _smoothInside(double normalizedDistance, double feather) {
    if (normalizedDistance <= 1 - feather) {
      return 1;
    }
    if (normalizedDistance >= 1) {
      return 0;
    }
    final t = (1 - normalizedDistance) / feather;
    return t * t * (3 - 2 * t);
  }

  static double _lerp(double from, double to, double t) =>
      from + (to - from) * t;
}
