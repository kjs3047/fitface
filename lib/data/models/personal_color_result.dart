class PersonalColorResult {
  const PersonalColorResult({
    required this.type,
    required this.recommendedColors,
    required this.avoidColors,
    required this.comment,
  });

  final String type;
  final List<String> recommendedColors;
  final List<String> avoidColors;
  final String comment;

  PersonalColorResult copyWith({
    String? type,
    List<String>? recommendedColors,
    List<String>? avoidColors,
    String? comment,
  }) {
    return PersonalColorResult(
      type: type ?? this.type,
      recommendedColors: recommendedColors ?? this.recommendedColors,
      avoidColors: avoidColors ?? this.avoidColors,
      comment: comment ?? this.comment,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'recommendedColors': recommendedColors,
      'avoidColors': avoidColors,
      'comment': comment,
    };
  }

  factory PersonalColorResult.fromJson(Map<String, dynamic> json) {
    return PersonalColorResult(
      type: json['type'] as String,
      recommendedColors:
          ((json['recommendedColors'] as List<dynamic>?) ?? const [])
              .map((value) => value as String)
              .toList(),
      avoidColors: ((json['avoidColors'] as List<dynamic>?) ?? const [])
          .map((value) => value as String)
          .toList(),
      comment: json['comment'] as String,
    );
  }
}
