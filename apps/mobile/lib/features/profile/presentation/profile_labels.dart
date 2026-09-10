import '../../../core/profile/user_profile.dart';
import '../../../l10n/app_localizations.dart';

/// Human labels for the three profile answers, in the current language.
String goalLabel(AppLocalizations l10n, TrainingGoal goal) => switch (goal) {
  TrainingGoal.muscle => l10n.profileGoalMuscle,
  TrainingGoal.form => l10n.profileGoalForm,
  TrainingGoal.health => l10n.profileGoalHealth,
};

String levelLabel(AppLocalizations l10n, TrainingLevel level) =>
    switch (level) {
      TrainingLevel.newcomer => l10n.profileLevelNew,
      TrainingLevel.occasional => l10n.profileLevelOccasional,
      TrainingLevel.regular => l10n.profileLevelRegular,
    };

String equipmentLabel(AppLocalizations l10n, Equipment equipment) =>
    switch (equipment) {
      Equipment.none => l10n.profileEquipmentNone,
      Equipment.dumbbell => l10n.profileEquipmentDumbbell,
    };
