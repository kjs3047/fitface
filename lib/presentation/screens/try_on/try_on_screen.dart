import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/ai_settings.dart';
import '../../../data/models/outfit_snapshot.dart';
import '../../../data/models/user_profile.dart';
import '../../../domain/profile/body_type.dart';
import '../../../providers/ai_settings_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/snapshot_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';
import '../compare/snapshot_image_viewer_screen.dart';

/// 스냅샷당 가상착장 생성 호출 상한(비용 방어).
/// 최초 1회 + 재생성 1회 = 총 2회까지만 OpenAI를 호출한다.
const kMaxTryOnRegen = 2;

class TryOnScreen extends ConsumerStatefulWidget {
  const TryOnScreen({required this.snapshotId, super.key});

  final String snapshotId;

  @override
  ConsumerState<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends ConsumerState<TryOnScreen> {
  bool _generating = false;
  bool _showOriginal = false;
  String? _error;

  OutfitSnapshot? _snapshot(List<OutfitSnapshot> snapshots) {
    for (final s in snapshots) {
      if (s.id == widget.snapshotId) {
        return s;
      }
    }
    return null;
  }

  /// 이미 결과가 있으면(=다시 생성) 비용 발생을 확인받은 뒤에만 생성한다.
  Future<void> _onGeneratePressed({
    required OutfitSnapshot snapshot,
    required UserProfile profile,
  }) async {
    if (snapshot.hasTryOnImage) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('다시 생성할까요?'),
          content: const Text(
            '이미 만든 결과가 있어요. 다시 생성하면 이미지 생성 비용이 한 번 더 발생합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('다시 생성'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    await _generate(snapshot: snapshot, profile: profile);
  }

  Future<void> _generate({
    required OutfitSnapshot snapshot,
    required UserProfile profile,
  }) async {
    final gender = profile.gender ?? defaultGender;
    final bodyType = profile.bodyType ?? defaultBodyType;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final prompt = _buildPrompt(
        gender: gender,
        bodyType: bodyType,
        profile: profile,
      );
      final bytes = await ref.read(openAiTryOnServiceProvider).generate(
            clothImagePath: snapshot.rawImagePath ?? snapshot.imagePath,
            faceImagePath: profile.croppedFaceImagePath ??
                profile.originalFaceImagePath ??
                snapshot.imagePath,
            prompt: prompt,
          );
      await ref.read(snapshotProvider.notifier).saveTryOnResult(
            snapshotId: snapshot.id,
            imageBytes: bytes,
            bodyType: bodyType.name,
          );
      if (mounted) {
        setState(() => _showOriginal = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  String _buildPrompt({
    required Gender gender,
    required BodyType bodyType,
    required UserProfile profile,
  }) {
    final body = bodyDescriptionForPrompt(
      gender: gender,
      bodyType: bodyType,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
    );
    return [
      'Create a realistic full-body photo of $body wearing the outfit shown '
          'in the clothing image.',
      'Keep the face identity from the face image. Natural studio lighting, '
          'plain background, front view, the person standing.',
      'This is a styling preview; do not alter the garment design or color.',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final snapshots =
        ref.watch(snapshotProvider).valueOrNull ?? const <OutfitSnapshot>[];
    final snapshot = _snapshot(snapshots);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final settings =
        ref.watch(aiSettingsProvider).valueOrNull ?? AiSettings.defaults();

    // 생성 중에는 뒤로가기를 막는다. 실수로 나가면 비용만 나가고 결과 확인이
    // 어렵기 때문이다.
    return PopScope(
      canPop: !_generating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _generating) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지를 생성하는 중이에요. 완료될 때까지 기다려 주세요.'),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.paper,
        appBar: const AppTopBar(title: '가상착장'),
        body: SafeArea(
          child: snapshot == null
              ? const Center(child: Text('스냅샷을 찾을 수 없습니다.'))
              : _buildBody(snapshot, profile, settings),
        ),
      ),
    );
  }

  Widget _buildBody(
    OutfitSnapshot snapshot,
    UserProfile? profile,
    AiSettings settings,
  ) {
    // 1) 기본정보(체형) 미등록 → 등록 유도.
    if (profile == null || !profile.hasBodyInfo) {
      return _Notice(
        icon: Icons.straighten,
        title: '먼저 기본정보가 필요해요',
        message: '가상착장에 키·몸무게·체형이 사용됩니다. 설정에서 한 번만 등록하면 됩니다.',
        actionLabel: '기본정보 등록하러 가기',
        onAction: () =>
            Navigator.pushNamed(context, RouteNames.userBasicInfo),
      );
    }

    // 2) 클라우드 게이팅.
    final cloudReady = settings.mode == AiEngineMode.openAi &&
        settings.allowCloudAnalysis &&
        (settings.openAiProxyUrl?.isNotEmpty ?? false);
    if (!cloudReady) {
      return const _Notice(
        icon: Icons.cloud_off_outlined,
        title: '클라우드 AI 모드에서 사용할 수 있어요',
        message: '설정에서 OpenAI 모드 + 클라우드 사용 동의 + 프록시 주소를 설정하세요.',
      );
    }

    // 3) 원본 프레임 없음(옛 스냅샷) → 재촬영 안내.
    if (!snapshot.hasRawImage) {
      return const _Notice(
        icon: Icons.camera_alt_outlined,
        title: '다시 촬영하면 사용할 수 있어요',
        message: '이 스냅샷은 원본 프레임이 없어 가상착장을 만들 수 없습니다. 새로 촬영해 주세요.',
      );
    }

    return _buildGenerator(snapshot, profile);
  }

  Widget _buildGenerator(OutfitSnapshot snapshot, UserProfile profile) {
    final currentBody = (profile.bodyType ?? defaultBodyType).name;
    // 캐싱: 같은 체형으로 만든 결과가 있으면 재생성 대신 그대로 보여준다.
    final hasFreshResult =
        snapshot.hasTryOnImage && snapshot.tryOnBodyType == currentBody;
    final reachedLimit = snapshot.tryOnRegenCount >= kMaxTryOnRegen;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _BodyInfoSummary(profile: profile),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _openViewer(snapshot),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreview(snapshot),
                  // 확대해서 볼 수 있다는 힌트.
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (snapshot.hasTryOnImage)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('원본 보기'),
              Switch(
                value: _showOriginal,
                onChanged: (v) => setState(() => _showOriginal = v),
              ),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        if (_generating)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('이미지를 생성하는 중이에요 (10~30초)'),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: reachedLimit && !hasFreshResult
                  ? null
                  : () => _onGeneratePressed(snapshot: snapshot, profile: profile),
              icon: const Icon(Icons.checkroom_outlined),
              label: Text(
                snapshot.hasTryOnImage ? '다시 생성' : '가상착장 만들기',
              ),
            ),
          ),
        if (reachedLimit) ...[
          const SizedBox(height: 8),
          Text(
            '이 스냅샷의 생성 횟수를 모두 사용했어요. 저장된 결과를 확인하세요.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'AI가 생성한 이미지로 실제 착용 모습과 다를 수 있습니다.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedInk,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 현재 미리보기에 표시 중인 이미지 경로(원본 토글 상태 반영).
  String _currentPreviewPath(OutfitSnapshot snapshot) {
    final showOriginal = _showOriginal || !snapshot.hasTryOnImage;
    return showOriginal
        ? (snapshot.rawImagePath ?? snapshot.imagePath)
        : snapshot.tryOnImagePath!;
  }

  void _openViewer(OutfitSnapshot snapshot) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SnapshotImageViewerScreen(
          imagePath: _currentPreviewPath(snapshot),
        ),
      ),
    );
  }

  Widget _buildPreview(OutfitSnapshot snapshot) {
    final path = _currentPreviewPath(snapshot);
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      key: ValueKey(path),
    );
  }
}

class _BodyInfoSummary extends StatelessWidget {
  const _BodyInfoSummary({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final gender = profile.gender ?? defaultGender;
    final bodyType = profile.bodyType ?? defaultBodyType;
    final parts = <String>[gender.label, bodyType.label];
    if (profile.heightCm != null) {
      parts.add('${profile.heightCm}cm');
    }
    if (profile.weightKg != null) {
      parts.add('${profile.weightKg}kg');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(parts.join(' · '))),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.mutedInk),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
