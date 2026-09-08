import 'dart:math' as math;

import '../rules/rule_evaluator.dart';
import '../session/exercise_session.dart';
import 'cue_catalog.dart';

/// What the audio / haptic layer should do right now.
class CueCommand {
  const CueCommand({
    required this.clipId,
    required this.variant,
    required this.priority,
    required this.haptic,
    required this.tMs,
    this.text,
    this.ruleId,
    this.interrupts = false,
  });

  final String clipId;

  /// Phrasing variant index (`assets/audio/cues/<locale>/<clipId>_<n>.opus`).
  final int variant;
  final int priority;
  final HapticKind haptic;
  final int tMs;

  /// Resolved text for the scheduler's locale (HUD subtitle).
  final String? text;

  /// Rule that caused the cue, if any.
  final String? ruleId;

  /// Whether the player should cut a currently playing lower-priority clip.
  final bool interrupts;

  @override
  String toString() =>
      'Cue($clipId#$variant p=$priority${ruleId == null ? '' : ' rule=$ruleId'})';
}

/// The anti-spam policy from docs/05 §5.
class FeedbackPolicy {
  const FeedbackPolicy({
    this.cueCooldownMs = 4000,
    this.sameRepCooldownMs = 6000,
    this.rephraseAfterConsecutiveReps = 3,
    this.muteAfterConsecutiveReps = 5,
    this.positiveEveryCleanReps = 3,
    this.positiveJitter = 1,
    this.minConfidence = 0.6,
    this.lowConfidenceCueEveryMs = 8000,
    this.countReps = true,
    this.quietMode = false,
    this.positiveCueId = 'nice',
    this.lowConfidenceCueId = 'cant_see_you',
    this.countCuePrefix = 'count_',
    this.maxCountCue = 20,
  });

  /// Minimum time between two plays of the same cue (different reps).
  final int cueCooldownMs;

  /// Minimum time before the same cue repeats within the *same* rep / hold
  /// (long planks need re-cueing; a squat rep normally gets one).
  final int sameRepCooldownMs;

  /// Same error for this many reps in a row → different phrasing.
  final int rephraseAfterConsecutiveReps;

  /// Same error for this many reps in a row → stop nagging (card at set end).
  final int muteAfterConsecutiveReps;
  final int positiveEveryCleanReps;
  final int positiveJitter;

  /// Rule events below this confidence never become cues.
  final double minConfidence;
  final int lowConfidenceCueEveryMs;
  final bool countReps;

  /// Only rep counts and severity-3 corrections.
  final bool quietMode;
  final String positiveCueId;
  final String lowConfidenceCueId;
  final String countCuePrefix;
  final int maxCountCue;
}

class _CueState {
  int? lastMs;
  int lastEventRep = -1;
  int timesPlayed = 0;
}

/// Turns [SessionEvent]s into a small, prioritised list of [CueCommand]s.
///
/// Deterministic given the injected `Random`; time comes from the events.
class FeedbackScheduler {
  FeedbackScheduler({
    required this.catalog,
    this.policy = const FeedbackPolicy(),
    this.locale = 'tr',
    math.Random? random,
  }) : _random = random ?? math.Random(7) {
    _nextPositiveAt = _rollPositive();
  }

  final CueCatalog catalog;
  final FeedbackPolicy policy;
  final String locale;
  final math.Random _random;

  final Map<String, _CueState> _cues = {};
  final Map<String, int> _ruleConsecutive = {};
  final Set<String> _muted = {};
  int _cleanStreak = 0;
  int _nextPositiveAt = 3;
  int _lastLowConfCueMs = -1 << 30;
  int _currentRep = 0;

  /// Rules that were muted because the error persisted; show them on the
  /// set-summary card instead.
  Set<String> get mutedRules => Set.unmodifiable(_muted);

  int _rollPositive() =>
      policy.positiveEveryCleanReps +
      (policy.positiveJitter > 0
          ? _random.nextInt(policy.positiveJitter + 1)
          : 0);

