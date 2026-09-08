import '../features/feature_extractor.dart';
import '../filters/one_euro_filter.dart';
import '../gestures/gesture_detector.dart';
import '../pose_frame.dart';
import '../rep/rep_detector.dart';
import '../rules/exercise_definition.dart';
import '../rules/expression.dart';
import '../rules/rule_evaluator.dart';
import '../rules/scopes.dart';
import '../score/score_engine.dart';

/// Tunables for one [ExerciseSession].
class SessionConfig {
  const SessionConfig({
    this.smoothing = const SmoothingConfig(),
    this.minTrackingConfidence = 0.5,
    this.minSignalConfidence = 0.4,
    this.extractorMinVisibility = 0.5,
    this.detectGestures = false,
    this.gestures = const GestureConfig(),
  });

  final SmoothingConfig smoothing;

  /// Mean core-landmark visibility below which the session freezes
  /// ("seni net göremiyorum").
  final double minTrackingConfidence;

  /// Rep signal / hold condition confidence below which the frame is ignored.
  final double minSignalConfidence;
  final double extractorMinVisibility;
  final bool detectGestures;
  final GestureConfig gestures;
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

sealed class SessionEvent {
  const SessionEvent(this.tMs);

  final int tMs;
}

class SessionPhaseChanged extends SessionEvent {
  const SessionPhaseChanged(super.tMs, this.from, this.to);

  final RepPhase from;
  final RepPhase to;
}

class SessionRepCompleted extends SessionEvent {
  const SessionRepCompleted(super.tMs, this.rep);

  final RepResult rep;
}

class SessionRepRejected extends SessionEvent {
  const SessionRepRejected(super.tMs, this.reason, this.durationMs);

  final RepRejectReason reason;
  final int durationMs;
}

class SessionRuleTriggered extends SessionEvent {
  const SessionRuleTriggered(super.tMs, this.rule);

  final RuleEvent rule;
}

class SessionTrackingChanged extends SessionEvent {
  const SessionTrackingChanged(
    super.tMs, {
    required this.tracking,
    required this.confidence,
  });

  final bool tracking;
  final double confidence;
}

class SessionHoldStarted extends SessionEvent {
  const SessionHoldStarted(super.tMs);
}

class SessionHoldProgress extends SessionEvent {
  const SessionHoldProgress(super.tMs, this.heldMs);

  final int heldMs;
}

class SessionHoldEnded extends SessionEvent {
  const SessionHoldEnded(super.tMs, this.hold);

  final HoldResult hold;
}

class SessionGesture extends SessionEvent {
  const SessionGesture(super.tMs, this.gesture);

  final Gesture gesture;
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class RepResult {
  const RepResult({
    required this.index,
    required this.summary,
    required this.score,
    required this.ruleResults,
  });

  final int index;
  final RepSummary summary;
  final RepScore score;
  final Map<String, RuleResult> ruleResults;

  int get tempoDownMs => summary.toPeakMs;
  int get tempoUpMs => summary.toRestMs;

  List<String> get failedRules => [
    for (final r in ruleResults.values)
      if (r.triggered) r.ruleId,
  ];

  Map<String, dynamic> toJson() => {
    'index': index,
    'startMs': summary.startMs,
    'endMs': summary.endMs,
    'tempoDownMs': tempoDownMs,
    'tempoUpMs': tempoUpMs,
    'extremeValue': summary.extremeValue,
    'score': score.rounded,
    'errors': failedRules,
  };
}

class HoldResult {
  const HoldResult({
    required this.index,
    required this.heldMs,
    required this.endMs,
    required this.score,
    required this.ruleResults,
  });

  final int index;
  final int heldMs;
  final int endMs;
  final RepScore score;
  final Map<String, RuleResult> ruleResults;

  List<String> get failedRules => [
    for (final r in ruleResults.values)
      if (r.triggered) r.ruleId,
  ];

  Map<String, dynamic> toJson() => {
    'index': index,
    'heldMs': heldMs,
    'endMs': endMs,
    'score': score.rounded,
    'errors': failedRules,
  };
}

/// Aggregate of one set (one exercise, one camera placement).
class SetResult {
  const SetResult({
    required this.exerciseId,
    required this.view,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.reps,
    required this.holds,
  });

  final String exerciseId;
  final CameraView view;
  final int startedAtMs;
  final int endedAtMs;
  final List<RepResult> reps;
  final List<HoldResult> holds;

  int get durationMs => endedAtMs - startedAtMs;
  int get repCount => reps.length;
  int get totalHoldMs => holds.fold(0, (a, h) => a + h.heldMs);

