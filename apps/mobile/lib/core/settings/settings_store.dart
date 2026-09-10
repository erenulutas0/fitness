import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_settings.dart';

part 'settings_store.g.dart';

/// Preferences on disk: one `settings.json` next to `sessions/` (D19 —
/// a file, not a database, for four fields).
///
/// Missing or unreadable → [AppSettings.defaults]. A corrupt preferences file
/// costs the user a toggle, never a crash on launch.
class SettingsStore {
  const SettingsStore({this.rootOverride});

  /// Test seam: point the store at a temporary directory instead of the
  /// platform's documents directory.
  final Directory? rootOverride;

  static const fileName = 'settings.json';

  Future<File> file() async {
    final base = rootOverride ?? await getApplicationDocumentsDirectory();
    if (!base.existsSync()) await base.create(recursive: true);
    return File('${base.path}/$fileName');
  }

  Future<AppSettings> load() async {
    final f = await file();
    if (!f.existsSync()) return AppSettings.defaults;
    try {
      final decoded = json.decode(await f.readAsString());
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
    } on Object {
      // fall through
    }
    return AppSettings.defaults;
  }

  Future<File> save(AppSettings settings) async {
    final f = await file();
    await f.writeAsString(json.encode(settings.toJson()));
    return f;
  }

  /// "Verilerimi sil": the next [load] returns the defaults.
  Future<void> delete() async {
    final f = await file();
    if (f.existsSync()) await f.delete();
  }
}

@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) => const SettingsStore();
