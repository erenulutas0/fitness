import '../features/feature_extractor.dart';
import '../rep/rep_detector.dart';
import 'exercise_definition.dart';
import 'expression.dart';
import 'scopes.dart';

/// A rule that fired (live, during a rep) or was confirmed at rep end.
class RuleEvent {
  const RuleEvent({
    required this.ruleId,
    required this.severity,
    required this.confidence,
    required this.tMs,
    required this.evaluateAt,
    required this.repIndex,
    this.cue,
    this.value,
  });

  final String ruleId;
  final String? cue;
  final int severity;
  final double confidence;
  final int tMs;
  final EvaluateAt evaluateAt;

  /// 1-based index of the rep (or hold) during which the rule fired.
  final int repIndex;

  /// Scalar value of the expression for rep-end rules.
  final double? value;

  /// severity × confidence — used by the feedback scheduler to rank cues.
  double get priorityScore => severity * confidence;

  @override
  String toString() =>
      'RuleEvent($ruleId rep=$repIndex sev=$severity conf=${confidence.toStringAsFixed(2)})';
}

/// Per-rule outcome for one completed rep / hold.
class RuleResult {
  const RuleResult({
    required this.ruleId,
    required this.triggered,
    required this.confidence,
    this.fraction,
    this.value,
    this.gatedFrames = 0,
  });

  final String ruleId;
  final bool triggered;
  final double confidence;

  /// Instant rules: fraction of gated frames in which the rule was true.
  final double? fraction;

  /// Rep-end rules: scalar value of the expression.
  final double? value;

  final int gatedFrames;

  @override
  String toString() =>
      'RuleResult($ruleId triggered=$triggered frac=${fraction?.toStringAsFixed(2)} value=${value?.toStringAsFixed(1)})';
}

/// Everything the evaluator knows once a rep / hold has ended.
class RepRuleOutcome {
  const RepRuleOutcome({required this.results, required this.events});

  final Map<String, RuleResult> results;

  /// Rep-end rule events that fired for this rep.
  final List<RuleEvent> events;

  Iterable<RuleResult> get triggered =>
      results.values.where((r) => r.triggered);
}

class _Acc {
  int gated = 0;
  int hits = 0;
  int consecutive = 0;
  double confSum = 0;
  int? lastFiredMs;
}

/// Evaluates the rules of an [ExerciseDefinition] frame by frame and at rep
/// end. Pure and synchronous; owns no timers.
class RuleEvaluator {
  RuleEvaluator({
    required this.definition,
    required this.view,
    this.maxBufferedFrames = 900,
    this.evaluator = const ExpressionEvaluator(),
  }) : _instant = definition
           .rulesFor(view)
           .where((r) => r.evaluateAt == EvaluateAt.instant)
           .toList(),
       _atEnd = definition
           .rulesFor(view)
           .where((r) => r.evaluateAt == EvaluateAt.repEnd)
           .toList() {
    for (final r in _instant) {
      _acc[r.id] = _Acc();
    }
  }

  final ExerciseDefinition definition;
  final CameraView view;

  /// Upper bound on frames buffered per rep for rep-end series evaluation.
  final int maxBufferedFrames;
  final ExpressionEvaluator evaluator;

  final List<RuleSpec> _instant;
  final List<RuleSpec> _atEnd;
  final Map<String, _Acc> _acc = {};
  final List<FeatureSet> _buffer = [];
  final List<RepPhase> _bufferPhases = [];
  int _repIndex = 1;

  /// 1-based index of the rep currently in progress.
  int get currentRepIndex => _repIndex;

  List<RuleSpec> get instantRules => List.unmodifiable(_instant);
  List<RuleSpec> get repEndRules => List.unmodifiable(_atEnd);

