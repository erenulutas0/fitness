# FORMA — proje bağlamı

Telefon kamerasıyla gerçek zamanlı egzersiz formu düzelten, sesli geri bildirim veren Flutter uygulaması.
Kod adı FORMA; marka adı ayrıca seçilecek. Türkçe birincil, İngilizce day-1.

Önce `docs/00-README.md`'yi (özet + Decision Log), sonra ilgili dokümanı oku. Bir karara aykırı bir şey
gerekiyorsa önce sor; karar değişirse Decision Log'a satır ekle.

## Session ritüeli (her oturumda, atlama)

1. `TODO.md`'yi oku. "Şimdi" bölümündeki ilk açık maddeden devam et.
2. Biten maddeyi `[x]` yap ve tarihi yaz; oturumda keşfedilen yeni işi uygun bölüme ekle.
3. Oturum sonunda: `TODO.md` güncel, testler yeşil, commit atılmış ve `main`'e push edilmiş olsun.
4. Kararlar `TODO.md`'ye değil `docs/00-README.md` Decision Log'a yazılır.

## Değişmez kurallar

- Kamera frame'leri Dart'a geçmez; cihaz dışına asla çıkmaz. Native katman yalnızca kamera + inference + overlay.
- Poz motoru: MediaPipe Pose Landmarker (Apache 2.0). Ultralytics/YOLO (AGPL) ve CC BY-NC lisanslı hiçbir
  model/veri eklenmez. Yeni bağımlılıkta lisansı PR/commit açıklamasına yaz.
- Antrenman mantığı (rep detection, kurallar, skor, feedback scheduler) saf Dart, `packages/forma_rules`
  içinde; Flutter ve plugin bağımlılığı sıfır; birim + golden replay testli.
- Egzersiz kuralları kodda değil `content/exercises/*.json` içinde (DSL şeması: docs/05 §4 ve
  `packages/forma_rules/lib/src/rules/`).
- Sesli geri bildirim önceden üretilmiş kliplerle (`apps/mobile/assets/audio/cues`); runtime TTS yalnızca yedek.
- Sağlık verisi tutulmaz; analitik olaylarına görüntü/landmark girmez.
- Kullanıcıya görünen her metin TR ve EN (`l10n`), TR birincil. Cue dili: emir kipi, ≤ 4 kelime, yargılamaz.
- MediaPipe/CameraX/AVFoundation API detayında uydurma yok: emin değilsen resmi dokümana bak ya da sor.

## Stack

Flutter stable (3.41) · Dart 3.11 · Riverpod (codegen) · go_router · Drift · Supabase · RevenueCat · PostHog ·
Sentry · just_audio + audio_session · flutter_inappwebview (anatomi, v0.2) · freezed / json_serializable ·
very_good_analysis.
Native: Android Kotlin (CameraX + MediaPipe Tasks Vision), iOS Swift (AVFoundation + MediaPipe Tasks iOS).

## Yapı (pub workspace, melos yok)

```
pubspec.yaml            # workspace kökü
apps/mobile             # Flutter uygulaması (feature-first clean architecture)
packages/forma_rules    # saf Dart kural motoru (pipeline: smoother → features → rep FSM → rules → score → feedback)
packages/forma_pose     # kamera + MediaPipe plugin'i (platform interface + android + ios + fake)
tools/eval              # precision/recall eval CLI (fixture JSON → rapor)
tools/tts_gen           # Python: cues.json → Opus klipler
content/                # exercises/*.json, cues/cues.json, sources/*.json (versiyonlu içerik)
docs/                   # 00-11 doküman seti + plans/ + eval/
```

## Komutlar

```
dart pub get                                  # kökte; tüm workspace'i çözer
cd packages/forma_rules && dart test          # kural motoru testleri
cd apps/mobile && flutter analyze && flutter test
cd apps/mobile && dart run build_runner build -d   # riverpod/freezed/json codegen
cd tools/eval && dart run bin/eval.dart --fixtures ../../packages/forma_rules/test/fixtures
cd apps/mobile && flutter test test/screenshots_test.dart --dart-define=SCREENSHOT_DIR=<dir>  # ekranlar, gerçek fontla PNG
```

## Çalışma şekli

- Önce plan, sonra kod. Kapsamı küçük tut; bir iş = bir commit (conventional commits, İngilizce).
- Her yeni davranış için test: birim (matematik/FSM/scheduler) + golden replay (`test/fixtures/*.json`).
- Performans bütçeleri docs/05 §10; ihlal ediyorsan söyle.
- Eşikleri elle ayarlama; `tools/eval` ile ayarla.
- Türkçe açıklama/doküman, İngilizce kod/tanımlayıcı/commit.
