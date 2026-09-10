import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/core/profile/profile_controller.dart';
import 'package:forma_mobile/core/profile/profile_store.dart';
import 'package:forma_mobile/core/profile/user_profile.dart';

void main() {
  late Directory root;
  late ProfileStore store;

  final profile = UserProfile(
    goal: TrainingGoal.muscle,
    level: TrainingLevel.newcomer,
    equipment: Equipment.dumbbell,
    createdAt: DateTime(2026, 9, 10, 12, 30),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('forma_profile');
    store = ProfileStore(rootOverride: root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('no file means no profile', () async {
    expect(await store.load(), isNull);
  });

  test('a profile survives a round trip through disk', () async {
    final file = await store.save(profile);
    expect(file.uri.pathSegments.last, 'profile.json');
    expect(await store.load(), profile);
  });

  test('level is written as "new" on the wire (docs/05 §9)', () async {
    final file = await store.save(profile);
    final raw = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(raw['level'], 'new');
    expect(raw['goal'], 'muscle');
    expect(raw['equipment'], 'dumbbell');
    expect(raw.keys, isNot(contains('heightCm')), reason: 'no health data');
  });

  test('an unreadable file reads as no profile', () async {
    (await store.file()).writeAsStringSync('{not json');
    expect(await store.load(), isNull);
  });

  test('unknown answers fall back instead of re-running onboarding', () {
    final back = UserProfile.fromJson(const {
      'goal': 'flexibility',
      'level': 'pro',
      'equipment': 'barbell',
      'createdAt': '2026-09-10T12:30:00.000',
    });
    expect(back.goal, TrainingGoal.form);
    expect(back.level, TrainingLevel.newcomer);
    expect(back.equipment, Equipment.none);
  });

  test('delete() sends the user back through onboarding', () async {
    await store.save(profile);
    await store.delete();
    expect((await store.file()).existsSync(), isFalse);
    expect(await store.load(), isNull);
  });

  test('hasProfile follows save() and clear()', () async {
    final container = ProviderContainer(
      overrides: [profileStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(await container.read(hasProfileProvider.future), isFalse);

    await container.read(profileProvider.notifier).save(profile);
    expect(await container.read(hasProfileProvider.future), isTrue);
    expect(container.read(profileProvider).value, profile);
    expect(await store.load(), profile, reason: 'on disk too');

    await container.read(profileProvider.notifier).clear();
    expect(await container.read(hasProfileProvider.future), isFalse);
    expect(container.read(profileProvider).value, isNull);
  });
}
