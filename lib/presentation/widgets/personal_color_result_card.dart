import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/personal_color_result.dart';

class PersonalColorResultCard extends StatelessWidget {
  const PersonalColorResultCard({
    required this.result,
    super.key,
  });

  final PersonalColorResult result;

  @override
  Widget build(BuildContext context) {
    final recommendedSwatches =
        result.recommendedColors.map(_ColorSwatchInfo.fromName).toList();
    final avoidSwatches =
        result.avoidColors.map(_ColorSwatchInfo.fromName).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '진단 결과',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Text(
              result.type,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 10),
            Text(
              result.comment,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _RecommendedTreemap(
              swatches: recommendedSwatches.take(3).toList(),
            ),
            const SizedBox(height: 14),
            _PaletteRows(
              recommended: recommendedSwatches.take(5).toList(),
              avoid: avoidSwatches.take(5).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedTreemap extends StatelessWidget {
  const _RecommendedTreemap({required this.swatches});

  final List<_ColorSwatchInfo> swatches;

  @override
  Widget build(BuildContext context) {
    if (swatches.isEmpty) {
      return const SizedBox.shrink();
    }

    final signature = swatches.first;
    final supporting = swatches.skip(1).take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('추천 색상 조합', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: 192,
          child: supporting.isEmpty
              ? _TreemapTile(
                  key: const Key('personal-color-signature-tile'),
                  swatch: signature,
                  label: '시그니처',
                  isSignature: true,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _TreemapTile(
                        key: const Key('personal-color-signature-tile'),
                        swatch: signature,
                        label: '시그니처',
                        isSignature: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = 0;
                              index < supporting.length;
                              index++) ...[
                            Expanded(
                              child: _TreemapTile(
                                key: Key(
                                  'personal-color-treemap-tile-${index + 2}',
                                ),
                                swatch: supporting[index],
                                label: '추천 ${index + 2}',
                              ),
                            ),
                            if (index != supporting.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TreemapTile extends StatelessWidget {
  const _TreemapTile({
    required this.swatch,
    required this.label,
    this.isSignature = false,
    super.key,
  });

  final _ColorSwatchInfo swatch;
  final String label;
  final bool isSignature;

  @override
  Widget build(BuildContext context) {
    final foreground = _foregroundForColor(swatch.color);
    final labelBackground = foreground.withValues(alpha: 0.12);
    final padding = isSignature ? 13.0 : 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = (constraints.maxWidth - padding * 2)
            .clamp(1.0, double.infinity)
            .toDouble();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: swatch.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.ink.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: labelBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSignature ? 8 : 6,
                      vertical: isSignature ? 5 : 3,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: foreground,
                          ),
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              swatch.name,
                              maxLines: isSignature ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: (isSignature
                                      ? Theme.of(context).textTheme.titleLarge
                                      : Theme.of(context).textTheme.labelLarge)
                                  ?.copyWith(color: foreground),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              swatch.hex,
                              key: Key(
                                'personal-color-treemap-code-${swatch.name}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: foreground.withValues(alpha: 0.76),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaletteRows extends StatelessWidget {
  const _PaletteRows({
    required this.recommended,
    required this.avoid,
  });

  final List<_ColorSwatchInfo> recommended;
  final List<_ColorSwatchInfo> avoid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PaletteStrip(
          key: const Key('personal-color-palette-recommended'),
          title: '추천 컬러',
          groupKey: 'recommended',
          swatches: recommended,
        ),
        const SizedBox(height: 10),
        _PaletteStrip(
          key: const Key('personal-color-palette-avoid'),
          title: '주의 색상',
          groupKey: 'avoid',
          swatches: avoid,
        ),
      ],
    );
  }
}

class _PaletteStrip extends StatelessWidget {
  const _PaletteStrip({
    required this.title,
    required this.groupKey,
    required this.swatches,
    super.key,
  });

  final String title;
  final String groupKey;
  final List<_ColorSwatchInfo> swatches;

  @override
  Widget build(BuildContext context) {
    if (swatches.isEmpty) {
      return const SizedBox.shrink();
    }

    const spacing = 6.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth =
                ((constraints.maxWidth - spacing * 4) / 5).clamp(44.0, 92.0);
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final swatch in swatches)
                  SizedBox(
                    width: itemWidth.toDouble(),
                    child: _CompactSwatch(
                      swatch: swatch,
                      groupKey: groupKey,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CompactSwatch extends StatelessWidget {
  const _CompactSwatch({
    required this.swatch,
    required this.groupKey,
  });

  final _ColorSwatchInfo swatch;
  final String groupKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: swatch.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.ink.withValues(alpha: 0.12)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          swatch.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.ink,
              ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            swatch.hex,
            key: Key('personal-color-palette-code-$groupKey-${swatch.name}'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.mutedInk,
                ),
          ),
        ),
      ],
    );
  }
}

class _ColorSwatchInfo {
  const _ColorSwatchInfo({
    required this.name,
    required this.color,
    required this.hex,
  });

  final String name;
  final Color color;
  final String hex;

  factory _ColorSwatchInfo.fromName(String name) {
    final normalized = name.replaceAll(' ', '');
    var hex = '#ECE6DD';
    for (final entry in _colorHexByName.entries) {
      if (normalized.contains(entry.key)) {
        hex = entry.value;
        break;
      }
    }
    return _ColorSwatchInfo(
      name: name,
      color: _parseHex(hex),
      hex: hex,
    );
  }

  static Color _parseHex(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}

Color _foregroundForColor(Color color) {
  final brightness = ThemeData.estimateBrightnessForColor(color);
  return brightness == Brightness.dark ? Colors.white : AppTheme.ink;
}

const _colorHexByName = {
  '라벤더': '#B8A9E6',
  '소프트블루': '#9DB7D5',
  '블루': '#9DB7D5',
  '로즈핑크': '#D89AAE',
  '핑크': '#D89AAE',
  '오렌지': '#F26A21',
  '브라운': '#7A5B47',
  '옐로': '#DFFF00',
  '노랑': '#DFFF00',
  '레드': '#C83E3A',
  '그린': '#6FA67A',
  '민트': '#9ED8C3',
  '베이지': '#D7C3A4',
  '화이트': '#F7F4EE',
  '블랙': '#171412',
  '그레이': '#8D8D88',
  '네이비': '#2F415E',
};
