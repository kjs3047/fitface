# FitFace Codex Prompts

## 0. 전체 마스터 프롬프트

```text
너는 Flutter 모바일 앱 개발자다.

우리는 FitFace라는 앱을 만든다.

앱 목적:
옷매장에서 후면 카메라로 실제 옷을 비추고, 사용자가 미리 등록한 얼굴~목 이미지를 카메라 화면 위에 오버레이하여 옷과 얼굴의 어울림을 확인하는 쇼핑 보조 앱이다.

핵심 MVP 기능:
1. 얼굴 사진 등록
2. 얼굴~목 크롭
3. 배경 제거 서비스 구조 준비
4. 카메라 프리뷰
5. 얼굴 오버레이 표시
6. 드래그 이동
7. 핀치 확대/축소
8. 투명도 조절
9. 현재 화면 스냅샷 저장
10. 최대 3개 후보 비교
11. 선택 메모
12. 로컬 저장
13. AI 판단 및 퍼스널 컬러 기능은 Mock 구조만 구현

개발 원칙:
- Flutter 기반 크로스플랫폼 앱으로 구현한다.
- 서버와 로그인은 제외한다.
- 얼굴 이미지와 스냅샷은 로컬에 저장한다.
- 개인정보 보호를 고려한다.
- 기능을 한 번에 만들지 말고 Task 단위로 진행한다.
- 각 Task 완료 후 실행 가능 상태를 유지한다.
- 코드 구조는 presentation/data/domain/core/providers로 분리한다.
- AI와 배경 제거는 추상 인터페이스로 분리해 향후 실제 구현체를 교체할 수 있게 한다.

이제 각 Task 문서에 따라 순차적으로 개발해라.
```

---

## Task 01 Prompt

```text
Flutter 앱 FitFace의 기본 프로젝트 구조를 만들어줘.

요구사항:
- lib 폴더를 core, data, domain, presentation, providers 구조로 나눠줘.
- 앱 테마는 깔끔한 쇼핑/카메라 앱 느낌으로 구성해줘.
- SplashScreen, OnboardingScreen 더미 화면을 만들어줘.
- 라우팅은 AppRoutes와 RouteNames로 분리해줘.
- 상태관리는 flutter_riverpod을 사용할 수 있게 준비해줘.
- 아직 카메라 기능은 구현하지 마.

완료 후 실행 가능한 상태여야 해.
```

## Task 02 Prompt

```text
FitFace 앱의 로컬 데이터 모델과 저장소를 구현해줘.

모델:
- UserProfile
- OverlayPreset
- OutfitSnapshot
- CompareSession

요구사항:
- Hive 또는 로컬 JSON 저장 중 안정적인 방식을 선택해 구현해줘.
- Repository 계층을 분리해줘.
- SnapshotRepository는 후보를 최대 3개까지만 유지해야 해.
- 4번째 후보 추가 시 기존 후보를 교체할 수 있는 메서드를 제공해줘.
- 모든 모델은 copyWith, toJson, fromJson을 제공해줘.
- 테스트하기 쉬운 구조로 만들어줘.
```

## Task 03 Prompt

```text
FitFace의 FaceRegisterScreen을 구현해줘.

요구사항:
- 사용자가 갤러리에서 사진을 선택할 수 있어야 해.
- 카메라 촬영 버튼도 UI는 만들되, 구현은 후순위로 둬도 돼.
- 선택한 이미지는 FaceCropScreen으로 전달해줘.
- 사진 등록 가이드 문구를 표시해줘.
- 정면 얼굴, 얼굴부터 목까지, 밝은 조명 권장 문구를 포함해줘.
- 권한 또는 이미지 선택 취소 예외를 처리해줘.
```

## Task 04 Prompt

```text
FitFace의 FaceCropScreen을 구현해줘.

목표:
사용자가 얼굴부터 목까지만 남기도록 사진을 크롭할 수 있어야 해.

요구사항:
- 전달받은 이미지 파일을 표시해줘.
- 크롭 UI를 제공해줘.
- 얼굴~목 영역을 맞추라는 안내문을 표시해줘.
- 크롭 완료 시 로컬 파일로 저장하고 FacePreviewScreen으로 전달해줘.
- 다시 선택 버튼을 제공해줘.
- 크롭 패키지는 안정적인 Flutter 패키지를 선택해서 사용해줘.
```

