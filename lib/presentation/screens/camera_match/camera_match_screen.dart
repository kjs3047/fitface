import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_settings.dart';
import '../../../data/models/outfit_snapshot.dart';
import '../../../providers/ai_settings_provider.dart';
import '../../../providers/camera_overlay_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/snapshot_provider.dart';
import '../../../providers/storage_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/ai_processing_status.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/face_overlay_widget.dart';
import '../../widgets/opacity_slider.dart';

class CameraMatchScreen extends ConsumerStatefulWidget {
  const CameraMatchScreen({super.key});

  @override
  ConsumerState<CameraMatchScreen> createState() => _CameraMatchScreenState();
}

class _CameraMatchScreenState extends ConsumerState<CameraMatchScreen> {
  final _captureKey = GlobalKey();
  CameraController? _controller;
  bool _isInitializing = true;
  bool _permissionDenied = false;
  bool _isSaving = false;
  bool _isAiPreviewing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _permissionDenied = false;
      _error = null;
    });
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        setState(() {
          _permissionDenied = true;
          _isInitializing = false;
        });
        return;
      }
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await _controller?.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _runAiPreview() async {
    if (_isAiPreviewing) {
      return;
    }
    setState(() => _isAiPreviewing = true);
    OutfitSnapshot? preview;
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('캡처 영역을 찾을 수 없습니다.');
      }
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('AI 판단용 이미지를 만들 수 없습니다.');
      }
      preview = await ref
          .read(snapshotProvider.notifier)
          .createSnapshotFromBytes(data.buffer.asUint8List());
      final result = await ref.read(aiAnalysisServiceProvider).analyzeSnapshot(
            preview,
          );
      await ref.read(localFileStorageProvider).deleteFileSafely(
            preview.imagePath,
          );
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'AI 판단',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text('${result.score.clamp(0, 100)}/100'),
                ],
              ),
              const SizedBox(height: 10),
              Text(result.comment),
              if (result.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in result.tags) Chip(label: Text(tag)),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    } catch (error) {
      if (preview != null) {
        await ref.read(localFileStorageProvider).deleteFileSafely(
              preview.imagePath,
            );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 판단에 실패했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAiPreviewing = false);
      }
    }
  }

  Future<void> _saveSnapshot() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    OutfitSnapshot? pending;
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('캡처 영역을 찾을 수 없습니다.');
      }
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('캡처 이미지를 만들 수 없습니다.');
      }
      final notifier = ref.read(snapshotProvider.notifier);
      pending =
          await notifier.createSnapshotFromBytes(data.buffer.asUint8List());
      await notifier.load();
      final current =
          ref.read(snapshotProvider).value ?? const <OutfitSnapshot>[];
      if (current.length >= 3) {
        final replaceIndex = await _selectReplacement(current);
        if (replaceIndex == null) {
          await ref
              .read(localFileStorageProvider)
              .deleteFileSafely(pending.imagePath);
          return;
        }
        await notifier.replace(replaceIndex, pending);
      } else {
        await notifier.add(pending);
      }
      if (!mounted) {
        return;
      }
      await _showSavedDialog(pending);
    } catch (error) {
      if (pending != null) {
        await ref
            .read(localFileStorageProvider)
            .deleteFileSafely(pending.imagePath);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스냅샷 저장에 실패했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<int?> _selectReplacement(List<OutfitSnapshot> snapshots) {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('후보 교체'),
        content: const Text('후보는 최대 3개까지 저장됩니다. 교체할 후보를 선택해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          for (var index = 0; index < snapshots.length; index++)
            TextButton(
              onPressed: () => Navigator.pop(context, index),
              child: Text('후보 ${index + 1}'),
            ),
        ],
      ),
    );
  }

  Future<void> _showSavedDialog(OutfitSnapshot snapshot) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('저장 완료'),
        content: const Text('현재 비교 화면을 후보로 저장했습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(
                context,
                RouteNames.snapshotDetail,
                arguments: snapshot.id,
              );
            },
            child: const Text('메모 추가'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, RouteNames.compare);
            },
            child: const Text('비교 보기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final overlay = ref.watch(cameraOverlayProvider);
    final aiSettings =
        ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();
    final overlayPath = profile?.overlayFaceImagePath;

    return Scaffold(
      appBar: AppTopBar(
        title: 'FitFace',
        showBack: false,
        actions: [
          IconButton(
            tooltip: '비교',
            onPressed: () => Navigator.pushNamed(context, RouteNames.compare),
            icon: const Icon(Icons.compare_outlined),
          ),
          IconButton(
            tooltip: '설정',
            onPressed: () => Navigator.pushNamed(context, RouteNames.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: overlayPath == null
            ? EmptyState(
                title: '등록된 얼굴 사진이 없습니다.',
                message: '얼굴 사진을 먼저 등록하면 카메라 위에 오버레이할 수 있습니다.',
                action: FilledButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    RouteNames.faceRegister,
                  ),
                  child: const Text('얼굴 등록하기'),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildCameraPreview(),
                              FaceOverlayWidget(
                                imagePath: overlayPath,
                                state: overlay,
                                onMove: ref
                                    .read(cameraOverlayProvider.notifier)
                                    .moveBy,
                                onTransform: (position, scale) {
                                  ref
                                      .read(cameraOverlayProvider.notifier)
                                      .setTransform(
                                        position: position,
                                        scale: scale,
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _BottomControls(
                    opacity: overlay.opacity,
                    aiMode: aiSettings.mode,
                    isSaving: _isSaving,
                    isAiPreviewing: _isAiPreviewing,
                    onOpacityChanged:
                        ref.read(cameraOverlayProvider.notifier).setOpacity,
                    onReset: ref.read(cameraOverlayProvider.notifier).reset,
                    onAi: _runAiPreview,
                    onSnap: _saveSnapshot,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_permissionDenied) {
      return const EmptyState(
        title: '카메라 권한이 필요합니다.',
        message: '매장 옷을 비추려면 카메라 접근을 허용해주세요.',
        icon: Icons.no_photography_outlined,
        action: OutlinedButton(
          onPressed: openAppSettings,
          child: Text('설정 열기'),
        ),
      );
    }
    if (_isInitializing) {
      return const ColoredBox(
        color: AppTheme.cameraBlack,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return EmptyState(
        title: '카메라를 시작하지 못했습니다.',
        message: _error!,
        icon: Icons.error_outline,
        action: OutlinedButton(
          onPressed: _initializeCamera,
          child: const Text('재시도'),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return EmptyState(
        title: '카메라 준비 중',
        message: '잠시 후 다시 시도해주세요.',
        action: OutlinedButton(
          onPressed: _initializeCamera,
          child: const Text('재시도'),
        ),
      );
    }
    return ColoredBox(
      color: AppTheme.cameraBlack,
      child: Center(
        child: CameraPreview(controller),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.opacity,
    required this.aiMode,
    required this.isSaving,
    required this.isAiPreviewing,
    required this.onOpacityChanged,
    required this.onReset,
    required this.onAi,
    required this.onSnap,
  });

  final double opacity;
  final AiEngineMode aiMode;
  final bool isSaving;
  final bool isAiPreviewing;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback onReset;
  final VoidCallback onAi;
  final VoidCallback onSnap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '오버레이 조절',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: '위치 초기화',
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            const SizedBox(height: 2),
            OpacitySlider(value: opacity, onChanged: onOpacityChanged),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isAiPreviewing ? null : onAi,
                    icon: isAiPreviewing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(isAiPreviewing ? '분석 중...' : 'AI판단'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : onSnap,
                    icon: const Icon(Icons.camera_outlined),
                    label: Text(isSaving ? '저장 중' : '스냅'),
                  ),
                ),
              ],
            ),
            if (isAiPreviewing) ...[
              const SizedBox(height: 10),
              AiProcessingStatus(
                keyPrefix: 'camera-match-ai',
                mode: aiMode,
                label: 'AI 판단 중',
                localMessage: 'Local Gemma가 현재 카메라 화면 이미지와 색상 정보를 분석하고 있습니다.',
                cloudMessage: 'OpenAI 프록시 서버로 현재 화면 분석 요청을 보내고 있습니다.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
