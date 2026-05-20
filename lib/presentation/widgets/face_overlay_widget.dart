import 'dart:io';

import 'package:flutter/material.dart';

import '../../providers/camera_overlay_provider.dart';

class FaceOverlayWidget extends StatefulWidget {
  const FaceOverlayWidget({
    required this.imagePath,
    required this.state,
    required this.onMove,
    required this.onTransform,
    super.key,
  });

  final String imagePath;
  final CameraOverlayState state;
  final ValueChanged<Offset> onMove;
  final void Function(Offset position, double scale) onTransform;

  @override
  State<FaceOverlayWidget> createState() => _FaceOverlayWidgetState();
}

class _FaceOverlayWidgetState extends State<FaceOverlayWidget> {
  late Offset _startPosition;
  late double _startScale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.3),
      child: GestureDetector(
        onScaleStart: (_) {
          _startPosition = widget.state.position;
          _startScale = widget.state.scale;
        },
        onScaleUpdate: (details) {
          if (details.pointerCount <= 1) {
            widget.onMove(details.focalPointDelta);
            return;
          }
          widget.onTransform(
            _startPosition + details.focalPointDelta,
            _startScale * details.scale,
          );
        },
        child: Transform.translate(
          offset: widget.state.position,
          child: Transform.scale(
            scale: widget.state.scale,
            child: Opacity(
              opacity: widget.state.opacity,
              child: Image.file(
                File(widget.imagePath),
                width: 180,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('얼굴 이미지를 불러올 수 없습니다.'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
