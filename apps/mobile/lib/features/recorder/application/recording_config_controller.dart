import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'recorder_controller.dart';

part 'recording_config_controller.g.dart';

/// Keeps the last used recording metadata so a session of 10 takes does not
/// retype the participant code, environment and camera every time.
@Riverpod(keepAlive: true)
class RecordingConfigController extends _$RecordingConfigController {
  @override
  RecordingConfig build() =>
      const RecordingConfig(exerciseId: 'bw_squat', view: CameraView.side);

  // ignore: use_setters_to_change_properties, a notifier mutation, not a property
  void update(RecordingConfig config) => state = config;
}
