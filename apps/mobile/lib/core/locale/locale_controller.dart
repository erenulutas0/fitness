import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../settings/settings_controller.dart';

part 'locale_controller.g.dart';

/// App locale. Turkish is primary; English is offered from day one (D8).
///
/// The choice lives in `settings.json` (`AppSettings.locale`): `tr` or `en`
/// when the user picked one in Settings, `null` to follow the device. This
/// controller only derives a [Locale] from it, so the app switches language
/// the moment the setting is written.
@riverpod
class LocaleController extends _$LocaleController {
  @override
  Locale build() {
    final chosen = ref.watch(settingsProvider).value?.locale;
    if (chosen != null) return Locale(chosen);
    final device = PlatformDispatcher.instance.locale;
    return device.languageCode == 'en'
        ? const Locale('en')
        : const Locale('tr');
  }

  /// Persist [locale]; the state follows through [settingsProvider].
  Future<void> select(Locale locale) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(locale: locale.languageCode));

  /// `tr` / `en` for content lookups.
  String get code => state.languageCode;
}
