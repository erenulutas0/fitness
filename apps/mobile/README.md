# forma_mobile

FORMA Flutter uygulaması (feature-first clean architecture, Riverpod codegen, go_router, l10n TR/EN).

```bash
flutter pub get
dart run build_runner build          # riverpod .g.dart
flutter run                          # cihaz yoksa fake pose motoru ile çalışır
flutter test
```

Pose modeli: `pwsh ../../tools/fetch_models.ps1` (gitignore'da). Mimari ve ekranlar: `docs/05`, `docs/06`.