  /// Mean score over reps (or holds); null if nothing was completed.
  double? get formScore {
    final scores = [
      for (final r in reps) r.score.score,
      for (final h in holds) h.score.score,
    ];
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// How many reps / holds failed each rule.
  Map<String, int> get errorCounts {
    final out = <String, int>{};
    for (final r in reps) {
      for (final id in r.failedRules) {
        out[id] = (out[id] ?? 0) + 1;
      }
    }
    for (final h in holds) {
      for (final id in h.failedRules) {
        out[id] = (out[id] ?? 0) + 1;
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'view': view.name,
    'startedAtMs': startedAtMs,
    'endedAtMs': endedAtMs,
    'formScore': formScore,
    'reps': [for (final r in reps) r.toJson()],
    'holds': [for (final h in holds) h.toJson()],
    'errorCounts': errorCounts,
  };
}

/// Immutable view of the live state for the HUD.
class SessionSnapshot {
  const SessionSnapshot({
    required this.phase,
    required this.repCount,
    required this.tracking,
    required this.confidence,
    required this.holdMs,
    required this.isHolding,
    this.lastRepScore,
    this.averageScore,
    this.signalValue,
    this.currentRepElapsedMs,
    this.gestureCandidate,
    this.gestureProgress = 0,
  });

  final RepPhase phase;
  final int repCount;
  final bool tracking;
  final double confidence;
  final int holdMs;
  final bool isHolding;
  final double? lastRepScore;
  final double? averageScore;
  final double? signalValue;
  final int? currentRepElapsedMs;
  final Gesture? gestureCandidate;
  final double gestureProgress;
}

/// The full per-frame pipeline for one exercise set:
/// smoother → features → rep FSM / hold → rules → score.
///
/// Pure Dart, synchronous, deterministic: feed [PoseFrame]s in order and read
/// the returned events. Nothing here touches Flutter, audio or the camera.
class ExerciseSession {
  ExerciseSession({
    required this.definition,
    required this.view,
    this.config = const SessionConfig(),
  }) : _smoother = LandmarkSmoother(config.smoothing),
       _extractor = FeatureExtractor(
         minVisibility: config.extractorMinVisibility,
       ),
       _rules = RuleEvaluator(definition: definition, view: view),
       _score = ScoreEngine(definition.score),
       _gestures = config.detectGestures
           ? GestureDetector(config.gestures)
           : null {
    if (!definition.cameraViews.contains(view)) {
      throw ArgumentError(
        '${definition.id} does not support view ${view.name}',
      );
    }
    if (definition.countMode == CountMode.reps) {
      final spec = definition.repFor(view);
      if (spec == null) {
        throw ArgumentError('${definition.id}: no rep spec for ${view.name}');
      }
      _rep = RepDetector(spec.toConfig());
      _signal = spec.signalExpr;
    } else {
      final hold = definition.hold;
      if (hold == null) throw ArgumentError('${definition.id}: no hold spec');
      _hold = HoldDetector(hold.toConfig());
      _holdCondition = hold.conditionExpr;
    }
  }

  final ExerciseDefinition definition;
  final CameraView view;
  final SessionConfig config;

  final LandmarkSmoother _smoother;
  final FeatureExtractor _extractor;
  final RuleEvaluator _rules;
  final ScoreEngine _score;
  final GestureDetector? _gestures;
  static const _eval = ExpressionEvaluator();

  RepDetector? _rep;
  Expr? _signal;
  HoldDetector? _hold;
  Expr? _holdCondition;

  final List<RepResult> _reps = [];
  final List<HoldResult> _holds = [];
  int? _startedAtMs;
  int _lastTs = 0;
  bool _tracking = false;
  double _confidence = 0;
  double? _signalValue;
  FeatureSet? _lastFeatures;

  /// Features of the most recent frame (for overlays / debugging).
  FeatureSet? get lastFeatures => _lastFeatures;

  List<RepResult> get reps => List.unmodifiable(_reps);
  List<HoldResult> get holds => List.unmodifiable(_holds);

  SessionSnapshot get snapshot {
    final rep = _rep;
    final hold = _hold;
    final scores = [
      for (final r in _reps) r.score.score,
      for (final h in _holds) h.score.score,
    ];
    return SessionSnapshot(
      phase:
          rep?.phase ??
          (hold != null && hold.isHolding ? RepPhase.peak : RepPhase.rest),
      repCount: rep?.count ?? 0,
      tracking: _tracking,
      confidence: _confidence,
      holdMs: hold?.heldMs(_lastTs) ?? 0,
      isHolding: hold?.isHolding ?? false,
      lastRepScore: _reps.isEmpty
          ? (_holds.isEmpty ? null : _holds.last.score.score)
          : _reps.last.score.score,
      averageScore: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      signalValue: _tracking ? _signalValue : null,
      currentRepElapsedMs: _tracking ? rep?.elapsedMs(_lastTs) : null,
      gestureCandidate: _gestures?.candidate,
      gestureProgress: _gestures?.progress(_lastTs) ?? 0,
    );
  }

  /// Process one raw frame. Returns the events produced by this frame.
  List<SessionEvent> process(PoseFrame raw) {
    final t = raw.timestampMs;
    _startedAtMs ??= t;
    _lastTs = t;
    final events = <SessionEvent>[];

    final frame = _smoother.smooth(raw);
    final fs = _extractor.extract(frame);
    _lastFeatures = fs;

    final conf = raw.hasPose ? (fs.value('vis_core') ?? 0) : 0.0;
    _confidence = conf;
    final tracking = raw.hasPose && conf >= config.minTrackingConfidence;
    if (tracking != _tracking) {
      _tracking = tracking;
      events.add(
        SessionTrackingChanged(t, tracking: tracking, confidence: conf),
      );
    }

    final gestures = _gestures;
    if (gestures != null && raw.hasPose) {
      final g = gestures.update(fs, t);
      if (g != null) events.add(SessionGesture(t, g));
    }

    if (!tracking) {
      // Out of frame: a rep in progress must not be completed later as if
      // nothing happened, and a hold must stop accruing time (docs/06 §7).
      if (definition.countMode == CountMode.reps) {
        if (_rep!.abort()) _rules.discardRep();
      } else {
        for (final e in _hold!.update(false, t)) {
          if (e is HoldEnded) _closeHold(t, e.heldMs, events);
        }
      }
      return events;
    }

    if (definition.countMode == CountMode.reps) {
      _processReps(fs, t, events);
    } else {
      _processHold(fs, t, events);
    }
    return events;
  }

  void _processReps(FeatureSet fs, int t, List<SessionEvent> events) {
    final rep = _rep!;
    EvalValue sig;
    try {
      sig = _eval.eval(_signal!, FrameScope(fs));
    } on ExpressionException {
      return;
    }
    if (sig.confidence < config.minSignalConfidence) return;
    final value = sig.asDouble;
    _signalValue = value;

    for (final e in rep.update(value, t)) {
      switch (e) {
        case PhaseChanged(:final from, :final to):
          events.add(SessionPhaseChanged(t, from, to));
        case RepCompleted(:final summary):
          final outcome = _rules.onRepEnd(t);
          final score = _score.score(outcome.results);
          final result = RepResult(
            index: summary.index,
            summary: summary,
            score: score,
            ruleResults: outcome.results,
          );
          _reps.add(result);
          for (final re in outcome.events) {
            events.add(SessionRuleTriggered(t, re));
          }
          events.add(SessionRepCompleted(t, result));
        case RepRejected(:final reason, :final durationMs):
          _rules.discardRep();
          events.add(SessionRepRejected(t, reason, durationMs));
      }
    }

    for (final re in _rules.onFrame(fs, rep.phase, t)) {
      events.add(SessionRuleTriggered(t, re));
    }
  }

  void _processHold(FeatureSet fs, int t, List<SessionEvent> events) {
    final hold = _hold!;
    EvalValue cond;
    try {
      cond = _eval.eval(_holdCondition!, FrameScope(fs));
    } on ExpressionException {
      return;
    }
    final holding =
        cond.confidence >= config.minSignalConfidence && cond.truthy;
    for (final e in hold.update(holding, t)) {
      switch (e) {
        case HoldStarted():
          events.add(SessionHoldStarted(t));
        case HoldProgress(:final heldMs):
          events.add(SessionHoldProgress(t, heldMs));
        case HoldEnded(:final heldMs):
          _closeHold(t, heldMs, events);
      }
    }
    if (hold.isHolding) {
      for (final re in _rules.onFrame(fs, RepPhase.peak, t)) {
        events.add(SessionRuleTriggered(t, re));
      }
    }
  }

  void _closeHold(int t, int heldMs, List<SessionEvent> events) {
    final outcome = _rules.onRepEnd(t);
    final score = _score.score(outcome.results);
    final result = HoldResult(
      index: _holds.length + 1,
      heldMs: heldMs,
      endMs: t,
      score: score,
      ruleResults: outcome.results,
    );
    _holds.add(result);
    for (final re in outcome.events) {
      events.add(SessionRuleTriggered(t, re));
    }
    events.add(SessionHoldEnded(t, result));
  }

  /// End the set. Closes an in-progress hold; an unfinished rep is dropped.
  SetResult finish([int? tMs]) {
    final t = tMs ?? _lastTs;
    final hold = _hold;
    if (hold != null) {
      final ended = hold.finish(t);
      if (ended != null && ended.heldMs >= hold.config.minHoldMs) {
        _closeHold(t, ended.heldMs, <SessionEvent>[]);
      }
    }
    return SetResult(
      exerciseId: definition.id,
      view: view,
      startedAtMs: _startedAtMs ?? t,
      endedAtMs: t,
      reps: List.unmodifiable(_reps),
      holds: List.unmodifiable(_holds),
    );
  }
}
