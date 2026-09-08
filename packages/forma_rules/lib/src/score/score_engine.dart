import '../rules/exercise_definition.dart';
import '../rules/rule_evaluator.dart';

/// Form score for one rep / hold: 0..100 with per-rule penalties.
class RepScore {
  const RepScore({
    required this.score,
    required this.penalties,
    required this.cleanThreshold,
  });

  final double score;

  /// Penalty points taken per failed rule (sums to `100 - score`, capped).
  final Map<String, double> penalties;
  final double cleanThreshold;

  bool get isClean => score >= cleanThreshold;

  int get rounded => score.round();

  @override
  String toString() => 'RepScore($rounded, penalties=$penalties)';
}

/// `score = 100 × (1 − Σ weight(rule) for every failed rule)`, clamped.
///
/// Weights are absolute so the score is explainable ("valgus cost you 40").
class ScoreEngine {
  const ScoreEngine(this.spec);

  final ScoreSpec spec;

  RepScore score(Map<String, RuleResult> results) {
    var total = 0.0;
    final penalties = <String, double>{};
    for (final r in results.values) {
      if (!r.triggered) continue;
      final w = spec.weightFor(r.ruleId);
      penalties[r.ruleId] = w * 100;
      total += w;
    }
    final s = (100 * (1 - total)).clamp(0.0, 100.0);
    return RepScore(
      score: s,
      penalties: penalties,
      cleanThreshold: spec.cleanThreshold,
    );
  }
}
