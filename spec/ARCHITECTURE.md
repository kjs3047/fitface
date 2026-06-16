# FitFace Architecture

## 1. 아키텍처 원칙

FitFace는 로컬 우선 앱입니다. 오버레이 비교는 완전 오프라인으로 동작하고,
AI 기능만 선택적으로 온디바이스(Local Gemma) 또는 클라우드(OpenAI 프록시)를
사용합니다.

핵심 원칙:

- Presentation / Domain / Data / Core 계층 분리
- AI와 배경 제거 기능은 인터페이스로 분리하고, 모드(Off/Mock/Local Gemma/OpenAI)로
  구현체를 교체
- 얼굴 이미지·스냅샷·메타데이터는 로컬 저장 (서버 저장 없음)
- OpenAI API 키는 앱이 아닌 백엔드 프록시가 환경변수로 보유
- 카메라/오버레이/캡처 기능은 화면 단위로 독립 구현
- 도메인 규칙(퍼스널 컬러 12유형, 체형 enum)은 단일 소스로 고정

## 2. 권장 폴더 구조

```text
lib/
  main.dart
  app.dart

  core/
    constants/
      app_constants.dart
      storage_keys.dart
    theme/
      app_theme.dart
    utils/
      file_utils.dart
      image_utils.dart
      date_utils.dart
    errors/
      app_exception.dart

  data/
    models/
      user_profile.dart
      overlay_preset.dart
      outfit_snapshot.dart
      compare_session.dart
      ai_analysis_result.dart
      personal_color_result.dart
    repositories/
      user_profile_repository.dart
      snapshot_repository.dart
      preset_repository.dart
    local/
      hive_boxes.dart
      local_file_storage.dart

  domain/
    personal_color/
      personal_color_type.dart        # 12계절 유형 단일 소스(라벨/축/분류/매핑)
    profile/
      body_type.dart                  # 성별 x 체형 6종 단일 소스(라벨/애셋/프롬프트)
    services/
      background_removal_service.dart  # + mock 구현
      ai_analysis_service.dart         # 코디네이터 + mock/localGemma/openAi 어댑터
      personal_color_service.dart      # + rule_based / mock / localGemma / openAi
      open_ai_try_on_service.dart      # 가상착장(프록시 /ai/try-on 호출)
      ...

  openai_proxy/
    openai_proxy_server.dart           # Responses 클라이언트 + 이미지 edits 클라이언트 + 엔드포인트

  presentation/
    routes/                            # app_routes.dart, route_names.dart
    screens/
      splash/ onboarding/
      face_register/                   # register / crop / preview / capture
      camera_match/                    # 카메라 + 오버레이 + 합성본/원본 캡처
      compare/                         # compare / snapshot_detail / image_viewer
      personal_color/                  # 퍼스널 컬러 결과
      profile/
        user_basic_info_screen.dart    # 키/몸무게/체형 등록
      try_on/
        try_on_screen.dart             # 가상착장 생성/결과/게이팅/비용통제
      ai_chat/                         # Local Gemma 챗봇
      settings/
    widgets/                           # app_top_bar, face_overlay_widget, ...

  providers/                           # user_profile / snapshot / camera_overlay /
                                       # ai_settings / service(provider) ...
```

(전체 파일은 코드를 참조. 위는 핵심 디렉토리만 표기.)

## 3. 주요 데이터 모델

### UserProfile

```dart
class UserProfile {
  final String id;
  final String? originalFaceImagePath;
  final String? overlayFaceImagePath;
  final String? personalColorType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.originalFaceImagePath,
    this.overlayFaceImagePath,
    this.personalColorType,
    required this.createdAt,
    required this.updatedAt,
  });
}
```

### OverlayPreset

```dart
class OverlayPreset {
  final String id;
  final double positionX;
  final double positionY;
  final double scale;
  final double opacity;
  final DateTime updatedAt;

  const OverlayPreset({
    required this.id,
    required this.positionX,
    required this.positionY,
    required this.scale,
    required this.opacity,
    required this.updatedAt,
  });
}
```

