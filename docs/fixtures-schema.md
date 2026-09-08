# Landmark fixture şeması (v1)

Kayıtlı ya da sentetik **landmark dizileri**; video yok, kimlik yok. `packages/forma_rules/test/fixtures/` altındaki
sentetik fixture'lar repoda; gerçek kişilerden kaydedilenler `data/fixtures/` altında ve **gitignore'da** (hendek;
onam formu şart — bkz. docs/08).

```jsonc
{
  "schemaVersion": 1,
  "id": "squat_side_p01_livingroom_01",
  "exerciseId": "bw_squat",            // content/exercises/<id>.json
  "view": "side",                      // front | side
  "person": "p01",                     // anonim kişi kodu
  "environment": "living_room",        // living_room | gym | low_light | outdoor ...
  "device": "Pixel 7",                 // isteğe bağlı
  "modelVariant": "lite",              // lite | full | heavy
  "recordedAt": "2026-09-20T10:15:00Z",
  "synthetic": false,
  "expectedReps": 10,                  // reps modunda
  "expectedHoldMs": 30000,             // hold modunda
  "errorLabels": [                     // tekrar bazında etiket (1 tabanlı)
    { "rep": 2, "rules": ["knee_valgus"] },
    { "rep": 5, "rules": ["knee_valgus", "shallow_depth"] }
  ],
  "notes": "bol eşofman, pencere arkada",
  "frames": [
    {
      "t": 0,                          // ms, ilk frame'e göre ya da mutlak (artan olmalı)
      "w": 720, "h": 1280,             // frame boyutu (aspect düzeltmesi için)
      "lm": [x, y, z, visibility, presence, ...],   // 33 × 5 = 165 sayı, normalize görüntü koordinatı
      "world": [x, y, z, ...],         // 33 × 3 = 99 sayı, metre, kalça merkezli (opsiyonel)
      "fps": 29.7, "inf": 21.3, "br": 0.42   // opsiyonel: fps, inference ms, ortalama parlaklık
    }
  ]
}
```

## Kurallar

- `frames[].t` artan sıralı; boşluk > 700 ms ise smoother sıfırlanır.
- `lm` sırası MediaPipe 33-nokta topolojisi (`PoseLandmark` enum, `packages/forma_rules/lib/src/landmarks.dart`).
- Kişi tespit edilmeyen frame: tüm visibility/presence 0.
- Etiketler **tekrar bazında**; kural id'leri egzersiz JSON'undaki `rules[].id` ile aynı.
- Kayıt aracı (uygulama içi gizli ekran, debug flavor) bu formatı üretir; `tools/eval` bu formatı okur.

## Sentetik fixture üretimi

```dart
final frames = const SyntheticPose().squat(view: CameraView.front, reps: 5, valgus: 0.3);
final fx = LandmarkFixture(id: 'syn_squat_front_valgus', exerciseId: 'bw_squat', view: CameraView.front,
  synthetic: true, expectedReps: 5, errorLabels: [for (var i = 1; i <= 5; i++) FixtureLabel(rep: i, rules: ['knee_valgus'])],
  frames: frames);
File('test/fixtures/syn_squat_front_valgus.json').writeAsStringSync(fx.toJsonString());
```
