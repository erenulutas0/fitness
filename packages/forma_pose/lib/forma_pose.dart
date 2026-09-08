/// Camera + on-device pose estimation for FORMA.
///
/// The native layer (CameraX + MediaPipe Tasks on Android, AVFoundation +
/// MediaPipe Tasks on iOS) owns the camera and inference; Dart only receives
/// compact `PoseFrame`s. Camera pixels never cross into Dart and never leave
/// the device (docs/00 D3).
library;

export 'src/fake_forma_pose.dart';
export 'src/forma_pose.dart';
export 'src/forma_pose_platform_interface.dart';
export 'src/frame_codec.dart';
export 'src/method_channel_forma_pose.dart';
export 'src/pose_preview.dart';
