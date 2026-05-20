# FitFace

## 개요

**FitFace**는 옷매장에서 후면 카메라로 실제 옷을 비추고, 사용자가 미리 등록한 **배경 제거된 얼굴~목 이미지**를 카메라 화면 위에 오버레이하여 옷과 얼굴의 어울림을 확인하는 모바일 쇼핑 보조 앱입니다.

## 핵심 컨셉

- 매장에 걸려 있는 옷, 마네킹이 입은 옷, 손에 든 옷을 후면 카메라로 비춥니다.
- 사용자가 등록한 얼굴~목 이미지를 카메라 위에 오버레이합니다.
- 사용자는 얼굴 이미지를 직접 드래그, 확대/축소, 투명도 조절하여 옷과 맞춰봅니다.
- 현재 비교 화면을 스냅샷으로 저장하고 최대 3개까지 비교합니다.
- AI 어울림 판단과 퍼스널 컬러 진단은 MVP 이후 확장 기능으로 설계합니다.

## 1차 MVP 목표

1. 얼굴 사진 등록
2. 얼굴~목 크롭
3. 배경 제거 서비스 구조 준비
4. 후면 카메라 프리뷰
5. 얼굴 오버레이 표시
6. 드래그 이동
7. 핀치 확대/축소
8. 투명도 조절
9. 현재 화면 스냅샷 저장
10. 최대 3개 후보 비교
11. 선택 메모
12. 로컬 저장
13. AI 판단 및 퍼스널 컬러 기능은 Mock 구조만 구현

## 권장 기술 스택

- Framework: Flutter
- Language: Dart
- State Management: Riverpod
- Camera: camera package
- Image Picker: image_picker
- Crop: crop_your_image 또는 image_cropper
- Local Storage: Hive 또는 JSON + file system
- File Path: path_provider
- Permission: permission_handler
- Capture: RepaintBoundary 또는 screenshot package

## 개발 원칙

- 서버와 로그인은 MVP에서 제외합니다.
- 얼굴 이미지와 스냅샷은 기본적으로 기기 내부에만 저장합니다.
- AI와 배경 제거는 추상 인터페이스로 분리하여 나중에 실제 구현체로 교체합니다.
- Codex 작업은 반드시 Task 단위로 진행합니다.
