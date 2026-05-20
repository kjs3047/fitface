import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/primary_button.dart';

class FaceRegisterScreen extends ConsumerStatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  ConsumerState<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends ConsumerState<FaceRegisterScreen> {
  final _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _isPicking = true);
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (!mounted) {
        return;
      }
      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 선택이 취소되었습니다.')),
        );
        return;
      }
      Navigator.pushNamed(context, RouteNames.faceCrop, arguments: image.path);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진을 불러오지 못했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _openCameraGuide() {
    Navigator.pushNamed(context, RouteNames.faceCapture);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final currentFacePath = _currentFacePath(profile);

    return Scaffold(
      appBar: const AppTopBar(title: '얼굴 사진 등록'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '얼굴 기준 만들기',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 10),
            Text(
              '정면 얼굴을 가이드 라인에 맞춰 등록하면 매장 카메라 위에 자연스럽게 겹쳐볼 수 있습니다.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            _FaceReferencePanel(imagePath: currentFacePath),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _isPicking ? '불러오는 중' : '카메라로 촬영',
              icon: Icons.photo_camera_outlined,
              onPressed: _isPicking ? null : _openCameraGuide,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isPicking ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('갤러리에서 선택'),
            ),
            const SizedBox(height: 18),
            _GuideCard(),
          ],
        ),
      ),
    );
  }

  String? _currentFacePath(UserProfile? profile) {
    return profile?.croppedFaceImagePath ??
        profile?.originalFaceImagePath ??
        profile?.overlayFaceImagePath;
  }
}

class _FaceReferencePanel extends StatelessWidget {
  const _FaceReferencePanel({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    return SizedBox(
      height: path == null ? 220 : 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.cameraBlack,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path == null)
              const _EmptyFaceReference()
            else
              _CurrentFaceReference(imagePath: path),
            const Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: _GuideLine(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentFaceReference extends StatelessWidget {
  const _CurrentFaceReference({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 52, 14, 66),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B1916),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Center(
                child: Image.file(
                  File(imagePath),
                  key: const Key('face-register-current-face-image'),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const _EmptyFaceReference();
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                '현재 등록된 얼굴',
                key: const Key('face-register-current-face-label'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFaceReference extends StatelessWidget {
  const _EmptyFaceReference();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 122,
        height: 170,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          Icons.face_retouching_natural,
          size: 56,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      '정면을 바라본 사진을 사용하세요.',
      '촬영/자르기 화면의 실루엣 선에 얼굴 윤곽과 목 중심을 맞추세요.',
      '너무 가까이 찍혀 선에 맞지 않으면 한 걸음 떨어져 다시 촬영하세요.',
      '너무 어둡거나 강한 색조명이 있는 사진은 피하세요.',
      '옷과 배경은 저장 전에 투명 처리됩니다.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사진 가이드', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '얼굴과 목을 선 안에 맞춰주세요',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
              ),
        ),
      ),
    );
  }
}
