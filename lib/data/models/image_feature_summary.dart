class ColorSwatchSummary {
  const ColorSwatchSummary({
    required this.hex,
    required this.ratio,
  });

  final String hex;
  final double ratio;

  Map<String, dynamic> toJson() {
    return {
      'hex': hex,
      'ratio': ratio,
    };
  }

  factory ColorSwatchSummary.fromJson(Map<String, dynamic> json) {
    return ColorSwatchSummary(
      hex: json['hex'] as String,
      ratio: (json['ratio'] as num).toDouble(),
    );
  }
}

class ImageFeatureSummary {
  const ImageFeatureSummary({
    required this.averageHex,
    required this.dominantColors,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.warmCoolBias,
    this.imageQualityHints = const [],
  });

  final String averageHex;
  final List<ColorSwatchSummary> dominantColors;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmCoolBias;
  final List<String> imageQualityHints;

  bool get hasImageQualityRisk => imageQualityHints.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'averageHex': averageHex,
      'dominantColors': dominantColors.map((color) => color.toJson()).toList(),
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'warmCoolBias': warmCoolBias,
      'imageQualityHints': imageQualityHints,
    };
  }

  factory ImageFeatureSummary.fromJson(Map<String, dynamic> json) {
    return ImageFeatureSummary(
      averageHex: json['averageHex'] as String,
      dominantColors: ((json['dominantColors'] as List<dynamic>?) ?? const [])
          .map(
            (value) =>
                ColorSwatchSummary.fromJson(value as Map<String, dynamic>),
          )
          .toList(),
      brightness: (json['brightness'] as num).toDouble(),
      contrast: (json['contrast'] as num).toDouble(),
      saturation: (json['saturation'] as num).toDouble(),
      warmCoolBias: (json['warmCoolBias'] as num).toDouble(),
      imageQualityHints:
          ((json['imageQualityHints'] as List<dynamic>?) ?? const [])
              .map((value) => value as String)
              .toList(),
    );
  }

  String toPromptText() {
    final colors = dominantColors
        .map((color) => '${color.hex} ${(color.ratio * 100).round()}%')
        .join(', ');
    final tone = warmCoolBias > 0.08
        ? 'warm'
        : warmCoolBias < -0.08
            ? 'cool'
            : 'neutral';
    final hints =
        imageQualityHints.isEmpty ? 'none' : imageQualityHints.join(', ');
    return 'average=$averageHex; dominant=[$colors]; '
        'brightness=${brightness.toStringAsFixed(2)}; '
        'contrast=${contrast.toStringAsFixed(2)}; '
        'saturation=${saturation.toStringAsFixed(2)}; '
        'warmCoolBias=${warmCoolBias.toStringAsFixed(2)} ($tone); '
        'qualityHints=$hints';
  }
}
