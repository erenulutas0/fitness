# TODO — FORMA canlı yapılacaklar listesi

> **Kural:** Her Claude Code oturumu buradan başlar ve burayı günceller. Biten madde `[x]` + tarih. Yeni iş ilgili
> bölüme. Kararlar buraya değil `docs/00-README.md` Decision Log'a. Kod-dışı işler "Kurucu" bölümünde.
> Son güncelleme: **2026-09-08, oturum 1** (Claude). Takvim: docs/09 — Hafta 0 = 15 Eylül 2026.

## Durum özeti

- Faz: **Hafta 1-2 "Motor"** işlerinin büyük kısmı bir oturumda kod olarak çıktı; cihaz testi yapılmadı (ADB yoktu).
- Yeşil: `packages/forma_rules` 105 test · `packages/forma_pose` 3 test · `apps/mobile` widget testi · eval raporu (sentetik, %100).
- Kırmızı/bilinmeyen: Android native plugin **derleniyor ama cihazda hiç çalışmadı**; iOS plugin stub (NOT_SUPPORTED); ses klipleri üretilmedi.
- Repo: `github.com/erenulutas0/fitness` (**public** — iş planı ve fiyat hipotezleri açık; private yapmayı düşün).

## Şimdi (sıradaki oturum bunlarla başlar)

