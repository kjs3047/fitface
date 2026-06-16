/// 가상착장용 신체 정보의 단일 소스(single source of truth).
///
/// 체형은 성별(여/남) × 6종으로 고정한다. 6종이면 충분한 이유:
/// 키·몸무게(연속값)가 세밀 보정을 담당하고, 체형 프리셋은 전체 실루엣
/// 방향만 잡으면 된다. gpt-image류는 텍스트 지시로 구별 가능한 실루엣
/// 분해능에 한계가 있어 더 쪼개도 생성 결과가 달라지지 않는다.
///
/// 이 파일은 UI(체형 선택) / 가상착장 프롬프트가 공유하는 기준이다.
library;

/// 성별 — 체형 실루엣과 프롬프트 인물 묘사에 쓴다.
enum Gender {
  female('여성', 'female'),
  male('남성', 'male');

  const Gender(this.label, this.assetKey);

  /// UI 표시용 한국어.
  final String label;

  /// 애셋 파일명에 쓰는 키(female/male).
  final String assetKey;

  static Gender? fromName(String? value) {
    for (final g in Gender.values) {
      if (g.name == value) {
        return g;
      }
    }
    return null;
  }
}

/// 체형 6종.
enum BodyType {
  slim('슬림형', 'slim', 'a slim, slender build'),
  normal('보통형', 'normal', 'an average, standard build'),
  muscular('근육형', 'muscular', 'a toned, muscular build'),
  topHeavy('상체발달형', 'top_heavy', 'a top-heavy build with broad shoulders (inverted triangle)'),
  bottomHeavy('하체발달형', 'bottom_heavy', 'a bottom-heavy build with fuller hips and legs (triangle)'),
  plus('플러스형', 'plus', 'a plus-size, fuller build');

  const BodyType(this.label, this.assetKey, this.promptDescription);

  /// UI 표시용 한국어.
  final String label;

  /// 애셋 파일명에 쓰는 키(slim/normal/...).
  final String assetKey;

  /// gpt-image 프롬프트에 넣는 영문 묘사.
  final String promptDescription;

  static BodyType? fromName(String? value) {
    for (final t in BodyType.values) {
      if (t.name == value) {
        return t;
      }
    }
    return null;
  }
}

/// 기본 선택값 — 모르는 사용자도 부담 없이 통과하도록 보통형.
const defaultBodyType = BodyType.normal;
const defaultGender = Gender.female;

/// 체형 실루엣 이미지 애셋 경로.
///
/// 규약: `assets/body_types/{gender}_{type}.png`
/// 예) assets/body_types/female_slim.png
String bodyTypeAsset(Gender gender, BodyType type) {
  return 'assets/body_types/${gender.assetKey}_${type.assetKey}.png';
}

/// 가상착장 프롬프트에 넣을 인물 묘사 한 줄.
/// 키/몸무게는 있는 값만 포함한다(없으면 생략, 정확도는 낮아짐).
String bodyDescriptionForPrompt({
  required Gender gender,
  required BodyType bodyType,
  int? heightCm,
  int? weightKg,
}) {
  final genderWord = gender == Gender.female ? 'woman' : 'man';
  final parts = <String>['a $genderWord with ${bodyType.promptDescription}'];
  if (heightCm != null) {
    parts.add('height about ${heightCm}cm');
  }
  if (weightKg != null) {
    parts.add('weight about ${weightKg}kg');
  }
  return parts.join(', ');
}
