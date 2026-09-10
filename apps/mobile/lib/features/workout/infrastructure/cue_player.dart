import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/locale/locale_controller.dart';
import '../../../core/settings/settings_controller.dart';

part 'cue_player.g.dart';

/// Speaks [CueCommand]s and fires the matching haptic.
abstract class CuePlayer {
  Future<void> play(CueCommand cue);

  Future<void> playAll(List<CueCommand> cues) async {
    for (final c in cues) {
      await play(c);
    }
  }

  /// Warm the audio path up so the first cue of a set is not the slow one.
  Future<void> prepare() async {}

  Future<void> dispose() async {}
}

/// Haptics only, plus a debug log. Used by tests and by any build without a
/// working audio path.
class HapticCuePlayer extends CuePlayer {
  final List<CueCommand> history = [];

  @override
  Future<void> play(CueCommand cue) async {
    history.add(cue);
    if (history.length > 200) history.removeAt(0);
    if (kDebugMode) {
      debugPrint('[cue] ${cue.clipId}#${cue.variant} "${cue.text}"');
    }
    await playHaptic(cue.haptic);
  }

  static Future<void> playHaptic(HapticKind haptic) async {
    switch (haptic) {
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

/// The real coach voice (docs/10 Prompt 5).
///
/// Pre-rendered clips are the product (D5): they start in a few milliseconds
/// and cost nothing at runtime. Until `tools/tts_gen` has produced them the
/// player falls back to the device's own speech engine, which keeps the coach
/// audible today at the cost of a slower, more robotic first word.
///
/// One channel only: a higher-priority cue cuts whatever is playing, a
/// lower-priority one is dropped rather than queued, because a correction two
/// reps late is worse than no correction.
class VoiceCuePlayer extends CuePlayer {
  VoiceCuePlayer({required this.locale, AudioPlayer? player, FlutterTts? tts})
    : _player = player ?? AudioPlayer(),
      _tts = tts ?? FlutterTts();

  /// `tr` or `en`; picks both the clip folder and the speech voice.
  final String locale;
  final AudioPlayer _player;
  final FlutterTts _tts;

  /// Settings "ses": off means no clip and no speech, but the haptic still
  /// fires — the phone across the room can still tap out the count.
  bool soundOn = true;

  final List<CueCommand> history = [];
  bool _ready = false;
  int _playingPriority = 0;
  final Set<String> _missingClips = {};
  bool _speaking = false;

  static const _basePath = 'assets/audio/cues';

  @override
  Future<void> prepare() async {
    if (_ready) return;
    _ready = true;
    try {
      final session = await AudioSession.instance;
      // Duck the user's music instead of stopping it: people train to music.
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.assistanceAccessibility,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
        ),
      );
      await session.setActive(true);
    } on Object catch (e) {
      debugPrint('[cue] audio session unavailable: $e');
    }
    try {
      await _tts.setLanguage(locale == 'en' ? 'en-US' : 'tr-TR');
      await _tts.setSpeechRate(locale == 'en' ? 0.55 : 0.6);
      await _tts.awaitSpeakCompletion(true);
      // First utterance on Android costs a few hundred ms; spend it now.
      await _tts.speak(' ');
    } on Object catch (e) {
      debugPrint('[cue] tts unavailable: $e');
    }
  }

  @override
  Future<void> play(CueCommand cue) async {
    history.add(cue);
    if (history.length > 200) history.removeAt(0);
    unawaited(HapticCuePlayer.playHaptic(cue.haptic));
    if (!soundOn) return;

    if (!cue.interrupts && cue.priority < _playingPriority && _isBusy) {
      return; // something more important is already speaking
    }
    _playingPriority = cue.priority;
    final asset = '$_basePath/$locale/${cue.clipId}_${cue.variant}.opus';
    if (!_missingClips.contains(asset)) {
      try {
        await _player.stop();
        await _player.setAsset(asset);
        unawaited(
          _player.play().whenComplete(() => _playingPriority = 0),
        );
        return;
      } on Object {
        // Asset not bundled yet: remember it and never retry this one.
        _missingClips.add(asset);
      }
    }
    final text = cue.text;
    if (text == null || text.isEmpty) {
      _playingPriority = 0;
      return;
    }
    try {
      await _tts.stop();
      _speaking = true;
      unawaited(
        _tts.speak(text).whenComplete(() {
          _speaking = false;
          _playingPriority = 0;
        }),
      );
    } on Object catch (e) {
      _speaking = false;
      _playingPriority = 0;
      debugPrint('[cue] speak failed: $e');
    }
  }

  /// Busy has to include the speech engine, not just the clip player. Until
  /// the clips are rendered every cue goes down the TTS path, and with only
  /// `_player.playing` here the priority policy was dead code: each cue cut
  /// the one before it, so a correction could truncate a safety cue.
  bool get _isBusy => _player.playing || _speaking;

  /// Clip ids that were requested but are not bundled; drives the TODO for
  /// `tools/tts_gen`.
  Set<String> get missingClips => Set.unmodifiable(_missingClips);

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _tts.stop();
  }
}

@Riverpod(keepAlive: true)
CuePlayer cuePlayer(Ref ref) {
  // Widget tests drive the pipeline without a platform audio channel.
  if (kIsWeb || _isTest) return HapticCuePlayer();
  final player = VoiceCuePlayer(
    locale: ref.watch(localeControllerProvider).languageCode,
  )..soundOn = ref.read(settingsProvider).orDefault.soundOn;
  // A toggle in Settings applies to the next cue, not the next launch.
  ref.listen(
    settingsProvider,
    (_, next) => player.soundOn = next.orDefault.soundOn,
  );
  unawaited(player.prepare());
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
}

bool get _isTest =>
    const bool.fromEnvironment('FLUTTER_TEST') ||
    Zone.current[#test.declarer] != null;
