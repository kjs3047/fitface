import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/crop_geometry.dart';
import '../../../core/utils/image_utils.dart';
import '../../../providers/storage_provider.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/face_cutout_guide_overlay.dart';
import '../../widgets/primary_button.dart';

class FaceCropScreen extends ConsumerStatefulWidget {
  const FaceCropScreen({
    required this.imagePath,
    super.key,
  });

  final String imagePath;

  @override
  ConsumerState<FaceCropScreen> createState() => _FaceCropScreenState();
}

class _FaceCropScreenState extends ConsumerState<FaceCropScreen> {
  bool _isCropping = false;
  bool _imageLoadFailed = false;
  Size? _imageSize;
  CropLayout? _lastLayout;

  double _scale = 1;
  Offset _offset = Offset.zero;
  late double _startScale;
  late Offset _startOffset;
  late Offset _startFocalPoint;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(covariant FaceCropScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _scale = 1;
      _offset = Offset.zero;
      _imageSize = null;
      _imageLoadFailed = false;
      _loadImageSize();
    }
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw const FormatException('이미지를 읽을 수 없습니다.');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _imageSize = Size(
          decoded.width.toDouble(),
          decoded.height.toDouble(),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _imageLoadFailed = true);
      }
    }
  }

  Future<void> _crop() async {
    final layout = _lastLayout;
    if (layout == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 배치를 아직 계산하지 못했습니다.')),
      );
      return;
    }

    setState(() => _isCropping = true);
    try {
      final storage = ref.read(localFileStorageProvider);
      final croppedPath = await ImageUtils.cropImageRect(
        inputPath: widget.imagePath,
        storage: storage,
        cropRect: CropGeometry.sourceRectForGuide(layout),
      );
      if (!mounted) {
        return;
      }
      Navigator.pushNamed(
        context,
        RouteNames.facePreview,
        arguments: FacePreviewArgs(
          originalImagePath: widget.imagePath,
          croppedImagePath: croppedPath,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('크롭 파일을 만들지 못했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  void _syncLayout(CropLayout layout) {
    _lastLayout = layout;
    final scaleChanged = (_scale - layout.scale).abs() > 0.001;
    final offsetChanged = (_offset - layout.offset).distance > 0.5;
    if (!scaleChanged && !offsetChanged) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scale = layout.scale;
        _offset = layout.offset;
      });
    });
  }

  void _applyTransform({
    required Size viewportSize,
    required Size imageSize,
    required double scale,
    required Offset offset,
  }) {
    final minScale = CropGeometry.minimumScale(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    final safeScale = scale
        .clamp(
          minScale,
          CropGeometry.maxScale,
        )
        .toDouble();
    setState(() {
      _scale = safeScale;
      _offset = CropGeometry.clampOffset(
        viewportSize: viewportSize,
        imageSize: imageSize,
        scale: safeScale,
        offset: offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: '얼굴~목 맞추기'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: _buildCropViewport(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropViewport() {
    if (_imageLoadFailed) {
      return const Card(
        child: Center(child: Text('이미지를 불러올 수 없습니다.')),
      );
    }
    final imageSize = _imageSize;
    if (imageSize == null) {
      return const Card(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final layout = CropGeometry.buildLayout(
          viewportSize: viewportSize,
          imageSize: imageSize,
          scale: _scale,
          offset: _offset,
        );
        _syncLayout(layout);

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppTheme.cameraBlack),
            child: GestureDetector(
              key: const Key('face-crop-viewport'),
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _startScale = _scale;
                _startOffset = _offset;
                _startFocalPoint = details.focalPoint;
              },
              onScaleUpdate: (details) {
                _applyTransform(
                  viewportSize: viewportSize,
                  imageSize: imageSize,
                  scale: _startScale * details.scale,
                  offset: _startOffset + details.focalPoint - _startFocalPoint,
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Transform.translate(
                      offset: layout.offset,
                      child: Transform.scale(
                        scale: layout.scale,
                        child: SizedBox(
                          width: layout.baseImageSize.width,
                          height: layout.baseImageSize.height,
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FaceCutoutGuideOverlay(
                        key: const Key('face-crop-cutout-guide'),
                        guideRect: layout.guideRect,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    final layout = _lastLayout;
    final imageSize = _imageSize;
    final canAdjust = layout != null && imageSize != null;
    final horizontal =
        layout == null ? 0.0 : CropGeometry.normalizedHorizontal(layout);
    final vertical =
        layout == null ? 0.0 : CropGeometry.normalizedVertical(layout);
    final minScale = layout?.minScale ?? 1.0;
    final safeScale = _scale.clamp(minScale, CropGeometry.maxScale).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '사진 위치 조정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '실루엣 선에 얼굴 윤곽과 목 중심이 맞도록 사진을 움직여주세요. '
              '너무 가까워 선에 맞지 않으면 다시 촬영하는 게 좋습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _CropSlider(
              icon: Icons.zoom_in_outlined,
              label: '확대',
              value: safeScale,
              min: minScale,
              max: CropGeometry.maxScale,
              onChanged: !canAdjust
                  ? null
                  : (value) => _applyTransform(
                        viewportSize: layout.viewportSize,
                        imageSize: imageSize,
                        scale: value,
                        offset: _offset,
                      ),
            ),
            _CropSlider(
              icon: Icons.swap_horiz,
              label: '좌우',
              value: horizontal,
              min: -1,
              max: 1,
              onChanged: !canAdjust
                  ? null
                  : (value) {
                      final offset = Offset(
                        layout.horizontalRange * value,
                        _offset.dy,
                      );
                      _applyTransform(
                        viewportSize: layout.viewportSize,
                        imageSize: imageSize,
                        scale: _scale,
                        offset: offset,
                      );
                    },
            ),
            _CropSlider(
              icon: Icons.swap_vert,
              label: '상하',
              value: vertical,
              min: -1,
              max: 1,
              onChanged: !canAdjust
                  ? null
                  : (value) {
                      final offset = Offset(
                        _offset.dx,
                        layout.verticalRange * value,
                      );
                      _applyTransform(
                        viewportSize: layout.viewportSize,
                        imageSize: imageSize,
                        scale: _scale,
                        offset: offset,
                      );
                    },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _isCropping ? '처리 중' : '다음',
              icon: Icons.check,
              onPressed: _isCropping || !canAdjust ? null : _crop,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isCropping
                  ? null
                  : () => Navigator.pushReplacementNamed(
                        context,
                        RouteNames.faceRegister,
                      ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('다시 선택'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropSlider extends StatelessWidget {
  const _CropSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.mutedInk),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
