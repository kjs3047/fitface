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

import '../../data/models/personal_color_result.dart';

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

  /// rule-based 폴백에서 쓰는 유형별 추천 색상 5종(이름 + HEX).
  final List<PersonalColorSwatch> recommendedColors;

  /// rule-based 폴백에서 쓰는 유형별 주의 색상 5종(이름 + HEX).
  final List<PersonalColorSwatch> avoidColors;

  bool get isWarm => temperature == ColorTemperature.warm;
  bool get isCool => temperature == ColorTemperature.cool;
}

/// 색상명+HEX 한 쌍을 짧게 만드는 헬퍼(팔레트 정의 가독성용).
PersonalColorSwatch _s(String name, String hex) =>
    PersonalColorSwatch(name: name, hex: hex);

/// 12유형 정의 목록. 프록시 enum / 프롬프트 기준표 / rule-based 팔레트가
/// 모두 이 목록을 단일 출처로 삼는다.
class PersonalColorTypes {
  const PersonalColorTypes._();

  // ── 봄 (웜) ──────────────────────────────────────────────
  static final springLight = PersonalColorType(
    label: '봄 웜 라이트',
    season: '봄',
    temperature: ColorTemperature.warm,
    value: ColorValue.light,
    chroma: ColorChroma.neutral,
    recommendedColors: [
      _s('크림', '#F5EBDC'),
      _s('피치', '#F6C9A8'),
      _s('라이트 코랄', '#F2A18C'),
      _s('애플 그린', '#A7C957'),
      _s('라이트 카멜', '#D2B48C'),
    ],
    avoidColors: [
      _s('차콜', '#36454F'),
      _s('블랙', '#171412'),
      _s('버건디', '#7B2D3A'),
      _s('쿨 퍼플', '#6A4C93'),
      _s('네이비', '#2F415E'),
    ],
  );
  static final springTrue = PersonalColorType(
    label: '봄 웜 트루',
    season: '봄',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.neutral,
    recommendedColors: [
      _s('코랄', '#FF7F50'),
      _s('웜 옐로', '#F2C14E'),
      _s('라이트 카멜', '#D2B48C'),
      _s('오렌지 레드', '#E8602C'),
      _s('골드 베이지', '#D9B98C'),
    ],
    avoidColors: [
      _s('차콜', '#36454F'),
      _s('블랙', '#171412'),
      _s('쿨 그레이', '#8D9BA8'),
      _s('아이스 블루', '#C6E2E9'),
      _s('버건디', '#7B2D3A'),
    ],
  );
  static final springBright = PersonalColorType(
    label: '봄 웜 브라이트',
    season: '봄',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.bright,
    recommendedColors: [
      _s('쨍한 코랄', '#FF6B53'),
      _s('클리어 옐로', '#FFD400'),
      _s('터쿼이즈', '#40E0D0'),
      _s('비비드 그린', '#3CB44B'),
      _s('오렌지', '#F26A21'),
    ],
    avoidColors: [
      _s('탁한 베이지', '#C2B49A'),
      _s('먹색', '#3A3A38'),
      _s('더스티 핑크', '#C9A0A8'),
      _s('뮤트 그레이', '#9A9A94'),
      _s('카키', '#8F8B5E'),
    ],
  );

  // ── 여름 (쿨) ────────────────────────────────────────────
  static final summerLight = PersonalColorType(
    label: '여름 쿨 라이트',
    season: '여름',
    temperature: ColorTemperature.cool,
    value: ColorValue.light,
    chroma: ColorChroma.neutral,
    recommendedColors: [
      _s('라벤더', '#B8A9E6'),
      _s('파스텔 핑크', '#F4C2D7'),
      _s('연한 블루', '#AAC9E6'),
      _s('아이보리', '#F7F0E1'),
      _s('라이트 그레이', '#CFD2D6'),
    ],
    avoidColors: [
      _s('강한 오렌지', '#F2600C'),
      _s('카멜', '#C19A6B'),
      _s('머스터드', '#D4A017'),
      _s('딥 브라운', '#5A3E2B'),
      _s('토마토 레드', '#E5503A'),
    ],
  );
  static final summerTrue = PersonalColorType(
    label: '여름 쿨 트루',
    season: '여름',
    temperature: ColorTemperature.cool,
    value: ColorValue.medium,
    chroma: ColorChroma.neutral,
    recommendedColors: [
      _s('로즈 핑크', '#D6809E'),
      _s('아이스 블루', '#C6E2E9'),
      _s('소프트 블루', '#9DB7D5'),
      _s('실버 그레이', '#B6BCC2'),
      _s('쿨 민트', '#9ED8C3'),
    ],
    avoidColors: [
      _s('강한 오렌지', '#F2600C'),
      _s('머스터드', '#D4A017'),
      _s('카멜', '#C19A6B'),
      _s('브릭', '#9C4A38'),
      _s('웜 베이지', '#D7C3A4'),
    ],
  );
  static final summerMuted = PersonalColorType(
    label: '여름 쿨 뮤트',
    season: '여름',
    temperature: ColorTemperature.cool,
    value: ColorValue.medium,
    chroma: ColorChroma.muted,
    recommendedColors: [
      _s('더스티 로즈', '#C29AA0'),
      _s('파우더 블루', '#AEC6D8'),
      _s('뮤트 라벤더', '#A99CBD'),
      _s('소프트 그레이', '#AFAFA8'),
      _s('세이지', '#A3B18A'),
    ],
    avoidColors: [
      _s('쨍한 코랄', '#FF6B53'),
      _s('비비드 옐로', '#FFE000'),
      _s('네온 핑크', '#FF4FA3'),
      _s('클리어 오렌지', '#FF7A1A'),
      _s('쨍한 화이트', '#FFFFFF'),
    ],
  );

