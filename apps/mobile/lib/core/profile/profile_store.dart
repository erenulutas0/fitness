import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'user_profile.dart';

part 'profile_store.g.dart';

/// The onboarding answers on disk: one `profile.json` next to `sessions/`
/// (D19 pattern). No file means onboarding has not been completed.
class ProfileStore {
  const ProfileStore({this.rootOverride});

  /// Test seam: point the store at a temporary directory instead of the
  /// platform's documents directory.
  final Directory? rootOverride;

  static const fileName = 'profile.json';

  Future<File> file() async {
    final base = rootOverride ?? await getApplicationDocumentsDirectory();
    if (!base.existsSync()) await base.create(recursive: true);
    return File('${base.path}/$fileName');
  }

  /// `null` when there is no profile yet. An unreadable file also reads as
  /// "no profile": onboarding takes a minute, a crash loop takes the user.
  Future<UserProfile?> load() async {
    final f = await file();
    if (!f.existsSync()) return null;
    try {
      final decoded = json.decode(await f.readAsString());
      if (decoded is Map<String, dynamic>) return UserProfile.fromJson(decoded);
    } on Object {
      // fall through
    }
    return null;
  }

  Future<File> save(UserProfile profile) async {
    final f = await file();
    await f.writeAsString(json.encode(profile.toJson()));
    return f;
  }

  /// "Verilerimi sil": the next launch goes through onboarding again.
  Future<void> delete() async {
    final f = await file();
    if (f.existsSync()) await f.delete();
  }
}

@Riverpod(keepAlive: true)
ProfileStore profileStore(Ref ref) => const ProfileStore();