### OutfitSnapshot

```dart
class OutfitSnapshot {
  final String id;
  final String imagePath;
  final String? memo;
  final List<String> tags;
  final int? aiScore;
  final String? aiComment;
  final DateTime createdAt;

  const OutfitSnapshot({
    required this.id,
    required this.imagePath,
    this.memo,
    this.tags = const [],
    this.aiScore,
    this.aiComment,
    required this.createdAt,
  });
}
```

### CompareSession

```dart
class CompareSession {
  final String id;
  final List<String> snapshotIds;
  final String? aiBestSnapshotId;
  final DateTime createdAt;

  const CompareSession({
    required this.id,
    required this.snapshotIds,
    this.aiBestSnapshotId,
    required this.createdAt,
  });
}
```

## 4. 상태 관리

### UserProfileProvider

역할:

- 사용자 프로필 로드
- 얼굴 이미지 경로 관리
- 프로필 업데이트
- 프로필 초기화

### CameraOverlayProvider

역할:

- 오버레이 위치 x/y
- scale
- opacity
- 초기화
- preset 저장/로드

상태 예시:

```dart
class CameraOverlayState {
  final Offset position;
  final double scale;
  final double opacity;

  const CameraOverlayState({
    required this.position,
    required this.scale,
    required this.opacity,
  });
}
```

### SnapshotProvider

역할:

- 후보 목록 로드
- 후보 추가
- 후보 삭제
- 후보 교체
- 메모 수정
- 최대 3개 제한 처리

### AiProvider

역할:

- 단일 후보 분석 요청
- 3개 후보 비교 요청
- Mock 결과 반환
- 향후 API 연결 준비

## 5. 로컬 저장 구조

```text
app_documents/
  fitface/
    profile/
      face_original.jpg
      face_overlay.png
    snapshots/
      snapshot_001.jpg
      snapshot_002.jpg
      snapshot_003.jpg
    metadata/
      hive boxes
```

## 6. 카메라/오버레이 구조

권장 구조:

```dart
Stack(
  children: [
    CameraPreview(controller),
    FaceOverlayWidget(...),
    BottomControlPanel(...),
  ],
)
```

캡처 시에는 카메라 프리뷰와 오버레이가 포함된 영역만 캡처해야 하며, 하단 버튼/슬라이더는 캡처하지 않는 것이 좋습니다.

## 7. AI 구조

AI는 모드(Off / Mock / Local Gemma / OpenAI)로 구현체가 교체됩니다.

- **어울림 판단/비교**: 코디네이터가 모드에 맞는 어댑터를 선택. Local Gemma는
  온디바이스, OpenAI는 프록시(`/ai/snapshot/analyze`, `/ai/snapshots/compare`).
- **퍼스널 컬러**: 12계절 유형 enum 고정. 프록시 structured output으로 유형을
  강제하고 색상은 hex 동반으로 받음. 실패 시 rule-based 폴백(축→유형 분류).
- **가상착장**: OpenAI 전용. `OpenAiTryOnService` → 프록시 `/ai/try-on` →
  `gpt-image-2`(이미지 edits). 얼굴 + 옷 원본 + 체형/키/몸무게 프롬프트를 합성.

```dart
abstract class AiAnalysisService {
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot);
  Future<String> compareSnapshots(List<OutfitSnapshot> snapshots);
}
```

OpenAI 키는 앱에 없고, 프록시(`bin/fitface_openai_proxy.dart`)가 환경변수로
보유합니다. 모델은 `OPENAI_MODEL`(텍스트) / `OPENAI_IMAGE_MODEL`(가상착장)로 설정.

## 8. 배경 제거 확장 인터페이스

```dart
abstract class BackgroundRemovalService {
  Future<String> removeBackground(String inputImagePath);
}
```

MVP에서는 `MockBackgroundRemovalService`가 입력 이미지를 그대로 반환합니다.
