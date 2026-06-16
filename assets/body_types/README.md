# 체형 실루엣 애셋

가상착장 "사용자 기본정보 > 체형" 선택 UI에서 쓰는 실루엣 이미지.

## 파일 규약

`{gender}_{type}.png` — 총 12개 (성별 2 × 체형 6)

| gender | type | 파일명 |
|---|---|---|
| female | slim | female_slim.png |
| female | normal | female_normal.png |
| female | muscular | female_muscular.png |
| female | top_heavy | female_top_heavy.png |
| female | bottom_heavy | female_bottom_heavy.png |
| female | plus | female_plus.png |
| male | slim | male_slim.png |
| male | normal | male_normal.png |
| male | muscular | male_muscular.png |
| male | top_heavy | male_top_heavy.png |
| male | bottom_heavy | male_bottom_heavy.png |
| male | plus | male_plus.png |

## 스펙

- PNG, 배경 투명(또는 단색 통일)
- 세로 실루엣, 비율 통일 권장(예: 3:4)
- 파일이 없으면 앱은 아이콘으로 폴백한다(`_BodyTypeImage.errorBuilder`).

경로 생성은 `lib/domain/profile/body_type.dart`의 `bodyTypeAsset(gender, type)`.
