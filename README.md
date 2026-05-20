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

## OpenAI Proxy

FitFace never stores an OpenAI API key in the mobile app. OpenAI mode calls a
small backend proxy, and the proxy reads the key from the server environment.

Run the local proxy:

```bash
$env:OPENAI_API_KEY="<your-openai-api-key>"
dart run bin/fitface_openai_proxy.dart
```

Optional environment variables:

```text
OPENAI_MODEL=gpt-5.4-mini
FITFACE_PROXY_HOST=127.0.0.1
FITFACE_PROXY_PORT=8787
FITFACE_PROXY_MAX_BODY_BYTES=12582912
FITFACE_PROXY_MAX_IMAGES=3
```

Then set the app's OpenAI proxy URL to the server URL, for example:

```text
http://127.0.0.1:8787
```

For Android emulator testing against a host-machine proxy, use:

```text
http://10.0.2.2:8787
```

The proxy exposes:

- `POST /ai/snapshot/analyze`
- `POST /ai/snapshots/compare`
- `POST /ai/personal-color`
- `GET /health`
