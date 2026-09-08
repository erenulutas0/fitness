# 05 — Teknik Stack, Mimari, Tasarım Kalıpları

## 1. Stack kararı

| Seçenek | Artı | Eksi | Sonuç |
|---|---|---|---|
| **Flutter + kendi native pose plugin'i** | Mevcut deneyim (KlioAI, Perde); tek UI kodu; hızlı iterasyon | Poz tahmini için hazır olgun plugin yok → ince bir Kotlin/Swift katmanı yazılır (2-3 hafta) | **Seçildi** |
| React Native (Expo dev client) + VisionCamera + `react-native-mediapipe-posedetection` | Topluluk paketi hazır (world coords, GPU, New Architecture) | Yeni ekosistem öğrenme; Expo/RN native modül karmaşası | Yedek plan: 3. haftada Flutter plugin'i iOS'ta çalışmazsa |
| Native (Kotlin + Swift) | En iyi performans/kontrol | İki kod tabanı, tek kişi için 2× iş | Hayır |
| Web (PWA) + MediaPipe Web | Sıfır mağaza sürtünmesi, demo için harika | Kamera/arka plan/performans kısıtları, abonelik | **Demo/landing için evet**, ürün için hayır |

**Prototip kestirmesi (Hafta 1):** `google_mlkit_pose_detection` ile 3 günde çalışan squat sayacı → UX varsayımlarını test et. Ürün motoru ise MediaPipe Tasks (world landmarks, lisans, gelecek) ile kendi plugin'imiz.

## 2. Mimari — veri hattı

```
Kamera (native, 30 fps, 640×480 veya 1280×720)
   │  (frame'ler Dart'a GEÇMEZ — kopya maliyeti ve gecikme)
   ▼
Native Pose Engine (Kotlin: CameraX + MediaPipe Tasks / Swift: AVFoundation + MediaPipe Tasks iOS)
   │  PoseFrame{ts, landmarks[33]{x,y,z,vis,presence}, world[33], fps, inferenceMs}
   ▼  EventChannel (binary, ~15-30 Hz; gerekirse Pigeon ile tipli)
Dart: PoseStream
   ▼
Smoother (One Euro filter, landmark başına)
   ▼
FeatureExtractor → açılar (diz, kalça, dirsek, gövde), hizalar (diz-ayak), mesafeler, hız
   ▼
ExerciseSession (Strategy: egzersize özel)
   ├─ RepDetector (durum makinesi: idle → descending → bottom → ascending → top)
   ├─ RuleEvaluator (JSON kural DSL'i → hata olayları, güven skoru)
   └─ ScoreEngine (tekrar başına form skoru 0-100)
   ▼
FeedbackScheduler (öncelik, cooldown, "emin değilsen sus", olumlu pekiştirme oranı)
   ├─ AudioCuePlayer (önceden üretilmiş klipler; ducking)
   ├─ Haptics
   └─ HUD state (Riverpod)
   ▼
SessionRecorder → yerel DB (Drift) → isteğe bağlı sync (Supabase)
```

**Sınır ilkesi:** Native katman *sadece* kamera + inference + (opsiyonel) skeleton overlay çizimi yapar. Tüm antrenman mantığı Dart'ta ve saf fonksiyonlarla (test edilebilirlik). Overlay, native PlatformView üzerine Flutter `CustomPaint` ile de çizilebilir; performans yetmezse native'e taşınır.

## 3. Olmazsa olmaz tasarım kalıpları

