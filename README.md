# FitFace

> 한국어: [README.ko.md](README.ko.md)

FitFace is a local-first Flutter app for checking how clothing suits you in a
store — before the fitting room. You overlay your registered face-to-neck image
onto the rear-camera view of real clothes, and optional on-device or cloud AI
adds outfit judgments, personal-color diagnosis, and a virtual try-on preview.

## Features

### Core (offline, no account)
- Face photo registration from gallery or camera, with a face-to-neck crop flow.
- Background removal service abstraction (mock implementation).
- Rear-camera preview with permission/initialization handling.
- Draggable, pinch-zoomable, opacity-controlled face overlay.
- Snapshot capture that saves both the composited frame and an overlay-free
  original frame (the latter feeds virtual try-on).
- Up to three outfit candidates with replace/delete/memo, a compare screen, and
  a snapshot detail screen with a pinch-zoom image viewer.
- Local JSON metadata + local image storage under the app documents directory.

### AI (selectable per mode: Off / Mock / Local Gemma / OpenAI)
- **Outfit analysis & compare** — scores and styling comments for snapshots.
- **Personal color** — diagnosis fixed to the **12-season system** (warm/cool ×
  value × chroma). The type is constrained to a 12-label enum; recommended/avoid
  colors and comments are AI-generated and now carry their own hex codes so the
  swatches render the exact colors. Rule-based fallback covers all 12 types.
- **Virtual try-on** — generates an image of you (registered face + saved body
  profile) wearing a snapshot's outfit via OpenAI `gpt-image-2`. Cloud-only.
- **Local Gemma chatbot** — on-device chat when running in Local Gemma mode.

### User body info (for virtual try-on)
Height, weight, and a body type (gender × 6 types) are registered once under
**Settings → 사용자 기본정보** and reused on every try-on, instead of being
asked each time.

### Cost controls (virtual try-on)
Medium image quality by default, a per-snapshot generation cap, a confirm
dialog before regenerating, back-navigation blocked while generating, a result
cache (same snapshot + body type reuses the saved image), and a "결과 보기"
hint on the entry button once a result exists.

## Run

```bash
flutter pub get
flutter test
flutter test integration_test
flutter run
```

## OpenAI Proxy

FitFace never stores an OpenAI API key in the mobile app. OpenAI mode (analysis,
personal color, and virtual try-on) calls a small backend proxy, and the proxy
reads the key from the server environment.

Run the local proxy:

```bash
$env:OPENAI_API_KEY="<your-openai-api-key>"
dart run bin/fitface_openai_proxy.dart
```

Optional environment variables:

```text
OPENAI_MODEL=gpt-5.4-mini          # text analysis / personal color model
OPENAI_IMAGE_MODEL=gpt-image-2     # virtual try-on image model
FITFACE_PROXY_HOST=127.0.0.1
FITFACE_PROXY_PORT=8787
FITFACE_PROXY_MAX_BODY_BYTES=12582912
FITFACE_PROXY_MAX_IMAGES=3
FITFACE_PROXY_AUTH_TOKEN=<shared-secret>
```

If the proxy is reachable from other devices (for example
`FITFACE_PROXY_HOST=0.0.0.0`), set `FITFACE_PROXY_AUTH_TOKEN` to a shared secret.
The proxy then requires every `/ai/*` request to send the same value in an
`X-FitFace-Token` header (`/health` stays open for connection tests). Enter the
same token in the app under **Settings → AI 설정 → OpenAI 프록시 주소** so the
app attaches it automatically. When `FITFACE_PROXY_AUTH_TOKEN` is unset the proxy
keeps the previous behavior and does not require a token (local development).

Prefer binding to `127.0.0.1` unless you intentionally expose the proxy on your
LAN, and rotate the OpenAI API key if it has ever been stored in plaintext.

> Restart the proxy after pulling changes — new endpoints/models (e.g.
> `/ai/try-on`, `OPENAI_IMAGE_MODEL`) only take effect on a fresh start.

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
- `POST /ai/try-on`
- `GET /health`
