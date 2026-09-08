/// Phases of one repetition, named independently of exercise direction.
///
/// `rest` → `toPeak` → `peak` → `toRest` → `rest` is one rep. For a squat the
/// peak is the bottom position; for a glute bridge it is the top. The squat
/// aliases `top / descending / bottom / ascending` are accepted in JSON.
enum RepPhase {
  rest,
  toPeak,
  peak,
  toRest
  ;

  static RepPhase? parse(String s) => switch (s) {
    'rest' || 'top' || 'idle' => RepPhase.rest,
    'toPeak' || 'to_peak' || 'descending' => RepPhase.toPeak,
    'peak' || 'bottom' => RepPhase.peak,
    'toRest' || 'to_rest' || 'ascending' => RepPhase.toRest,
    _ => null,
  };
}

/// Thresholds for the rep state machine.
///
/// If [peakThreshold] < [restThreshold] the signal *decreases* toward the peak
/// (squat knee angle); otherwise it increases (glute-bridge hip angle).
class RepConfig {
  const RepConfig({
    required this.restThreshold,
    required this.peakThreshold,
    this.hysteresis = 5,
    this.minDurationMs = 500,
    this.maxDurationMs,
  }) : assert(restThreshold != peakThreshold, 'rest and peak must differ'),
       assert(hysteresis >= 0, 'hysteresis must be >= 0');

  final double restThreshold;
  final double peakThreshold;
  final double hysteresis;

  /// Reps shorter than this are rejected as noise / bounces.
  final int minDurationMs;

  /// Reps longer than this are rejected (optional).
  final int? maxDurationMs;

  bool get decreasingTowardPeak => peakThreshold < restThreshold;
}

/// Summary of one completed repetition.
class RepSummary {
  const RepSummary({
    required this.index,
    required this.startMs,
    required this.peakMs,
    required this.extremeMs,
    required this.endMs,
    required this.startValue,
    required this.extremeValue,
  });

  /// 1-based rep number within the set.
  final int index;
  final int startMs;

  /// Time the peak zone was first entered.
  final int peakMs;

  /// Time of the extreme signal value (the true bottom / top of the rep).
  final int extremeMs;
  final int endMs;

  final double startValue;

  /// Extreme signal value reached (min for decreasing, max for increasing).
  final double extremeValue;

  int get durationMs => endMs - startMs;

  /// Time from rest to the extreme (eccentric for squat / push-up).
  int get toPeakMs => extremeMs - startMs;

  /// Time from the extreme back to rest (concentric for squat / push-up).
  int get toRestMs => endMs - extremeMs;
}

sealed class RepEvent {
  const RepEvent(this.tMs);

  final int tMs;
}

class PhaseChanged extends RepEvent {
  const PhaseChanged(super.tMs, this.from, this.to);

  final RepPhase from;
  final RepPhase to;
}

class RepCompleted extends RepEvent {
  const RepCompleted(super.tMs, this.summary);

  final RepSummary summary;
}

enum RepRejectReason { tooFast, tooSlow }

class RepRejected extends RepEvent {
  const RepRejected(super.tMs, this.reason, this.durationMs);

  final RepRejectReason reason;
  final int durationMs;
}

/// Hysteresis-gated state machine that counts repetitions on a scalar signal.
class RepDetector {
  RepDetector(this.config);

  final RepConfig config;

  RepPhase _phase = RepPhase.rest;
  int _count = 0;
  int? _startMs;
  int? _peakMs;
  int _extremeMs = 0;
  double _startValue = 0;
  double _extreme = 0;

  RepPhase get phase => _phase;
  int get count => _count;

  /// Milliseconds since the current rep started, or null while at rest.
  int? elapsedMs(int nowMs) {
    final s = _startMs;
    return s == null ? null : nowMs - s;
  }

  // Internally the signal is normalized so that the peak is always "high".
  double _n(double v) => config.decreasingTowardPeak ? -v : v;

