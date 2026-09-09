import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../workout/infrastructure/pose_engine_provider.dart';

/// Placeholder "Bugün" tab: quick form check + exercise list. Onboarding,
/// programs and progress arrive in later prompts (docs/10).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final content = ref.watch(contentRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          // Run the workout on the synthetic engine, so the screens after
          // "a rep was counted" can be reached without doing squats at the
          // phone. Debug only, like the recorder next to it.
          if (kDebugMode)
            IconButton(
              key: const Key('today_demo_mode'),
              tooltip: 'Demo motoru (sentetik tekrarlar)',
              icon: Icon(
                ref.watch(demoModeProvider)
                    ? Icons.smart_toy
                    : Icons.smart_toy_outlined,
                color: ref.watch(demoModeProvider)
                    ? FormaColors.secondary
                    : null,
              ),
              onPressed: () => ref
                  .read(demoModeProvider.notifier)
                  .set(on: !ref.read(demoModeProvider)),
            ),
          // Founder-only fixture recorder; compiled out of release builds.
          if (kDebugMode)
            IconButton(
              key: const Key('today_recorder'),
              tooltip: 'Kayıt (fixture)',
              icon: const Icon(Icons.fiber_manual_record_outlined),
              onPressed: () => unawaited(context.push(Routes.recorder)),
            ),
        ],
      ),
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: FormaColors.warning)),
        ),
        data: (bundle) {
          final exercises = bundle.visible(includeDrafts: true);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                l10n.todayTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(l10n.todaySubtitle),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('today_quick_check'),
                onPressed: () => _start(context, bundle.exercise('bw_squat')!),
                icon: const Icon(Icons.videocam_rounded),
                label: Text(l10n.quickFormCheck),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.exercisesSection,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final e in exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      key: Key('exercise_${e.id}'),
                      title: Text(e.name.text(l10n.localeName)),
                      subtitle: Text(
                        e.cameraViews
                            .map(
                              (v) => v == CameraView.front
                                  ? l10n.viewFront
                                  : l10n.viewSide,
                            )
                            .join(' · '),
                      ),
                      trailing: e.status == 'draft'
                          ? Chip(
                              label: Text(l10n.draftBadge),
                              visualDensity: VisualDensity.compact,
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => _start(context, e),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _start(BuildContext context, ExerciseDefinition e) async {
    final l10n = AppLocalizations.of(context);
    var view = e.cameraViews.first;
    if (e.cameraViews.length > 1) {
      final picked = await showModalBottomSheet<CameraView>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.chooseView,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              for (final v in e.cameraViews)
                ListTile(
                  key: Key('view_${v.name}'),
                  title: Text(
                    v == CameraView.front ? l10n.viewFront : l10n.viewSide,
                  ),
                  onTap: () => Navigator.of(ctx).pop(v),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (picked == null) return;
      view = picked;
    }
    if (context.mounted) unawaited(context.push(Routes.hud(e.id, view)));
  }
}
