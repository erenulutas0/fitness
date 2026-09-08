import 'package:flutter/services.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_repository.g.dart';

/// The content bundle (`forma_content` package assets): exercise rule sets and
/// cue texts. Loaded once; remote bundle updates come in v0.3 (docs/10 P11).
class ContentBundle {
  const ContentBundle({required this.exercises, required this.cues});

  final Map<String, ExerciseDefinition> exercises;
  final CueCatalog cues;

  ExerciseDefinition? exercise(String id) => exercises[id];

  /// Exercises the app should list (drafts hidden unless [includeDrafts]).
  List<ExerciseDefinition> visible({bool includeDrafts = false}) => [
    for (final e in exercises.values)
      if (includeDrafts || e.status != 'draft') e,
  ]..sort((a, b) => a.id.compareTo(b.id));
}

const _prefix = 'packages/forma_content/';

Future<ContentBundle> loadContentBundle(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final exercises = <String, ExerciseDefinition>{};
  for (final key in manifest.listAssets()) {
    if (!key.startsWith('${_prefix}exercises/') || !key.endsWith('.json')) {
      continue;
    }
    final def = ExerciseDefinition.parse(await bundle.loadString(key));
    exercises[def.id] = def;
  }
  final cues = CueCatalog.parse(
    await bundle.loadString('${_prefix}cues/cues.json'),
  );
  return ContentBundle(exercises: exercises, cues: cues);
}

@Riverpod(keepAlive: true)
Future<ContentBundle> contentRepository(Ref ref) =>
    loadContentBundle(rootBundle);
