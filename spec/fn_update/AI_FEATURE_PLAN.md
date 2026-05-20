# FitFace AI 기능 추가 계획

## 1. 목표

FitFace의 AI 기능은 얼굴 자체를 평가하는 기능이 아니다. 목표는 사용자가 매장에서 저장한 착장 후보를 기준으로 얼굴 오버레이와 옷의 색감, 조명, 분위기, 스타일 조화를 빠르게 판단하도록 돕는 것이다.

AI 기능은 다음 원칙을 따른다.

- 기본값은 로컬 우선이다.
- Local Gemma와 OpenAI API는 동일한 분석 파이프라인을 사용한다.
- Local Gemma는 FitFace 앱 내부에 온디바이스 런타임을 직접 붙인다.
- Edge Gallery 앱에 설치된 Gemma 모델을 직접 호출하거나 재사용하는 구조는 기본 설계에 넣지 않는다.
- OpenAI API는 모바일 앱에서 직접 호출하지 않고 백엔드 프록시를 통해 호출한다.
- 이미지 직접 분석을 기본으로 하되, 앱이 사전 추출한 색상/밝기/대비 정보를 prompt에 함께 넣어 결과의 구체성과 일관성을 높인다.
- vision 분석 실패 시 색상정보 기반 text-only 분석으로 fallback한다.
- 모델/API 자체가 실패해도 앱이 멈추지 않도록 rule-based fallback을 둔다.

## 2. AI 모드

설정 화면에서 AI 실행 방식을 선택할 수 있게 한다.

| 모드 | 설명 | 용도 |
|---|---|---|
| Off | AI 기능 비활성화 | 개인정보 우선 사용자 |
| Mock | 현재처럼 개발/테스트용 결과 반환 | 테스트, CI, 개발 기본값 |
| Local Gemma | FitFace 내부 온디바이스 Gemma 런타임 사용 | 기본 추천 모드 |
| OpenAI API | 백엔드 프록시를 통해 OpenAI API 사용 | 고품질 클라우드 분석 옵션 |

OpenAI API 모드는 명시적 클라우드 전송 동의가 있을 때만 사용할 수 있다. 앱에는 OpenAI API key를 저장하지 않는다.

## 3. 공통 분석 파이프라인

Local Gemma와 OpenAI API는 같은 상위 절차를 사용한다.

```text
스냅샷/얼굴 이미지 준비
→ 이미지 사전 분석
→ AI context 생성
→ 선택된 AI 엔진 호출
→ JSON 결과 파싱
→ 결과 검증/보정
→ 로컬 저장
→ UI 표시
```

이미지 사전 분석에서 추출할 정보는 다음과 같다.

```text
dominantColors
palette
brightness
contrast
saturation
warmCoolBias
averageColor
colorHarmonyHints
imageQualityHints
```

추후 필요하면 다음 정보를 추가한다.

```text
faceOverlayRegion
garmentRegion
backgroundLightingBias
faceToClothingContrast
```

## 4. 분석 우선순위와 fallback

각 분석 요청은 3단계로 처리한다.

| 우선순위 | 이름 | 입력 | 목적 |
|---|---|---|---|
| 1순위 | image + features | 이미지, 색상정보, 메모, 퍼스널 컬러 context | 기본 분석 경로 |
| 2순위 | features only | 색상정보, 메모, 퍼스널 컬러 context | vision 실패 시 대체 |
| 3순위 | rule-based fallback | 사전 분석값 또는 기본값 | 모델/API 실패 시 최소 결과 제공 |

Local Gemma 기준 fallback:

```text
Gemma vision 분석
→ 실패 시 Gemma text-only 분석
→ 실패 시 rule-based fallback
```

OpenAI API 기준 fallback:

```text
OpenAI image 분석
→ 실패 시 OpenAI features-only 분석
→ 네트워크/API 불가 시 rule-based fallback
```

## 5. 아키텍처

현재 `AiAnalysisService` 경계를 유지하고, 공통 조정 계층을 추가한다.

```text
Presentation
  SnapshotDetailScreen
  CompareScreen
  PersonalColorScreen
  CameraMatchScreen
  SettingsScreen

Providers
  ai_settings_provider.dart
  ai_analysis_provider.dart

Domain
  AiAnalysisCoordinator
  ImageFeatureExtractor
  AiPromptBuilder
  AiResultValidator

Services
  AiAnalysisService
    - MockAiAnalysisService
    - LocalGemmaAnalysisService
    - OpenAiAnalysisService

  PersonalColorService
    - MockPersonalColorService
    - LocalGemmaPersonalColorService
    - OpenAiPersonalColorService
```

화면은 `AiAnalysisCoordinator` 또는 provider만 호출한다. 실제 엔진 선택, prompt 구성, fallback 처리는 coordinator 내부에서 수행한다.

## 6. 데이터 모델

