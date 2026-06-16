# FitFace

> English: [README.md](README.md)

FitFace는 매장에서 탈의실에 들어가기 전에 옷이 나에게 어울리는지 확인하는
로컬 우선 Flutter 앱입니다. 미리 등록한 얼굴~목 이미지를 후면 카메라의 실제 옷
화면 위에 오버레이하고, 선택적으로 온디바이스/클라우드 AI가 어울림 판단,
퍼스널 컬러 진단, 가상착장 미리보기를 더해 줍니다.

## 기능

### 코어 (오프라인, 계정 없음)
- 갤러리/카메라로 얼굴 사진 등록 + 얼굴~목 크롭 플로우.
- 배경 제거 서비스 추상화(현재 Mock 구현).
- 후면 카메라 프리뷰(권한/초기화 상태 처리).
- 드래그·핀치 줌·투명도 조절이 되는 얼굴 오버레이.
- 스냅샷 저장 시 합성본과 **오버레이 없는 원본 프레임**을 함께 저장
  (원본은 가상착장 입력으로 쓰임).
- 최대 3개 후보(교체/삭제/메모), 비교 화면, 스냅샷 상세 화면(핀치 줌 뷰어).
- 로컬 JSON 메타데이터 + 앱 문서 디렉토리에 로컬 이미지 저장.

### AI (모드 선택: Off / Mock / Local Gemma / OpenAI)
- **어울림 판단·비교** — 스냅샷 점수와 스타일링 코멘트.
- **퍼스널 컬러** — **12계절 체계**(웜/쿨 × 명도 × 채도)로 고정. 유형은 12개
  enum으로 제약하고, 추천/주의 색상과 코멘트는 AI가 생성하되 색상별 hex를
  함께 받아 스와치가 정확한 색으로 표시됨. 12유형 rule-based 폴백 포함.
- **가상착장** — 등록 얼굴 + 저장된 신체 정보로 스냅샷의 옷을 입은 이미지를
  OpenAI `gpt-image-2`로 생성. 클라우드 전용.
- **Local Gemma 챗봇** — Local Gemma 모드에서 온디바이스 대화.

### 사용자 기본정보 (가상착장용)
키·몸무게·체형(성별 × 6종)을 **설정 → 사용자 기본정보**에서 한 번만 등록하고,
가상착장 때마다 재사용합니다(매번 입력하지 않음).

### 비용 통제 (가상착장)
기본 이미지 품질 medium, 스냅샷당 생성 횟수 상한, 재생성 전 확인 다이얼로그,
생성 중 뒤로가기 차단, 결과 캐싱(같은 스냅샷+체형이면 저장본 재사용),
결과가 있으면 진입 버튼이 "결과 보기"로 표시.

## 실행

```bash
flutter pub get
flutter test
flutter test integration_test
flutter run
```

## OpenAI 프록시

FitFace는 OpenAI API 키를 앱에 저장하지 않습니다. OpenAI 모드(분석, 퍼스널 컬러,
가상착장)는 작은 백엔드 프록시를 호출하고, 프록시가 서버 환경변수에서 키를 읽습니다.

로컬 프록시 실행:

```bash
$env:OPENAI_API_KEY="<your-openai-api-key>"
dart run bin/fitface_openai_proxy.dart
```

선택 환경변수:

```text
OPENAI_MODEL=gpt-5.4-mini          # 텍스트 분석 / 퍼스널 컬러 모델
OPENAI_IMAGE_MODEL=gpt-image-2     # 가상착장 이미지 모델
FITFACE_PROXY_HOST=127.0.0.1
FITFACE_PROXY_PORT=8787
FITFACE_PROXY_MAX_BODY_BYTES=12582912
FITFACE_PROXY_MAX_IMAGES=3
FITFACE_PROXY_AUTH_TOKEN=<공유-시크릿>
```

프록시를 다른 기기에서 접근하게 하려면(예: `FITFACE_PROXY_HOST=0.0.0.0`)
`FITFACE_PROXY_AUTH_TOKEN`에 공유 시크릿을 설정하세요. 그러면 모든 `/ai/*` 요청은
`X-FitFace-Token` 헤더로 같은 값을 보내야 합니다(`/health`는 연결 테스트용으로
열려 있음). 앱의 **설정 → AI 설정 → OpenAI 프록시 주소**에 같은 토큰을 입력하면
앱이 자동으로 헤더에 붙입니다. `FITFACE_PROXY_AUTH_TOKEN`이 비어 있으면 토큰을
요구하지 않습니다(로컬 개발).

의도적으로 LAN에 노출할 게 아니라면 `127.0.0.1` 바인딩을 권장하고, 키가 평문으로
저장된 적이 있다면 OpenAI API 키를 교체하세요.

> 변경사항을 받은 뒤에는 프록시를 재시작하세요 — 새 엔드포인트/모델
> (예: `/ai/try-on`, `OPENAI_IMAGE_MODEL`)은 재시작해야 적용됩니다.

앱의 OpenAI 프록시 주소를 서버 URL로 설정합니다. 예:

```text
http://127.0.0.1:8787
```

Android 에뮬레이터에서 호스트 PC의 프록시를 쓰려면:

```text
http://10.0.2.2:8787
```

프록시가 제공하는 엔드포인트:

- `POST /ai/snapshot/analyze`
- `POST /ai/snapshots/compare`
- `POST /ai/personal-color`
- `POST /ai/try-on`
- `GET /health`
