import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/content/content_repository.dart';
import '../../workout/presentation/skeleton_painter.dart';
import '../application/recorder_controller.dart';
import '../infrastructure/fixture_store.dart';

/// Ground-truth labelling for a finished recording (docs/fixtures-schema.md).
///
/// The engine's own reading is shown as a hint but never pre-selected: a
/// fixture that just agrees with the engine cannot measure it. Founder tool,
/// debug only, so the copy stays Turkish and outside the l10n bundle.
class RecorderLabelScreen extends ConsumerStatefulWidget {
  const RecorderLabelScreen({required this.draft, super.key});

  final RecordingDraft draft;

  @override
  ConsumerState<RecorderLabelScreen> createState() =>
      _RecorderLabelScreenState();
}

class _RecorderLabelScreenState extends ConsumerState<RecorderLabelScreen> {
  late int _units = widget.draft.engineReps.clamp(0, 60);
  late int _holdSeconds = (widget.draft.engineHoldMs / 1000).round();
  final Map<int, Set<String>> _labels = {};
  late final TextEditingController _notes = TextEditingController(
    text: widget.draft.config.notes ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save({required bool share}) async {
    final draft = widget.draft;
    final isHold = _isHold;
    setState(() => _saving = true);
    // Ticking rep 6 and then correcting the count down to 5 used to ship the
    // stale label: the harness counts a label on a rep that does not exist as
    // a miss, so the rule's recall is permanently depressed and a threshold
    // sweep compensates by loosening it.
    final maxUnit = isHold ? 1 : _units;
    final labels = <FixtureLabel>[
      for (final e in _labels.entries)
        if (e.value.isNotEmpty && e.key <= maxUnit)
          FixtureLabel(rep: e.key, rules: e.value.toList()..sort()),
    ]..sort((a, b) => a.rep.compareTo(b.rep));
    final fixture = draft.toFixture(
      labels: labels,
      expectedReps: isHold ? null : _units,
      expectedHoldMs: isHold ? _holdSeconds * 1000 : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    final store = ref.read(fixtureStoreProvider);
    final file = await store.save(fixture);
    ref.invalidate(storedFixturesProvider);
    if (share) {
      final saved = await store.list();
      final match = saved.where((f) => f.file.path == file.path).toList();
      if (match.isNotEmpty) await store.share(match);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kaydedildi: ${file.uri.pathSegments.last}')),
    );
    context.go(Routes.recorder);
  }

  bool get _isHold =>
      ref
          .read(contentRepositoryProvider)
          .value
          ?.exercise(widget.draft.config.exerciseId)
          ?.countMode ==
      CountMode.hold;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final bundle = ref.watch(contentRepositoryProvider).value;
    final def = bundle?.exercise(draft.config.exerciseId);
    final cues = bundle?.cues;
    if (def == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isHold = def.countMode == CountMode.hold;
    final rules = def.rulesFor(draft.config.view).toList();
    final unitCount = isHold ? 1 : _units;

    return Scaffold(
      appBar: AppBar(title: const Text('Etiketle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Summary(draft: draft, def: def),
          const SizedBox(height: 16),
          if (isHold)
            _Stepper(
              label: 'Gerçek süre (sn)',
              value: _holdSeconds,
              onChanged: (v) => setState(() => _holdSeconds = v),
              step: 5,
            )
          else
            _Stepper(
              label: 'Gerçek tekrar sayısı',
              value: _units,
              onChanged: (v) => setState(() => _units = v),
            ),
          const SizedBox(height: 8),
          const Text(
            'Her tekrar için gerçekten olan hataları işaretle. Motorun tahmini yanında '
            'rozet olarak görünür ama seçili gelmez — fixture motoru ölçecek, onaylamayacak.',
            style: TextStyle(color: FormaColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Bu açı için tanımlı kural yok; sadece sayım etiketlenir.',
                ),
              ),
            ),
          for (var i = 1; i <= unitCount; i++)
            _UnitCard(
              index: i,
              isHold: isHold,
              rules: rules,
              cues: cues,
              engineRules: draft.engineRulesFor(i),
              extremeFrame: isHold ? null : draft.extremeFrameFor(i),
              selected: _labels[i] ?? const {},
              onToggle: (ruleId, {required on}) => setState(() {
                final set = _labels.putIfAbsent(i, () => <String>{});
                if (on) {
                  set.add(ruleId);
                } else {
                  set.remove(ruleId);
                }
              }),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'kıyafet, ışık, zemin…',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('recorder_save'),
            onPressed: _saving ? null : () => _save(share: false),
            child: const Text('Kaydet'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(share: true),
            icon: const Icon(LucideIcons.share),
            label: const Text('Kaydet ve paylaş'),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.draft, required this.def});

  final RecordingDraft draft;
  final ExerciseDefinition def;

  @override
  Widget build(BuildContext context) {
    final c = draft.config;
    final lost = draft.lostRatio;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${def.name.tr} · ${c.view == CameraView.front ? 'ön' : 'yan'} · ${c.person} · ${c.environment}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${(draft.durationMs / 1000).toStringAsFixed(1)} s · ${draft.frames.length} frame · '
              'model ${c.model.name} · ort. görünürlük ${draft.meanVisibility.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                color: FormaColors.textMuted,
              ),
            ),
            if (lost > 0.05)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Frame'lerin %${(lost * 100).round()}'inde takip zayıftı; "
                  'kadraj kötüyse kaydı tekrarlamak daha iyi.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: FormaColors.warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        key: const Key('recorder_unit_minus'),
        onPressed: value - step >= 0 ? () => onChanged(value - step) : null,
        icon: const Icon(LucideIcons.circleMinus),
      ),
      SizedBox(
        width: 52,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        key: const Key('recorder_unit_plus'),
        onPressed: () => onChanged(value + step),
        icon: const Icon(LucideIcons.circlePlus),
      ),
    ],
  );
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.index,
    required this.isHold,
    required this.rules,
    required this.cues,
    required this.engineRules,
    required this.selected,
    required this.onToggle,
    this.extremeFrame,
  });

  final int index;
  final bool isHold;
  final List<RuleSpec> rules;
  final CueCatalog? cues;
  final Set<String> engineRules;
  final Set<String> selected;
  final void Function(String ruleId, {required bool on}) onToggle;

  /// The frame the engine scored for this rep. Labelling kept getting skipped
  /// because it asks you to remember which rep was which minutes after the
  /// fact; a picture of the bottom position answers that instantly. Drawn
  /// from the landmarks we already keep, so no video is stored.
  final PoseFrame? extremeFrame;

  String _label(RuleSpec r) {
    final cue = r.cue;
    if (cue != null) {
      final text = cues?.text(cue, locale: 'tr');
      if (text != null && text.isNotEmpty) return text;
    }
    return r.id.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (extremeFrame != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ColoredBox(
                      color: FormaColors.background,
                      child: SizedBox(
                        width: 54,
                        height: 72,
                        child: CustomPaint(
                          painter: SkeletonPainter(
                            frame: extremeFrame!,
                            tracking: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  isHold ? 'Tutuş' : 'Tekrar $index',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                if (engineRules.isNotEmpty)
                  Expanded(
                    child: Text(
                      'motor: ${engineRules.join(', ')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: FormaColors.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in rules)
                  FilterChip(
                    key: Key('label_${index}_${r.id}'),
                    label: Text(
                      _label(r),
                      style: const TextStyle(fontSize: 12),
                    ),
                    tooltip: r.id,
                    selected: selected.contains(r.id),
                    onSelected: (on) => onToggle(r.id, on: on),
                    avatar: engineRules.contains(r.id)
                        ? const Icon(LucideIcons.bot, size: 16)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