`AiAnalysisResult`를 확장한다.

```text
score: int
comment: String
tags: List<String>
bestSnapshotId: String?
candidateScores: Map<String, int>
candidateComments: Map<String, String>
strengths: List<String>
concerns: List<String>
suggestions: List<String>
confidence: double?
engine: mock | localGemma | openai | ruleBased
analysisMode: imageAndFeatures | featuresOnly | fallback
createdAt: DateTime
rawFeatureSummary: Map<String, dynamic>?
```

`OutfitSnapshot`에는 현재 존재하는 `aiScore`, `aiComment`, `tags`를 우선 활용한다. 분석 결과가 커지면 별도 저장 파일로 분리한다.

권장 저장 구조:

```text
metadata/
  snapshots.json
  snapshot_ai_results.json
  personal_color_result.json
  ai_settings.json
```

퍼스널 컬러는 `UserProfile.personalColorType`만 저장하지 않고 전체 결과를 `personal_color_result.json`에 저장한다.

## 7. 설정 화면

`SettingsScreen`에 AI 설정 섹션을 추가한다.

필수 항목:

- AI 기능 사용 여부
- AI 엔진 선택: Off / Mock / Local Gemma / OpenAI API
- 클라우드 AI 사용 동의
- OpenAI API 서버 주소
- Local Gemma 모델 상태
- Local Gemma 모델 선택 또는 초기화
- 분석 결과 캐시 삭제

OpenAI API key는 앱에 저장하지 않는다. 앱은 백엔드 프록시 주소만 저장한다.

## 8. Local Gemma 구현

Android를 우선 지원한다.

```text
Flutter
→ MethodChannel
→ Android Kotlin
→ LiteRT-LM
→ Gemma 4 E4B-it
→ JSON 문자열 반환
```

Local Gemma는 기본적으로 멀티모달 이미지 분석을 사용한다.

```text
이미지 + prompt + feature summary
→ Gemma
→ JSON result
```

모델 관리는 단계적으로 구현한다.

| 단계 | 방식 |
|---|---|
| 개발/초기 | 사용자가 `.litertlm` 모델 파일을 선택하면 FitFace 앱 저장소로 복사하고 경로를 저장 |
| 제품화 | 앱 내부 모델 다운로드, 검증, 저장 구조 추가 |

Edge Gallery 앱에 설치된 모델을 FitFace가 직접 가져다 쓰는 방식은 Android 앱 sandbox 때문에 안정적인 제품 구조가 아니다. Edge Gallery는 참고 구현과 기기 성능 검증용으로만 사용한다.

## 9. OpenAI API 구현

OpenAI 모드는 백엔드 프록시를 전제로 한다.

```text
FitFace
→ POST /ai/snapshot/analyze
→ POST /ai/snapshots/compare
→ POST /ai/personal-color
→ Backend
→ OpenAI Responses API
→ JSON result
→ FitFace
```

백엔드 책임:

- OpenAI API key 보관
- 이미지 크기 제한
- EXIF/metadata 제거 또는 검증
- rate limit
- 요청 로그 최소화
- 이미지 장기 저장 금지
- JSON schema 검증
- 에러 코드 표준화

앱은 이미지 전송 전 resize/compress를 수행한다. 클라우드 동의가 없으면 OpenAI 모드는 호출하지 않는다.

## 10. 화면별 적용 계획

### SnapshotDetailScreen

저장 후보 1개에 대한 AI 분석을 제공한다.

```text
AI 판단 버튼
→ 분석 중 상태
→ AI 분석 카드 표시
→ 점수, 코멘트, 태그, 좋은 점, 아쉬운 점, 추천 행동
→ 결과 저장
→ 재분석 버튼
```

### CompareScreen

저장 후보 최대 3개를 비교한다.

```text
AI에게 3개 비교 요청
→ 후보별 image + features 구성
→ BEST 선정
→ 후보별 점수/이유 표시
→ BEST badge 유지
→ 후보 변경/삭제 시 비교 결과 무효화
```

### PersonalColorScreen

등록 얼굴 이미지 기준 퍼스널 컬러 분석을 제공한다. 화면 진입 시 자동 실행하지 않고 사용자가 직접 시작한다.

```text
분석 시작 버튼
→ 얼굴 이미지 + features 분석
→ 퍼스널 컬러 타입
→ 추천 색상
→ 피해야 할 색상
→ 쇼핑 팁
→ 결과 저장
```

### CameraMatchScreen

실시간 분석은 하지 않는다. 사용자가 요청할 때만 현재 화면을 임시 캡처해 1회 분석한다.

```text
AI 판단 버튼
→ 현재 화면 임시 캡처
→ 분석
→ 결과 bottom sheet 표시
→ 임시 이미지 삭제
```

### FaceRegister / FaceCrop / FacePreview

얼굴 등록 품질 체크를 제공한다.

