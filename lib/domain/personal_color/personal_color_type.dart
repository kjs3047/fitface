/// 퍼스널 컬러 12계절 유형의 단일 소스(single source of truth).
///
/// 12계절 체계는 4계절(봄/여름/가을/겨울)을 온도(웜/쿨) × 명도(라이트/딥) ×
/// 채도(브라이트/뮤트) 축으로 각각 3세부로 나눈 국제 통용 표준이다.
/// 한국 통용 명칭("봄 라이트")에 온도를 명시해 자기설명적으로 고정한다.
///
/// 이 파일은 앱 측(프롬프트/rule-based/Gemma 매핑)이 공유하는 기준이다.
/// 프록시(`openai_proxy_server.dart`)는 Dart 코드를 공유하지 않으므로 동일한
/// 목록을 그쪽에도 별도로 두되, 문자열은 반드시 [PersonalColorType.all]과
/// 글자까지 일치시켜야 한다.
library;

/// 분류 축 — 온도.
enum ColorTemperature { warm, cool }

/// 분류 축 — 명도(밝기).
enum ColorValue { light, medium, deep }

/// 분류 축 — 채도(맑음/탁함).
enum ColorChroma { bright, neutral, muted }

/// 12계절 유형 하나의 정의.
class PersonalColorType {
  const PersonalColorType({
    required this.label,
    required this.season,
    required this.temperature,
    required this.value,
    required this.chroma,
    required this.recommendedColors,
    required this.avoidColors,
  });

  /// 저장·표시·프롬프트·스키마에 쓰이는 정식 문자열. 절대 변형 금지.
  final String label;

  /// 계절(봄/여름/가을/겨울).
  final String season;

  final ColorTemperature temperature;
  final ColorValue value;
  final ColorChroma chroma;

  /// rule-based 폴백에서 쓰는 유형별 추천 색상 5종.
  final List<String> recommendedColors;

  /// rule-based 폴백에서 쓰는 유형별 주의 색상 5종.
  final List<String> avoidColors;

  bool get isWarm => temperature == ColorTemperature.warm;
  bool get isCool => temperature == ColorTemperature.cool;
}

/// 12유형 정의 목록. 프록시 enum / 프롬프트 기준표 / rule-based 팔레트가
/// 모두 이 목록을 단일 출처로 삼는다.
class PersonalColorTypes {
  const PersonalColorTypes._();

  // ── 봄 (웜) ──────────────────────────────────────────────
  static const springLight = PersonalColorType(
    label: '봄 웜 라이트',
    season: '봄',
    temperature: ColorTemperature.warm,
    value: ColorValue.light,
    chroma: ColorChroma.neutral,
    recommendedColors: ['크림', '피치', '라이트 코랄', '애플 그린', '라이트 카멜'],
    avoidColors: ['차콜', '블랙', '버건디', '쿨 퍼플', '네이비'],
  );
  static const springTrue = PersonalColorType(
    label: '봄 웜 트루',
    season: '봄',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.neutral,
    recommendedColors: ['코랄', '웜 옐로', '라이트 카멜', '오렌지 레드', '골드 베이지'],
    avoidColors: ['차콜', '블랙', '쿨 그레이', '아이스 블루', '버건디'],
  );
  static const springBright = PersonalColorType(
    label: '봄 웜 브라이트',
    season: '봄',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.bright,
    recommendedColors: ['쨍한 코랄', '클리어 옐로', '터쿼이즈', '비비드 그린', '오렌지'],
    avoidColors: ['탁한 베이지', '먹색', '더스티 핑크', '뮤트 그레이', '카키'],
  );

  // ── 여름 (쿨) ────────────────────────────────────────────
  static const summerLight = PersonalColorType(
    label: '여름 쿨 라이트',
    season: '여름',
    temperature: ColorTemperature.cool,
    value: ColorValue.light,
    chroma: ColorChroma.neutral,
    recommendedColors: ['라벤더', '파스텔 핑크', '연한 블루', '아이보리', '라이트 그레이'],
    avoidColors: ['강한 오렌지', '카멜', '머스터드', '딥 브라운', '토마토 레드'],
  );
  static const summerTrue = PersonalColorType(
    label: '여름 쿨 트루',
    season: '여름',
    temperature: ColorTemperature.cool,
    value: ColorValue.medium,
    chroma: ColorChroma.neutral,
    recommendedColors: ['로즈 핑크', '아이스 블루', '소프트 블루', '실버 그레이', '쿨 민트'],
    avoidColors: ['강한 오렌지', '머스터드', '카멜', '브릭', '웜 베이지'],
  );
  static const summerMuted = PersonalColorType(
    label: '여름 쿨 뮤트',
    season: '여름',
    temperature: ColorTemperature.cool,
    value: ColorValue.medium,
    chroma: ColorChroma.muted,
    recommendedColors: ['더스티 로즈', '파우더 블루', '뮤트 라벤더', '소프트 그레이', '세이지'],
    avoidColors: ['쨍한 코랄', '비비드 옐로', '네온 핑크', '클리어 오렌지', '쨍한 화이트'],
  );