## Task 05 Prompt

```text
FitFace의 배경 제거 서비스 구조와 FacePreviewScreen을 구현해줘.

요구사항:
- BackgroundRemovalService 추상 클래스를 만들어줘.
- MockBackgroundRemovalService는 현재 입력 이미지를 그대로 반환하게 해줘.
- 나중에 실제 배경 제거 API나 온디바이스 모델로 교체할 수 있게 구조를 분리해줘.
- FacePreviewScreen에서는 결과 이미지를 체크무늬 배경 위에 보여줘.
- 사용자가 '이 사진 사용하기'를 누르면 UserProfile에 originalFaceImagePath와 overlayFaceImagePath를 저장해줘.
- 저장 후 CameraMatchScreen으로 이동해줘.
```

## Task 06 Prompt

```text
FitFace의 CameraMatchScreen에 후면 카메라 프리뷰를 구현해줘.

요구사항:
- camera 패키지를 사용해줘.
- 기본 카메라는 후면 카메라야.
- 카메라 권한을 처리해줘.
- 권한 거부 시 안내 화면과 설정 이동 버튼을 표시해줘.
- 카메라 초기화 중에는 로딩을 표시해줘.
- 카메라 초기화 실패 시 재시도 버튼을 제공해줘.
- 아직 얼굴 오버레이는 구현하지 말고 카메라 프리뷰만 안정적으로 나오게 해줘.
```

## Task 07 Prompt

```text
FitFace의 CameraMatchScreen 위에 얼굴 오버레이 기능을 구현해줘.

요구사항:
- UserProfile의 overlayFaceImagePath 이미지를 카메라 프리뷰 위에 표시해줘.
- FaceOverlayWidget을 별도 위젯으로 분리해줘.
- 사용자는 얼굴 이미지를 드래그로 이동할 수 있어야 해.
- 사용자는 핀치 제스처로 크기를 조절할 수 있어야 해.
- scale 범위는 0.4 ~ 3.0으로 제한해줘.
- 투명도는 0.2 ~ 1.0 범위로 적용해줘.
- 투명도 슬라이더를 하단에 배치해줘.
- 초기화 버튼을 누르면 위치/크기/투명도가 기본값으로 돌아가게 해줘.
- 상태관리는 Riverpod provider로 분리해줘.
```

## Task 08 Prompt

```text
FitFace의 스냅샷 저장 기능을 구현해줘.

요구사항:
- CameraMatchScreen에서 카메라 프리뷰와 얼굴 오버레이가 함께 보이는 영역을 캡처해줘.
- 하단 버튼과 투명도 슬라이더는 캡처 이미지에 포함하지 않는 것이 좋아.
- 캡처 이미지는 앱 로컬 documents 디렉토리의 snapshots 폴더에 저장해줘.
- 저장 후 OutfitSnapshot 모델을 생성해 SnapshotRepository에 저장해줘.
- 후보는 최대 3개까지만 저장 가능해.
- 이미 3개가 있으면 어느 후보를 교체할지 선택하는 다이얼로그를 표시해줘.
- 저장 완료 후 '메모 추가', '비교 보기', '닫기' 선택지를 제공해줘.
```

## Task 09 Prompt

```text
FitFace의 후보 상세 화면과 메모 기능을 구현해줘.

요구사항:
- SnapshotDetailScreen을 만들어줘.
- 저장된 스냅샷 이미지를 크게 보여줘.
- 메모 입력 필드를 제공해줘.
- 메모는 선택 입력이며 필수로 강요하면 안 돼.
- 저장 버튼을 누르면 해당 OutfitSnapshot의 memo를 업데이트해줘.
- 삭제 버튼을 누르면 후보와 이미지 파일을 삭제해줘.
- 삭제 전 확인 다이얼로그를 표시해줘.
```

## Task 10 Prompt

