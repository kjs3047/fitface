import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class OpacitySlider extends StatelessWidget {
  const OpacitySlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.opacity, size: 18),
            const SizedBox(width: 8),
            Text(
              '투명도',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                min: AppConstants.minOverlayOpacity,
                max: AppConstants.maxOverlayOpacity,
                value: value
                    .clamp(
                      AppConstants.minOverlayOpacity,
                      AppConstants.maxOverlayOpacity,
                    )
                    .toDouble(),
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
