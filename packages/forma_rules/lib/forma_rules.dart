/// FORMA's pure-Dart exercise form engine.
///
/// Pipeline: `PoseFrame` → `LandmarkSmoother` → `FeatureExtractor` →
/// `RepDetector` / `HoldDetector` → `RuleEvaluator` → `ScoreEngine` →
/// `FeedbackScheduler`. `ExerciseSession` wires it together.
library;

export 'src/features/feature_extractor.dart';
export 'src/feedback/cue_catalog.dart';
export 'src/feedback/feedback_scheduler.dart';
export 'src/filters/one_euro_filter.dart';
export 'src/fixtures/fixture.dart';
export 'src/geometry.dart';
export 'src/gestures/gesture_detector.dart';
export 'src/landmarks.dart';
export 'src/pose_frame.dart';
export 'src/rep/rep_detector.dart';
export 'src/rules/exercise_definition.dart';
export 'src/rules/expression.dart';
export 'src/rules/rule_evaluator.dart';
export 'src/rules/scopes.dart';
export 'src/score/score_engine.dart';
export 'src/session/exercise_session.dart';
export 'src/setup/framing_checker.dart';
export 'src/synthetic/synthetic_pose.dart';
