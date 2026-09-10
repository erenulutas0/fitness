import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../infrastructure/cue_player.dart';

/// Rest between sets (docs/06 §4.4): a countdown that is spoken, not just
/// shown, because the phone is across the room and the user is not looking at
/// it. The last three seconds count down out loud the way the set start does.
class RestTimer extends ConsumerStatefulWidget {
  const RestTimer({
    required this.seconds,
    required this.onDone,
    required this.onSkip,
    super.key,
  });

  final int seconds;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  ConsumerState<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends ConsumerState<RestTimer> {
  late int _left = widget.seconds;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _speak('rest');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 3 && _left >= 1) _speak('ready_$_left', priority: 5);
      if (_left <= 0) _complete();
    });
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    _speak('go', priority: 5, haptic: HapticKind.success);
    widget.onDone();
  }

  void _speak(
    String clipId, {
    int priority = 4,
    HapticKind haptic = HapticKind.none,
  }) {
    final catalog = ref.read(contentRepositoryProvider).value?.cues;
    if (catalog == null || !catalog.has(clipId)) return;
    final locale = ref.read(localeControllerProvider).languageCode;
    unawaited(
      ref
          .read(cuePlayerProvider)
          .play(
            CueCommand(
              clipId: clipId,
              variant: 0,
              priority: priority,
              haptic: haptic,
              tMs: 0,
              text: catalog.text(clipId, locale: locale),
              interrupts: priority >= 4,
            ),
          ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final left = _left.clamp(0, widget.seconds);
    final progress = widget.seconds == 0
        ? 1.0
        : (widget.seconds - _left) / widget.seconds;
    return FormaCard(
      raised: true,
      padding: const EdgeInsets.all(FormaSpacing.page),
      child: Column(
        children: [
          Text(l10n.restTitle, style: text.labelMedium),
          const SizedBox(height: FormaSpacing.sm),
          Semantics(
            container: true,
            liveRegion: true,
            label: l10n.holdSecondsSemantics(left),
            excludeSemantics: true,
            child: Text(
              '$left',
              key: const Key('rest_seconds'),
              style: text.displayLarge?.copyWith(color: FormaColors.secondary),
            ),
          ),
          const SizedBox(height: FormaSpacing.md),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: FormaColors.outline,
            color: FormaColors.secondary,
          ),
          const SizedBox(height: FormaSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('rest_skip'),
                  onPressed: _complete,
                  child: ButtonLabel(l10n.startNextSet),
                ),
              ),
              const SizedBox(width: FormaSpacing.md),
              Expanded(
                child: OutlinedButton(
                  key: const Key('rest_end'),
                  onPressed: () {
                    _timer?.cancel();
                    widget.onSkip();
                  },
                  child: ButtonLabel(l10n.endSession),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
