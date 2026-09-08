import 'dart:io';

import 'package:forma_rules/forma_rules.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'fixture_store.g.dart';

/// One recorded fixture on disk.
class StoredFixture {
  const StoredFixture({
    required this.file,
    required this.sizeBytes,
    required this.modified,
  });

  final File file;
  final int sizeBytes;
  final DateTime modified;

  String get name => file.uri.pathSegments.last;
  double get sizeMb => sizeBytes / (1024 * 1024);
}

/// Reads and writes landmark fixtures in the app's private documents
/// directory (`fixtures/`). Recordings hold joint coordinates only, never
/// video, and stay on the device until the founder shares them (docs/08).
class FixtureStore {
  const FixtureStore({this.rootOverride});

  /// Test seam: point the store at a temporary directory instead of the
  /// platform's documents directory.
  final Directory? rootOverride;

  Future<Directory> directory() async {
    final base = rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/fixtures');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// `bw_squat_front_p01_living_room_20260908-1542.json`
  static String fileNameFor(LandmarkFixture fixture) {
    final now = DateTime.tryParse(fixture.recordedAt ?? '') ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return '${fixture.exerciseId}_${fixture.view.name}_${fixture.person}_${fixture.environment}_$stamp.json';
  }

  Future<File> save(LandmarkFixture fixture) async {
    final dir = await directory();
    final file = File('${dir.path}/${fileNameFor(fixture)}');
    await file.writeAsString(fixture.rebased().toJsonString());
    return file;
  }

  Future<List<StoredFixture>> list() async {
    final dir = await directory();
    final files = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.json'),
    );
    final out = <StoredFixture>[];
    for (final f in files) {
      final stat = f.statSync();
      out.add(
        StoredFixture(
          file: f,
          sizeBytes: stat.size,
          modified: stat.modified,
        ),
      );
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<void> delete(StoredFixture fixture) => fixture.file.delete();

  /// Hand the JSON files to the system share sheet so they can be pulled off
  /// the phone (mail, Drive, cable). Nothing is uploaded by the app itself.
  Future<void> share(List<StoredFixture> fixtures) async {
    if (fixtures.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final f in fixtures) XFile(f.file.path)],
        subject: 'FORMA landmark fixtures (${fixtures.length})',
      ),
    );
  }
}

@Riverpod(keepAlive: true)
FixtureStore fixtureStore(Ref ref) => const FixtureStore();

@riverpod
Future<List<StoredFixture>> storedFixtures(Ref ref) =>
    ref.watch(fixtureStoreProvider).list();
