# FitFace Architecture

## 1. 아키텍처 원칙

FitFace는 MVP 단계에서 서버 없이 로컬 앱으로 동작합니다.

핵심 원칙:

- Presentation / Domain / Data / Core 계층 분리
- AI와 배경 제거 기능은 인터페이스로 분리
- 얼굴 이미지와 스냅샷은 로컬 저장
- 카메라/오버레이/캡처 기능은 화면 단위로 독립 구현
- Codex가 Task 단위로 개발하기 쉬운 구조 유지

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
    services/
      background_removal_service.dart
      mock_background_removal_service.dart
      ai_analysis_service.dart
      mock_ai_analysis_service.dart
      personal_color_service.dart
      mock_personal_color_service.dart

  presentation/
    routes/
      app_routes.dart
      route_names.dart
    screens/
      splash/
        splash_screen.dart
      onboarding/
        onboarding_screen.dart
      face_register/
        face_register_screen.dart
        face_crop_screen.dart
        face_preview_screen.dart
      camera_match/
        camera_match_screen.dart
      compare/
        compare_screen.dart
        snapshot_detail_screen.dart
      personal_color/
        personal_color_screen.dart
      settings/
        settings_screen.dart
    widgets/
      primary_button.dart
      app_top_bar.dart
      face_overlay_widget.dart
      opacity_slider.dart
      snapshot_card.dart
      empty_state.dart

  providers/
    user_profile_provider.dart
    snapshot_provider.dart
    camera_overlay_provider.dart
    ai_provider.dart
```

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

## 7. AI 확장 인터페이스

```dart
abstract class AiAnalysisService {
  Future<AiAnalysisResult> analyzeSnapshot(OutfitSnapshot snapshot);
  Future<String> compareSnapshots(List<OutfitSnapshot> snapshots);
}
```

MVP에서는 `MockAiAnalysisService`를 사용합니다.

## 8. 배경 제거 확장 인터페이스

```dart
abstract class BackgroundRemovalService {
  Future<String> removeBackground(String inputImagePath);
}
```

MVP에서는 `MockBackgroundRemovalService`가 입력 이미지를 그대로 반환합니다.
