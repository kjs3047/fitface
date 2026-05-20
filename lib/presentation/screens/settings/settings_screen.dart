import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/snapshot_provider.dart';
import '../../../providers/storage_provider.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/app_top_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearSnapshots(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: '후보 전체 삭제',
      message: '저장된 후보 이미지와 메모를 모두 삭제할까요?',
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(snapshotProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('후보를 모두 삭제했습니다.')),
      );
    }
  }

  Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: '앱 데이터 초기화',
      message: '얼굴 사진, 후보 이미지, 메모, 오버레이 설정을 모두 삭제할까요?',
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(localFileStorageProvider).clearAll();
    await ref.read(userProfileProvider.notifier).load();
    await ref.read(snapshotProvider.notifier).load();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.onboarding,
        (route) => false,
      );
    }
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AppTopBar(title: '설정'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.tune_outlined),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '앱 설정',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '얼굴 이미지와 저장 후보를 관리합니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '개인정보 안내',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '얼굴 사진과 스냅샷은 기본적으로 기기 내부에만 저장됩니다. '
                      'MVP에서는 서버 전송, 로그인, 클라우드 동기화를 사용하지 않습니다.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.face_retouching_natural,
                    title: '얼굴 사진 변경',
                    subtitle: '촬영하거나 갤러리에서 다시 등록',
                    onTap: () => Navigator.pushNamed(
                      context,
                      RouteNames.faceRegister,
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    title: '저장된 후보 전체 삭제',
                    subtitle: '후보 이미지와 메모 삭제',
                    onTap: () => _clearSnapshots(context, ref),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.restart_alt,
                    title: '앱 데이터 초기화',
                    subtitle: '얼굴, 후보, 메모, 오버레이 설정 초기화',
                    danger: true,
                    onTap: () => _resetApp(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: '퍼스널 컬러 확인',
                    subtitle: '현재 등록된 얼굴 이미지 기준',
                    onTap: () => Navigator.pushNamed(
                      context,
                      RouteNames.personalColor,
                    ),
                  ),
                  const Divider(height: 1),
                  const _SettingsTile(
                    icon: Icons.info_outline,
                    title: '앱 버전',
                    subtitle: '0.1.0',
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Theme.of(context).colorScheme.error : AppTheme.ink;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
