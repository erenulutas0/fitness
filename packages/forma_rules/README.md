# forma_rules

FORMA'nın saf Dart kural motoru: `PoseFrame` → One Euro smoother → `FeatureExtractor` → `RepDetector` /
`HoldDetector` → JSON kural DSL'i (`RuleEvaluator`) → `ScoreEngine` → `FeedbackScheduler`. `ExerciseSession`
hepsini bağlar. Flutter bağımlılığı yok; aynı kod mobilde, CLI'da (`tools/eval`) ve web demosunda çalışır.

```bash
dart test                          # 105 test, sentetik golden fixture'lar dahil
dart run tool/gen_fixtures.dart    # test/fixtures/*.json yeniden üret
```

- DSL şeması ve özellik listesi: `lib/src/rules/exercise_definition.dart`, `lib/src/features/feature_extractor.dart` (`FeatureNames`).
- Fixture formatı: `docs/fixtures-schema.md`.
- Sentetik 3D iskelet üretici (squat, push-up, plank, glute bridge): `lib/src/synthetic/synthetic_pose.dart`.
