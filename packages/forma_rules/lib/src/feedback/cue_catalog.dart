import 'dart:convert';

/// Haptic pattern paired with a cue.
enum HapticKind {
  none,

  /// Single short tick (rep count).
  tick,

  /// Short double buzz (correction cue).
  pulse,

  /// Longer success pattern (set done / positive).
  success
  ;

  static HapticKind parse(String? s) => switch (s) {
    'tick' => HapticKind.tick,
    'pulse' => HapticKind.pulse,
    'success' => HapticKind.success,
    _ => HapticKind.none,
  };
}

/// One voice cue with per-locale phrasing variants.
class CueDefinition {
  const CueDefinition({
    required this.id,
    required this.variants,
    this.haptic = HapticKind.none,
    this.priority = 2,
    this.category = 'general',
  });

  factory CueDefinition.fromJson(String id, Map<String, dynamic> j) {
    final variants = <String, List<String>>{};
    for (final e in j.entries) {
      if (e.value is List) {
        variants[e.key] = (e.value as List<dynamic>).cast<String>();
      } else if (e.value is String && (e.key == 'tr' || e.key == 'en')) {
        variants[e.key] = [e.value as String];
      }
    }
    return CueDefinition(
      id: id,
      variants: variants,
      haptic: HapticKind.parse(j['haptic'] as String?),
      priority: (j['priority'] as num?)?.toInt() ?? 2,
      category: j['category'] as String? ?? 'general',
    );
  }

  final String id;

  /// locale → phrasing variants (index 0 = default).
  final Map<String, List<String>> variants;
  final HapticKind haptic;

  /// 1 (positive) .. 5 (system); higher may interrupt lower in the player.
  final int priority;

  /// `correction` | `count` | `positive` | `setup` | `system`.
  final String category;

  List<String> textsFor(String locale) =>
      variants[locale] ??
      variants[locale.split('_').first] ??
      variants['tr'] ??
      const [];

  int variantCount(String locale) => textsFor(locale).length;

  String? text(String locale, int variant) {
    final t = textsFor(locale);
    if (t.isEmpty) return null;
    return t[variant % t.length];
  }

  Map<String, dynamic> toJson() => {
    ...variants,
    'haptic': haptic.name,
    'priority': priority,
    'category': category,
  };
}

/// The cue table (`content/cues/cues.json`).
class CueCatalog {
  const CueCatalog(this.cues, {this.version = 1});

  factory CueCatalog.fromJson(Map<String, dynamic> j) {
    final cues = <String, CueDefinition>{};
    final raw = j['cues'] as Map<String, dynamic>? ?? const {};
    for (final e in raw.entries) {
      cues[e.key] = CueDefinition.fromJson(
        e.key,
        e.value as Map<String, dynamic>,
      );
    }
    return CueCatalog(cues, version: (j['version'] as num?)?.toInt() ?? 1);
  }

  static CueCatalog parse(String jsonText) =>
      CueCatalog.fromJson(json.decode(jsonText) as Map<String, dynamic>);

  final Map<String, CueDefinition> cues;
  final int version;

  bool has(String id) => cues.containsKey(id);

  CueDefinition? operator [](String id) => cues[id];

  String? text(String id, {required String locale, int variant = 0}) =>
      cues[id]?.text(locale, variant);

  /// Every cue must have at least one phrasing in each of [locales].
  List<String> validate({Set<String> locales = const {'tr', 'en'}}) {
    final errors = <String>[];
    for (final c in cues.values) {
      for (final l in locales) {
        if ((c.variants[l] ?? const []).isEmpty) {
          errors.add('cue ${c.id}: missing $l');
        }
      }
      if (c.priority < 1 || c.priority > 5) {
        errors.add('cue ${c.id}: priority must be 1..5');
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'cues': {for (final e in cues.entries) e.key: e.value.toJson()},
  };
}
