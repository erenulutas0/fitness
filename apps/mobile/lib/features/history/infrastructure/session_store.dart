import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/stored_session.dart';

part 'session_store.g.dart';

/// Workout history, one JSON file per session under `sessions/`.
///
/// Deliberately not a database (D19). What we keep is a few rows per workout —
/// a few hundred a year — so the querying SQL buys is not worth a code
/// generator and a native sqlite library, and drift_dev cannot currently be
/// installed alongside the analyzer version custom_lint and freezed pin.
/// [SessionStore] is the seam: if history ever needs real queries, this class
/// changes and nothing above it does.
class SessionStore {
  const SessionStore({this.rootOverride});

  /// Test seam: point the store at a temporary directory instead of the
  /// platform's documents directory.
  final Directory? rootOverride;

  Future<Directory> directory() async {
    final base = rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sessions');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// `session_20260910-024412.json` — sortable by name, which is why the
  /// listing never has to open a file just to order the results.
  static String fileNameFor(StoredSession s) {
    final t = s.startedAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return 'session_$stamp.json';
  }

  Future<File> save(StoredSession session) async {
    final dir = await directory();
    final file = File('${dir.path}/${fileNameFor(session)}');
    await file.writeAsString(json.encode(session.toJson()));
    return file;
  }

  /// Newest first. Unreadable files are skipped rather than thrown: one bad
  /// file must not cost the user their whole history.
  Future<List<StoredSession>> list({int? limit}) async {
    final dir = await directory();
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    final out = <StoredSession>[];
    for (final f in files) {
      if (limit != null && out.length >= limit) break;
      try {
        final decoded = json.decode(await f.readAsString());
        if (decoded is Map<String, dynamic>) {
          out.add(StoredSession.fromJson(decoded));
        }
      } on Object {
        continue;
      }
    }
    return out;
  }

  /// The most recent session, ignoring [exceptId] so a session that has just
  /// been written can ask what came before it.
  Future<StoredSession?> latest({String? exceptId}) async {
    for (final s in await list(limit: 5)) {
      if (s.id != exceptId) return s;
    }
    return null;
  }

  Future<void> delete(StoredSession session) async {
    final file = File('${(await directory()).path}/${fileNameFor(session)}');
    if (file.existsSync()) await file.delete();
  }
}

@Riverpod(keepAlive: true)
SessionStore sessionStore(Ref ref) => const SessionStore();

/// The session before the one on screen, for "today vs last" (docs/06 §4.5).
@riverpod
Future<StoredSession?> previousSession(Ref ref, String currentId) =>
    ref.watch(sessionStoreProvider).latest(exceptId: currentId);