| Kalıp | Nerede | Neden |
|---|---|---|
| **Feature-first Clean Architecture** (presentation / application / domain / infrastructure) | Tüm uygulama | Domain (kural motoru) UI'dan ve plugin'den bağımsız; birim test |
| **Strategy** | `ExerciseDefinition` → egzersize özel özellik çıkarımı ve kurallar | Yeni egzersiz = yeni veri + (gerekirse) yeni strateji sınıfı |
| **State Machine** (hysteresis'li) | RepDetector | Gürültülü açı sinyalinde çift sayımı önler; faz bilgisi kurallara girdi |
| **Rule DSL (veri-güdümlü kurallar)** | `exercises/*.json` | Kural = veri; uygulama yayını olmadan uzaktan güncellenir; PT'ler katkı yapabilir |
| **Command queue + öncelik** | FeedbackScheduler | Aynı anda 3 hata çıkarsa en kritik tek cue; spam yok |
| **Observer / Streams** | Pose → UI | Riverpod `StreamProvider` |
| **Repository** | Session, Program, Content | Yerel DB ile bulut arasında tek arayüz |
| **Golden/Replay testing** | Landmark JSON fixture'ları | Kural regresyonu; CI'da cihazsız test |
| **Feature flags + remote config** | Supabase tablo veya Firebase RC | Egzersiz aç/kapa, eşik ayarı, paywall deneyleri |

## 4. Kural DSL'i (örnek)

```json
{
  "id": "bw_squat",
  "version": 3,
  "name": {"tr": "Squat (vücut ağırlığı)", "en": "Bodyweight squat"},
  "cameraViews": ["front", "side"],
  "primaryMuscles": ["FMA:22428", "FMA:22430"],
  "secondaryMuscles": ["FMA:22314"],
  "rep": {
    "signal": "angle(hip_l, knee_l, ankle_l)",
    "topThreshold": 160, "bottomThreshold": 100, "hysteresis": 8,
    "minDurationMs": 700
  },
  "rules": [
    {
      "id": "knee_valgus",
      "views": ["front"],
      "phase": ["descending", "bottom", "ascending"],
      "expr": "kneeAnkleRatio_l < 0.85 || kneeAnkleRatio_r < 0.85",
      "minConfidence": 0.7,
      "severity": 3,
      "cue": "cue_knees_out",
      "explain": {"tr": "Diz içe çökünce bağlar zorlanır; kalçayı dışa iterek dizi ayak parmağı hizasında tut.", "source": "src_012"}
    },
    {
      "id": "shallow_depth",
      "views": ["side"],
      "phase": ["bottom"],
      "expr": "min(angle(hip,knee,ankle)) > 110",
      "minConfidence": 0.6,
      "severity": 2,
      "cue": "cue_go_deeper",
      "evaluateAt": "rep_end"
    }
  ],
  "score": {"weights": {"knee_valgus": 0.4, "shallow_depth": 0.3, "torso_lean": 0.3}}
}
```

**Taraf seçimi (küçük ama bilinmesi gereken tutarsızlık):** `angle(hip, knee, ankle)` gibi taraf belirtilmemiş
nokta adları **baskın tarafı** (görünürlüğü yüksek olan) kullanır; `knee_angle` gibi hazır özellikler ise iki taraf
da güvenilirse **ortalamayı**, değilse iyi olanı verir. Yan görüşte ikisi aynı sonucu verir, ön görüşte farklı
olabilir — bir kuralda tek taraf lazımsa `_l` / `_r` ekiyle açıkça yaz.

İfade dili: küçük, güvenli bir expression evaluator (Dart'ta `expressions` paketi ya da kendi parser'ımız; `eval` yok). Kurallar `phase` ve `view` ile kapılanır; `evaluateAt` "anlık" ya da "tekrar sonu".

## 5. FeedbackScheduler spesifikasyonu

- Girdi: hata olayları `{ruleId, severity, confidence, ts}`, tekrar olayları, oturum durumu.
- Politika:
  1. Aynı anda birden fazla hata → en yüksek `severity × confidence`.
  2. Aynı cue için cooldown ≥ 4 sn ve en az 1 tekrar arası.
  3. Aynı hata art arda 3 tekrar sürerse → farklı ifade (cue varyantı) ve set sonunda "nasıl düzeltilir" kartı; 5 tekrar sürerse sus (rahatsız etmeme).
  4. Her 3-4 temiz tekrarda bir olumlu cue ("işte bu"), rastgele varyant.
  5. Confidence < eşik → sessiz (yanlış uyarı, eksik uyarıdan daha zararlı).
  6. Sayım her zaman söylenir (tekrar numarası), hata cue'su sayımla çakışmaz (kuyruk).
- Çıktı: `CueCommand{clipId, priority, haptic}`; AudioCuePlayer tek kanal, kesme kuralı: yüksek öncelik düşük önceliği keser.

## 6. Klasör yapısı (Flutter)

```
forma/
  apps/mobile/                     # Flutter uygulaması
    lib/
      app/                         # router, theme, bootstrap, DI
      core/                        # ortak: result, errors, logging, extensions
      features/
        onboarding/
        camera_setup/
        workout/                   # HUD, session controller
          application/             # use-case'ler, controllers (Riverpod)
          domain/                  # ExerciseSession, RepDetector, RuleEvaluator, FeedbackScheduler (saf Dart)
          infrastructure/          # pose stream adapter, audio, haptics, repo impl
          presentation/            # ekranlar, widget'lar, overlay painter
        anatomy/                   # WebView + three.js köprüsü (v0.2)
        program/                   # program motoru + kaynak kartları (v0.3)
        progress/
        paywall/
        settings/
      content/                     # exercises/*.json, cues/*.json, sources/*.json (versiyonlu)
    assets/audio/cues/tr/*.opus, en/*.opus
    assets/models/pose_landmarker_lite.task, full.task
    test/  (unit + golden replay)  integration_test/
  packages/
    forma_pose/                    # federated plugin: platform_interface + android + ios
    forma_rules/                   # saf Dart kural motoru (mobil ve web/CLI paylaşımlı)
  tools/
    landmark_recorder/             # cihazda kayıt → JSON fixture
    eval/                          # precision/recall harness (Dart CLI veya Python)
    tts_gen/                       # cue kliplerini üreten script
  web/demo/                        # MediaPipe Web + forma_rules (dart2js) landing demo
  docs/                            # bu set
  CLAUDE.md
```

## 7. Kütüphane seçimleri

| Alan | Seçim | Neden |
|---|---|---|
| State | **Riverpod** (codegen) | Test edilebilir, stream dostu |
| Routing | go_router | Deep link, guard |
| Yerel DB | **Drift** (SQLite) | Tip güvenli sorgular, migration; Isar'ın bakımı belirsiz |
| Backend | **Supabase** (Postgres, Auth, Storage, Edge Functions) | Hızlı, ucuz, RLS; Firebase alternatif |
| Abonelik | **RevenueCat** | Paywall, trial, TR/global fiyat, analitik |
| Analitik | PostHog (ürün analitiği, funnel, session replay UI-only) + Firebase Analytics (mağaza atıf) | |
| Crash | Sentry (Flutter + native) | |
| Ses | `just_audio` (klipler) + `audio_session` (ducking) + `flutter_tts` (yedek) | |
| Haptik | `haptic_feedback` / platform | |
| WebView (anatomi) | `flutter_inappwebview` (JS köprüsü) | |
| Kamera preview | Native PlatformView (plugin içinde) | Frame kopyasız |
| Model dosyaları | Uygulamayla gömülü (lite) + isteğe bağlı indirme (full) | |
| Kod üretimi | freezed, json_serializable, riverpod_generator | |
| Lint | very_good_analysis | |

## 8. Native plugin: `forma_pose` arayüzü

```dart
abstract class FormaPosePlatform {
  Future<void> start({required CameraLens lens, required PoseModel model, bool gpu = true});
  Future<void> stop();
  Stream<PoseFrame> get frames;          // 33 landmark + world + fps + inferenceMs
  Future<void> setModel(PoseModel model); // lite/full
  Widget preview();                       // PlatformView
}
```

Android: CameraX `ImageAnalysis` (STRATEGY_KEEP_ONLY_LATEST) → MediaPipe `PoseLandmarker` LIVE_STREAM mode, GPU delegate → sonuçlar EventChannel'a `ByteData` olarak (JSON değil; 33×(3+2)+33×3 float ≈ 1 KB/frame). iOS: `AVCaptureVideoDataOutput` → MediaPipe Tasks iOS `PoseLandmarker` liveStream → aynı format. Rotasyon/ayna (ön kamera) native'de normalize edilir.

## 9. Veri modeli (özet)

- `Session{id, startedAt, exercises[], device, modelVariant}`
- `SetResult{exerciseId, view, reps[], durationMs, formScore, errorsSummary{ruleId: count}}`
- `Rep{index, startTs, endTs, tempoDown, tempoUp, minAngle, score, errors[]}`
- `Program{days[], goal, level, equipment, version}` (v0.3)
- `UserProfile{goal, level, equipment, heightCm?, weightKg?, locale}` — sağlık verisi tutulmaz.
- Bulut: yalnızca özet (skorlar, sayılar). **Landmark dizileri ve video varsayılan olarak yüklenmez**; kullanıcı "form klibimi kaydet/paylaş" derse yerelde saklanır, paylaşım kullanıcı eylemiyle olur.

## 10. Performans bütçeleri (Kapı 2)

| Metrik | Hedef | Ölçüm | İlk cihaz koşusu (8 Eyl 2026, Galaxy S23 / Android 16, debug) |
|---|---|---|---|
| Inference (lite, GPU) | ≤ 33 ms (orta segment Android, ör. 2023 Snapdragon 6-serisi) | Plugin `inferenceMs` | **21-24 ms** (yakalama → landmark, üst segment cihaz) |
| Uçtan uca cue gecikmesi (hareket → ses başlangıcı) | ≤ 400 ms | Yüksek hızlı kamera ile ölçüm veya sentetik test | Ses katmanı yok; Dart hattı 0,06 ms/frame |
| Kamera preview | 30 fps, jank yok | DevTools | **30,2-30,4 fps** |
| 10 dk seans | Thermal throttling yok, batarya ≤ %8 | Cihaz matrisi | Ölçülmedi |
| Uygulama boyutu | ≤ 60 MB (lite model + TR/EN klipler) | | **40,4 MB** (arm64 release, lite+full model gömülü). Üç ABI'li tek APK 91,7 MB → yayın **AAB** ile |
| Soğuk açılış → kamera hazır | ≤ 2,5 sn | | Ölçülmedi |

Orta segment cihazda ölçüm tekrarlanmadan bu satırlar kesin sayılmaz (S23 üst segment).

Cihaz matrisi (minimum): 1 düşük Android (Redmi/Samsung A-serisi 2022), 1 orta, 1 üst; iPhone 11, iPhone 14+.

## 11. Test stratejisi

1. **Birim:** açı/hiza matematiği, One Euro filter, RepDetector (sentetik sinüs sinyali), RuleEvaluator (DSL ifadeleri), FeedbackScheduler (zamanlı senaryolar).
2. **Golden replay:** `tools/landmark_recorder` ile cihazda kaydedilen JSON landmark dizileri `test/fixtures/` altında; her fixture için beklenen tekrar sayısı ve hata etiketleri. CI'da cihazsız koşar.
3. **Eval harness:** `tools/eval` her egzersiz için precision/recall/F1 (hata tipi bazında) + tekrar sayım hatası (MAE). Kapı 2 raporu buradan çıkar. Eşik ayarı (threshold tuning) bu harness ile yapılır, elle değil.
4. **Widget/golden UI testleri:** HUD durumları.
5. **Integration (cihaz):** kamera izni akışı, plugin start/stop, arka plana geçiş, arama gelmesi, düşük ışık.
6. **Beta telemetri:** anonim `low_confidence_ratio`, `cue_count_per_rep`, `setup_completion_rate`.

## 12. CI/CD ve süreç

- GitHub Actions: analyze + test + build (Android APK/AAB, iOS build macOS runner). Fastlane ile TestFlight / Play Internal.
- Branch: `main` korumalı; feature → PR; Claude Code her promptu ayrı worktree'de.
- Sürümleme: semver + content bundle versiyonu ayrı (`exercises.version`).
- Release checklist: performans bütçeleri, eval raporu, KVKK metni, mağaza metadata, lisans ekranı.

## 13. Gözlemlenebilirlik

Analitik olayları (PostHog): `onboarding_completed`, `camera_setup_started/completed/abandoned{reason}`, `set_started{exercise, view}`, `rep_counted`, `cue_played{ruleId}`, `set_completed{score}`, `low_confidence_period`, `paywall_viewed/converted`, `session_completed`. Kişisel görüntü verisi asla olaya girmez.

## 14. Güvenlik ve gizlilik mühendisliği

- Kamera frame'leri belleğin dışına çıkmaz; diske yazılmaz (kullanıcı klip kaydını açmadıkça).
- Ağ: yalnızca özet metrikler, TLS, Supabase RLS.
- Kimlik: anonim başlat, sonra e-posta/Apple/Google; abonelik RevenueCat anonim ID ile de çalışır.
- Kullanıcı verisini silme: tek buton, 30 gün içinde tam silme.
- Üçüncü taraf SDK'ları minimum (reklam SDK'sı yok).

## 15. Teknik riskler ve yedekler

| Risk | Yedek |
|---|---|
| iOS'ta MediaPipe Tasks entegrasyonu sorunlu | Apple Vision motoru, 33-nokta formatına eşleme; ya da RN'e geçiş (3. hafta kararı) |
| Düşük segment Android'de fps düşük | lite model + 480p + her 2. frame işleme; sayım yine çalışır, ince kurallar kapanır |
| Dart tarafı overlay çizimi jank | Overlay native'e taşınır |
| Kural doğruluğu Kapı 2'yi geçmiyor | Hata setini daralt (ör. squat'ta sadece derinlik + valgus), açı kısıtla |
