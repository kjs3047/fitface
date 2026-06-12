import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../routes/route_names.dart';

/// AI 판단 결과에 퍼스널 컬러가 반영되지 않았을 때, 더 정확한 진단을 위해
/// 퍼스널 컬러 설정을 안내하는 배너. [visible]이 false면 아무것도 그리지 않는다.
///
/// 잉크 스플래시용 추가 레이아웃 패스를 피하려고 InkWell/Material 대신
/// GestureDetector를 사용한다(여러 리스트/카드 안에 안전하게 중첩되도록).
class PersonalColorHintBanner extends StatelessWidget {
  const PersonalColorHintBanner({
    required this.visible,
    this.onTap,
    super.key,
  });

  final bool visible;

  /// 누르면 퍼스널 컬러 화면으로 이동. null이면 기본 동작(라우트 이동)을 쓴다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: onTap ??
          () => Navigator.pushNamed(context, RouteNames.personalColor),
      child: DecoratedBox(
        key: const Key('personal-color-hint-banner'),
        decoration: BoxDecoration(
          color: AppTheme.bronzeSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(
                Icons.palette_outlined,
                size: 20,
                color: AppTheme.bronze,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '퍼스널 컬러를 설정하면 더 정확한 진단이 가능합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
