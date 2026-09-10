import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_settings.dart';
import 'settings_store.dart';

part 'settings_controller.g.dart';

/// `settingsProvider`: the current [AppSettings], loaded once and kept alive.
///
/// Readers (the HUD) `ref.watch(settingsProvider).orDefault`; the settings
/// screen calls [update]. Every write goes to disk before the state changes,
/// so what the user sees is what will be there after a restart.
@Riverpod(keepAlive: true, name: 'settingsProvider')
class SettingsController extends _$SettingsController {
  @override
  Future<AppSettings> build() => ref.watch(settingsStoreProvider).load();

  /// `update((s) => s.copyWith(soundOn: false))`: Riverpod's own [update],
  /// except the result is on disk before it is in [state]. `locale` cannot
  /// be reset to "device" through [AppSettings.copyWith] — nothing in the
  /// app needs that; [reset] clears it.
  @override
  Future<AppSettings> update(
    FutureOr<AppSettings> Function(AppSettings) cb, {
    FutureOr<AppSettings> Function(Object, StackTrace)? onError,
  }) async {
    AppSettings next;
    try {
      next = await cb(await future);
    } on Object catch (e, st) {
      if (onError == null) rethrow;
      next = await onError(e, st);
    }
    assert(
      next.locale == null || AppSettings.supportedLocales.contains(next.locale),
      'locale must be one of ${AppSettings.supportedLocales}',
    );
    if (state.value != next) {
      await ref.read(settingsStoreProvider).save(next);
      state = AsyncData(next);
    }
    return next;
  }

  /// Back to [AppSettings.defaults] and no file on disk ("Verilerimi sil").
  Future<void> reset() async {
    await ref.read(settingsStoreProvider).delete();
    state = const AsyncData(AppSettings.defaults);
  }
}

extension AsyncAppSettings on AsyncValue<AppSettings> {
  /// The settings, or the defaults while the file is still being read.
  /// Synchronous on purpose: the HUD cannot wait on a toggle.
  AppSettings get orDefault => value ?? AppSettings.defaults;
}
