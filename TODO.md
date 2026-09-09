# TODO — FORMA canlı yapılacaklar listesi

> **Kural:** Her Claude Code oturumu buradan başlar ve burayı günceller. Biten madde `[x]` + tarih. Yeni iş ilgili
> bölüme. Kararlar buraya değil `docs/00-README.md` Decision Log'a. Kod-dışı işler "Kurucu" bölümünde.
> Son güncelleme: **2026-09-09, oturum 7** (Claude, ses + kadraj adımı + anatomik makullük + CI/AAB + 18 hata avı). Takvim: docs/09 — Hafta 0 = 15 Eylül 2026.

## Durum özeti

- Faz: **Hafta 1-2 "Motor"** kod olarak bitti ve **gerçek cihazda uçtan uca çalıştı** (Galaxy S23, Android 16).
- Yeşil: `forma_rules` 128 test · `forma_eval` 26 test · `forma_pose` 3 test · `apps/mobile` 3 test · `flutter analyze` + `custom_lint` +
  `dart format` temiz · cihazda 30 fps / 21-24 ms landmark gecikmesi / tekrar sayımı / kural + cue + overlay vurgusu ·
  **kayıt ekranı** (cihazda kayıt → JSON → `tools/eval` döngüsü kapalı) · **koç sesli konuşuyor** ·
  **set kadraj adımı + geri sayımla açılıyor** (ikisi de cihazda doğrulandı).
- Kırmızı/bilinmeyen: önceden üretilmiş ses klipleri hâlâ yok (cihaz TTS'i yedek olarak çalışıyor ama robotik ve
  ilk kelimesi gecikebiliyor); iOS plugin stub; gerçek "telefon 2-3 m uzakta" senaryosu yapılmadı; termal test
  yalnızca kısmen (kadrajda kimse yokken 7,5 dk).
- **İlk gerçek dünya doğruluk ölçümü var** (9 Eylül): stok videolardan gözle doğrulanmış yer gerçeğiyle
  `shallow_depth` 2 TP / 0 FP / 0 FN, rep MAE 0. Örneklem küçük (6 tekrar, 2 video) ama etiketler motorun
  çıktısından değil iskelet önizlemesinden geldi — döngüsel değil.
- Repo: `github.com/erenulutas0/fitness` (**public** — iş planı ve fiyat hipotezleri açık; private yapmayı düşün).

## Şimdi (sıradaki oturum bunlarla başlar)

