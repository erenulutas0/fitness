import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/theme.dart';
import 'package:forma_mobile/core/locale/locale_controller.dart';
import 'package:forma_mobile/core/settings/settings_store.dart';
import 'package:forma_mobile/features/settings/presentation/settings_screen.dart';
import 'package:forma_mobile/l10n/app_localizations.dart';

void main() {
  late Directory root;
  late SettingsStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('forma_settings_screen');
    store = SettingsStore(rootOverride: root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  Widget app() => ProviderScope(
    overrides: [settingsStoreProvider.overrideWithValue(store)],
    child: MaterialApp(
      theme: FormaTheme.dark(),
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SettingsScreen(),
    ),
  );

  testWidgets('flipping "Az konuş" writes settings.json', (tester) async {
    // Real file I/O, so the whole interaction runs under runAsync.
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Ayarlar'), findsOneWidget);

      SwitchListTile quiet() =>
          tester.widget(find.byKey(const Key('settings_quiet')));
      expect(quiet().value, isFalse);
      expect((await store.file()).existsSync(), isFalse);

      await tester.tap(find.byKey(const Key('settings_quiet')));
      // Give the write a moment to land on disk before looking.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(quiet().value, isTrue);
      final saved = await store.load();
      expect(saved.quietMode, isTrue);
      expect(saved.soundOn, isTrue, reason: 'the other fields stay');
      expect((await store.file()).existsSync(), isTrue);
    });
  });

  testWidgets('the language row writes the locale and the app follows', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Cihaz dili'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('option_language_en')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect((await store.load()).locale, 'en');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(container.read(localeControllerProvider), const Locale('en'));
    });
  });
}