  // ── 가을 (웜) ────────────────────────────────────────────
  static final autumnMuted = PersonalColorType(
    label: '가을 웜 뮤트',
    season: '가을',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.muted,
    recommendedColors: [
      _s('올리브', '#808000'),
      _s('웜 베이지', '#D7C3A4'),
      _s('머스터드', '#D4A017'),
      _s('테라코타', '#C66E4E'),
      _s('세이지 그린', '#9CAA87'),
    ],
    avoidColors: [
      _s('아이스 블루', '#C6E2E9'),
      _s('형광 핑크', '#FF4FA3'),
      _s('실버 그레이', '#B6BCC2'),
      _s('쿨 민트', '#9ED8C3'),
      _s('쨍한 화이트', '#FFFFFF'),
    ],
  );
  static final autumnTrue = PersonalColorType(
    label: '가을 웜 트루',
    season: '가을',
    temperature: ColorTemperature.warm,
    value: ColorValue.medium,
    chroma: ColorChroma.neutral,
    recommendedColors: [
      _s('카멜', '#C19A6B'),
      _s('브릭', '#9C4A38'),
      _s('머스터드', '#D4A017'),
      _s('올리브', '#808000'),
      _s('웜 브라운', '#7A5B47'),
    ],
    avoidColors: [
      _s('아이스 블루', '#C6E2E9'),
      _s('형광 핑크', '#FF4FA3'),
      _s('쿨 그레이', '#8D9BA8'),
      _s('파스텔 라벤더', '#D5C7EA'),
      _s('쨍한 화이트', '#FFFFFF'),
    ],
  );
  static final autumnDeep = PersonalColorType(
    label: '가을 웜 딥',
    season: '가을',
    temperature: ColorTemperature.warm,
    value: ColorValue.deep,
    chroma: ColorChroma.neutral,
    recommendedColors: [
      _s('다크 브라운', '#4A3527'),
      _s('딥 올리브', '#4F5320'),
      _s('버건디 브라운', '#5E2E2A'),
      _s('포레스트 그린', '#2D4A35'),
      _s('딥 카멜', '#9A6F45'),
    ],
    avoidColors: [
      _s('파스텔 핑크', '#F4C2D7'),
      _s('아이스 블루', '#C6E2E9'),
      _s('라이트 그레이', '#CFD2D6'),
      _s('쿨 민트', '#9ED8C3'),
      _s('연한 라벤더', '#D5C7EA'),
    ],
  );

  // ── 겨울 (쿨) ────────────────────────────────────────────
  static final winterBright = PersonalColorType(
    label: '겨울 쿨 브라이트',
    season: '겨울',
    temperature: ColorTemperature.cool,
    value: ColorValue.medium,
    chroma: ColorChroma.bright,
    recommendedColors: [
      _s('쿨 레드', '#D11A45'),
      _s('퓨어 화이트', '#FFFFFF'),
      _s('비비드 마젠타', '#D81E8C'),
      _s('클리어 블루', '#1F6FEB'),
      _s('에메랄드', '#1FA67A'),
    ],
    avoidColors: [
      _s('탁한 베이지', '#C2B49A'),
      _s('머스터드', '#D4A017'),
      _s('카키 브라운', '#766B4A'),
      _s('웜 오렌지', '#E8742C'),
      _s('흐린 파스텔', '#E4DDE8'),
    ],
  );
  static final winterTrue = PersonalColorType(
    label: '겨울 쿨 트루',
    season: '겨울',
    temperature: ColorTemperature.cool,
    value: ColorValue.deep,
    chroma: ColorChroma.neutral,
    recommendedColors: [
      _s('네이비', '#2F415E'),
      _s('쿨 레드', '#D11A45'),
      _s('퓨어 화이트', '#FFFFFF'),
      _s('로열 블루', '#2545C9'),
      _s('쿨 핑크', '#E06C9F'),
    ],
    avoidColors: [
      _s('웜 베이지', '#D7C3A4'),
      _s('머스터드', '#D4A017'),
      _s('카멜', '#C19A6B'),
      _s('테라코타', '#C66E4E'),
      _s('올리브', '#808000'),
    ],
  );
  static final winterDeep = PersonalColorType(
    label: '겨울 쿨 딥',
    season: '겨울',
    temperature: ColorTemperature.cool,
    value: ColorValue.deep,
    chroma: ColorChroma.muted,
    recommendedColors: [
      _s('차콜', '#36454F'),
      _s('블랙', '#171412'),
      _s('버건디', '#7B2D3A'),
      _s('딥 네이비', '#1E2A44'),
      _s('와인', '#5E2233'),
    ],
    avoidColors: [
      _s('웜 베이지', '#D7C3A4'),
      _s('머스터드', '#D4A017'),
      _s('카멜', '#C19A6B'),
      _s('피치', '#F6C9A8'),
      _s('연한 파스텔', '#E4DDE8'),
    ],
  );

  /// 12유형 전체 — 선언 순서 = 계절 순서.
  static final List<PersonalColorType> all = [
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