  /// Handle one batch of events (typically one frame's worth).
  List<CueCommand> handle(List<SessionEvent> events, {required int nowMs}) {
    final out = <CueCommand>[];
    final ruleEvents = <RuleEvent>[];
    RepResult? completedRep;
    HoldResult? completedHold;

    for (final e in events) {
      switch (e) {
        case SessionTrackingChanged(:final tracking):
          if (!tracking &&
              nowMs - _lastLowConfCueMs >= policy.lowConfidenceCueEveryMs) {
            final cmd = _make(
              policy.lowConfidenceCueId,
              nowMs,
              priority: 4,
              interrupts: true,
            );
            if (cmd != null) {
              _lastLowConfCueMs = nowMs;
              out.add(cmd);
            }
          }
        case SessionRuleTriggered(:final rule):
          ruleEvents.add(rule);
        case SessionRepCompleted(:final rep):
          completedRep = rep;
        case SessionHoldEnded(:final hold):
          completedHold = hold;
        case SessionPhaseChanged():
        case SessionRepRejected():
        case SessionHoldStarted():
        case SessionHoldProgress():
        case SessionGesture():
          break;
      }
    }

    // 1. Rep count (always, first in the queue).
    if (completedRep != null) {
      _currentRep = completedRep.index;
      _updateConsecutive(completedRep.failedRules);
      if (policy.countReps) {
        final n = math.min(completedRep.index, policy.maxCountCue);
        final cmd = _make(
          '${policy.countCuePrefix}$n',
          nowMs,
          priority: 3,
          haptic: HapticKind.tick,
        );
        if (cmd != null) out.add(cmd);
      }
    }
    if (completedHold != null) {
      _updateConsecutive(completedHold.failedRules);
    }

    // 2. Best correction cue of this batch.
    final correction = _pickCorrection(ruleEvents, nowMs);
    if (correction != null) out.add(correction);

    // 3. Positive reinforcement on clean reps (only when nothing to correct).
    if (completedRep != null) {
      if (completedRep.score.isClean) {
        _cleanStreak++;
        if (_cleanStreak >= _nextPositiveAt && correction == null) {
          final cmd = _make(
            policy.positiveCueId,
            nowMs,
            priority: 1,
            haptic: HapticKind.success,
            randomVariant: true,
          );
          if (cmd != null) out.add(cmd);
          _cleanStreak = 0;
          _nextPositiveAt = _rollPositive();
        }
      } else {
        _cleanStreak = 0;
      }
    }
    return out;
  }

  void _updateConsecutive(List<String> failed) {
    final failedSet = failed.toSet();
    for (final id in failedSet) {
      _ruleConsecutive[id] = (_ruleConsecutive[id] ?? 0) + 1;
      if (_ruleConsecutive[id]! >= policy.muteAfterConsecutiveReps) {
        _muted.add(id);
      }
    }
    for (final id in _ruleConsecutive.keys.toList()) {
      if (!failedSet.contains(id)) {
        _ruleConsecutive[id] = 0;
        _muted.remove(id);
      }
    }
  }

  CueCommand? _pickCorrection(List<RuleEvent> events, int nowMs) {
    RuleEvent? best;
    for (final e in events) {
      final cue = e.cue;
      if (cue == null || !catalog.has(cue)) continue;
      if (e.confidence < policy.minConfidence) continue;
      if (policy.quietMode && e.severity < 3) continue;
      if (_muted.contains(e.ruleId)) continue;
      final st = _cues[cue];
      if (st != null) {
        final last = st.lastMs;
        if (last != null) {
          final needed = st.lastEventRep == e.repIndex
              ? policy.sameRepCooldownMs
              : policy.cueCooldownMs;
          if (nowMs - last < needed) continue;
        }
      }
      if (best == null || e.priorityScore > best.priorityScore) best = e;
    }
    if (best == null) return null;
    final cue = best.cue!;
    final st = _cues.putIfAbsent(cue, _CueState.new);
    final consecutive = _ruleConsecutive[best.ruleId] ?? 0;
    final def = catalog[cue]!;
    final n = math.max(def.variantCount(locale), 1);
    var variant = st.timesPlayed % n;
    if (consecutive >= policy.rephraseAfterConsecutiveReps &&
        n > 1 &&
        variant == 0) {
      variant = 1;
    }
    st
      ..lastMs = nowMs
      ..lastEventRep = best.repIndex
      ..timesPlayed += 1;
    return CueCommand(
      clipId: cue,
      variant: variant,
      priority: best.severity >= 3 ? 3 : 2,
      haptic: def.haptic == HapticKind.none ? HapticKind.pulse : def.haptic,
      tMs: nowMs,
      text: def.text(locale, variant),
      ruleId: best.ruleId,
    );
  }

  CueCommand? _make(
    String clipId,
    int nowMs, {
    required int priority,
    HapticKind haptic = HapticKind.none,
    bool interrupts = false,
    bool randomVariant = false,
  }) {
    final def = catalog[clipId];
    if (def == null) return null;
    final n = math.max(def.variantCount(locale), 1);
    final st = _cues.putIfAbsent(clipId, _CueState.new);
    final variant = randomVariant ? _random.nextInt(n) : st.timesPlayed % n;
    st
      ..lastMs = nowMs
      ..timesPlayed += 1;
    return CueCommand(
      clipId: clipId,
      variant: variant,
      priority: priority,
      haptic: haptic == HapticKind.none ? def.haptic : haptic,
      tMs: nowMs,
      text: def.text(locale, variant),
      interrupts: interrupts,
    );
  }

  void reset() {
    _cues.clear();
    _ruleConsecutive.clear();
    _muted.clear();
    _cleanStreak = 0;
    _currentRep = 0;
    _lastLowConfCueMs = -1 << 30;
  }
}