- [ ] **Kasten hatalı kayıt** (kurucu çekecek — 9 Eylül'de söz verildi; ilk 2 gerçek pozitif stok videodan geldi): yan açıdan 5 tekrar, ikisi bilerek sığ,
      ikisi bilerek dizler içe, biri temiz. Şu an korpusta yalnızca temiz kayıt var; temiz veriyle sadece yanlış
      alarmı ölçebiliyoruz, **kaçırmayı (recall) ölçemiyoruz** — Kapı 2'nin (recall ≥ %70) önündeki tek engel bu.
- [ ] **Topuk kalkması kararı**: aynı videoda bilerek topuk kaldır, `--preview` ile iskeleti izle.
      Model ayağı doğru görüyorsa kuralı taban çizgisiyle yeniden yazarız; göremiyorsa kapalı kalır (D17).
- [ ] **Etiketleme alışkanlığı**: ilk iki kayıtta hiç etiket işaretlenmedi, dolayısıyla eval "her tekrar temiz"
      varsaydı. Artık kolay: `--sheet` her tekrarın dip karesini numaralı tek bir resme diziyor (tekrar no,
      saniye, ölçülen derinlik). Resimlere bak, kötüleri `--label 2:shallow_depth` ile işaretle.
- [ ] `shallow_depth` eşiğinin **alt** ucu belirsiz. İlk etiketli gerçek veriyle tarandı (9 Eylül,
      `bin/sweep.dart`): 95-105° arası her değer F1 = 1,00; **107,5°'de iki pozitiften biri kaçıyor**, 110°+
      ikisini de kaçırıyor. Yani "112-115'e çekelim" hipotezi çürüdü — 105 üst sınırda, yükseltmek kaçırmaya
      başlıyor. Ama korpusta 72° ile 107° arasında hiç tekrar yok, o yüzden 95-105 bandının tamamı aynı skoru
      veriyor: **alt uç ölçülmedi**. Yarınki çekimde işe yarayacak olan, bilerek "sınırda" tekrarlar —
      tam paralel civarı (95-105°), sadece apaçık sığ ve apaçık derin olanlar değil.
- [ ] **Ayak görünürlüğü sorunu**: dört kayıtta da ayak landmark güveni 0.37-0.64. Kamera yüksekliği/mesafesi
      ve ayakkabı etkisini test et; kadraj adımı artık "biraz geri git" diyor ama ayak özelinde bir yönerge yok.
- [ ] **İlk gerçek kayıt setini topla** (kurucu + Claude birlikte): telefon 2-3 m uzakta, tam vücut kadrajda.
      Hedef ilk hafta 20 kayıt: 5 egzersiz × 2 açı × birkaç ortam. Kayıt ekranı hazır, akış: Bugün → sağ üstteki
      kayıt ikonu → egzersiz/açı/kişi/ortam → Kaydı başlat → Durdur ve etiketle → hataları işaretle → Kaydet.
      Kayıtlar `Kaydet ve paylaş` ile telefondan çıkar; `data/fixtures/` gitignore'da.
- [ ] **Gerçek senaryo testi:** telefon 2-3 m uzakta, tripod/masa, tam vücut kadrajda, 10 tekrar squat (ön + yan).
      İlk koşuda kamera aynadaki yansımayı gördü; kadraj/mesafe gerçek değildi.
- [ ] Gerçek kayıtlarla **eşik ayarı**: squat FSM eşikleri (rest 155 / peak 125) ve One Euro parametreleri
      (`minCutoff 1.5, beta 0.1`) sentetik veriye göre seçildi. Araç hazır (`bin/sweep.dart`); mevcut korpusta
      rep MAE zaten 0 olduğu için tarama "değiştirme" diyor, `shallow_depth` için ise etiket olmadığından
      öneri vermeyi reddediyor. Etiketli kayıt gelince ilk iş bu taramayı koşmak.
- [ ] `tools/tts_gen` ile ilk TR/EN klipleri üret (**kurucu:** Google TTS hesabı + `ffmpeg`),
      `assets/audio/cues/` pubspec'e ekle. Oynatıcı hazır: klip varsa klibi, yoksa cihaz TTS'ini kullanıyor.
- [ ] D15 kararını onayla/ret: el-serbest jest kontrolü (`GestureDetector` motorda hazır, HUD'a bağlanmadı) +
      poz-tetikli otomatik set başlangıcı.
- [ ] 10 dk termal/batarya testini **kadrajda gerçek bir insanla** tekrarla. 9 Eylül'de 7,5 dk koşuldu ama sahne
      karanlıktı (kimse yok → MediaPipe yalnızca dedektör geçişi), yani rakamlar alt sınır: batarya 32,2 → 37,3 °C,
      CPU 48,1 → 54,7 °C (tepe 57,0), throttling yok, eğri sonda hâlâ ~0,4 °C/dk yükseliyordu. Ayrıntı docs/05 §10.
- [ ] **USB'ye bağlıyken batarya düştü** (%79 → %78, 7,5 dk): uygulama portun verdiğinden fazla çekiyor.
      Bataryadan koşarken "%8 / 10 dk" hedefi ciddi risk altında — prizsiz ölçüm şart.
- [ ] **Loş odada kamera ~25 fps** veriyor (30 değil); otomatik pozlama kareyi uzatıyor. Tempo ölçümü ve cue
      gecikmesi bundan etkilenir; kadraj asistanı "ışık az" diyor ama fps düşüşü ayrıca ele alınmalı.
- [ ] **Kadrajda iki kişi** olduğunda ne olacağı tanımsız: MediaPipe birini seçiyor (`numPoses = 1`), kullanıcı
      hangisinin izlendiğini bilmiyor (stok kayıt px_4258996 bu durumda). Kadraj asistanı uyarabilir.
- [ ] Orta segment bir Android'de fps/gecikme tekrarı (S23 üst segment).

## Hafta 1-2 — Motor (docs/09)

- [x] 2026-09-09 — **İlk gerçek dünya yer gerçeği ve recall ölçümü**. Elde 20 stok videodan yalnızca 6'sı tekrar
      üretiyor (kalanı kadraj korumasınca doğru şekilde reddediliyor). İkisi gözle doğrulandı ve etiketlendi:
      • `px_6868332` — iskelet önizlemesinde iki tekrar da **açıkça sığ** (uyluklar paralelin belirgin üstünde),
        motor 107° ve 108° ölçüp `shallow_depth` dedi → **2 gerçek pozitif**.
      • `px_8837118` — dört tekrar da açıkça derin, motor sessiz kaldı → **4 gerçek negatif**.
      Sonuç: `shallow_depth` 2 TP / 0 FP / 0 FN, rep MAE 0. `torso_lean` **etiketlenmedi**: gövde açısının 55°'yi
      geçip geçmediği gözle karara bağlanamaz, o yüzden ölçülmemiş olarak duruyor (raporda `n/a`).
      Yöntem: `--preview` ile iskeleti videonun üstüne çiz → her tekrarın dip karesine bak → yalnızca tartışmasız
      olanı etiketle. Etiketler `data/stock/*.json` içinde (gitignore'da).
- [x] 2026-09-09 — **18 hata bulundu ve düzeltildi** (5 ajanlı düşmanca inceleme; 28 ham bulgu → 18 doğrulandı,
      6 reddedildi). Her davranış düzeltmesi, düzeltmeden önce kırılan bir testle geldi; **8 gerçek kaydın tekrar
      sayıları değişmedi** — düzeltmeler yalnızca hata yollarını değiştiriyor. Öne çıkanlar:
      • Tekrar sonu kuralları **ayakta duran** karelerde ölçülüyordu (900'lük tampon giriş bekleyişiyle doluyordu):
        temiz derin squat "sığ" damgası yiyebiliyordu.
      • Sinyal körleşince FSM donuyordu: iki squat tek 4,7 sn'lik tekrara birleşip sayaç bir eksik kalıyordu.
      • `maxDurationMs` yalnızca dönüşte bakılıyordu → dipte kalan tekrar sonsuza kadar açık, sayaç donmuş.
      • Kısa hold hiç olay üretmiyordu → çöken denemenin kareleri sonraki plank'a sızıyordu (temiz plank 60 puan).
      • Hiçbir landmark görünmediğinde kadraj kutusu (0,0)'a çöküp "biraz geri git" diyordu — 3 m uzaktaki
        kullanıcıya sonsuza kadar.
      • Kamera açılırken ekrandan çıkmak native motoru açık bırakıyordu → sonraki her set `ALREADY_RUNNING`.
      • Native start'ın asenkron hatası MethodChannel'ı hiç yanıtlamıyordu → HUD sonsuza kadar "Başlıyor…".
      • Cue öncelik politikası ölü koddu (klip yokken `_isBusy` hep false): her cue bir öncekini kesiyordu.
      • 3 dk otomatik durdurma, biten kaydı çöpe atıp ekranda "Vazgeç" bırakıyordu.
      • Eval: negatif eşik `--0.04` olarak yazılıp kuralın işaretini ters çeviriyordu; Kapı 2 hiç ölçüm
        yapılmadan PASS diyordu; değerlendirilmeyen etiketler sessizce düşüyordu (heel_rise'lı 3 tekrar);
        hold egzersizlerinde cue/tekrar yapısal olarak 0,00'dı (plank gerçekte 1,50).
- [x] 2026-09-09 — **Koç artık konuşuyor** (docs/10 Prompt 5): `VoiceCuePlayer` önce
      `assets/audio/cues/<dil>/<clip>_<varyant>.opus` klibini arıyor, yoksa aynı cümleyi cihazın konuşma motoruyla
      söylüyor — yani ses bugün var, klipler üretilince kendiliğinden hızlanıp doğallaşıyor. Tek kanal: yüksek
      öncelikli cue çalanı keser, düşük öncelikli olan kuyruğa girmez (iki tekrar geç gelen düzeltme, hiç gelmemesinden
      kötü). `audio_session` kullanıcının müziğini durdurmak yerine kısıyor; konuşma motoru açılışta ısıtılıyor.
      Cihazda doğrulandı: geri sayım ve düzeltmeler Türkçe sesli geliyor.
- [x] 2026-09-09 — **Kadraj adımı** (docs/06 §4.2): set artık kadrajla açılıyor; tek seferde tek yönerge
      ("biraz geri git", "ışık az") hem sesli hem ekranda, kadraj 700 ms iyi kalınca 5 sn sesli geri sayım,
      sabırsız kullanıcı için "Şimdi başla". Ayrı ekran değil, **aynı açık kamera** üzerinde çalışıyor: ekranlar
      arasında kamerayı kapatıp açmak ~1 sn kaybettiriyor. Telefon yerleştirilirken yapılan tekrarlar set
      başlarken atılıyor; kadraj dışı uyarısı artık "Seni göremiyorum" yerine "Biraz geri git" diyor.
- [x] 2026-09-09 — **Anatomik makullük kontrolü**: baldır/uyluk oranı 1,6'yı geçerse oturum donuyor. 26 kayıtta
      ölçüldü — gerçek kayıtlarda oran hiç 1,21'i geçmedi, uydurma iskeletlerde 1,6-25 arasına çıkıyor. Etki:
      kesik kadrajlı stok videolarda kalan sahte tekrarlar sıfırlandı (px_6326821 1→0, px_2785531 3→0),
      kurucunun kayıtları 5/5/3/5 ile aynı kaldı. D18'in ikinci katmanı.
- [x] 2026-09-09 — `minSignalConfidence` 0,4 → **0,5**, yani kuralların `minConfidence` eşiğiyle aynı: "tekrar
      sayılıyor ama hiçbir kural değerlendirilmiyor" boşluğu kapandı. 26 kayıtlık korpusta tekrar sayımı değişmedi.
- [x] 2026-09-09 — Yayın formatı **AAB**: CI artık `custom_lint` çalıştırıyor ve hem APK hem AAB üretip yüklüyor.
      Ölçüldü: `app-release.aab` **74,9 MB** (üç ABI bir arada); cihaza inen tek ABI'lik pay ~40 MB, bütçe içinde.
      `full` modeli asset'ten çıkarıp ilk kullanımda indirmek 9,4 MB daha kazandırır (v1.x).
- [x] 2026-09-09 — Uygulama adı iki platformda da **FORMA** (`android:label`, `CFBundleDisplayName`/`CFBundleName`);
      iOS'a `NSCameraUsageDescription` eklendi (izin diyaloğu metni Türkçe ve ne yapıldığını açıklıyor).
- [x] 2026-09-09 — MediaPipe modeli artık main thread'de yüklenmiyor: `PoseEngine` landmarker'ı analiz
      executor'ında `FutureTask` ile kuruyor, hata da aynı yoldan `ModelException` olarak geri dönüyor.
- [x] 2026-09-08 — **26 kayıtlık tarama** (4 cihaz kaydı + kurucunun 2 videosu + 20 ücretsiz stok video):
      tekrar sayımı doğru kadrajlı her kayıtta tutarlı; kesik kadrajlı stok videolarda motor **imkansız diz açıları**
      (3-12°) üretiyordu. Kök neden ölçüldü: MediaPipe kadraj dışındaki eklemi tahmin edip yüksek `visibility`
      veriyor ama koordinatı 0-1 aralığının dışına yazıyor.
- [x] 2026-09-08 — **Kadraj koruması (D18)**: kritik eklem görüntü dışına çıkarsa ya da vücut kadrajın %97'sinden
      fazlasını kaplarsa oturum donuyor; kadraj kaybı için ayrı cue ("Biraz geri git"). Etki: kesik stok
      videolarda sahte tekrarlar sıfırlandı (5→0, 3→0, 1→0), kurucunun cihaz kayıtları hiç etkilenmedi.

- [x] 2026-09-08 — **İlk doğruluk incelemesi** (kurucunun 2 videosu + 2 Pexels örneği + 4 cihaz kaydı = 8 fixture):
      tekrar sayımı **MAE 0** (her kayıtta doğru sayı), derinlik tespiti iskelet önizlemesiyle gözle doğrulandı
      (88-96° derin, 107-116° sığ ayrımı görüntülerle uyuşuyor), düşük güvende susma çalışıyor.
      Landmark görünürlüğü: gövde 0.75-1.00, bacak 0.69-0.99, **ayak 0.37-0.64** — ayak en zayıf halka,
      topuk kuralının neden güvenilmez olduğunu da bu açıklıyor (D17).

- [x] 2026-09-08 — **`tools/video_to_fixture`**: sıradan video → fixture JSON (aynı MediaPipe modeli, masaüstü).
      Kayıt ekranından çok daha az iş: telefonla normal video çek, dönüştür. `--preview` iskeleti videonun üzerine
      çizer (ayak noktaları turuncu), böylece bir kuralı açmadan önce modelin gerçekten ne gördüğü gözle
      doğrulanır. `--label REP:kural` ile etiket, `--rotate/--start/--end/--max-width` ile çekim düzeltmeleri.

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
- [x] 2026-09-08 — `forma_pose`: platform interface, binary codec (40 B header + 33×5 + 33×3 float), `FakeFormaPose` (sentetik/fixture), Android Kotlin (CameraX RGBA + PoseLandmarker LIVE_STREAM, GPU→CPU fallback, PreviewView platform view, izin akışı), iOS stub.
- [x] 2026-09-08 — `apps/mobile`: Riverpod codegen, go_router, l10n TR/EN, tema (docs/06 token'ları), Bugün ekranı, HUD (sayaç, skor halkası, tempo, cue metni, iskelet overlay + hata eklemi vurgusu, gizlilik rozeti), set özeti (skor, en sık 2 hata + "neden" kartı), fake motor ile widget testi.
- [x] 2026-09-08 — `tools/eval`: precision/recall/F1, rep MAE, cue/rep; `docs/eval/latest.md` üretir; Kapı 2 eşiği ile çıkış kodu.
- [x] 2026-09-08 — `flutter build apk --debug` lokalde yeşil: Kotlin plugin MediaPipe `tasks-vision:0.10.21` + CameraX 1.4.2 ile derleniyor (`app-debug.apk` 175 MB, debug; release boyutu ayrıca ölçüldü).
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
- [x] 2026-09-09 — Android plugin çalışma zamanı doğrulandı (izin, CameraX bind, GPU delegate, EventChannel
      throughput) ve CI'daki build adımı yeşil: debug APK + release APK + release AAB üretiliyor.
- [x] 2026-09-09 — **Eşik taraması** (docs/10 Prompt 9): `tools/eval/bin/sweep.dart` bir parametreyi aralıkta
      tarayıp her değer için korpusu yeniden oynatıyor ve en iyi değeri **öneriyor** (yazmıyor). Tekrar FSM'i,
      kural ifadesindeki sayı, One Euro ve oturum eşikleri taranabiliyor; birden fazla `--sweep` kartezyen
      çarpım. Korpus soruyu cevaplayamıyorsa (hiç hata etiketi yok, ya da kural için 10'dan az etiketli tekrar)
      **öneri vermeyi reddediyor** — aksi halde "en yüksek F1" sadece "hiç uyarmayan eşik" olurdu. 17 test.
- [ ] `reverse_lunge` kuralları: adım uzunluğu, ön diz ilerlemesi, gövde eğimi — sentetik lunge iskeleti yok, gerçek kayıt şart.
- [ ] `push_up` ön açı (dirsek açılması `shoulder_angle`) — kamera yerde ön açı gerçekçi mi, keşifte sor.
- [x] 2026-09-09 — docs/01'deki hata tablosu ile gerçekte açık olan kurallar ayrıştırıldı: glute bridge bel
      hiperekstansiyonu (2D'de ayırt edilemiyor) ve squat topuk kalkması (D17) kapalı, push-up ön açı ve
      reverse lunge kuralları henüz yazılmadı — tablo hedefi, altındaki paragraf durumu gösteriyor.

## Hafta 3-4 — 5 egzersiz + HUD (Kapı 2)

- [ ] Gerçek kişilerle test videosu/kayıt seti: 5 kişi × 5 egzersiz × 2 açı × 3 ortam (`data/fixtures/`, gitignore'da; onam formu).
- [ ] Kapı 2 raporu: precision ≥ %80, recall ≥ %70, cue gecikmesi ≤ 400 ms, 10 dk thermal test (cihaz matrisi docs/05 §10).
      Cue gecikmesinin **yazılım payı ölçüldü: 100 ms** (bütçenin dörtte biri, tamamı `minConsecutiveFrames: 3`
      kapısından). Kalan 300 ms konuşma motoru + hoparlör; cihazda uçtan uca ölçüm yapılmadı ve asıl risk orada.
- [ ] HUD: yatay mod, overlay aç/kapa ayarı, "az konuş" modu (`FeedbackPolicy.quietMode` hazır), düşük güvende gri sayaç (var) + tek seferlik cue (var).
- [x] 2026-09-10 — **Set/seans akışı** (docs/06 §4.4-4.5): set özeti → **sesli dinlenme sayacı** (son 3 saniye
      sesli, telefon karşı duvarda olduğu için sessiz sayaç sayaç değil) → sonraki set → seans özeti
      (ortalama skor, set set döküm, seansın en sık 3 hatası). `WorkoutSessionController` seansı tutuyor;
      egzersiz değişirse yeni seans başlıyor, hiçbir şey saymayan set ortalamaya girmiyor. HUD'un kendi
      `setIndex/setTotal` alanları silindi (aynı şey için iki sayaç = kayan sayı).
- [ ] Seans sonu **paylaşılabilir kart** (iskelet çizimi, video değil) — docs/06 §4.5'in kalan yarısı.
- [ ] "Bugünün skoru vs geçen seans" — kalıcı depolama gerektiriyor, aşağıdaki Drift maddesine bağlı.
- [ ] Yerel DB: Session/SetResult/Rep şeması (docs/05 §9). **Şu an kurulamıyor:** `drift_dev` analyzer ≥13
      istiyor, `custom_lint` 0.8.1 ve `freezed` 3.2.3 bizi analyzer 8'de tutuyor (10 Eylül'de denendi, pubspec
      geri alındı). Üç seçenek: (a) toolchain'i topluca yükselt — riverpod_generator/freezed codegen'i kırma
      riski var, (b) codegen'siz daha basit bir kalıcılık katmanı yaz (seans başına birkaç kayıt; SQL'e gerek
      olmayabilir), (c) drift_dev'in analyzer kısıtı gevşeyene kadar bekle. Karar kurucunun.
      Not: `sqlite3_flutter_libs` native `.so` getiriyor — hangi yol seçilirse seçilsin 16 KB hizalaması
      `tools/check_so_alignment.py` ile yeniden doğrulanmalı.
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
      Görünen ad artık FORMA; değişecek olan yalnızca paket kimliği.
- [ ] Ses klipleri üretilene kadar her cue cihaz TTS'iyle söyleniyor: ilk kelime birkaç yüz ms gecikebilir ve ses
      robotik. `VoiceCuePlayer` klip bulunca kendiliğinden ona geçer, kod değişikliği gerekmez.
- [x] 2026-09-09 — Kadraj geri sayımının duvar saatinde kalmasına **karar verildi**: geri sayım insana bakan bir
      sayaç, insan zamanında akmalı. Frame zaman damgasına bağlansaydı kamera takıldığında geri sayım donup
      kullanıcıyı ekranda kilitlerdi. İki saat hiçbir yerde karşılaştırılmıyor.
- [ ] `SessionConfig.maxShinThighRatio` (1,6) ve `maxBodyHeightFraction` (0,97) 26 kayıtlık küçük bir korpustan
      geldi; kayıt sayısı artınca yeniden ölç. Aynısı `signalLossGraceMs` (300 ms) için de geçerli.
- [x] 2026-09-09 — Eval'de hiç ölçülmemiş 5 kural için sentetik fixture eklendi (plank hip_pike/head_drop,
      push_up hip_pike/shallow_depth, squat shallow_depth_front). Raporda artık **tek bir `n/a` yok**: ürünün
      gönderdiği 11 kuralın hepsi en az bir fixture tarafından çalıştırılıyor. Sentetik olduğu için "hata varken
      tetikleniyor mu"yu kanıtlar, "gerçek vücutta çalışıyor mu"yu değil — ama sessizce bozulan bir kuralı yakalar.
- [x] 2026-09-09 — `syn_squat_side_lean_heels`'in `heel_rise` etiketi **bilerek duruyor**: fixture gerçekten
      `heelRise: 0.08` ile üretildi, yani etiket doğru. Kural D17 ile kapalı olduğu için o 3 tekrar ölçülmüyor
      ve eval bunu uyarı olarak basıyor. Kural geri açılırsa yer gerçeği hazır.
- [ ] FMA kas id'leri (`content/exercises/*.json` primary/secondaryMuscles) doğrulanmadı — anatomi katmanında kontrol.
- [ ] `explain.source` id'leri yer tutucu (`src_valgus_01` vb.) — `content/sources/` doldurulunca eşle.
- [ ] Eval: FN sayımı "tespit edilmeyen tekrar"ı da sayıyor. Index kayması artık **sessiz değil** — sayılar
      uyuşmuyorsa harness "etiketler yanlış tekrara denk gelmiş olabilir" uyarısı basıyor. Gerçek bir kayma
      görülürse (şimdiye kadar rep MAE hep 0) zaman örtüşmesine dayalı eşleme/DTW gerekecek.
- [ ] Kayıt ekranı metinleri l10n dışında (bilinçli: kurucu aracı, sadece debug). Beta'da başka birine kayıt
      yaptıracaksan İngilizceye çevir.
- [ ] Kayıt sırasında ham frame'ler bellekte tutuluyor (3 dk ≈ 11 MB). Daha uzun kayıt gerekirse parça parça diske yaz.
- [ ] Lisans ekranı listesi: `share_plus`, `path_provider` (BSD-3), `just_audio`, `flutter_tts` (MIT),
      `audio_session` (MIT). Hepsi docs/08'deki tabloda; uygulama içi ekran yazılınca oradan beslenecek.
- [ ] `GestureDetector`: kesintisiz tutulan bir jest her `cooldownMs`'de yeniden tetikleniyor (yeni bir tutuş
      beklemiyor). Bugün zararsız — jestler HUD'a bağlı değil — ama D15 onaylanırsa önce bu düzelmeli.
- [ ] `toUprightBitmap` kare başına iki tam boy ARGB_8888 bitmap ayırıyor ve parlaklığı `getPixel` ile okuyor.
      Ölçülmedi; 10 dk termal testinde bakılacak ilk yer burası.
- [ ] MediaPipe `tensor.cc: Tensors are designed for single writes` uyarısı her koşuda çıkıyor (GPU delegate, zararsız
      görünüyor); 1.0.0'da da var, takip et.
- [ ] HUD'daki debug metrik satırı `kDebugMode` ile sınırlı; release'de görünmüyor ama beta build'lerde bir ayar arkasına alınabilir.
- [x] 2026-09-09 — `flutter analyze` + `custom_lint` (riverpod_lint) CI'da koşuyor; release AAB de CI'da üretiliyor.
- [x] 2026-09-09 — Plugin example'ı artık uygulamayla aynı cover-fit overlay'i kullanıyor (iskelet preview'a oturuyor).
- [x] 2026-09-09 — `PoseEngine.createLandmarker` main thread'i bloklamıyor (analiz executor'ında `FutureTask`).
- [x] 2026-09-08 — CI: action sürümleri v5'e çekildi; `tools/check_so_alignment.py` ile 16 KB hizalaması her build'de doğrulanıyor.
- [x] 2026-09-08 — `.gitattributes` ile satır sonları LF'e sabitlendi (`dart format --set-exit-if-changed` Windows'ta da aynı davranıyor).

## Kurucuya ait (kod dışı)

- [ ] **Kapı 1 keşif:** 5 PT/fizyoterapist + 10 kullanıcı görüşmesi (docs/09 Hafta 0). Çıkış: 6/10 "formumdan emin değilim", 3/5 PT "önerirdim".
- [ ] **Kasten hatalı squat videosu** (yukarıda "Şimdi" listesinde) — recall ölçümünün önündeki tek engel.
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
- **2026-09-08 / oturum 6 (Claude):** Kurucunun iki videosu ve 20 ücretsiz stok video işlendi (`video_to_fixture`),
  26 kayıt tarandı. Topuk sorusu iskelet önizlemesiyle gözle kapatıldı (topuklar yerde, model dipte ayağı eğik
  görüyor). Kesik kadrajın imkansız açılar ürettiği ölçüldü ve kadraj koruması eklendi (D18) + ayrı kadraj cue'su.
  Testler: 115 + 3 + 3 yeşil.
- **2026-09-09 / oturum 7 (Claude):** "Yeni video beklemeyen ne varsa bitir" oturumu. Ürünü cihazda eksik hissettiren
  iki boşluk kapandı: koç artık **sesli** konuşuyor (klip varsa klip, yoksa cihaz TTS'i) ve set **kadraj adımıyla**
  açılıyor (sesli yönerge + 5 sn geri sayım + "Şimdi başla"); ikisi de Galaxy S23'te doğrulandı. Kesik kadrajda
  kalan imkansız açılar anatomik makullük kontrolüyle kapatıldı, `minSignalConfidence` kural eşiğine hizalandı.
  Uygulama adı FORMA oldu + iOS kamera izni metni, CI'a `custom_lint` ve release AAB eklendi (74,9 MB ölçüldü),
  MediaPipe modeli main thread'den çıkarıldı, plugin example overlay'i uygulamayla hizalandı, docs/05 + docs/08 +
  fixtures-schema güncellendi. Son iş: **eşik taraması** (`tools/eval/bin/sweep.dart`, docs/10 Prompt 9) —
  parametreyi tarayıp öneriyor, `content/`'e yazmıyor ve korpus soruyu cevaplayamıyorsa öneri vermeyi
  reddediyor; eval harness'ı artık CI'da analiz ediliyor ve test ediliyor.
  Ardından 5 ajanlı düşmanca bir hata avı koşuldu: 28 ham bulgunun 18'i doğrulandı ve düzeltildi (7'si yüksek),
  6'sı reddedildi. Her biri regresyon testli; 8 gerçek kaydın tekrar sayıları değişmedi.
  Gece devamı: ilk gerçek dünya doğruluk sayısı (stok videodan gözle doğrulanmış yer gerçeğiyle
  `shallow_depth` 2 TP / 0 FP / 0 FN), kısmi termal koşu, cue gecikmesinin yazılım payı (100 ms),
  hiç ölçülmemiş 5 kural için fixture, ve **etiketlemeyi resme bakmaya indiren iki araç** (`--sheet` ve
  kayıt ekranındaki tekrar iskeletleri). Ayrıca `shallow_depth` eşiği ilk kez ölçüye dayalı tarandı:
  105 üst sınırda, yükseltmek kaçırmaya başlıyor.
  Testler: **128 + 26 + 3 + 3 yeşil**.
  Kalan tek blokaj: kasten hatalı kayıt (kurucu yarın çekecek).
