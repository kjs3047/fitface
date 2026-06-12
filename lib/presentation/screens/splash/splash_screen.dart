import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/file_utils.dart';
import '../../../providers/user_profile_provider.dart';
import '../../routes/route_names.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    await ref.read(userProfileProvider.notifier).load();
    final profile = ref.read(userProfileProvider).value;
    final hasFace = await FileUtils.exists(profile?.overlayFaceImagePath);
    if (!mounted) {
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      hasFace ? RouteNames.cameraMatch : RouteNames.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EDITORIAL FITTING',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 14),
            Text(
              'FitFace',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '얼굴을 겹쳐보는 피팅 도구',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
