class OverlayPreset {
  const OverlayPreset({
    required this.id,
    required this.positionX,
    required this.positionY,
    required this.scale,
    required this.opacity,
    required this.updatedAt,
  });

  final String id;
  final double positionX;
  final double positionY;
  final double scale;
  final double opacity;
  final DateTime updatedAt;

  OverlayPreset copyWith({
    String? id,
    double? positionX,
    double? positionY,
    double? scale,
    double? opacity,
    DateTime? updatedAt,
  }) {
    return OverlayPreset(
      id: id ?? this.id,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'positionX': positionX,
      'positionY': positionY,
      'scale': scale,
      'opacity': opacity,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OverlayPreset.fromJson(Map<String, dynamic> json) {
    return OverlayPreset(
      id: json['id'] as String,
      positionX: (json['positionX'] as num).toDouble(),
      positionY: (json['positionY'] as num).toDouble(),
      scale: (json['scale'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
