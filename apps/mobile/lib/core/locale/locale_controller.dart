import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// App locale. Turkish is primary; English is offered from day one (D8).
@riverpod
class LocaleController extends _$LocaleController {
  @override
  Locale build() {
    final device = PlatformDispatcher.instance.locale;
    return device.languageCode == 'en'
        ? const Locale('en')
        : const Locale('tr');
  }

  // ignore: use_setters_to_change_properties, a Notifier mutation, not a plain property
  void select(Locale locale) => state = locale;

  /// `tr` / `en` for content lookups.
  String get code => state.languageCode;
}
