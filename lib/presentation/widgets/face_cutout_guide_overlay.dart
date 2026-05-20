import 'package:flutter/material.dart';

import '../../core/utils/crop_geometry.dart';
import '../../core/utils/face_cutout_geometry.dart';

class FaceCutoutGuideOverlay extends StatelessWidget {
  const FaceCutoutGuideOverlay({
    this.guideRect,
    this.dimOutsideGuide = true,
    super.key,
  });

  final Rect? guideRect;
  final bool dimOutsideGuide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final rect = guideRect ?? CropGeometry.buildGuideRect(size);
        return CustomPaint(
          painter: _FaceCutoutGuidePainter(
            guideRect: rect,
            dimOutsideGuide: dimOutsideGuide,
            guideColor: colorScheme.primary,
            boxColor: Colors.white,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _FaceCutoutGuidePainter extends CustomPainter {
  const _FaceCutoutGuidePainter({
    required this.guideRect,
    required this.dimOutsideGuide,
    required this.guideColor,
    required this.boxColor,
  });

  final Rect guideRect;
  final bool dimOutsideGuide;
  final Color guideColor;
  final Color boxColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (dimOutsideGuide) {
      _paintOutsideDim(canvas, size);
    }

    final boxPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(8)),
      boxPaint,
    );

    final cutoutPath = FaceCutoutGeometry.cutoutPathFor(guideRect);
    final fillPaint = Paint()
      ..color = guideColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(cutoutPath, fillPaint);
    canvas.drawPath(cutoutPath, strokePaint);

    final centerPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(guideRect.center.dx, guideRect.top + guideRect.height * 0.12),
      Offset(guideRect.center.dx, guideRect.bottom - guideRect.height * 0.08),
      centerPaint,
    );
  }

  void _paintOutsideDim(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.46);
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, guideRect.top), dimPaint)
      ..drawRect(
        Rect.fromLTRB(0, guideRect.bottom, size.width, size.height),
        dimPaint,
      )
      ..drawRect(
        Rect.fromLTRB(0, guideRect.top, guideRect.left, guideRect.bottom),
        dimPaint,
      )
      ..drawRect(
        Rect.fromLTRB(
          guideRect.right,
          guideRect.top,
          size.width,
          guideRect.bottom,
        ),
        dimPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _FaceCutoutGuidePainter oldDelegate) {
    return oldDelegate.guideRect != guideRect ||
        oldDelegate.dimOutsideGuide != dimOutsideGuide ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.boxColor != boxColor;
  }
}
