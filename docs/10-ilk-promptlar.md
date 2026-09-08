# 10 — İlk Promptlar (Claude Code)

## Nasıl kullanılır

1. `git init forma && cd forma && mkdir docs` → bu seti `docs/` altına koy.
2. Aşağıdaki `CLAUDE.md`'yi repo köküne kaydet.
3. Claude Code'u aç, **plan modunda** Prompt 0'ı ver; planı onaylamadan kod yazdırma.
4. Her prompt için ayrı branch/worktree (`git worktree add ../forma-pose feat/pose-android`). Paralel çalıştırılabilecekler: Prompt 2 (Android plugin) ‖ Prompt 4 (kural motoru, saf Dart) ‖ Prompt 6 (TTS script).
5. Her promptun sonunda "bitti" tanımı: test geçiyor, `docs/` güncellendi, PR açıklaması var.
6. Promptlar Türkçe; kod, tanımlayıcılar, commit mesajları İngilizce.

Claude Code dokümantasyonu (CLAUDE.md, plan modu, worktree'ler için): https://docs.claude.com/en/docs/claude-code/overview

---

## CLAUDE.md (repo köküne)

```markdown
# FORMA — proje bağlamı

Kamera ile gerçek zamanlı egzersiz formu düzelten, sesli geri bildirim veren Flutter uygulaması.
Önce docs/00-README.md'yi, sonra ilgili dokümanı oku. Kararlar docs/00-README.md Decision Log'da; bir karara aykırı bir şey gerekiyorsa önce sor.

## Değişmez kurallar
- Kamera frame'leri Dart'a geçmez; cihaz dışına asla çıkmaz. Native katman yalnızca kamera + inference + overlay.
- Poz motoru: MediaPipe Pose Landmarker (Apache 2.0). Ultralytics/YOLO (AGPL) ve CC BY-NC lisanslı hiçbir model/veri eklenmez. Yeni bağımlılıkta lisansı yaz.
- Antrenman mantığı (rep detection, kurallar, skor, feedback scheduler) saf Dart, `packages/forma_rules` içinde, UI ve plugin'den bağımsız, test edilebilir.
- Egzersiz kuralları kodda değil `content/exercises/*.json` içinde (DSL şeması docs/05, bölüm 4).
- Sesli geri bildirim önceden üretilmiş kliplerle (`assets/audio/cues`), runtime TTS yalnızca yedek.
- Sağlık verisi tutulmaz; analitik olaylarına görüntü/landmark girmez.
- Her kullanıcıya görünen metin TR ve EN (`l10n`), TR birincil.

## Stack
Flutter (stable) · Riverpod (codegen) · go_router · Drift · Supabase · RevenueCat · PostHog · Sentry · just_audio + audio_session · flutter_inappwebview (anatomi) · freezed/json_serializable · very_good_analysis.
Native: Android Kotlin (CameraX + MediaPipe Tasks Vision), iOS Swift (AVFoundation + MediaPipe Tasks iOS).

## Yapı
apps/mobile (uygulama) · packages/forma_pose (federated plugin) · packages/forma_rules (saf Dart) · tools/{landmark_recorder,eval,tts_gen} · web/demo · content/ · docs/

## Çalışma şekli
- Önce plan, sonra kod. Kapsamı küçük tut; bir prompt = bir PR.
- Her yeni davranış için test: birim (matematik/FSM/scheduler) + golden replay (test/fixtures/*.json).
- Komutlar: `melos bootstrap` (monorepo), `flutter analyze`, `flutter test`, `dart run tools/eval` .
- Performans bütçeleri docs/05 bölüm 10; ihlal ediyorsan söyle.
- Bilmediğin bir MediaPipe/CameraX/AVFoundation API detayında uydurma; resmi dokümana bak ya da sor.
- Türkçe açıklama, İngilizce kod/commit. Commit: conventional commits.
```

---

## Prompt 0 — Kickoff (plan modu)

```
docs/ klasöründeki tüm dokümanları oku (00'dan 11'e). Sonra:
1) Projeyi kendi cümlelerinle 5 maddede özetle; anlamadığın veya çelişkili bulduğun yerleri listele.
2) docs/09'daki Hafta 1-2 için detaylı bir uygulama planı çıkar: monorepo yapısı, paket sınırları, her paketin public API'si, hangi işlerin paralel yürüyebileceği, riskli noktalar (özellikle MediaPipe Tasks'ın Android/iOS entegrasyonu ve Flutter EventChannel throughput'u).
3) Kararı bana bırakman gereken en fazla 5 soruyu sor (ör. melos kullanımı, min SDK, Riverpod codegen tercihi).
Kod yazma; planı docs/plans/week-01-02.md olarak kaydet.
```

## Prompt 1 — Monorepo iskeleti

```
docs/05'teki klasör yapısını kur: melos ile monorepo; apps/mobile (Flutter, Riverpod codegen, go_router, freezed, very_good_analysis, l10n TR/EN), packages/forma_rules (saf Dart, sıfır Flutter bağımlılığı), packages/forma_pose (federated plugin: platform_interface + android + ios, şimdilik stub), tools/ boş iskelet.
- Feature-first clean architecture; features/workout altında domain/application/infrastructure/presentation.
- GitHub Actions: analyze + test (Dart ve Flutter), Android debug build; iOS build şimdilik atla.
- README'de kurulum komutları.
- Bir "Hello workout" ekranı: Riverpod ile sahte PoseFrame stream'i (sinüs sinyali) üreten bir provider ve bunu çizen basit bir sayaç. Bu, plugin gelmeden UI'ı geliştirebilmek için.
Test: forma_rules boş bile olsa bir dummy test; CI yeşil.
```

## Prompt 2 — Android `forma_pose` plugin'i (CameraX + MediaPipe Tasks)

```
packages/forma_pose/android'i implement et:
- CameraX Preview + ImageAnalysis (STRATEGY_KEEP_ONLY_LATEST, 640x480 varsayılan, ayarlanabilir), ön/arka lens.
- MediaPipe Tasks Vision PoseLandmarker, RunningMode.LIVE_STREAM, GPU delegate (CPU'ya düşme), model lite/full asset'ten.
- Sonuçları EventChannel ile ByteData olarak gönder: header{ts, w, h, fps, inferenceMs, rotation} + 33×(x,y,z,visibility,presence) + 33×world(x,y,z). Ön kamerada ayna ve rotasyon native'de normalize edilsin.
- PlatformView ile preview widget'ı; overlay şimdilik Flutter CustomPaint (landmark'ları noktalarla çiz).
- Dart API docs/05 bölüm 8'deki gibi: start/stop/setModel/frames/preview.
- Örnek uygulama: fps ve inferenceMs overlay'i.
- Hata yolları: izin yok, kamera meşgul, model yüklenemedi → tipli hatalar.
- Lifecycle: arka plana geçince stop, dönünce resume.
Ölçüm: orta segment bir cihazda fps ve inferenceMs değerlerini raporla; hedef lite modelde ≤33 ms.
Bağımlılık versiyonlarını ve lisanslarını PR açıklamasına yaz.
```

## Prompt 3 — Landmark kaydedici / oynatıcı + fixture'lar

```
tools/landmark_recorder: uygulama içi gizli ekran (debug flavor) — bir egzersiz seçilir, kayıt başlar, PoseFrame dizisi JSON olarak cihaza yazılır (video değil), etiket alanları: exerciseId, view, person (anonim id), environment, expectedReps, errorLabels[] (rep bazında). Dosya paylaşımı (share sheet) ile bilgisayara alınabilsin.
packages/forma_rules içinde `FixtureReplayer`: JSON'u gerçek zamanlı veya hızlı modda PoseFrame stream'i olarak oynatır.
test/fixtures/ altına 2 sentetik fixture üret (sinüs tabanlı temiz squat, gürültülü squat) ve replay testi yaz.
Şema dokümanı: docs/fixtures-schema.md.
```

## Prompt 4 — Kural motoru: özellikler, FSM, DSL, skor

```
packages/forma_rules'u implement et (saf Dart, %90+ test kapsamı hedefi):
1) Landmark index sabitleri (MediaPipe 33), One Euro filter (landmark başına), açı/hiza/mesafe yardımcıları (2D ve world 3D).
2) FeatureExtractor: docs/05 bölüm 4'teki DSL'in ihtiyaç duyduğu değişkenler (angle(a,b,c), kneeAnkleRatio, torsoAngle, hipHeight, shoulderLevelDiff, vb.).
3) RepDetector: hysteresis'li durum makinesi (idle/descending/bottom/ascending/top), minDurationMs, tempo ölçümü.
4) Rule DSL: JSON şeması + doğrulayıcı + güvenli expression evaluator (eval yok; `expressions` paketi ya da küçük bir parser). phase/view/minConfidence/evaluateAt destekli.
5) ScoreEngine: tekrar başına 0-100, kural ağırlıklarıyla.
6) content/exercises/bw_squat.json'u docs/05'teki örnekten üret; push-up/lunge/plank/glute_bridge için iskelet JSON'lar (kurallar TODO ile).
Testler: sentetik sinyallerde tekrar sayımı (çift sayım yok), her kural için pozitif/negatif fixture, DSL şema hataları.
Performans: 30 Hz girdide frame başına < 2 ms (benchmark testi).
```

## Prompt 5 — FeedbackScheduler + ses/haptik

```
packages/forma_rules içinde FeedbackScheduler (docs/05 bölüm 5 politikası): öncelik = severity×confidence, cooldown, varyant döngüsü, "5 tekrar sürerse sus", olumlu pekiştirme oranı, düşük güvende sessizlik, sayım/cue çakışma kuyruğu. Zaman enjekte edilebilir (test için sahte saat).
apps/mobile içinde AudioCuePlayer: just_audio ile assets/audio/cues/{locale}/{clipId}.opus; audio_session ile ducking (müzik kısılır); tek kanal, yüksek öncelik düşük önceliği keser; haptik eşlemesi.
content/cues.json: clipId → {tr: [varyant metinleri], en: [...]}; şimdilik 40 cue (sayılar 1-20, 5 egzersizin kritik hataları, olumlu cue'lar, kurulum cue'ları).
Testler: scheduler senaryoları (3 hata aynı anda, aynı hata art arda, düşük güven).
```

## Prompt 6 — TTS klip üretim scripti

```
tools/tts_gen: Python script. content/cues.json'u okur, Google Cloud Text-to-Speech (tr-TR ve en-US neural sesler, ses adı parametreli) ile her varyant için ses üretir, ffmpeg ile Opus 48 kbps'e çevirir, sessizlik kırpar, loudness normalize eder (-16 LUFS), assets/audio/cues/{locale}/{clipId}_{n}.opus olarak yazar; manifest üretir. Idempotent: değişmeyen metinleri yeniden üretmez (hash). Azure için alternatif backend arayüzü bırak. Kullanım ve maliyet notu README'de (ücretsiz kota hesabı).
```

## Prompt 7 — Kamera kurulum asistanı + HUD

```
docs/06 bölüm 4.2-4.4'ü implement et:
- Kamera kurulum: egzersizin açı piktogramı, canlı çerçeve (tüm vücut landmark visibility ortalaması > eşik → yeşil), "geri git / telefonu yükselt" yönlendirmesi, ışık kontrolü (frame parlaklığı plugin'den), 5 sn sesli geri sayım.
- HUD: büyük tabular sayaç, form skoru halkası, tempo, son cue metni (3 sn), overlay aç/kapa, "Bitir/Atla" büyük butonlar, gizlilik rozeti, düşük güvende gri sayaç. Yatay ve dikey.
- Set özeti ekranı: skor, tekrar, en sık 2 hata + "neden" kartı (content/exercises'daki explain alanı).
- Riverpod ile session controller; PoseStream → forma_rules pipeline → HUD state.
- Design token'ları docs/06 bölüm 6'dan theme olarak.
Widget testleri: HUD durumları (normal, düşük güven, cue gösterimi). Sahte PoseFrame stream'iyle çalışsın; gerçek plugin arkasında aynı arayüz.
```

## Prompt 8 — iOS `forma_pose` plugin'i

```
packages/forma_pose/ios: AVFoundation (AVCaptureVideoDataOutput, 640x480, ön/arka), MediaPipe Tasks iOS PoseLandmarker liveStream modu, GPU delegate, Android ile bit uyumlu ByteData formatı, PlatformView preview, lifecycle. Eğer MediaPipe Tasks iOS entegrasyonunda çözülemeyen bir engel çıkarsa: Apple Vision (VNDetectHumanBodyPoseRequest / iOS 17+ 3D) ile aynı Dart arayüzünü sağlayan ikinci bir motor yaz ve landmark'ları MediaPipe 33 formatına eşle (eksik noktaları presence=0 ile işaretle). Kararı ve gerekçeyi docs/00 Decision Log'a ekle.
Ölçüm: iPhone 11 ve 14'te fps/inferenceMs.
```

## Prompt 9 — Eval harness

```
tools/eval (Dart CLI): test/fixtures ve data/fixtures altındaki etiketli JSON kayıtlarını forma_rules pipeline'ından geçirir; egzersiz ve hata tipi bazında precision/recall/F1, tekrar sayımı MAE, tekrar başına ortalama cue sayısı hesaplar; markdown ve JSON rapor üretir (docs/eval/latest.md). Eşik (threshold) taraması: seçilen kural parametrelerini aralıkta tarayıp F1'i maksimize eden değeri önerir (grid search), ama otomatik yazmaz, öneri verir. CI'da rapor artifact olarak.
```

## Prompt 10 — Anatomi görüntüleyici (v0.2)

```
apps/mobile/features/anatomy: flutter_inappwebview içinde three.js sahnesi (assets/anatomy/index.html + glb). GLB'yi Z-Anatomy türevinden hazırlamak için tools/anatomy_prep (Blender Python script): yalnızca kas + iskelet, kas başına ayrı mesh, isimler FMA id ile, meshopt/Draco sıkıştırma, hedef ≤ 20 MB; CC BY-NC lisanslı alt parçaları hariç tut ve bir ATTRIBUTION.md üret.
JS köprüsü: highlightMuscles(ids, intensities), setView(front/back/side), reset. Dart tarafında egzersiz JSON'undaki primary/secondary kaslara göre çağır; set özetinde ölçüme dayalı yoğunluk (şimdilik: hareket açıklığı oranı × primary ağırlığı).
Performans: orta segment cihazda 30 fps döndürme; lazy indirme (ilk açılışta değil).
Lisans ekranına anatomi atfını ekle (docs/04 örneği).
```

## Prompt 11 — İçerik ve kaynak kartları (v0.3)

```
content/sources/*.json şeması: id, title, authors, year, journal, doi, openAccess(bool), summary{tr,en} (2 cümle, kendi cümlelerimizle), evidenceStrength(low/moderate/high), tags. docs/11'deki aday listeden ilk 10 kaydı iskelet olarak oluştur; summary alanlarını BOŞ bırak ve "kurucu okuyup dolduracak" işareti koy (halüsinasyon yok).
Program motoru: girdi (hedef, seviye, gün, ekipman) → 3 haftalık plan; set/tekrar/RIR parametreleri sources'a referanslı; UI'da "?" → kaynak kartı. Remote content bundle: Supabase'den versiyonlu JSON çekme + yerel cache + şema doğrulama.
```

## Gözden geçirme promptu (her PR sonrası)

```
Bu PR'ı docs/05 (mimari sınırlar, performans bütçeleri), docs/08 (gizlilik: frame/landmark buluta gidiyor mu, yeni bağımlılık lisansı), docs/06 (cue dili kuralları) açısından incele. İhlalleri, eksik testleri ve TR/EN metin eksiklerini listele; kritikse düzelt, değilse TODO olarak issue aç.
```

## Genel ipuçları

- Native API'lerde (MediaPipe Tasks sürümleri, CameraX, AVFoundation) Claude Code'un uydurmasına izin verme: "emin değilsen resmi dokümana bak" cümlesi CLAUDE.md'de duruyor; PR açıklamasında sürüm ve link iste.
- Büyük promptları bölmekten çekinme; her biri test edilebilir bir parça olsun.
- Fixture verisi (Prompt 3) ne kadar erken birikirse, kural geliştirme o kadar hızlanır. İlk hafta 20 kayıt hedefle.
- Eşikleri elle ayarlama; eval harness'la (Prompt 9) ayarla.
