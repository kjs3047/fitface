# FitFace Implementation Review

Date: 2026-05-19

## Requirement Coverage

| Area | Evidence |
|---|---|
| Flutter project and platform structure | `pubspec.yaml`, `lib/`, `android/`, `ios/`, `windows/` |
| Presentation / Domain / Data / Core / Providers separation | `lib/presentation`, `lib/domain`, `lib/data`, `lib/core`, `lib/providers` |
| Face registration | `FaceRegisterScreen` with gallery and camera picker entry points |
| Face-to-neck crop | `FaceCropScreen` with guide frame, zoom/position controls, local cropped image output |
| Background removal extension point | `BackgroundRemovalService`, `MockBackgroundRemovalService` |
| Rear camera preview | `CameraMatchScreen` using `camera`, permission denied state, retry state |
| Face overlay | `FaceOverlayWidget`, `CameraOverlayProvider` drag, pinch scale, opacity, reset |
| Snapshot capture | `RepaintBoundary` capture in `CameraMatchScreen`, local PNG storage |
| Max 3 candidates and replacement | `SnapshotRepository.addSnapshot`, `replaceSnapshot`, replacement dialog |
| Candidate compare/detail/memo/delete | `CompareScreen`, `SnapshotDetailScreen` |
| Local storage | `LocalFileStorage` JSON metadata plus app document image files |
| Mock AI and personal color | `MockAiAnalysisService`, `MockPersonalColorService`, connected UI buttons/screens |
| Settings and reset | `SettingsScreen`, local data reset and privacy notice |
| Android/iOS permissions | `AndroidManifest.xml`, `Info.plist` camera/photo usage descriptions |

## Verification Run

| Check | Result |
|---|---|
| `puro -e stable flutter pub get` | Passed |
| `puro -e stable flutter analyze` | Passed, no issues found |
| `puro -e stable flutter test` | Passed, 11 tests |
| `puro -e stable flutter build apk --debug` | Passed, APK generated at `build/app/outputs/flutter-apk/app-debug.apk` |
| `puro -e stable flutter test integration_test -d windows` | Blocked by missing Visual Studio C++ toolchain |
| `puro -e stable flutter test integration_test -d emulator-5554` | Passed on Android emulator, first-launch onboarding e2e |

## Residual Risks

- Real camera preview, image picker, runtime permission dialogs, and physical pinch gestures still need manual testing on Android or iOS hardware because the automated e2e covers first-launch routing only.
- Flutter warned that current Android plugins still apply Kotlin Gradle Plugin directly. The build passes now, but future Flutter versions may require plugin upgrades.

## Code Review Notes

- The storage layer deletes only files under the FitFace app root when using `deleteFileSafely`, reducing accidental deletion risk.
- Candidate order is preserved by storage order so replacement changes the selected slot instead of re-sorting by timestamp.
- AI and background removal are behind interfaces, so real implementations can replace the mock services without changing UI call sites.
- Camera capture excludes the bottom controls by scoping `RepaintBoundary` to the preview/overlay stack.
