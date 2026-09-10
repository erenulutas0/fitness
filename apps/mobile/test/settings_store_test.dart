import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/core/settings/app_settings.dart';
import 'package:forma_mobile/core/settings/settings_controller.dart';
import 'package:forma_mobile/core/settings/settings_store.dart';

void main() {
  late Directory root;
  late SettingsStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('forma_settings');
    store = SettingsStore(rootOverride: root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('no file yet reads as the defaults', () async {
    expect(await store.load(), AppSettings.defaults);
    expect(AppSettings.defaults.soundOn, isTrue);
    expect(AppSettings.defaults.quietMode, isFalse);
    expect(AppSettings.defaults.overlayOn, isTrue);
    expect(AppSettings.defaults.locale, isNull);
  });

  test('settings survive a round trip through disk', () async {
    const s = AppSettings(
      soundOn: false,
      quietMode: true,
      overlayOn: false,
      locale: 'en',
    );
    final file = await store.save(s);
    expect(file.uri.pathSegments.last, 'settings.json');
    expect(await store.load(), s);
  });

  test('a corrupt or foreign file costs a toggle, not a launch', () async {
    final file = await store.file();
    file.writeAsStringSync('{not json');
    expect(await store.load(), AppSettings.defaults);

    file.writeAsStringSync('{"soundOn": false, "locale": "de"}');
    final back = await store.load();
    expect(back.soundOn, isFalse);
    expect(back.overlayOn, isTrue, reason: 'missing fields keep defaults');
    expect(back.locale, isNull, reason: 'unsupported locale is dropped');
  });

  test('delete() brings back the defaults', () async {
    await store.save(const AppSettings(quietMode: true));
    await store.delete();
    expect((await store.file()).existsSync(), isFalse);
    expect(await store.load(), AppSettings.defaults);
  });

  test('the controller writes before it changes state', () async {
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(await container.read(settingsProvider.future), AppSettings.defaults);
    expect(container.read(settingsProvider).orDefault.soundOn, isTrue);

    await container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(soundOn: false, locale: 'tr'));
    expect(container.read(settingsProvider).orDefault.soundOn, isFalse);
    expect(container.read(settingsProvider).orDefault.locale, 'tr');
    expect((await store.load()).soundOn, isFalse, reason: 'on disk too');

    await container.read(settingsProvider.notifier).reset();
    expect(container.read(settingsProvider).orDefault, AppSettings.defaults);
    expect((await store.file()).existsSync(), isFalse);
  });

  test('orDefault is the defaults while the file is still loading', () {
    const loading = AsyncValue<AppSettings>.loading();
    expect(loading.orDefault, AppSettings.defaults);
  });
}
