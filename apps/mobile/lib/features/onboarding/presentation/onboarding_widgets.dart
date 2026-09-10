import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';

/// The frame every onboarding screen sits in: background, page padding,
/// content above, the screen's actions pinned to the bottom edge.
///
/// A screen passes at most one [FilledButton] in [actions] (brief §1: one
/// lime button per screen, at the bottom; secondary actions outlined or
/// plain text).
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.child,
    this.actions = const [],
    this.appBar,
    super.key,
  });

  final Widget child;
  final List<Widget> actions;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FormaColors.background,
      appBar: appBar,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FormaSpacing.page,
            FormaSpacing.sm,
            FormaSpacing.page,
            FormaSpacing.page,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: child),
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) const SizedBox(height: FormaSpacing.sm),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lucide back arrow for the onboarding app bars. The default [BackButton]
/// draws a Material glyph, which the brief rules out.
class OnboardingBackButton extends StatelessWidget {
  const OnboardingBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.canPop()) return const SizedBox.shrink();
    return IconButton(
      key: const Key('onboarding_back'),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(LucideIcons.arrowLeft),
      onPressed: context.pop,
    );
  }
}

/// Three dots for the three questions. The current step is a lime pill,
/// finished steps lime dots, the rest outline. Read out as one label
/// ("Adım 2 / 3"); the dots themselves carry no semantics.
class OnboardingProgressDots extends StatelessWidget {
  const OnboardingProgressDots({
    required this.current,
    required this.total,
    required this.semanticsLabel,
    super.key,
  });

  /// Zero-based index of the step being shown.
  final int current;
  final int total;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: FormaSpacing.sm),
            Container(
              width: i == current ? FormaSpacing.xl : FormaSpacing.sm,
              height: FormaSpacing.sm,
              decoration: ShapeDecoration(
                color: i <= current ? FormaColors.primary : FormaColors.outline,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One answer: a big tappable card. The selected one gets a lime 2 px border
/// and a check icon, so the state is never colour alone (brief §1).
///
/// Not a `FormaCard`: that widget has no border parameter, and the outline
/// is the whole point here.
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Selected border width (brief 2-A: "lime 2px border"); the theme uses the
  /// same width for [OutlinedButton].
  static const _selectedBorderWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(FormaRadius.card));
    final side = selected
        ? const BorderSide(
            color: FormaColors.primary,
            width: _selectedBorderWidth,
          )
        : const BorderSide(color: FormaColors.outline);
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? FormaColors.surfaceRaised : FormaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FormaSpacing.lg,
              vertical: FormaSpacing.xl,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: selected
                        ? FormaColors.primary
                        : FormaColors.textMuted,
                  ),
                  const SizedBox(width: FormaSpacing.md),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: FormaSpacing.md),
                Visibility(
                  visible: selected,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: const Icon(
                    LucideIcons.check,
                    color: FormaColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
