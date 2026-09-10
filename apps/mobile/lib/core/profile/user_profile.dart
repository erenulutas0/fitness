import 'package:flutter/foundation.dart';

/// Why the user is here (onboarding question 1).
enum TrainingGoal { muscle, form, health }

/// How much they already train (onboarding question 2). `new` is a keyword,
/// hence [newcomer]; the wire value is still `new` (docs/05 §9).
enum TrainingLevel {
  newcomer('new'),
  occasional('occasional'),
  regular('regular')
  ;

  const TrainingLevel(this.wire);

  final String wire;
}

/// What they have at home (onboarding question 3).
enum Equipment { none, dumbbell }

/// The onboarding answers (brief Faz 1 §5, docs/05 §9 `UserProfile`).
///
/// No height, weight or anything else that counts as health data: the three
/// answers are what the exercise list and future programs are filtered by,
/// nothing more.
@immutable
class UserProfile {
  const UserProfile({
    required this.goal,
    required this.level,
    required this.equipment,
    required this.createdAt,
  });

  /// Unknown enum values fall back to the most common answer rather than
  /// throwing: a profile written by a newer build must not send an updated
  /// app back through onboarding.
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    goal: TrainingGoal.values.asNameMap()[j['goal']] ?? TrainingGoal.form,
    level:
        TrainingLevel.values.where((l) => l.wire == j['level']).firstOrNull ??
        TrainingLevel.newcomer,
    equipment: Equipment.values.asNameMap()[j['equipment']] ?? Equipment.none,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  static const schemaVersion = 1;

  final TrainingGoal goal;
  final TrainingLevel level;
  final Equipment equipment;
  final DateTime createdAt;

  UserProfile copyWith({
    TrainingGoal? goal,
    TrainingLevel? level,
    Equipment? equipment,
  }) => UserProfile(
    goal: goal ?? this.goal,
    level: level ?? this.level,
    equipment: equipment ?? this.equipment,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'goal': goal.name,
    'level': level.wire,
    'equipment': equipment.name,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.goal == goal &&
      other.level == level &&
      other.equipment == equipment &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(goal, level, equipment, createdAt);

  @override
  String toString() =>
      'UserProfile(goal: ${goal.name}, level: ${level.wire}, '
      'equipment: ${equipment.name}, createdAt: $createdAt)';
}
