import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/camera_overlay_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/primary_button.dart';

class FacePreviewScreen extends ConsumerStatefulWidget {
  const FacePreviewScreen({
    required this.args,
    super.key,
  });

  final FacePreviewArgs args;

  @override
  ConsumerState<FacePreviewScreen> createState() => _FacePreviewScreenState();
}

class _FacePreviewScreenState extends ConsumerState<FacePreviewScreen> {
  bool _isSaving = false;
  bool _isPreparing = true;
  String? _overlayPath;
  String? _prepareError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCutout());
  }

  Future<void> _prepareCutout() async {
    setState(() {
      _isPreparing = true;
      _prepareError = null;
    });
    try {
      final overlayPath = await ref
          .read(backgroundRemovalServiceProvider)
          .removeBackground(widget.args.croppedImagePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _overlayPath = overlayPath;
        _isPreparing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _prepareError = error.toString();
        _isPreparing = false;
      });
    }
  }

  Future<void> _save() async {
    final overlayPath = _overlayPath;
    if (overlayPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('누끼 결과가 아직 준비되지 않았습니다.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(userProfileProvider.notifier).saveFace(
            originalFaceImagePath: widget.args.originalImagePath,
            croppedFaceImagePath: widget.args.croppedImagePath,
            overlayFaceImagePath: overlayPath,
          );
      await ref.read(cameraOverlayProvider.notifier).reset();
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.cameraMatch,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('얼굴 이미지를 저장하지 못했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: '얼굴 미리보기'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: CustomPaint(
                      painter: _CheckerPainter(),
                      child: _buildPreview(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '누끼 미리보기',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '자르기 화면의 실루엣 기준으로 얼굴과 목 중심부만 남긴 누끼 결과입니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: _isPreparing
                            ? '누끼 처리 중'
                            : _isSaving
                                ? '저장 중'
                                : '이 사진 사용하기',
                        icon: Icons.check_circle_outline,
                        onPressed:
                            _isSaving || _isPreparing || _prepareError != null
                                ? null
                                : _save,
                      ),
                      if (_prepareError != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _prepareCutout,
                          icon: const Icon(Icons.refresh),
                          label: const Text('누끼 다시 처리'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.crop_outlined),
                        label: const Text('다시 자르기'),
                      ),
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  RouteNames.faceRegister,
                                  ModalRoute.withName(RouteNames.onboarding),
                                ),
                        child: const Text('다시 선택'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_isPreparing) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _prepareError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '누끼 처리에 실패했습니다.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final overlayPath = _overlayPath;
    if (overlayPath == null) {
      return const Center(child: Text('누끼 결과가 없습니다.'));
    }
    return Center(
      child: Image.file(
        File(overlayPath),
        fit: BoxFit.contain,
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 18.0;
    final light = Paint()..color = AppTheme.surface;
    final dark = Paint()..color = const Color(0xFFF0EAE1);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final paint =
            ((x / cell).floor() + (y / cell).floor()).isEven ? light : dark;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
