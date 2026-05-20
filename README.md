# FitFace

FitFace is a local-first Flutter MVP for checking how a registered face-to-neck image matches clothing in a store camera view.

## Implemented MVP Scope

- Face photo registration from gallery or camera.
- Face-to-neck crop flow with a guide overlay and local cropped file output.
- Background removal service abstraction with a mock implementation.
- Rear camera preview with permission and initialization states.
- Draggable, pinch-zoomable, opacity-controlled face overlay.
- Snapshot capture of the camera and overlay area.
- Local JSON metadata and local image storage under the app documents directory.
- Up to three outfit candidates with replace/delete/update memo flows.
- Compare screen, snapshot detail screen, settings screen.
- Mock AI analysis and mock personal color analysis service boundaries.
- Unit/widget/integration test files for the documented flows.

## Run

```bash
flutter pub get
flutter test
flutter test integration_test
flutter run
```

The current machine used for implementation did not have `flutter` or `dart` available in PATH, so runtime verification must be executed in an environment with Flutter installed.
