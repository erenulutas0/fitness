import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cue_player.g.dart';

/// Plays [CueCommand]s: audio clip + haptic. The audio implementation
/// (just_audio + audio_session ducking, docs/10 Prompt 5) is not wired yet;
/// this default plays the haptic and logs the text so the HUD subtitle and
/// the scheduler logic can be exercised end to end.
abstract class CuePlayer {
  Future<void> play(CueCommand cue);

  Future<void> playAll(List<CueCommand> cues) async {
    for (final c in cues) {
      await play(c);
    }
  }
}

class HapticLogCuePlayer extends CuePlayer {
  final List<CueCommand> history = [];

  @override
  Future<void> play(CueCommand cue) async {
    history.add(cue);
    if (history.length > 200) history.removeAt(0);
    if (kDebugMode) {
      debugPrint('[cue] ${cue.clipId}#${cue.variant} "${cue.text}"');
    }
    switch (cue.haptic) {
      case HapticKind.tick:
        await HapticFeedback.selectionClick();
      case HapticKind.pulse:
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await HapticFeedback.mediumImpact();
      case HapticKind.success:
        await HapticFeedback.lightImpact();
      case HapticKind.none:
        break;
    }
  }
}

@Riverpod(keepAlive: true)
CuePlayer cuePlayer(Ref ref) => HapticLogCuePlayer();
