# TODO — FORMA canlı yapılacaklar listesi

> **Kural:** Her Claude Code oturumu buradan başlar ve burayı günceller. Biten madde `[x]` + tarih. Yeni iş ilgili
> bölüme. Kararlar buraya değil `docs/00-README.md` Decision Log'a. Kod-dışı işler "Kurucu" bölümünde.
> Son güncelleme: **2026-09-08, oturum 4** (Claude, ilk gerçek kayıtlar + heel_rise kapatıldı). Takvim: docs/09 — Hafta 0 = 15 Eylül 2026.

## Durum özeti

- Faz: **Hafta 1-2 "Motor"** kod olarak bitti ve **gerçek cihazda uçtan uca çalıştı** (Galaxy S23, Android 16).
- Yeşil: `forma_rules` 109 test · `forma_pose` 3 test · `apps/mobile` 3 test · eval raporu (sentetik, %100) ·
  cihazda 30 fps / 21-24 ms landmark gecikmesi / tekrar sayımı / kural + cue + overlay vurgusu ·
  **kayıt ekranı**: cihazda kayıt → JSON → `tools/eval` döngüsü kapandı.
- Kırmızı/bilinmeyen: ses klipleri yok (cue'lar sadece metin + haptik); iOS plugin stub; gerçek
  "telefon 2-3 m uzakta" senaryosu ve termal test yapılmadı.
- Repo: `github.com/erenulutas0/fitness` (**public** — iş planı ve fiyat hipotezleri açık; private yapmayı düşün).

## Şimdi (sıradaki oturum bunlarla başlar)

- [ ] **Kasten hatalı kayıtlar** (recall ölçmek için): her hata tipi için 1-2 kayıt — bilerek topuk kaldır,
      bilerek sığ in, bilerek dizleri içe ver, bilerek gövdeyi öne eğ. Şu an sadece temiz kayıt var; temiz veriyle
      yalnızca yanlış alarmı ölçebiliyoruz, kaçırmayı ölçemiyoruz.
- [ ] **Etiketleme alışkanlığı**: ilk iki kayıtta hiç etiket işaretlenmedi, dolayısıyla eval "her tekrar temiz"
      varsaydı. Kayıt sonrası gerçekten olan hataları işaretle, yoksa doğruluk ölçümü tek yönlü kalıyor.
- [ ] `shallow_depth` eşiği (105°) doğrulanacak: 18:16 kaydının 3. tekrarı 109° ölçüldü ve sığ işaretlendi,
      diğerleri 97-98°. Kurucu onaylarsa eşik doğru, aksi halde 112-115° civarına çekilecek.
- [ ] **İlk gerçek kayıt setini topla** (kurucu + Claude birlikte): telefon 2-3 m uzakta, tam vücut kadrajda.
      Hedef ilk hafta 20 kayıt: 5 egzersiz × 2 açı × birkaç ortam. Kayıt ekranı hazır, akış: Bugün → sağ üstteki
      kayıt ikonu → egzersiz/açı/kişi/ortam → Kaydı başlat → Durdur ve etiketle → hataları işaretle → Kaydet.
      Kayıtlar `Kaydet ve paylaş` ile telefondan çıkar; `data/fixtures/` gitignore'da.

- [ ] Yayın formatı **AAB** olsun (`flutter build appbundle`): tek ABI release APK 40,4 MB (bütçe 60 MB ✓) ama
      üç ABI'li tek APK 91,7 MB. CI'daki APK adımı yanında AAB üret. `full` modeli asset'ten çıkarıp ilk kullanımda
      indirmek 9,4 MB daha kazandırır (v1.x).
- [ ] **Gerçek senaryo testi:** telefon 2-3 m uzakta, tripod/masa, tam vücut kadrajda, 10 tekrar squat (ön + yan).
      İlk koşuda kamera aynadaki yansımayı gördü; kadraj/mesafe gerçek değildi.
- [ ] Gerçek kayıtlarla **eşik ayarı**: squat FSM eşikleri (rest 155 / peak 125) ve One Euro parametreleri
      (`minCutoff 1.5, beta 0.1`) sentetik veriye göre seçildi; elle değil `tools/eval` ile ayarla.
- [ ] `AudioCuePlayer`: `just_audio` + `audio_session` (ducking), tek kanal, öncelik/kesme (docs/05 §5).
      Şu an `HapticLogCuePlayer` yalnızca haptik + log; cue metni HUD'da görünüyor.
- [ ] `tools/tts_gen` ile ilk TR/EN klipleri üret (Google TTS hesabı + `ffmpeg`), `assets/audio/cues/` pubspec'e ekle.
- [ ] Kamera kurulum asistanı ekranı (docs/06 §4.2): `FramingChecker` motorda hazır → ekran + 5 sn sesli geri sayım +
      "ışık az" uyarısı (`brightness` artık cihazdan geliyor).
- [ ] D15 kararını onayla/ret: el-serbest jest kontrolü (`GestureDetector` motorda hazır, HUD'a bağlanmadı) +
      poz-tetikli otomatik set başlangıcı.
- [ ] 10 dk termal/batarya testi (docs/05 §10) ve orta segment bir Android'de fps/gecikme tekrarı (S23 üst segment).

## Hafta 1-2 — Motor (docs/09)

- [x] 2026-09-08 — **İlk gerçek kayıtlar analiz edildi** (2 kayıt, Galaxy S23, yan açı, 5'er tekrar):
      tekrar sayımı 5/5 doğru (MAE 0), derinlik 78-85° ve 97-109°, gövde eğimi temiz, takip kaybı ~%0-2.
      `tools/eval/bin/inspect.dart` ile tekrar tekrar döküm (süre, tempo, derinlik, skor, tetiklenen kural).
- [x] 2026-09-08 — **`heel_rise` kuralı kapatıldı** (D17). İki temiz kayıtta 5/5 ve 2/5 yanlış alarm verdi.
      Ölçülen: ayakta ~0.02, dipte ~0.18; fark iki kayıtta da ~0.15, yani artış topuk kalkmasından değil squat'a
      inmekten geliyor. Ayak uzunluğuna bölünce ve MediaPipe dünya koordinatlarında da aynı (0.19 → 0.79).
      Kurallar artık içerikten `enabled: false` ile kapatılabiliyor (`disabledNote` zorunlu), 3 yeni test.

- [x] 2026-09-08 — **Kayıt (fixture) ekranı** (docs/10 Prompt 3), debug build'lerde Bugün ekranından erişilir:
      kurulum (egzersiz, açı, anonim kişi kodu, ortam, model, kamera, not; son ayarlar hatırlanır) → canlı kayıt
      (kadraj bandı: "biraz geri git / ışık az", görünürlük, fps, süre, frame sayısı, motorun canlı tekrar sayısı,
      5 sn geri sayım, 3 dk sınır) → etiketleme (gerçek tekrar sayısı, tekrar başına kural işaretleme; motorun
      tahmini rozet olarak görünür ama **seçili gelmez**) → JSON kaydet / paylaş, kayıt listesi (paylaş, sil).
      Ham frame'ler kaydedilir (yumuşatma sonradan ayarlanabilsin diye), koordinatlar 6 haneye yuvarlanır,
      zaman damgaları sıfırdan başlar. Cihazda doğrulandı: 769 frame / 565 KB, `tools/eval` dosyayı okudu.
- [x] 2026-09-08 — `PoseEngineInfo.device` (Android `Build.MANUFACTURER + MODEL`) → fixture'a yazılıyor;
      eval raporunu donanıma göre kırmak için. Cihazda doğrulandı: `samsung SM-S911B`.

- [x] 2026-09-08 — Monorepo: pub workspace (D11), `apps/mobile`, `packages/forma_rules`, `packages/forma_pose`, `content` (asset paketi), `tools/eval`, `tools/tts_gen`, CI (`.github/workflows/ci.yml`).
- [x] 2026-09-08 — `forma_rules`: landmark modeli, One Euro filtre, `FeatureExtractor` (2D + world 3D açılar, valgus/heel/hip-line/gesture özellikleri), `RepDetector` (hysteresis FSM, nötr fazlar D14), `HoldDetector`, kural DSL (parser + evaluator + series + validator), `ExerciseDefinition` JSON, `RuleEvaluator` (instant + rep_end), `ScoreEngine`, `ExerciseSession`, `FeedbackScheduler` (cooldown / rephrase / mute / positive / low-confidence), `CueCatalog`, `LandmarkFixture` + replayer, sentetik 3D iskelet üretici (squat, push-up, plank, glute bridge), `GestureDetector` (D15), `FramingChecker`. 105 test, 57 µs/frame.
- [x] 2026-09-08 — İçerik: `bw_squat` (5 kural), `push_up` (3), `plank` (hold, 3), `glute_bridge` (1), `reverse_lunge` (taslak, 2); `cues.json` 60+ cue TR/EN varyantlı; sentetik golden fixture'lar (12).
- [x] 2026-09-08 — `forma_pose`: platform interface, binary codec (40 B header + 33×5 + 33×3 float), `FakeFormaPose` (sentetik/fixture), Android Kotlin (CameraX RGBA + PoseLandmarker LIVE_STREAM, GPU→CPU fallback, PreviewView platform view, izin akışı) — **derlenmedi/test edilmedi**, iOS stub.
- [x] 2026-09-08 — `apps/mobile`: Riverpod codegen, go_router, l10n TR/EN, tema (docs/06 token'ları), Bugün ekranı, HUD (sayaç, skor halkası, tempo, cue metni, iskelet overlay + hata eklemi vurgusu, gizlilik rozeti), set özeti (skor, en sık 2 hata + "neden" kartı), fake motor ile widget testi.
- [x] 2026-09-08 — `tools/eval`: precision/recall/F1, rep MAE, cue/rep; `docs/eval/latest.md` üretir; Kapı 2 eşiği ile çıkış kodu.
- [x] 2026-09-08 — `flutter build apk --debug` lokalde yeşil: Kotlin plugin MediaPipe `tasks-vision:0.10.21` + CameraX 1.4.2 ile derleniyor (`app-debug.apk` 175 MB, debug; release boyutu ayrıca ölçülecek).
- [x] 2026-09-08 — **Cihazda uçtan uca doğrulandı** (Galaxy S23, Android 16, arm64, debug): kamera izni → CameraX →
      MediaPipe GPU → landmark → kural motoru → cue → HUD. **30,2-30,4 fps**, **21-24 ms** yakalama→landmark gecikmesi,
      iskelet overlay kadraja oturuyor, tekrar sayıldı, `shallow_depth` tetiklendi ("Daha derin in"), hata ekleminde
      turuncu vurgu, "Seni net göremiyorum" düşük güvende çalıştı.
- [x] 2026-09-08 — **16 KB sayfa boyutu uyumluluğu** (D16): Android 16 uyumsuzluk uyarısı verdi; MediaPipe
      `tasks-vision` 0.10.21 → **1.0.0**, CameraX 1.4.2 → **1.6.2**. APK'daki tüm `.so` dosyaları artık ≥ 16384 hizalı
      (doğrulandı), uyarı kayboldu. Google Play, Android 15+ hedefleyen uygulamalarda bunu zorunlu tutuyor.
- [x] 2026-09-08 — Cihazda bulunan 3 hata düzeltildi: (1) poz yokken fps/gecikme/parlaklık meta verisi düşüyordu,
      (2) kadraj dışına çıkınca tekrar FSM'i askıda kalıp dönüşte hayalet tekrar sayıyordu (`RepDetector.abort`,
      3 regresyon testi), (3) plank süresi kadraj dışında işlemeye devam ediyordu.
- [x] 2026-09-08 — Modeller `packages/forma_pose/assets/models/` altına taşındı (uygulama ve example tek kopyayı
      paylaşıyor); parlaklık her 15 frame'de bir örnekleniyor; preview platform view geç oluşursa yeniden bağlanıyor.
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
- [ ] Kayıt ekranı metinleri l10n dışında (bilinçli: kurucu aracı, sadece debug). Beta'da başka birine kayıt
      yaptıracaksan İngilizceye çevir.
- [ ] Kayıt sırasında ham frame'ler bellekte tutuluyor (3 dk ≈ 11 MB). Daha uzun kayıt gerekirse parça parça diske yaz.
- [ ] `share_plus` + `path_provider` eklendi (ikisi de BSD-3). Lisans ekranına girecek listeye ekle (docs/08).
- [x] 2026-09-08 — CI: action sürümleri v5'e çekildi; `tools/check_so_alignment.py` ile 16 KB hizalaması her build'de doğrulanıyor.
- [ ] Plugin example'ındaki overlay aspect düzeltmesi yok (iskelet preview ile birebir örtüşmüyor); uygulamadaki
      `SkeletonPainter` cover-fit yapıyor, example basit. Örnek uygulamayı ona hizala ya da paylaşılan bir painter çıkar.
- [ ] `PoseEngine.createLandmarker` modeli main thread'de yüklüyor (~5,8 MB); soğuk açılışta birkaç yüz ms bloklayabilir.
- [ ] MediaPipe `tensor.cc: Tensors are designed for single writes` uyarısı her koşuda çıkıyor (GPU delegate, zararsız
      görünüyor); 1.0.0'da da var, takip et.
- [ ] HUD'daki debug metrik satırı `kDebugMode` ile sınırlı; release'de görünmüyor ama beta build'lerde bir ayar arkasına alınabilir.
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
- **2026-09-08 / oturum 2 (Claude):** Galaxy S23 bağlandı. Modeller plugin paketine taşındı, plugin demo ve ana
  uygulama cihaza kuruldu, uçtan uca hat doğrulandı (30 fps, 21-24 ms, tekrar + kural + cue + overlay). Cihazda
  3 hata bulunup düzeltildi (poz yokken meta veri kaybı, hayalet tekrar, plank süresi), 16 KB sayfa uyumluluğu
  için MediaPipe 1.0.0 + CameraX 1.6.2'ye yükseltildi ve doğrulandı. Release APK 91,7 MB ölçüldü (bütçe aşımı,
  "Şimdi" listesine alındı). Testler: 108 + 3 + 1 yeşil.
- **2026-09-08 / oturum 3 (Claude):** Kayıt (fixture) ekranı yazıldı ve cihazda uçtan uca denendi: kayıt → etiketleme
  → JSON → `tools/eval` raporu. `PoseEngineInfo` artık cihaz modelini taşıyor; `PoseFrame.toJson` koordinatları
  yuvarlıyor ve fixture zaman damgaları sıfırlanıyor (dosya ~yarı boyut). 2 yeni test (kayıt→fixture→eval
  round-trip ve kayıt akışı widget testi). Testler: 109 + 3 + 3 yeşil.
- **2026-09-08 / oturum 4 (Claude):** Kurucu kayıt ekranından iki temiz squat seti kaydetti. `inspect.dart` yazıldı;
  analiz `heel_rise` kuralının her tekrarda yanlış alarm verdiğini gösterdi ve nedeni ölçümle bulundu (özellik
  squat derinliğiyle artıyor, 3B'de de). Kural kapatıldı (D17), kurallara `enabled`/`disabledNote` eklendi,
  golden replay testi kapalı kuralları hesaba katacak şekilde sağlamlaştırıldı. Testler: 111 yeşil.
