import 'package:flutter/foundation.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_controller.g.dart';

/// One finished set, plus the pose the user held at its deepest point.
///
/// The pose is landmarks only and never leaves the phone unless the user
/// shares the card themselves (docs/06 §4.5: a drawing, not a video).
@immutable
class SessionSet {
  const SessionSet({required this.result, this.pose});

  final SetResult result;
  final PoseFrame? pose;
}

/// One workout session: several sets of the same exercise, back to back.
///
/// Kept in memory for now. Persisting it (docs/05 §9) is the next step and
/// needs a storage decision — see the note in TODO about drift_dev clashing
/// with the analyzer version custom_lint and freezed pin.
@immutable
class WorkoutSessionState {
  const WorkoutSessionState({
    this.exerciseId,
    this.view = CameraView.side,
    this.sets = const [],
    this.setTotal = defaultSetTotal,
    this.id = '',
    this.startedAt,
  });

  static const defaultSetTotal = 3;

  final String? exerciseId;
  final CameraView view;
  final List<SessionSet> sets;
  final int setTotal;

  /// Identity and start time, fixed when the session begins so the stored
  /// record and the "vs last session" lookup agree on which one is which.
  final String id;
  final DateTime? startedAt;

  /// 1-based number of the set about to be performed.
  int get currentSetIndex => sets.length + 1;

  bool get isActive => exerciseId != null;

  /// True once the planned sets are done. The user can still add more.
  bool get isComplete => sets.length >= setTotal;

  /// Mean form score over the sets that produced one.
  double? get meanScore {
    final scores = [
      for (final s in sets)
        if (s.result.formScore != null) s.result.formScore!,
    ];
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  int get totalReps => sets.fold(0, (a, s) => a + s.result.repCount);
  int get totalHoldMs => sets.fold(0, (a, s) => a + s.result.totalHoldMs);

  /// The pose to put on the shareable card: the deepest one recorded in the
  /// best-scoring set, so the card shows the user at their best.
  PoseFrame? get bestPose {
    SessionSet? best;
    for (final s in sets) {
      if (s.pose == null) continue;
      if (best == null ||
          (s.result.formScore ?? 0) > (best.result.formScore ?? 0)) {
        best = s;
      }
    }
    return best?.pose;
  }

  /// How often each rule fired across the whole session.
  Map<String, int> get errorCounts {
    final out = <String, int>{};
    for (final s in sets) {
      for (final e in s.result.errorCounts.entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value;
      }
    }
    return out;
  }

  WorkoutSessionState copyWith({
    String? exerciseId,
    CameraView? view,
    List<SessionSet>? sets,
    int? setTotal,
  }) => WorkoutSessionState(
    exerciseId: exerciseId ?? this.exerciseId,
    view: view ?? this.view,
    sets: sets ?? this.sets,
    setTotal: setTotal ?? this.setTotal,
    id: id,
    startedAt: startedAt,
  );
}

@Riverpod(keepAlive: true)
class WorkoutSessionController extends _$WorkoutSessionController {
  @override
  WorkoutSessionState build() => const WorkoutSessionState();

  /// Begin a session, or keep the one already running for this exercise.
  ///
  /// The HUD calls this on every entry, including the second and third set,
  /// so switching exercise mid-session starts a new session rather than
  /// mixing squats and push-ups into one score.
  void begin(String exerciseId, CameraView view) {
    if (state.exerciseId == exerciseId && state.view == view) return;
    final now = DateTime.now();
    state = WorkoutSessionState(
      exerciseId: exerciseId,
      view: view,
      id: '${exerciseId}_${now.millisecondsSinceEpoch}',
      startedAt: now,
    );
  }

  /// Record a finished set. Empty sets (nothing counted) are dropped: they
  /// are usually a false start, and averaging a zero into the session score
  /// would punish the user for it.
  void recordSet(SetResult result, {PoseFrame? pose}) {
    if (result.repCount == 0 && result.totalHoldMs == 0) return;
    state = state.copyWith(
      sets: [
        ...state.sets,
        SessionSet(result: result, pose: pose),
      ],
    );
  }

  void setTotal(int total) =>
      state = state.copyWith(setTotal: total.clamp(1, 10));

  void reset() => state = const WorkoutSessionState();
}