  List<RepEvent> update(double signal, int tMs) {
    final events = <RepEvent>[];
    final s = _n(signal);
    final rest = _n(config.restThreshold);
    final peak = _n(config.peakThreshold);
    final h = config.hysteresis;

    void go(RepPhase to) {
      events.add(PhaseChanged(tMs, _phase, to));
      _phase = to;
    }

    switch (_phase) {
      case RepPhase.rest:
        if (s > rest + h) {
          _startMs = tMs;
          _peakMs = null;
          _startValue = signal;
          _extreme = signal;
          _extremeMs = tMs;
          go(RepPhase.toPeak);
        }
      case RepPhase.toPeak:
        _trackExtreme(signal, tMs);
        if (s >= peak) {
          _peakMs = tMs;
          go(RepPhase.peak);
        } else if (s <= rest) {
          // Small movement that never reached the peak zone: not a rep.
          _startMs = null;
          go(RepPhase.rest);
        }
      case RepPhase.peak:
        _trackExtreme(signal, tMs);
        if (s < peak - h) go(RepPhase.toRest);
      case RepPhase.toRest:
        _trackExtreme(signal, tMs);
        if (s >= peak) {
          go(RepPhase.peak);
        } else if (s <= rest) {
          final start = _startMs!;
          final duration = tMs - start;
          final max = config.maxDurationMs;
          if (duration < config.minDurationMs) {
            events.add(RepRejected(tMs, RepRejectReason.tooFast, duration));
          } else if (max != null && duration > max) {
            events.add(RepRejected(tMs, RepRejectReason.tooSlow, duration));
          } else {
            _count++;
            events.add(
              RepCompleted(
                tMs,
                RepSummary(
                  index: _count,
                  startMs: start,
                  peakMs: _peakMs ?? start,
                  extremeMs: _extremeMs,
                  endMs: tMs,
                  startValue: _startValue,
                  extremeValue: _extreme,
                ),
              ),
            );
          }
          _startMs = null;
          go(RepPhase.rest);
        }
    }
    return events;
  }

  void _trackExtreme(double signal, int tMs) {
    final better = config.decreasingTowardPeak
        ? signal < _extreme
        : signal > _extreme;
    if (better) {
      _extreme = signal;
      _extremeMs = tMs;
    }
  }

  void reset() {
    _phase = RepPhase.rest;
    _count = 0;
    _startMs = null;
    _peakMs = null;
  }
}

/// Configuration for timed holds (plank).
class HoldConfig {
  const HoldConfig({this.minHoldMs = 1000, this.exitGraceMs = 700});

  /// A hold shorter than this is not reported.
  final int minHoldMs;

  /// Condition may be false for up to this long without ending the hold.
  final int exitGraceMs;
}

sealed class HoldEvent {
  const HoldEvent(this.tMs);

  final int tMs;
}

class HoldStarted extends HoldEvent {
  const HoldStarted(super.tMs);
}

class HoldProgress extends HoldEvent {
  const HoldProgress(super.tMs, this.heldMs);

  final int heldMs;
}

class HoldEnded extends HoldEvent {
  const HoldEnded(super.tMs, this.heldMs);

  final int heldMs;
}

/// Accumulates time while a boolean condition stays true.
class HoldDetector {
  HoldDetector([this.config = const HoldConfig()]);

  final HoldConfig config;

  bool _holding = false;
  int? _startMs;
  int? _lastTrueMs;
  int _lastProgressMs = 0;

  bool get isHolding => _holding;

  int heldMs(int nowMs) {
    final s = _startMs;
    return (_holding && s != null) ? nowMs - s : 0;
  }

  List<HoldEvent> update(bool conditionMet, int tMs) {
    final events = <HoldEvent>[];
    if (conditionMet) {
      _lastTrueMs = tMs;
      if (!_holding) {
        _holding = true;
        _startMs = tMs;
        _lastProgressMs = tMs;
        events.add(HoldStarted(tMs));
      } else if (tMs - _lastProgressMs >= 1000) {
        _lastProgressMs = tMs;
        events.add(HoldProgress(tMs, tMs - _startMs!));
      }
    } else if (_holding && tMs - (_lastTrueMs ?? tMs) > config.exitGraceMs) {
      final held = (_lastTrueMs ?? tMs) - _startMs!;
      _holding = false;
      _startMs = null;
      if (held >= config.minHoldMs) events.add(HoldEnded(tMs, held));
    }
    return events;
  }

  /// Force-end the hold (set finished by the user).
  HoldEnded? finish(int tMs) {
    if (!_holding) return null;
    final held = tMs - _startMs!;
    _holding = false;
    _startMs = null;
    return HoldEnded(tMs, held);
  }

  void reset() {
    _holding = false;
    _startMs = null;
    _lastTrueMs = null;
  }
}
