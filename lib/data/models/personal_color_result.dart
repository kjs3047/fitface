/// 색상 하나 — 이름과 (가능하면) HEX 코드 한 쌍.
///
/// AI가 색상명과 #RRGGBB HEX를 함께 반환하면 UI가 그 HEX를 그대로 칠한다.
/// 옛 응답/저장값은 이름만 있으므로 [hex]가 null일 수 있고, 이때 UI가
/// 자체 추론(이름→근사색)으로 폴백한다.
class PersonalColorSwatch {
  const PersonalColorSwatch({
    required this.name,
    this.hex,
  });

  final String name;
  final String? hex;

  PersonalColorSwatch copyWith({String? name, String? hex}) {
    return PersonalColorSwatch(
      name: name ?? this.name,
      hex: hex ?? this.hex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (hex != null) 'hex': hex,
    };
  }

  /// 객체 `{name, hex}`와 옛 문자열 `"라벤더"` 두 형태를 모두 수용한다.
  factory PersonalColorSwatch.fromJson(dynamic value) {
    if (value is String) {
      return PersonalColorSwatch(name: value);
    }
    if (value is Map) {
      final name = value['name'] as String? ?? '';
      final hex = (value['hex'] as String?)?.trim();
      return PersonalColorSwatch(
        name: name,
        hex: (hex != null && hex.isNotEmpty) ? hex : null,
      );
    }
    return const PersonalColorSwatch(name: '');
  }

  static List<PersonalColorSwatch> listFromJson(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map(PersonalColorSwatch.fromJson)
        .where((swatch) => swatch.name.isNotEmpty)
        .toList();
  }
}

class PersonalColorResult {
  const PersonalColorResult({
    required this.type,
    required this.recommendedColors,
    required this.avoidColors,
    required this.comment,
  });

  final String type;
  final List<PersonalColorSwatch> recommendedColors;
  final List<PersonalColorSwatch> avoidColors;
  final String comment;

  /// 프롬프트 주입 등 색상 "이름"만 필요한 곳을 위한 헬퍼.
  List<String> get recommendedColorNames =>
      recommendedColors.map((swatch) => swatch.name).toList();
  List<String> get avoidColorNames =>
      avoidColors.map((swatch) => swatch.name).toList();

  PersonalColorResult copyWith({
    String? type,
    List<PersonalColorSwatch>? recommendedColors,
    List<PersonalColorSwatch>? avoidColors,
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
      'recommendedColors':
          recommendedColors.map((swatch) => swatch.toJson()).toList(),
      'avoidColors': avoidColors.map((swatch) => swatch.toJson()).toList(),
      'comment': comment,
    };
  }

  factory PersonalColorResult.fromJson(Map<String, dynamic> json) {
    return PersonalColorResult(
      type: json['type'] as String,
      recommendedColors:
          PersonalColorSwatch.listFromJson(json['recommendedColors']),
      avoidColors: PersonalColorSwatch.listFromJson(json['avoidColors']),
      comment: json['comment'] as String,
    );
  }
}
