import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/content/content_repository.dart';
import '../application/recording_config_controller.dart';
import '../infrastructure/fixture_store.dart';

/// Founder tool, debug builds only, so its copy stays Turkish and out of the
/// l10n bundle on purpose (docs/10 Prompt 3).
const _environments = <String, String>{
  'living_room': 'Oturma odası',
  'gym': 'Salon',
  'low_light': 'Düşük ışık',
  'outdoor': 'Dışarısı',
  'other': 'Diğer',
};

class RecorderSetupScreen extends ConsumerWidget {
  const RecorderSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentRepositoryProvider);
    final config = ref.watch(recordingConfigControllerProvider);
    final stored = ref.watch(storedFixturesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt (fixture)')),
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (bundle) {
          final exercises = bundle.visible(includeDrafts: true);
          final def = bundle.exercise(config.exerciseId) ?? exercises.first;
          final views = def.cameraViews;
          final view = views.contains(config.view) ? config.view : views.first;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom + 24,
            ),
            children: [
              const Text(
                'Ham landmark dizisi kaydedilir; video kaydedilmez. Kayıtlar cihazda kalır, '
                'paylaşana kadar hiçbir yere gitmez. Katılımcıdan onam almayı unutma.',
                style: TextStyle(color: FormaColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _Labeled(
                label: 'Egzersiz',
                child: DropdownButtonFormField<String>(
                  key: const Key('recorder_exercise'),
                  initialValue: def.id,
                  items: [
                    for (final e in exercises)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          '${e.name.tr}${e.status == 'draft' ? ' (taslak)' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    final next = bundle.exercise(v)!;
                    ref
                        .read(recordingConfigControllerProvider.notifier)
                        .update(
                          config.copyWith(
                            exerciseId: v,
                            view: next.cameraViews.contains(config.view)
                                ? config.view
                                : next.cameraViews.first,
                          ),
                        );
                  },
                ),
              ),
              _Labeled(
                label: 'Kamera açısı',
                child: SegmentedButton<CameraView>(
                  segments: [
                    for (final v in views)
                      ButtonSegment(
                        value: v,
                        label: Text(v == CameraView.front ? 'Ön' : 'Yan'),
                      ),
                  ],
                  selected: {view},
                  onSelectionChanged: (s) => ref
                      .read(recordingConfigControllerProvider.notifier)
                      .update(config.copyWith(view: s.first)),
                ),
              ),
              _Labeled(
                label: 'Kişi kodu (anonim)',
                child: TextFormField(
                  key: const Key('recorder_person'),
                  initialValue: config.person,
                  decoration: const InputDecoration(hintText: 'p01'),
                  onChanged: (v) => ref
                      .read(recordingConfigControllerProvider.notifier)
                      .update(
                        config.copyWith(
                          person: v.trim().isEmpty ? 'p01' : v.trim(),
                        ),
                      ),
                ),
              ),
              _Labeled(
                label: 'Ortam',
                child: DropdownButtonFormField<String>(
                  initialValue: config.environment,
                  items: [
                    for (final e in _environments.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => v == null
                      ? null
                      : ref
                            .read(recordingConfigControllerProvider.notifier)
                            .update(config.copyWith(environment: v)),
                ),
              ),
              _Labeled(
                label: 'Model',
                child: SegmentedButton<PoseModel>(
                  segments: const [
                    ButtonSegment(value: PoseModel.lite, label: Text('lite')),
                    ButtonSegment(value: PoseModel.full, label: Text('full')),
                  ],
                  selected: {config.model},
                  onSelectionChanged: (s) => ref
                      .read(recordingConfigControllerProvider.notifier)
                      .update(config.copyWith(model: s.first)),
                ),
              ),
              _Labeled(
                label: 'Kamera',
                child: SegmentedButton<CameraLens>(
                  segments: const [
                    ButtonSegment(
                      value: CameraLens.back,
                      label: Text('Arka kamera'),
                    ),
                    ButtonSegment(
                      value: CameraLens.front,
                      label: Text('Ön kamera'),
                    ),
                  ],
                  selected: {config.lens},
                  onSelectionChanged: (s) => ref
                      .read(recordingConfigControllerProvider.notifier)
                      .update(config.copyWith(lens: s.first)),
                ),
              ),
              _Labeled(
                label: 'Not (opsiyonel)',
                child: TextFormField(
                  initialValue: config.notes,
                  decoration: const InputDecoration(
                    hintText: 'bol eşofman, pencere arkada…',
                  ),
                  onChanged: (v) => ref
                      .read(recordingConfigControllerProvider.notifier)
                      .update(
                        config.copyWith(
                          notes: v.trim().isEmpty ? null : v.trim(),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('recorder_start'),
                onPressed: () => context.push(
                  Routes.recorderCapture,
                  extra: config.copyWith(view: view),
                ),
                icon: const Icon(LucideIcons.circleDot),
                label: const Text('Kaydı başlat'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text(
                    'Kayıtlar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  stored.maybeWhen(
                    data: (list) => list.isEmpty
                        ? const SizedBox.shrink()
                        : TextButton.icon(
                            onPressed: () =>
                                ref.read(fixtureStoreProvider).share(list),
                            icon: const Icon(LucideIcons.share, size: 18),
                            label: Text('Hepsini paylaş (${list.length})'),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              stored.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (list) => list.isEmpty
                    ? const Text(
                        'Henüz kayıt yok.',
                        style: TextStyle(color: FormaColors.textMuted),
                      )
                    : Column(
                        children: [
                          for (final f in list)
                            Card(
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  f.name,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${f.sizeMb.toStringAsFixed(2)} MB · ${f.modified.toLocal()}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.share,
                                        size: 20,
                                      ),
                                      onPressed: () => ref
                                          .read(fixtureStoreProvider)
                                          .share([f]),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.trash2,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        await ref
                                            .read(fixtureStoreProvider)
                                            .delete(f);
                                        ref.invalidate(storedFixturesProvider);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: FormaColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}
