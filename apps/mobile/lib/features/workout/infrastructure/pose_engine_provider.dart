import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pose_engine_provider.g.dart';

/// Which engine the app should use. Tests and desktop override this with a
/// [FakeFormaPose]; on phones it is the native MediaPipe engine, and the
/// controller falls back to a synthetic engine if the native one reports
/// NOT_SUPPORTED (e.g. iOS until Prompt 8 lands).
@Riverpod(keepAlive: true)
FormaPosePlatform poseEngine(Ref ref) => FormaPose.platform;

/// Synthetic fallback used when no camera engine is available.
FakeFormaPose buildFallbackEngine(CameraView view) =>
    FakeFormaPose.syntheticSquat(
      view: view,
      valgus: view == CameraView.front ? 0.3 : 0,
      peakAngle: view == CameraView.side ? 112 : 90,
      reps: 4,
    );
