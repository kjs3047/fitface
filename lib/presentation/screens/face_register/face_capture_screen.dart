import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/storage_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/face_cutout_guide_overlay.dart';
import '../../widgets/primary_button.dart';

class FaceCaptureScreen extends ConsumerStatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _cameraError;
  int _cameraInitToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  // surface 초기화 전에 dispose하면 camera_android_camerax가
  // releaseFlutterSurfaceTexture()에서 IllegalStateException을 던진다(검은 화면 원인).
  static Future<void> _safeDispose(CameraController? controller) async {
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (_) {
      // 초기화 미완료 컨트롤러의 dispose 예외는 무시한다.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_safeDispose(_controller));
    super.dispose();
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _cameraInitToken++;
    if (mounted) {
      setState(() {
        _controller = null;
        _isInitializing = false;
      });
    } else {
      _controller = null;
    }
    await _safeDispose(controller);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = _controller;
      if (!_isInitializing &&
          (controller == null || !controller.value.isInitialized)) {
        _initializeCamera();
      }
      return;
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      unawaited(_releaseCamera());
      return;
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) {
      return;
    }
    final initToken = ++_cameraInitToken;
    CameraController? nextController;
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });
    try {
      final permission = await Permission.camera.request();
      if (!mounted || initToken != _cameraInitToken) {
        return;
      }
      if (!permission.isGranted) {
        setState(() {
          _cameraError = permission.isPermanentlyDenied
              ? '카메라 권한이 차단되어 있습니다. Android 설정에서 FitFace의 카메라 권한을 허용해주세요.'
              : '카메라 권한이 필요합니다. 얼굴 촬영을 계속하려면 카메라 접근을 허용해주세요.';
          _isInitializing = false;
        });
        return;
      }

      final cameras = await availableCameras();
      if (!mounted || initToken != _cameraInitToken) {
        return;
      }
      if (cameras.isEmpty) {
        throw StateError('사용 가능한 카메라가 없습니다.');
      }
      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      nextController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await nextController.initialize();
      if (!mounted || initToken != _cameraInitToken) {
        await _safeDispose(nextController);
        return;
      }
      final previousController = _controller;
      final initializedController = nextController;
      nextController = null;
      setState(() {
        _controller = initializedController;
        _isInitializing = false;
      });
      // Replacing the preview already succeeded; old controller cleanup is best effort.
      await _safeDispose(previousController);
    } catch (error) {
      await _safeDispose(nextController);
      if (!mounted) {
        return;
      }
      if (initToken != _cameraInitToken) {
        return;
      }
      setState(() {
        _cameraError = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final picture = await controller.takePicture();
      final storage = ref.read(localFileStorageProvider);
      final copiedPath = await storage.copyFileToSubdir(
        picture.path,
        StorageKeys.profileDir,
        'face_camera_${FitFaceDateUtils.fileStamp(DateTime.now())}.jpg',
      );
      try {
        await File(picture.path).delete();
      } catch (_) {
        // The copied profile image is the durable source; temp cleanup is best effort.
      }
      await _releaseCamera();
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(
        context,
        RouteNames.faceCrop,
        arguments: copiedPath,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진을 촬영하지 못했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: '얼굴 촬영'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCameraPreview(),
                      const IgnorePointer(
                        child: FaceCutoutGuideOverlay(
                          key: Key('face-capture-cutout-guide'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '실루엣 선에 얼굴 윤곽과 목 중심을 맞춘 뒤 촬영하세요.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '너무 가까우면 한 걸음 떨어져 다시 맞추는 게 좋습니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: _isCapturing ? '촬영 중' : '촬영하기',
                        icon: Icons.photo_camera_outlined,
                        onPressed: _isInitializing ||
                                _isCapturing ||
                                _cameraError != null
                            ? null
                            : _capture,
                      ),
                      if (_cameraError != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _initializeCamera,
                          icon: const Icon(Icons.refresh),
                          label: const Text('카메라 다시 연결'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final error = _cameraError;
    if (error != null) {
      return ColoredBox(
        color: AppTheme.cameraBlack,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '카메라를 사용할 수 없습니다.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (_isInitializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(
        color: AppTheme.cameraBlack,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return ColoredBox(
      color: AppTheme.cameraBlack,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
