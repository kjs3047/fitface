import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../routes/route_names.dart';
import '../../widgets/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heroHeight =
                (constraints.maxHeight * 0.46).clamp(300.0, 410.0).toDouble();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SizedBox(
                  height: heroHeight,
                  child: _OnboardingHero(),
                ),
                const SizedBox(height: 24),
                Text(
                  'FitFace',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '옷매장에서 실제 옷을 비추고, 내 얼굴을 겹쳐 어울림을 확인해보세요. '
                  '정면 얼굴 사진을 등록하면 매장 카메라 위에 얼굴을 띄울 수 있습니다.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: '내 얼굴 등록하기',
                  icon: Icons.add_a_photo_outlined,
                  onPressed: () {
                    Navigator.pushNamed(context, RouteNames.faceRegister);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.cameraBlack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RackPainter()),
          ),
          Align(
            alignment: const Alignment(0, -0.04),
            child: Container(
              width: 136,
              height: 184,
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.face_retouching_natural,
                    size: 52,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '얼굴 기준',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Row(
              children: [
                const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '카메라 위에 바로 겹쳐보기',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rail = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.18),
      Offset(size.width * 0.88, size.height * 0.18),
      rail,
    );

    // 에디토리얼 무채색: 옷걸이를 흑백 톤으로 정돈해 색은 사진에만 남긴다.
    final colors = [
      const Color(0xFFEDEDEA),
      const Color(0xFFBFBFBA),
      const Color(0xFF6E6E69),
      const Color(0xFF9A9A95),
    ];
    for (var i = 0; i < 4; i++) {
      final left = size.width * (0.16 + i * 0.17);
      final top = size.height * 0.22;
      final width = size.width * 0.14;
      final height = size.height * (0.55 + (i.isEven ? 0.04 : -0.02));
      final paint = Paint()..color = colors[i].withValues(alpha: 0.76);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          const Radius.circular(8),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
