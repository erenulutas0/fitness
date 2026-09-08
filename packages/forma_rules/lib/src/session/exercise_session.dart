import 'dart:math' as math;

import '../features/feature_extractor.dart';
import '../filters/one_euro_filter.dart';
import '../geometry.dart';
import '../gestures/gesture_detector.dart';
import '../landmarks.dart';
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
    this.minSignalConfidence = 0.5,
    this.extractorMinVisibility = 0.5,
    this.requireBodyInFrame = true,
    this.frameEdgeMargin = 0,
    this.maxBodyHeightFraction = 0.97,
    this.maxShinThighRatio = 1.6,
    this.signalLossGraceMs = 300,
    this.detectGestures = false,
    this.gestures = const GestureConfig(),
  });

  final SmoothingConfig smoothing;

  /// Mean core-landmark visibility below which the session freezes
  /// ("seni net göremiyorum").
  final double minTrackingConfidence;

  /// Rep signal / hold condition confidence below which the frame is ignored.
  ///
  /// Kept equal to the rules' own `minConfidence` on purpose: with a lower
  /// value the coach counts reps it will never comment on, which reads as
  /// "it sees me but has nothing to say".
  final double minSignalConfidence;
  final double extractorMinVisibility;

  /// Freeze while a joint the rules depend on is outside the picture.
  ///
  /// The model keeps predicting joints that have left the shot and still
  /// reports high visibility for them, so visibility alone cannot catch a
  /// cropped frame. It does place them outside the normalized 0..1 range,
  /// which is a clean signal: measured over 26 recordings, every clip that
  /// produced impossible knee angles (3-12 degrees) had joints out of range
  /// in 59-100% of frames, while none of the properly framed phone
  /// recordings had a single one.
  final bool requireBodyInFrame;

  /// Extra tolerance around the edge. 0 means "only reject what is actually
  /// outside", which is what real recordings want: at the bottom of a squat
  /// the hips legitimately come close to the lower edge.
  final double frameEdgeMargin;

  /// Body taller than this share of the picture means the camera is too
  /// close for the whole body to fit, even when nothing has left the frame.
  final double maxBodyHeightFraction;

  /// Anatomical sanity check: a shin is never much longer than a thigh.
  ///
  /// Foreshortening can stretch the ratio a little, but not past ~1.5.
  /// Measured over the corpus: properly framed recordings never exceeded
  /// 1.21, while clips where the model invented a skeleton reached 1.6-25 in
  /// 3-73% of their frames. Catches the case the frame-edge check cannot: a
  /// close-up where the joints stay inside the picture but the body does not.
  final double maxShinThighRatio;

  /// How long the rep signal may stay below [minSignalConfidence] before the
  /// rep in progress is abandoned. Long enough to ride out a noisy frame,
  /// short enough that the blind stretch never lands inside a counted rep.
  final int signalLossGraceMs;
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
    this.bodyInFrame = true,
  });

  final bool tracking;
  final double confidence;

  /// False when tracking stopped because a joint left the picture rather than
  /// because the model lost confidence: the coach should say "step back",
  /// not "I cannot see you".
  final bool bodyInFrame;
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
    this.bodyInFrame = true,
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

  /// False when the body is cut off by the edge of the picture; the HUD can
  /// then say "step back" instead of the generic "I cannot see you".
  final bool bodyInFrame;
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
  bool _bodyInFrame = true;
  double _confidence = 0;
  double? _signalValue;
  int? _signalLostSinceMs;
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
      bodyInFrame: _bodyInFrame,
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

  /// True while the joints the rules depend on sit inside the picture.
  ///
  /// Only the core chain is checked (shoulders, hips, knees, ankles): an arm
  /// swinging out of shot is harmless, a knee outside it is not, and requiring
  /// the whole bounding box threw away valid reps in real recordings.
  bool _isBodyInFrame(FeatureSet fs) {
    final m = config.frameEdgeMargin;
    for (final l in coreLandmarks) {
      final lm = fs.frame[l];
      if (lm.visibility < config.extractorMinVisibility) continue;
      if (lm.x < m || lm.x > 1 - m || lm.y < m || lm.y > 1 - m) {
        return false;
      }
    }
    // Nothing has left the shot, but the body may still fill it completely,
    // which means the camera is too close to see the whole movement.
    final height = fs.value('bbox_height') ?? 0;
    if (height > config.maxBodyHeightFraction) return false;
    return _isSkeletonPlausible(fs);
  }

  /// Reject frames whose skeleton cannot belong to a human body.
  bool _isSkeletonPlausible(FeatureSet fs) {
    final hip = fs.point('hip_mid');
    final knee = fs.point('knee_mid');
    final ankle = fs.point('ankle_mid');
    if (hip == null || knee == null || ankle == null) return true;
    if (math.min(hip.confidence, math.min(knee.confidence, ankle.confidence)) <
        config.extractorMinVisibility) {
      return true;
    }
    final thigh = Vec2.distance(hip.p, knee.p);
    final shin = Vec2.distance(knee.p, ankle.p);
    if (thigh < 1e-4) return true;
    return shin / thigh <= config.maxShinThighRatio;
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
    _bodyInFrame = !config.requireBodyInFrame || _isBodyInFrame(fs);
    final tracking =
        raw.hasPose && conf >= config.minTrackingConfidence && _bodyInFrame;
    if (tracking != _tracking) {
      _tracking = tracking;
      events.add(
        SessionTrackingChanged(
          t,
          tracking: tracking,
          confidence: conf,
          bodyInFrame: _bodyInFrame,
        ),
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
          if (e is HoldEnded) {
            _closeHold(t, e.heldMs, events);
          } else if (e is HoldAborted) {
            _rules.discardRep();
          }
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
    if (sig.confidence < config.minSignalConfidence) {
      // The signal can go blind while overall tracking still looks fine: both
      // ankles at 0.3 with the rest of the body clear keeps mean visibility
      // above the tracking gate but takes knee_angle below the signal gate.
      // Skipping frames leaves the rep open, so the blind stretch lands inside
      // its duration — wrong tempo, and past maxDurationMs the rep is rejected
      // and never counted. Give it a moment for a noisy frame, then abandon
      // the rep the same way losing the body does.
      _signalLostSinceMs ??= t;
      if (t - _signalLostSinceMs! > config.signalLossGraceMs && _rep!.abort()) {
        _rules.discardRep();
      }
      return;
    }
    _signalLostSinceMs = null;
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
        case HoldAborted():
          // Too short to count, but the rules were accumulating: drop them so
          // the next attempt starts clean.
          _rules.discardRep();
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
