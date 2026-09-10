import 'package:flutter/foundation.dart';

/// User preferences (brief Faz 1 §4). Small enough to be one JSON object.
///
/// [locale] is `'tr'`, `'en'` or `null` for "never chosen — follow the
/// device"; the language picker writes it, `LocaleController` reads it.
@immutable
class AppSettings {
  const AppSettings({
    this.soundOn = true,
    this.quietMode = false,
    this.overlayOn = true,
    this.locale,
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    soundOn: j['soundOn'] as bool? ?? defaults.soundOn,
    quietMode: j['quietMode'] as bool? ?? defaults.quietMode,
    overlayOn: j['overlayOn'] as bool? ?? defaults.overlayOn,
    locale: switch (j['locale']) {
      final String code when supportedLocales.contains(code) => code,
      _ => null,
    },
  );

  static const defaults = AppSettings();
  static const supportedLocales = ['tr', 'en'];
  static const schemaVersion = 1;

  /// Audio cues on. Off keeps haptics.
  final bool soundOn;

  /// "Az konuş": only the most important cue, less often (`FeedbackPolicy`).
  final bool quietMode;

  /// Draw the skeleton over the camera preview.
  final bool overlayOn;

  /// `'tr'` | `'en'` | null (device).
  final String? locale;

  AppSettings copyWith({
    bool? soundOn,
    bool? quietMode,
    bool? overlayOn,
    String? locale,
  }) => AppSettings(
    soundOn: soundOn ?? this.soundOn,
    quietMode: quietMode ?? this.quietMode,
    overlayOn: overlayOn ?? this.overlayOn,
    locale: locale ?? this.locale,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'soundOn': soundOn,
    'quietMode': quietMode,
    'overlayOn': overlayOn,
    if (locale != null) 'locale': locale,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.soundOn == soundOn &&
      other.quietMode == quietMode &&
      other.overlayOn == overlayOn &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(soundOn, quietMode, overlayOn, locale);

  @override
  String toString() =>
      'AppSettings(soundOn: $soundOn, quietMode: $quietMode, '
      'overlayOn: $overlayOn, locale: $locale)';
}
