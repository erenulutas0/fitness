import 'package:forma_pose/forma_pose.dart';

import '../../l10n/app_localizations.dart';

/// What went wrong when the camera would not start, in the app's own
/// vocabulary.
///
/// [PoseEngineException.message] is an English developer string written for a
/// log ("camera permission not granted"); it was reaching Turkish users
/// verbatim. The engine's job is to say what happened, this enum's job is to
/// say it in a sentence someone can act on.
enum PoseError {
  permission,
  camera,
  model,
  unsupported,
  busy,

  /// A route pointed at an exercise that is not in the content bundle — a
  /// bad deep link, not a camera problem.
  unknownExercise,
  unknown
  ;

  static PoseError fromCode(PoseErrorCode code) => switch (code) {
    PoseErrorCode.permissionDenied => PoseError.permission,
    PoseErrorCode.cameraUnavailable => PoseError.camera,
    PoseErrorCode.modelLoadFailed => PoseError.model,
    PoseErrorCode.notSupported => PoseError.unsupported,
    PoseErrorCode.alreadyRunning => PoseError.busy,
    PoseErrorCode.unknown => PoseError.unknown,
  };

  /// True when the way out is the OS settings page rather than a retry:
  /// Android stops showing the permission dialog after two denials.
  bool get needsSettings => this == PoseError.permission;

  String text(AppLocalizations l10n) => switch (this) {
    PoseError.permission => l10n.poseErrorPermission,
    PoseError.camera => l10n.poseErrorCamera,
    PoseError.model => l10n.poseErrorModel,
    PoseError.unsupported => l10n.poseErrorUnsupported,
    PoseError.busy => l10n.poseErrorBusy,
    PoseError.unknownExercise => l10n.poseErrorUnknownExercise,
    PoseError.unknown => l10n.poseErrorUnknown,
  };
}