```text
너무 어두움
흐림
강한 색조명
정면 아님
가이드 적합성 부족
```

품질이 낮아도 사용을 막지는 않고, 분석 신뢰도와 안내 문구에 반영한다.

## 11. Prompt와 JSON 정책

Local Gemma와 OpenAI는 같은 JSON schema를 목표로 한다.

예시 출력:

```json
{
  "score": 84,
  "comment": "밝은 블루 계열이 얼굴 톤을 맑게 보이게 해서 전체적으로 안정적입니다.",
  "tags": ["쿨톤추천", "맑은색감", "부드러운대비"],
  "strengths": ["얼굴 주변 밝기가 안정적입니다.", "옷 색상이 과하게 튀지 않습니다."],
  "concerns": ["매장 조명이 노란 편이면 실제 색감이 조금 달라 보일 수 있습니다."],
  "suggestions": ["비슷한 계열에서는 채도가 너무 높은 파랑보다 소프트 블루를 우선 보세요."],
  "confidence": 0.78
}
```

JSON 파싱 실패 시 한 번 재요청하거나 응답 텍스트에서 JSON 복구를 시도한다. 그래도 실패하면 fallback 결과를 사용한다.

## 12. 개인정보와 표현 정책

필수 원칙:

- 기본값은 로컬 우선이다.
- OpenAI API는 명시적 동의가 필요하다.
- 얼굴/스냅샷 전송 여부를 설정에 명확히 표시한다.
- EXIF/metadata를 제거한다.
- 서버에 이미지를 장기 저장하지 않는다.
- AI 결과는 스타일링 참고용으로 표시한다.
- 얼굴 자체 외모 평가는 금지한다.

허용 표현:

```text
얼굴 톤이 밝아 보입니다.
옷 색상이 얼굴 주변을 차분하게 보이게 합니다.
매장 조명에서는 대비가 강하게 보일 수 있습니다.
```

금지 표현:

```text
얼굴이 예쁘다/못생겼다
피부가 나쁘다
외모 점수
절대적으로 어울린다/안 어울린다
```

## 13. 구현 단계

작업은 `feature/ai-integration` 브랜치에서 진행한다.

| 단계 | 작업 |
|---|---|
| AI-01 | AI 설정 모델/저장소/provider 추가 |
| AI-02 | 설정 화면에 AI 모드 선택 UI 추가 |
| AI-03 | `AiAnalysisResult` 확장 |
| AI-04 | `ImageFeatureExtractor` 구현 |
| AI-05 | `AiAnalysisCoordinator`와 fallback 구조 구현 |
| AI-06 | Snapshot 상세 AI 분석 카드 적용 |
| AI-07 | Compare 화면 후보 3개 비교 적용 |
| AI-08 | PersonalColor 분석 저장/재분석 적용 |
| AI-09 | Android MethodChannel 골격 추가 |
| AI-10 | Local Gemma vision 분석 연결 |
| AI-11 | Local Gemma text-only fallback 연결 |
| AI-12 | OpenAI API 프록시 adapter 연결 |
| AI-13 | CameraMatch 임시 캡처 AI 판단 추가 |
| AI-14 | 얼굴 사진 품질 체크 추가 |
| AI-15 | 테스트/기기 검증/성능 측정 |
| AI-16 | 원격 feature 브랜치 push 후 main merge 준비 |

## 14. 검증 기준

완료 전 다음 기준을 확인한다.

```text
flutter analyze 통과
flutter test 통과
Mock 모드 기존 테스트 유지
AI 모드 설정 저장/복원 확인
Local Gemma 모델 없음 상태 처리
Local Gemma vision 분석 성공
Local Gemma vision 실패 시 features-only fallback 확인
OpenAI API 모드는 백엔드 프록시만 호출
클라우드 동의 없을 때 OpenAI 호출 차단
단일 후보 분석 결과 저장 확인
후보 3개 비교 결과 표시 확인
퍼스널 컬러 결과 저장 확인
앱 데이터 초기화 시 AI 결과/설정 정리 확인
```

## 15. 브랜치 운영

```text
main
  MVP 기준 브랜치

feature/ai-integration
  전체 AI 기능 작업 브랜치
```

작업은 기능 단위로 커밋한다. 최종 검증 후 `feature/ai-integration`을 원격에 push하고, 확인이 끝나면 `main`으로 merge한다.

## 16. 최종 결론

Gemma는 이미지 분석을 직접 사용한다. 단, FitFace가 먼저 계산한 색상/밝기/대비 정보를 prompt에 함께 넣어 분석 품질과 일관성을 높인다.

Vision 분석이 실패하면 같은 색상정보만으로 text-only 분석을 수행하고, 최종 실패 시 rule-based fallback을 사용한다.

OpenAI API도 같은 파이프라인을 사용한다. 차이는 실행 위치, 개인정보 동의, 비용, 네트워크 의존성뿐이다.