  // ── 가을 (웜) ────────────────────────────────────────────
  static const autumnMuted = PersonalColorType(
    label: '가을 웜 뮤트',
    season: '가을',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.muted,
    recommendedColors: ['올리브', '웜 베이지', '머스터드', '테라코타', '세이지 그린'],
    avoidColors: ['아이스 블루', '형광 핑크', '실버 그레이', '쿨 민트', '쨍한 화이트'],
  );
  static const autumnTrue = PersonalColorType(
    label: '가을 웜 트루',
    season: '가을',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.neutral,
    recommendedColors: ['카멜', '브릭', '머스터드', '올리브', '웜 브라운'],
    avoidColors: ['아이스 블루', '형광 핑크', '쿨 그레이', '파스텔 라벤더', '쨍한 화이트'],
  );
  static const autumnDeep = PersonalColorType(
    label: '가을 웜 딥',
    season: '가을',
    temperature: ColorTemperature.warm,
    value: ColorValue.deep,
    chroma: ColorChroma.neutral,
    recommendedColors: ['다크 브라운', '딥 올리브', '버건디 브라운', '포레스트 그린', '딥 카멜'],
    avoidColors: ['파스텔 핑크', '아이스 블루', '라이트 그레이', '쿨 민트', '연한 라벤더'],
  );

  // ── 겨울 (쿨) ────────────────────────────────────────────
  static const winterBright = PersonalColorType(
    label: '겨울 쿨 브라이트',
    season: '겨울',
    temperature: ColorTemperature.cool,
    value: ColorValue.medium,
    chroma: ColorChroma.bright,
    recommendedColors: ['쿨 레드', '퓨어 화이트', '비비드 마젠타', '클리어 블루', '에메랄드'],
    avoidColors: ['탁한 베이지', '머스터드', '카키 브라운', '웜 오렌지', '흐린 파스텔'],
  );
  static const winterTrue = PersonalColorType(
    label: '겨울 쿨 트루',
    season: '겨울',
    temperature: ColorTemperature.cool,
    value: ColorValue.deep,
    chroma: ColorChroma.neutral,
    recommendedColors: ['네이비', '쿨 레드', '퓨어 화이트', '로열 블루', '쿨 핑크'],
    avoidColors: ['웜 베이지', '머스터드', '카멜', '테라코타', '올리브'],
  );
  static const winterDeep = PersonalColorType(
    label: '겨울 쿨 딥',
    season: '겨울',
    temperature: ColorTemperature.cool,
    value: ColorValue.deep,
    chroma: ColorChroma.muted,
    recommendedColors: ['차콜', '블랙', '버건디', '딥 네이비', '와인'],
    avoidColors: ['웜 베이지', '머스터드', '카멜', '피치', '연한 파스텔'],
  );

  /// 12유형 전체 — 선언 순서 = 계절 순서.
  static const List<PersonalColorType> all = [
    springLight,
    springTrue,
    springBright,
    summerLight,
    summerTrue,
    summerMuted,
    autumnMuted,
    autumnTrue,
    autumnDeep,
    winterBright,
    winterTrue,
    winterDeep,
  ];

  /// 정식 라벨 문자열 12개.
  static List<String> get labels => all.map((t) => t.label).toList();

  /// 라벨로 유형을 찾는다. 목록 밖이면 null.
  static PersonalColorType? byLabel(String label) {
    final normalized = label.trim();
    for (final type in all) {
      if (type.label == normalized) {
        return type;
      }
    }
    return null;
  }

  /// 임의 문자열을 12유형 중 하나로 매핑한다.
  ///
  /// 정확히 일치하면 그 유형, 아니면 문자열에 담긴 키워드(계절/톤/명도/채도)로
  /// 가장 가까운 유형을 추정한다. 추정 불가 시 null.
  /// Gemma 등 스키마 강제가 안 되는 경로의 응답 정규화에 쓴다.
  static PersonalColorType? closestTo(String raw) {
    final exact = byLabel(raw);
    if (exact != null) {
      return exact;
    }
    // 영문 키워드는 소문자로만 비교하므로 입력을 소문자화한다(한글은 영향 없음).
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }

    // 계절 추정 — 한/영 키워드.
    String? season;
    if (_containsAny(text, ['봄', 'spring'])) {
      season = '봄';
    } else if (_containsAny(text, ['여름', 'summer'])) {
      season = '여름';
    } else if (_containsAny(text, ['가을', 'autumn', 'fall'])) {
      season = '가을';
    } else if (_containsAny(text, ['겨울', 'winter'])) {
      season = '겨울';
    }