- [ ] **Cihazda ilk çalıştırma** (USB/ADB): `cd apps/mobile && flutter run` → kamera izni, preview, fps/inferenceMs oku. Hedef: lite modelde ≤ 33 ms (docs/05 §10). Sorun çıkarsa `packages/forma_pose/example` ile izole et.
- [ ] `pwsh tools/fetch_models.ps1` ile modeli indir (gitignore'da) — APK'ya gömülmesi için `assets/models/*.task` mevcut olmalı.
- [ ] Gerçek kamerada **squat FSM eşiklerini** kontrol et (`knee_angle` rest 155 / peak 125 sentetik veriye göre; gerçek MediaPipe gürültüsüyle One Euro parametreleri `minCutoff 1.5, beta 0.1` ayarlanacak — elle değil, kayıt + `tools/eval` ile).
- [ ] **Landmark recorder** (docs/10 Prompt 3): uygulama içi gizli ekran (debug), PoseFrame dizisini `docs/fixtures-schema.md` formatında JSON'a yazsın, share sheet ile çıkarsın. İlk hafta hedef 20 kayıt.
- [ ] D15 kararını onayla/ret: el-serbest jest kontrolü (`GestureDetector` motorda hazır, HUD'a bağlanmadı) + poz-tetikli otomatik set başlangıcı.
- [ ] Kamera kurulum asistanı ekranı (docs/06 §4.2): `FramingChecker` motorda hazır → ekran + 5 sn sesli geri sayım + "ışık az" uyarısı.
- [ ] `AudioCuePlayer`: `just_audio` + `audio_session` (ducking), tek kanal, öncelik/kesme kuralı (docs/05 §5). Şu an `HapticLogCuePlayer` sadece haptik + log.
- [ ] `tools/tts_gen` ile ilk TR/EN klipleri üret (Google TTS hesabı + `ffmpeg`), `assets/audio/cues/` pubspec'e ekle.

## Hafta 1-2 — Motor (docs/09)

- [x] 2026-09-08 — Monorepo: pub workspace (D11), `apps/mobile`, `packages/forma_rules`, `packages/forma_pose`, `content` (asset paketi), `tools/eval`, `tools/tts_gen`, CI (`.github/workflows/ci.yml`).
- [x] 2026-09-08 — `forma_rules`: landmark modeli, One Euro filtre, `FeatureExtractor` (2D + world 3D açılar, valgus/heel/hip-line/gesture özellikleri), `RepDetector` (hysteresis FSM, nötr fazlar D14), `HoldDetector`, kural DSL (parser + evaluator + series + validator), `ExerciseDefinition` JSON, `RuleEvaluator` (instant + rep_end), `ScoreEngine`, `ExerciseSession`, `FeedbackScheduler` (cooldown / rephrase / mute / positive / low-confidence), `CueCatalog`, `LandmarkFixture` + replayer, sentetik 3D iskelet üretici (squat, push-up, plank, glute bridge), `GestureDetector` (D15), `FramingChecker`. 105 test, 57 µs/frame.
- [x] 2026-09-08 — İçerik: `bw_squat` (5 kural), `push_up` (3), `plank` (hold, 3), `glute_bridge` (1), `reverse_lunge` (taslak, 2); `cues.json` 60+ cue TR/EN varyantlı; sentetik golden fixture'lar (12).
- [x] 2026-09-08 — `forma_pose`: platform interface, binary codec (40 B header + 33×5 + 33×3 float), `FakeFormaPose` (sentetik/fixture), Android Kotlin (CameraX RGBA + PoseLandmarker LIVE_STREAM, GPU→CPU fallback, PreviewView platform view, izin akışı) — **derlenmedi/test edilmedi**, iOS stub.
- [x] 2026-09-08 — `apps/mobile`: Riverpod codegen, go_router, l10n TR/EN, tema (docs/06 token'ları), Bugün ekranı, HUD (sayaç, skor halkası, tempo, cue metni, iskelet overlay + hata eklemi vurgusu, gizlilik rozeti), set özeti (skor, en sık 2 hata + "neden" kartı), fake motor ile widget testi.
- [x] 2026-09-08 — `tools/eval`: precision/recall/F1, rep MAE, cue/rep; `docs/eval/latest.md` üretir; Kapı 2 eşiği ile çıkış kodu.
- [x] 2026-09-08 — `flutter build apk --debug` lokalde yeşil: Kotlin plugin MediaPipe `tasks-vision:0.10.21` + CameraX 1.4.2 ile derleniyor (`app-debug.apk` 175 MB, debug; release boyutu ayrıca ölçülecek).
- [ ] Android plugin'i gerçek cihazda doğrula (çalışma zamanı: izin, CameraX bind, GPU delegate, EventChannel throughput); CI'daki APK adımını da yeşile çek.
- [ ] Eşik taraması (grid search önerisi) `tools/eval`'a ekle (docs/10 Prompt 9).
- [ ] `reverse_lunge` kuralları: adım uzunluğu, ön diz ilerlemesi, gövde eğimi — sentetik lunge iskeleti yok, gerçek kayıt şart.
- [ ] `push_up` ön açı (dirsek açılması `shoulder_angle`) — kamera yerde ön açı gerçekçi mi, keşifte sor.
- [ ] Glute bridge bel hiperekstansiyonu: 2D'de güvenilir değil; şimdilik kural yok (docs/01 tablosundaki hata listesi güncellenmeli).

## Hafta 3-4 — 5 egzersiz + HUD (Kapı 2)

- [ ] Gerçek kişilerle test videosu/kayıt seti: 5 kişi × 5 egzersiz × 2 açı × 3 ortam (`data/fixtures/`, gitignore'da; onam formu).
- [ ] Kapı 2 raporu: precision ≥ %80, recall ≥ %70, cue gecikmesi ≤ 400 ms, 10 dk thermal test (cihaz matrisi docs/05 §10).
- [ ] HUD: yatay mod, overlay aç/kapa ayarı, "az konuş" modu (`FeedbackPolicy.quietMode` hazır), düşük güvende gri sayaç (var) + tek seferlik cue (var).
- [ ] Set/seans akışı: dinlenme sayacı, 3 set, seans özeti, paylaşılabilir kart (iskelet çizimi, video değil).
- [ ] Yerel DB (Drift): Session/SetResult/Rep şeması (docs/05 §9).
- [ ] iOS plugin (docs/10 Prompt 8): MediaPipe Tasks iOS ya da Apple Vision → 33-nokta eşleme; RN'e geçiş karar noktası 3. hafta sonu.
- [ ] Figma 6 ekran + 5 kişilik kullanılabilirlik testi (docs/06 §10).
- [ ] Fontlar: Manrope + Inter (SIL OFL) paketle; tabular rakam sayaç.

## Hafta 5-6 — Beta (Kapı 3)

- [ ] Onboarding ≤ 60 sn (3 soru + kamera izni + 5 squat demo = aha anı).
- [ ] İlerleme ekranı: form skoru trendi, seans geçmişi.
- [ ] Basit program (3 gün/hafta) — Bugün sekmesi gerçek içerik.
- [ ] PostHog olayları (docs/05 §13) + Sentry; görüntü/landmark asla olaya girmez.
- [ ] Anatomi viewer çekirdeği (WebView + three.js, Z-Anatomy türevi ≤ 20 MB, NC parçalar hariç) — v0.2.
- [ ] Beta: 20 kullanıcı, D7 ≥ %25, "kalksa üzülürüm" ≥ %40.

## Hafta 7-12 — Kanıt katmanı, para, cila, soft launch

- [ ] Kaynak kartları şeması + ilk 10 kaynak iskeleti (özetleri **kurucu** yazar) — docs/10 Prompt 11.
- [ ] Program motoru v0.3 (hedef/seviye/gün/ekipman → plan, RIR parametreleri kaynaklı).
- [ ] RevenueCat + paywall + 7 gün trial (yıllık plan ana ürün, haftalık plan yok).
- [ ] Ölçüme dayalı kas haritası; haftalık kapsama.
- [ ] Mağaza varlıkları, ASO TR/EN, KVKK/gizlilik/lisans ekranları, hesap silme, türev 3D model repo'su.
- [ ] Soft launch TR (Kasım sonu) → EN Ocak.

## Fikir havuzu (docs/03 ek fikirler 13-21; kararlaştırılmadı)

- [ ] Kişisel taban çizgisi kalibrasyonu (15) — DSL'de `baseline(...)` fonksiyonu gerektirir.
- [ ] Hayalet iskelet tekrarı (16) — landmark dizisi zaten `SessionRecorder`'a girecek.
- [ ] Hız kaybına dayalı yorgunluk/RIR (17) — `RepSummary.toPeakMs/toRestMs` trendi + kaynak kartı.
- [ ] Silüet modu (18), temiz tekrar serisi (19), koç ses paketleri (20), web demo (21).

## Teknik borç / bilinen eksikler

- [ ] `applicationId` `app.forma.forma_mobile` → marka seçilince bundle id'yi değiştir (mağazaya çıkmadan).
- [ ] FMA kas id'leri (`content/exercises/*.json` primary/secondaryMuscles) doğrulanmadı — anatomi katmanında kontrol.
- [ ] `explain.source` id'leri yer tutucu (`src_valgus_01` vb.) — `content/sources/` doldurulunca eşle.
- [ ] `FeatureSet.point('hip')` baskın taraf, `knee_angle` iki tarafın ortalaması: DSL dokümanına yaz (küçük tutarsızlık).
- [ ] Eval: FN sayımı "tespit edilmeyen tekrar"ı da sayıyor; gerçek kayıtlarda tekrar hizalama (index kayması) için DTW/eşleme gerekebilir.
- [ ] `flutter analyze` custom_lint (riverpod_lint) CI'da çalıştırılmıyor; ekle.
- [ ] Windows'ta `dart format --set-exit-if-changed` CRLF'e duyarlı olabilir; `.gitattributes` ile LF zorla.

## Kurucuya ait (kod dışı)

- [ ] **Kapı 1 keşif:** 5 PT/fizyoterapist + 10 kullanıcı görüşmesi (docs/09 Hafta 0). Çıkış: 6/10 "formumdan emin değilim", 3/5 PT "önerirdim".
- [ ] Marka adı aday listesi + Türk Patent/EUIPO ön arama; domain.
- [ ] Beta onam formu (video kaydı/etiketleme rızası).
- [ ] Google Cloud TTS hesabı (ücretsiz kota) → `tools/tts_gen`.
- [ ] Repo görünürlüğü kararı (public → private?).
- [ ] Rakip uygulamaları kur, 3'er seans, cue dili notları.
- [ ] Avukat 1 saat: KVKK metni, CC BY-SA türev model yükümlülüğü (yayına çıkmadan).
- [ ] D15 (jest kontrolü) onayı.

## Oturum günlüğü

- **2026-09-08 / oturum 1 (Claude):** Doküman seti okundu; `docs/`'a taşındı; Decision Log D11–D15 ve 9 yeni fikir eklendi; monorepo + motor + içerik + plugin (Android kod, cihazsız) + uygulama iskeleti + eval + TTS scripti + CI yazıldı; testler yeşil; GitHub'a push edildi.
