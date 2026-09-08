# FORMA

> Telefon kamerasıyla hareketini izleyip **anında sesle düzelten**, her setin sonunda **hangi kası çalıştırdığını
> gösteren** ve verdiği her öneride **kaynağını gösteren**, Türkçe birinci sınıf bir kuvvet antrenmanı koçu.
> Görüntü telefondan hiç çıkmaz.

Kod adı **FORMA**; marka adı ayrıca seçilecek. Durum: **v0.1 "Kamera Koç" geliştirme aşamasında** (bkz. `TODO.md`).

## Repo haritası

| Yol | Ne |
|---|---|
| `docs/` | Vizyon, pazar, rekabet, görüntü işleme/lisans, mimari, UX, pazarlama, hukuk, yol haritası (00–11) |
| `TODO.md` | Canlı yapılacaklar listesi — her oturumda güncellenir |
| `CLAUDE.md` | Claude Code için proje kuralları |
| `packages/forma_rules` | Saf Dart kural motoru: landmark yumuşatma → özellikler → tekrar FSM → kural DSL → skor → geri bildirim |
| `packages/forma_pose` | Kamera + MediaPipe Pose Landmarker plugin'i (Android Kotlin, iOS Swift, Fake) |
| `apps/mobile` | Flutter uygulaması |
| `content/` | Egzersiz kural setleri (`exercises/*.json`), sesli cue metinleri (`cues/cues.json`), kaynaklar |
| `tools/eval` | Precision/recall değerlendirme CLI'ı |
| `tools/tts_gen` | Cue kliplerini üreten Python scripti (Google Cloud TTS → Opus) |

## Kurulum

Gereksinimler: Flutter 3.41+ (Dart 3.11+), Android SDK 36, JDK 17+, (iOS için) Xcode 16+.

```bash
dart pub get                                   # workspace kökünde
cd packages/forma_rules && dart test           # kural motoru
cd apps/mobile && flutter run                  # uygulama (cihaz yoksa fake pose stream ile çalışır)
```

Pose modeli (`.task`) repoda değil; indirmek için:

```bash
pwsh tools/fetch_models.ps1     # Windows
sh tools/fetch_models.sh        # macOS/Linux
```

## Mimari (özet)

```
Kamera (native) → MediaPipe Pose Landmarker (native, GPU) → PoseFrame (EventChannel, binary)
  → forma_rules: OneEuro smoother → FeatureExtractor → RepDetector (FSM) → RuleEvaluator (JSON DSL)
  → ScoreEngine → FeedbackScheduler → AudioCuePlayer / Haptics / HUD
```

Ayrıntı: `docs/05-teknik-stack-ve-mimari.md`.

## Lisans

Kaynak kod: tüm hakları saklıdır (şimdilik). Üçüncü taraf bileşenler: MediaPipe (Apache 2.0), Z-Anatomy /
BodyParts3D türevleri (CC BY-SA), fontlar (SIL OFL). Tam liste uygulama içi "Lisanslar" ekranında ve `docs/08`.
