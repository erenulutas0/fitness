# Pose models

`pose_landmarker_lite.task` / `pose_landmarker_full.task` (MediaPipe Pose Landmarker, Apache 2.0) live here but are
**not committed**. Download them with `tools/fetch_models.ps1` (Windows) or `tools/fetch_models.sh`.

They belong to the plugin so the app and `example/` share one copy; the native engine resolves them as package
assets (`getAssetFilePathByName("assets/models/<file>", "forma_pose")`).

- lite (~5.8 MB): default on every device
- full (~9.4 MB): higher accuracy on mid/high-end devices, switchable at runtime with `FormaPose.setModel`