```text
FitFace의 CompareScreen을 구현해줘.

요구사항:
- 저장된 OutfitSnapshot을 최대 3개까지 표시해줘.
- 3개의 비교 슬롯을 고정으로 보여줘.
- 후보가 없는 슬롯은 '비어 있음' 상태로 표시해줘.
- 각 후보 카드를 누르면 SnapshotDetailScreen으로 이동해줘.
- 각 후보에는 메모 일부를 표시해줘.
- 후보 삭제 버튼을 제공해줘.
- 'AI에게 3개 비교 요청' 버튼을 제공하되, MVP에서는 Mock 결과 다이얼로그를 표시해줘.
- 카메라 화면으로 돌아가는 버튼을 제공해줘.
```

## Task 11 Prompt

```text
FitFace의 AI 분석 서비스 Mock 구조를 구현해줘.

요구사항:
- AiAnalysisService 추상 클래스를 만들어줘.
- analyzeSnapshot, compareSnapshots 메서드를 제공해줘.
- MockAiAnalysisService는 1초 지연 후 임시 결과를 반환하게 해줘.
- CameraMatchScreen 또는 SnapshotDetailScreen의 AI 판단 버튼과 연결해줘.
- CompareScreen의 AI 비교 버튼과 연결해줘.
- 결과 표현은 단정적이지 않게 해줘.
- 예: '이 옷은 얼굴 톤을 비교적 밝게 보이게 할 가능성이 있습니다.'
```

## Task 12 Prompt

```text
FitFace의 퍼스널 컬러 화면을 Mock으로 구현해줘.

요구사항:
- PersonalColorScreen을 만들어줘.
- 퍼스널 컬러 진단은 스타일링 참고용이라는 안내 문구를 표시해줘.
- PersonalColorService 추상 클래스와 MockPersonalColorService를 만들어줘.
- Mock 결과는 봄 웜, 여름 쿨, 가을 웜, 겨울 쿨 중 하나를 반환하게 해줘.
- 추천 색상과 피해야 할 색상 목록을 카드 형태로 보여줘.
- 실제 AI 분석은 구현하지 말고 구조만 만들어줘.
```

## Task 13 Prompt

```text
FitFace의 SettingsScreen을 구현해줘.

요구사항:
- 얼굴 사진 변경 메뉴를 제공해줘.
- 저장된 후보 전체 삭제 메뉴를 제공해줘.
- 앱 데이터 전체 초기화 메뉴를 제공해줘.
- 초기화 시 UserProfile, OverlayPreset, OutfitSnapshot, 로컬 이미지 파일을 삭제해줘.
- 초기화 후 OnboardingScreen으로 이동해줘.
- 개인정보 안내 영역을 만들어줘.
- 얼굴 사진과 스냅샷은 기본적으로 기기 내부에만 저장된다는 문구를 표시해줘.
```

## Task 14 Prompt

```text
FitFace 앱 전체 UI를 정리해줘.

요구사항:
- 쇼핑 카메라 앱에 어울리는 깔끔하고 직관적인 스타일로 정리해줘.
- 버튼, 카드, 하단 패널, 앱바 스타일을 통일해줘.
- 매장 안에서 한 손으로 조작하기 쉽게 주요 버튼은 하단에 배치해줘.
- EmptyState, LoadingState, ErrorState 위젯을 공통화해줘.
- 카메라 화면에서는 조작 UI가 너무 많이 가리지 않도록 반투명 패널을 사용해줘.
```

## Task 15 Prompt

```text
FitFace 앱의 주요 사용자 흐름을 점검하고 버그를 수정해줘.

테스트할 흐름:
1. 최초 실행 → 온보딩 → 얼굴 등록
2. 갤러리 사진 선택 → 크롭 → 미리보기 → 저장
3. 카메라 화면 진입
4. 얼굴 오버레이 드래그/핀치/투명도 조절
5. 스냅샷 저장
6. 후보 3개 비교
7. 4번째 저장 시 교체 다이얼로그
8. 메모 추가/수정
9. 후보 삭제
10. 앱 데이터 초기화

각 흐름에서 발생 가능한 예외를 찾아 수정해줘.
```
