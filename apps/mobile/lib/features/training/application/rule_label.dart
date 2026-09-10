import 'package:forma_rules/forma_rules.dart';

import '../../../core/content/content_repository.dart';

/// What to call a rule where the user can see it: the cue the coach says for
/// it ("Dizlerini dışa aç"), in [locale]. Falls back to the rule id with the
/// underscores taken out when the rule is silent or unknown, so a stored
/// session from newer content still reads as words.
String ruleLabel(
  ContentBundle bundle, {
  required String exerciseId,
  required String ruleId,
  required String locale,
}) {
  final rule = bundle
      .exercise(exerciseId)
      ?.rules
      .where((r) => r.id == ruleId)
      .firstOrNull;
  return ruleText(bundle, rule, locale: locale) ?? ruleId.replaceAll('_', ' ');
}

/// The cue text for [rule], or null when it has no cue or the catalog lacks
/// the phrase in [locale].
String? ruleText(
  ContentBundle bundle,
  RuleSpec? rule, {
  required String locale,
}) {
  final cue = rule?.cue;
  if (cue == null) return null;
  return bundle.cues.text(cue, locale: locale);
}
