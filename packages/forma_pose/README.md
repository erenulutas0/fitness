# forma_pose

Camera + on-device pose estimation plugin for FORMA. See `docs/05` §8 for the API and `lib/src/frame_codec.dart`
for the binary wire format. Camera frames never reach Dart and never leave the device.

- `FormaPose.start(PoseStartOptions(...))` → `PoseEngineInfo`
- `FormaPose.frames` → `Stream<PoseFrame>` (33 landmarks + world landmarks, 15–30 Hz)
- `PosePreview()` → native camera preview (platform view)
- `FakeFormaPose.syntheticSquat()` / `FakeFormaPose.fixture(...)` → run without a camera

Model files: `apps/mobile/assets/models/pose_landmarker_{lite,full}.task` (download with `tools/fetch_models.*`).
The engine resolves them through Flutter's asset lookup (`assets/models/<file>`).

Licences: MediaPipe Tasks (Apache 2.0), CameraX (Apache 2.0).