  /// Feed one frame (already smoothed + featurised) with the current phase.
  /// Returns live rule events (cues to play now).
  List<RuleEvent> onFrame(FeatureSet fs, RepPhase phase, int tMs) {
    final events = <RuleEvent>[];
    // Only frames that belong to a rep are worth keeping for the rep-end
    // series. Standing between reps would otherwise fill the buffer, and once
    // it is full the rep's own frames never get in: `min(knee_angle) > 105`
    // would then be measured on someone standing upright and fire on every
    // rep. Holds are unaffected — they always report `peak`.
    if (phase != RepPhase.rest && _buffer.length < maxBufferedFrames) {
      _buffer.add(fs);
      _bufferPhases.add(phase);
    }
    final scope = FrameScope(fs);
    for (final rule in _instant) {
      final acc = _acc[rule.id]!;
      if (!rule.gates(phase)) {
        acc.consecutive = 0;
        continue;
      }
      EvalValue v;
      try {
        v = evaluator.eval(rule.exprAst, scope);
      } on ExpressionException {
        acc.consecutive = 0;
        continue;
      }
      if (v.confidence < rule.minConfidence) {
        acc.consecutive = 0;
        continue;
      }
      acc.gated++;
      acc.confSum += v.confidence;
      if (v.truthy) {
        acc.hits++;
        acc.consecutive++;
        final last = acc.lastFiredMs;
        final canFire = last == null || tMs - last >= rule.refireMs;
        if (acc.consecutive >= rule.minConsecutiveFrames && canFire) {
          acc.lastFiredMs = tMs;
          events.add(
            RuleEvent(
              ruleId: rule.id,
              cue: rule.cue,
              severity: rule.severity,
              confidence: v.confidence,
              tMs: tMs,
              evaluateAt: EvaluateAt.instant,
              repIndex: _repIndex,
            ),
          );
        }
      } else {
        acc.consecutive = 0;
      }
    }
    return events;
  }

  /// Close the current rep / hold: compute per-rule results, evaluate
  /// rep-end rules on the buffered series, then reset for the next rep.
  RepRuleOutcome onRepEnd(int tMs) {
    final results = <String, RuleResult>{};
    final events = <RuleEvent>[];

    for (final rule in _instant) {
      final acc = _acc[rule.id]!;
      final fraction = acc.gated > 0 ? acc.hits / acc.gated : 0.0;
      final conf = acc.gated > 0 ? acc.confSum / acc.gated : 0.0;
      results[rule.id] = RuleResult(
        ruleId: rule.id,
        triggered:
            acc.gated >= rule.minGatedFrames && fraction >= rule.minFraction,
        confidence: conf,
        fraction: fraction,
        gatedFrames: acc.gated,
      );
    }

    for (final rule in _atEnd) {
      final frames = <FeatureSet>[];
      for (var i = 0; i < _buffer.length; i++) {
        if (rule.gates(_bufferPhases[i])) frames.add(_buffer[i]);
      }
      var triggered = false;
      var conf = 0.0;
      double? value;
      if (frames.isNotEmpty) {
        try {
          final v = evaluator.eval(rule.exprAst, SeriesScope(frames));
          conf = v.confidence;
          value = v.asDouble;
          triggered = v.truthy && conf >= rule.minConfidence;
        } on ExpressionException {
          triggered = false;
        }
      }
      results[rule.id] = RuleResult(
        ruleId: rule.id,
        triggered: triggered,
        confidence: conf,
        value: value,
        gatedFrames: frames.length,
      );
      if (triggered) {
        events.add(
          RuleEvent(
            ruleId: rule.id,
            cue: rule.cue,
            severity: rule.severity,
            confidence: conf,
            tMs: tMs,
            evaluateAt: EvaluateAt.repEnd,
            repIndex: _repIndex,
            value: value,
          ),
        );
      }
    }

    _resetRep();
    _repIndex++;
    return RepRuleOutcome(results: results, events: events);
  }

  /// Drop the accumulated frames of a rep that was rejected (too fast/slow)
  /// without producing results or advancing the rep index.
  void discardRep() => _resetRep();

  void _resetRep() {
    for (final a in _acc.values) {
      a
        ..gated = 0
        ..hits = 0
        ..consecutive = 0
        ..confSum = 0
        ..lastFiredMs = null;
    }
    _buffer.clear();
    _bufferPhases.clear();
  }

  void reset() {
    _resetRep();
    _repIndex = 1;
  }
}
