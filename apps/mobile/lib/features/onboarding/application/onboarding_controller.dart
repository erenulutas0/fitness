import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';

part 'onboarding_controller.g.dart';

/// The demo session (docs/06 §4.1): five bodyweight squats from the side.
const demoExerciseId = 'bw_squat';
const demoTargetReps = 5;

/// The three onboarding answers while the user is still answering. Each is
/// `null` until its question has been tapped.
@immutable
class OnboardingAnswers {
  const OnboardingAnswers({this.goal, this.level, this.equipment});

  final TrainingGoal? goal;
  final TrainingLevel? level;
  final Equipment? equipment;

  /// The profile these answers describe. A question that was never answered
  /// (the user skipped, or came back later) takes the most common answer —
  /// the same fallback [UserProfile.fromJson] uses.
  UserProfile toProfile(DateTime now) => UserProfile(
    goal: goal ?? TrainingGoal.form,
    level: level ?? TrainingLevel.newcomer,
    equipment: equipment ?? Equipment.none,
    createdAt: now,
  );

  OnboardingAnswers copyWith({
    TrainingGoal? goal,
    TrainingLevel? level,
    Equipment? equipment,
  }) => OnboardingAnswers(
    goal: goal ?? this.goal,
    level: level ?? this.level,
    equipment: equipment ?? this.equipment,
  );

  @override
  bool operator ==(Object other) =>
      other is OnboardingAnswers &&
      other.goal == goal &&
      other.level == level &&
      other.equipment == equipment;

  @override
  int get hashCode => Object.hash(goal, level, equipment);
}

/// Shared by the three question screens, so going back a step keeps what was
/// tapped. Kept alive: between two screens nobody watches it for a frame.
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  void chooseGoal(TrainingGoal goal) => state = state.copyWith(goal: goal);

  void chooseLevel(TrainingLevel level) => state = state.copyWith(level: level);

  void chooseEquipment(Equipment equipment) =>
      state = state.copyWith(equipment: equipment);

  /// Writes the profile and clears the draft. Called before the demo session
  /// starts and by "skip", so the router never sends a returning user back
  /// through onboarding.
  Future<UserProfile> complete({DateTime? now}) async {
    final profile = state.toProfile(now ?? DateTime.now());
    await ref.read(profileProvider.notifier).save(profile);
    state = const OnboardingAnswers();
    return profile;
  }
}
