# FitFace

## 개요

**FitFace**는 옷매장에서 후면 카메라로 실제 옷을 비추고, 사용자가 미리 등록한 **배경 제거된 얼굴~목 이미지**를 카메라 화면 위에 오버레이하여 옷과 얼굴의 어울림을 확인하는 모바일 쇼핑 보조 앱입니다.

## 핵심 컨셉

- 매장에 걸려 있는 옷, 마네킹이 입은 옷, 손에 든 옷을 후면 카메라로 비춥니다.
- 사용자가 등록한 얼굴~목 이미지를 카메라 위에 오버레이합니다.
- 사용자는 얼굴 이미지를 직접 드래그, 확대/축소, 투명도 조절하여 옷과 맞춰봅니다.
- 현재 비교 화면을 스냅샷으로 저장하고 최대 3개까지 비교합니다.
- 선택한 AI 모드(Off / Mock / Local Gemma / OpenAI)에 따라 어울림 판단,
  퍼스널 컬러 진단, 가상착장을 제공합니다.

## 동작 단계

### 1차: 오버레이 비교 (오프라인)

1. 얼굴 사진 등록 / 얼굴~목 크롭 / 배경 제거(구조)
2. 후면 카메라 프리뷰 + 얼굴 오버레이(드래그·핀치·투명도)
3. 스냅샷 저장(합성본 + 오버레이 없는 원본) / 최대 3개 비교 / 선택 메모 / 로컬 저장

### 2차: AI 진단 (실연동 완료)

- 어울림 판단 / 후보 비교 — 점수·코멘트
- 퍼스널 컬러 — **12계절 유형 고정**(유형 enum + 색상별 hex). Local Gemma / OpenAI / rule-based 폴백
- Local Gemma 온디바이스 챗봇

### 3차: 가상착장 (OpenAI 전용)

- 등록 얼굴 + 사용자 기본정보(키/몸무게/체형) + 스냅샷 원본 옷을 합성해
  `gpt-image-2`로 착장 이미지를 생성
- 비용 통제(중간 품질, 생성 횟수 상한, 재생성 확인, 캐싱) 포함

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

- 로그인/계정은 두지 않습니다. 오버레이 비교는 완전 오프라인으로 동작합니다.
- 얼굴 이미지와 스냅샷은 기본적으로 기기 내부에만 저장합니다.
- AI는 추상 인터페이스로 분리하고, Mock / Local Gemma(온디바이스) /
  OpenAI(프록시 경유) 구현체를 모드로 교체합니다. 배경 제거는 아직 Mock 구현입니다.
- OpenAI API 키는 앱에 두지 않고 백엔드 프록시(`bin/fitface_openai_proxy.dart`)가
  서버 환경변수로 보유합니다.
- 가상착장 등 이미지 생성은 클라우드(OpenAI `gpt-image-2`) 전용이며 비용 통제를 둡니다.
