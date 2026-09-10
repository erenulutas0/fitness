import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';

/// The tab shell (docs/06 §3, brief 2-C): Bugün · Antrenman · İlerleme ·
/// Profil. Vücut waits for the anatomy layer (v0.2).
///
/// Only the four tabs live inside it; the HUD, the summaries, onboarding,
/// settings and the legal page are full-screen routes above it, so nothing
/// draws a navigation bar under a camera preview.
class FormaShell extends StatelessWidget {
  const FormaShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab again scrolls it back to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            key: const Key('tab_today'),
            icon: const Icon(LucideIcons.house),
            label: l10n.todayTitle,
          ),
          NavigationDestination(
            key: const Key('tab_training'),
            icon: const Icon(LucideIcons.dumbbell),
            label: l10n.trainingTitle,
          ),
          NavigationDestination(
            key: const Key('tab_progress'),
            icon: const Icon(LucideIcons.trendingUp),
            label: l10n.progressTitle,
          ),
          NavigationDestination(
            key: const Key('tab_profile'),
            icon: const Icon(LucideIcons.user),
            label: l10n.profileTitle,
          ),
        ],
      ),
    );
  }
}