    // 온도 추정 — 계절을 모를 때만 사용.
    if (season == null) {
      if (_containsAny(text, ['웜', 'warm'])) {
        // 명도로 봄/가을 결정.
        season = _containsAny(text, ['딥', 'deep', 'dark', '어두', '뮤트', 'muted'])
            ? '가을'
            : '봄';
      } else if (_containsAny(text, ['쿨', 'cool'])) {
        season = _containsAny(text, ['딥', 'deep', 'dark', '어두', '브라이트', 'bright'])
            ? '겨울'
            : '여름';
      }
    }
    if (season == null) {
      return null;
    }

    final candidates = all.where((t) => t.season == season).toList();
    if (candidates.length == 1) {
      return candidates.first;
    }

    // 세부 축 키워드로 좁힌다.
    final wantsLight = _containsAny(text, ['라이트', 'light', '밝']);
    final wantsDeep = _containsAny(text, ['딥', 'deep', 'dark', '어두']);
    final wantsBright = _containsAny(text, ['브라이트', 'bright', '쨍', '비비드', 'vivid']);
    final wantsMuted = _containsAny(text, ['뮤트', 'muted', '소프트', 'soft', '탁']);

    PersonalColorType? scored;
    var best = -1;
    for (final t in candidates) {
      var score = 0;
      if (wantsLight && t.value == ColorValue.light) score++;
      if (wantsDeep && t.value == ColorValue.deep) score++;
      if (wantsBright && t.chroma == ColorChroma.bright) score++;
      if (wantsMuted && t.chroma == ColorChroma.muted) score++;
      if (score > best) {
        best = score;
        scored = t;
      }
    }
    // 세부 단서가 전혀 없으면 계절의 '트루'를 기본값으로.
    if (best <= 0) {
      return candidates.firstWhere(
        (t) => t.value == ColorValue.medium && t.chroma == ColorChroma.neutral,
        orElse: () => candidates.first,
      );
    }
    return scored;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  /// 색상 통계 축으로 12유형 중 하나를 고른다(rule-based 폴백 분류기).
  ///
  /// - [warmCoolBias] > [warmThreshold]  → 웜(봄/가을), < -[warmThreshold] → 쿨(여름/겨울)
  ///   사이면 뉴트럴: 12계절에는 뉴트럴이 없으므로 명도/채도로 가장 가까운
  ///   계절에 배정한다.
  /// - [brightness]로 계절 내 라이트/트루/딥, [saturation]으로 브라이트/뮤트를 가른다.
  ///
  /// 임계값은 기존 6유형 분기(warmCoolBias 0.08, brightness 0.55,
  /// saturation 0.38)를 12분해에 맞춰 확장한 값이다.
  static PersonalColorType classify({
    required double warmCoolBias,
    required double brightness,
    required double saturation,
    double warmThreshold = 0.08,
  }) {
    final isWarm = warmCoolBias > warmThreshold;
    final isCool = warmCoolBias < -warmThreshold;

    if (isWarm) {
      // 봄(고명도) vs 가을(저명도).
      if (brightness >= 0.55) {
        // 봄: 채도 높으면 브라이트, 아주 밝으면 라이트, 나머지 트루.
        if (saturation >= 0.55) return springBright;
        if (brightness >= 0.7) return springLight;
        return springTrue;
      }
      // 가을: 아주 어두우면 딥, 저채도면 뮤트, 나머지 트루.
      if (brightness < 0.4) return autumnDeep;
      if (saturation < 0.32) return autumnMuted;
      return autumnTrue;
    }

    if (isCool) {
      // 여름(고명도) vs 겨울(저명도).
      if (brightness >= 0.55) {
        // 여름: 아주 밝으면 라이트, 저채도면 뮤트, 나머지 트루.
        if (brightness >= 0.7) return summerLight;
        if (saturation < 0.32) return summerMuted;
        return summerTrue;
      }
      // 겨울: 고채도면 브라이트, 아주 어두우면 딥, 나머지 트루.
      if (saturation >= 0.55) return winterBright;
      if (brightness < 0.4) return winterDeep;
      return winterTrue;
    }

    // 뉴트럴 — 명도/채도로 가장 가까운 계절에 배정.
    // 밝고 맑음 → 봄, 밝고 탁함 → 여름, 어둡고 탁함 → 가을, 어둡고 맑음 → 겨울.
    if (brightness >= 0.55) {
      return saturation >= 0.4 ? springTrue : summerTrue;
    }
    return saturation >= 0.4 ? winterTrue : autumnTrue;
  }
}
