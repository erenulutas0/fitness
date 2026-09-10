import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/features/history/domain/stored_session.dart';
import 'package:forma_mobile/features/history/infrastructure/session_store.dart';
import 'package:forma_rules/forma_rules.dart';

StoredSession _session(String id, DateTime at, {double? score}) =>
    StoredSession(
      id: id,
      startedAt: at,
      endedAt: at.add(const Duration(minutes: 12)),
      sets: [
        StoredSet(
          exerciseId: 'bw_squat',
          view: CameraView.side,
          durationMs: 40000,
          repCount: 10,
          holdMs: 0,
          errorCounts: const {'shallow_depth': 2},
          formScore: score,
        ),
      ],
    );

void main() {
  late Directory root;
  late SessionStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('forma_sessions');
    store = SessionStore(rootOverride: root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('a session survives a round trip through disk', () async {
    final result = SetResult(
      exerciseId: 'bw_squat',
      view: CameraView.side,
      startedAtMs: 0,
      endedAtMs: 40000,
      reps: const [],
      holds: const [],
    );
    final session = StoredSession(
      id: 'bw_squat_1',
      startedAt: DateTime(2026, 9, 10, 2, 44, 12),
      endedAt: DateTime(2026, 9, 10, 2, 56),
      sets: [StoredSet.fromResult(result)],
      device: 'samsung SM-S911B',
      modelVariant: 'lite',
    );
    final file = await store.save(session);
    expect(file.uri.pathSegments.last, 'session_20260910-024412.json');

    final back = (await store.list()).single;
    expect(back.id, 'bw_squat_1');
    expect(back.startedAt, session.startedAt);
    expect(back.device, 'samsung SM-S911B');
    expect(back.exercises, ['bw_squat']);
    expect(back.sets.single.view, CameraView.side);
  });

  test('history is newest first', () async {
    await store.save(_session('a', DateTime(2026, 9, 8, 10), score: 70));
    await store.save(_session('b', DateTime(2026, 9, 9, 10), score: 80));
    await store.save(_session('c', DateTime(2026, 9, 10, 10), score: 90));
    expect([for (final s in await store.list()) s.id], ['c', 'b', 'a']);
    expect([for (final s in await store.list(limit: 2)) s.id], ['c', 'b']);
  });

  test('latest() skips the session that just ended', () async {
    await store.save(_session('older', DateTime(2026, 9, 9, 10), score: 70));
    await store.save(_session('current', DateTime(2026, 9, 10, 10), score: 90));
    expect((await store.latest())!.id, 'current');
    expect((await store.latest(exceptId: 'current'))!.id, 'older');
    expect(await store.latest(exceptId: 'older'), isNotNull);
  });

  test('one corrupt file does not cost the user their history', () async {
    await store.save(_session('good', DateTime(2026, 9, 9, 10), score: 70));
    File(
      '${(await store.directory()).path}/session_20260910-999999.json',
    ).writeAsStringSync('{not json');
    final list = await store.list();
    expect(list, hasLength(1));
    expect(list.single.id, 'good');
  });

  test('aggregates read back the same as they were computed', () async {
    final session = StoredSession(
      id: 'agg',
      startedAt: DateTime(2026, 9, 10),
      endedAt: DateTime(2026, 9, 10, 0, 20),
      sets: [
        StoredSet(
          exerciseId: 'bw_squat',
          view: CameraView.side,
          durationMs: 1,
          repCount: 10,
          holdMs: 0,
          errorCounts: const {'shallow_depth': 2},
          formScore: 60,
        ),
        StoredSet(
          exerciseId: 'bw_squat',
          view: CameraView.side,
          durationMs: 1,
          repCount: 8,
          holdMs: 0,
          errorCounts: const {'shallow_depth': 1, 'torso_lean': 3},
          formScore: 80,
        ),
      ],
    );
    await store.save(session);
    final back = (await store.list()).single;
    expect(back.meanScore, 70);
    expect(back.totalReps, 18);
    expect(back.errorCounts, {'shallow_depth': 3, 'torso_lean': 3});
  });

  test('an empty history has nothing to compare against', () async {
    expect(await store.list(), isEmpty);
    expect(await store.latest(), isNull);
  });
}
