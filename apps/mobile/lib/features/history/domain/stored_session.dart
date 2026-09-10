import 'package:forma_rules/forma_rules.dart';

/// One finished set as it is kept on disk (docs/05 §9 `SetResult`).
///
/// A summary, not a recording: scores, counts and per-rep timing, never joint
/// coordinates. Landmark sequences stay out of storage by design — the only
/// place they exist is memory during the session and, if the user chooses it,
/// the drawing on a share card.
class StoredSet {
  const StoredSet({
    required this.exerciseId,
    required this.view,
    required this.durationMs,
    required this.repCount,
    required this.holdMs,
    required this.errorCounts,
    this.formScore,
    this.reps = const [],
  });

  factory StoredSet.fromResult(SetResult r) => StoredSet(
    exerciseId: r.exerciseId,
    view: r.view,
    durationMs: r.durationMs,
    repCount: r.repCount,
    holdMs: r.totalHoldMs,
    errorCounts: r.errorCounts,
    formScore: r.formScore,
    reps: [for (final rep in r.reps) rep.toJson()],
  );

  factory StoredSet.fromJson(Map<String, dynamic> j) => StoredSet(
    exerciseId: j['exerciseId'] as String? ?? '',
    view: CameraView.parse(j['view'] as String? ?? 'side') ?? CameraView.side,
    durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
    repCount: (j['repCount'] as num?)?.toInt() ?? 0,
    holdMs: (j['holdMs'] as num?)?.toInt() ?? 0,
    errorCounts: {
      for (final e in (j['errorCounts'] as Map<String, dynamic>? ?? {}).entries)
        e.key: (e.value as num).toInt(),
    },
    formScore: (j['formScore'] as num?)?.toDouble(),
    reps: [
      for (final r in (j['reps'] as List<dynamic>? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ],
  );

  final String exerciseId;
  final CameraView view;
  final int durationMs;
  final int repCount;
  final int holdMs;
  final Map<String, int> errorCounts;
  final double? formScore;

  /// Per-rep detail in the shape `RepResult.toJson` already produces
  /// (docs/05 §9 `Rep`). Kept as raw maps: history reads a handful of fields
  /// and nothing here should force the engine's types on the storage layer.
  final List<Map<String, dynamic>> reps;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'view': view.name,
    'durationMs': durationMs,
    'repCount': repCount,
    'holdMs': holdMs,
    'errorCounts': errorCounts,
    if (formScore != null) 'formScore': formScore,
    'reps': reps,
  };
}

/// One workout session on disk (docs/05 §9 `Session`).
class StoredSession {
  const StoredSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
    this.device,
    this.modelVariant,
  });

  factory StoredSession.fromJson(Map<String, dynamic> j) => StoredSession(
    id: j['id'] as String? ?? '',
    startedAt:
        DateTime.tryParse(j['startedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    endedAt:
        DateTime.tryParse(j['endedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    sets: [
      for (final s in (j['sets'] as List<dynamic>? ?? const []))
        StoredSet.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    device: j['device'] as String?,
    modelVariant: j['modelVariant'] as String?,
  );

  static const schemaVersion = 1;

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<StoredSet> sets;
  final String? device;
  final String? modelVariant;

  /// Exercises this session touched, in the order they first appeared
  /// (docs/05 §9 `exercises[]`). One today; the field is what lets a session
  /// hold more than one later without a migration.
  List<String> get exercises {
    final out = <String>[];
    for (final s in sets) {
      if (!out.contains(s.exerciseId)) out.add(s.exerciseId);
    }
    return out;
  }

  double? get meanScore {
    final scores = [
      for (final s in sets)
        if (s.formScore != null) s.formScore!,
    ];
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  int get totalReps => sets.fold(0, (a, s) => a + s.repCount);
  int get totalHoldMs => sets.fold(0, (a, s) => a + s.holdMs);

  Map<String, int> get errorCounts {
    final out = <String, int>{};
    for (final s in sets) {
      for (final e in s.errorCounts.entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value;
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'exercises': exercises,
    if (device != null) 'device': device,
    if (modelVariant != null) 'modelVariant': modelVariant,
    'sets': [for (final s in sets) s.toJson()],
  };
}
