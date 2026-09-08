# 04 — Görüntü İşleme, 3D Varlıklar, Ses: Seçenekler, Lisanslar, Maliyet

Kural: **Görüntü cihazda işlenir, buluta gitmez.** Bu tek karar gizlilik, gecikme ve maliyet problemlerinin üçünü birden çözer. Bulutta poz tahmini yapmanın tek gerekçesi olabilirdi (daha büyük model = daha doğru), onu da modern on-device modeller karşılıyor.

## 1. Poz tahmini (pose estimation) seçenekleri

| Seçenek | Lisans | Ticari kullanım | Nokta sayısı / 3D | Platform | Hız (orta segment telefon) | Karar |
|---|---|---|---|---|---|---|
| **MediaPipe Pose Landmarker** (Google AI Edge, BlazePose GHUM) | Apache 2.0 | Serbest, NOTICE ekle | 33 nokta; normalize 2D + **world landmarks (metrik 3D)**; lite/full/heavy | Android, iOS, Web, Python | lite: ~30 fps GPU; full: ~15-25 fps | **Ana motor** |
| **ML Kit Pose Detection** (Google) | Google terms, ücretsiz | Serbest | 33 nokta; z "deneysel", gerçek 3D değil; tek kişi; yüz görünmeli | Android, iOS | Benzer | **Prototip için** (olgun Flutter plugin'i var: `google_mlkit_pose_detection`), ama API **beta, SLA ve deprecation politikası yok** → üretimde riskli |
| **Apple Vision** (`VNDetectHumanBodyPoseRequest`, iOS 14+; `...3DRequest` iOS 17+) | Apple SDK | Serbest | 2D 19 nokta; 3D 17 eklem (iOS 17+) | Sadece iOS | Neural Engine ile çok hızlı | iOS için **yedek/alternatif motor** |
| **MoveNet** (TF) | Apache 2.0 | Serbest | 17 nokta, 2D; Lightning çok hızlı | TFLite her yerde | 30+ fps | Düşük segment Android için fallback |
| **RTMPose** (OpenMMLab) | Apache 2.0 (doğrula) | Serbest | 17/26 nokta 2D, yüksek doğruluk; 3D varyantı var | ONNX/NCNN; entegrasyon emek ister | Orta | v1.x'te doğruluk artırmak için aday |
| **ViTPose** | Apache 2.0 | Serbest | Yüksek doğruluk, ağır | Sunucu tarafı | Mobilde ağır | Hayır (cihazda değil) |
| **YOLO11/YOLO26-pose** (Ultralytics) | **AGPL-3.0** | **Hayır** — tüm uygulamayı AGPL ile açmadan olmaz; Enterprise lisans ücretli; Roboflow ücretli planı alt-lisans veriyor | 17 nokta | Her yer | Hızlı | **Kullanma.** Senin bildiğin araç ama lisans kapalı ürüne uymuyor |
| **Sapiens** (Meta) | CC BY-NC 4.0 | **Hayır** (ticari değil) | Çok yüksek doğruluk | Sunucu | Ağır | Hayır |
| **Ticari SDK'lar** (Kemtai, Asensei, Sency) | Sözleşme | Ücretli, B2B fiyatlama, genelde başlangıç için uygun değil | — | — | — | Hayır (kendi hendeğimizi onlara vermeyiz) |

### Karar: MediaPipe Pose Landmarker, cihazda, GPU delegate ile

Gerekçe:
- Lisans temiz (Apache 2.0), Google 2026'da hâlâ aktif güncelliyor (dokümantasyon Ağustos 2026 tarihli).
- **World landmarks** metrik 3D koordinat veriyor → eklem açıları kamera açısından daha az etkilenerek hesaplanabilir (tek kamerada yine hata payı var, ama 2D'den çok daha iyi).
- lite/full/heavy modeller cihaza göre seçilebilir: düşük segment → lite, orta-üst → full.
- Android/iOS/Web aynı model, aynı nokta indeksleri → kural motoru tek yazılır, web demo bedava.

Riskler: iOS tarafında Flutter plugin ekosistemi zayıf (küçük topluluk paketleri, "initial iOS support"); çözüm kendi ince plugin'imiz (bkz. 05). Yüksek segment kıyafet/bol eşofmanda doğruluk düşer → kurulum asistanında uyarı, düşük güven skorunda geri bildirimi kıs.

### 2D mi 3D mi, kamera açısı

- Kural motoru **açı tabanlı** çalışır: diz açısı, kalça açısı, gövde-yer açısı, diz-ayak hizası (valgus), omuz seviyesi farkı.
- Her egzersiz için **izin verilen kamera açıları** tanımlı (ör. squat: ön 0±25° veya yan 90±25°). Kurulum asistanı kullanıcıyı doğru açıya yönlendirir; kural setleri açıya göre ayrı ağırlıklanır (yan açıda derinlik güvenilir, ön açıda valgus güvenilir).
- Tek kamerada derinlik belirsizliği var → "emin değilsen sus" politikası: landmark visibility/presence eşiğinin altında uyarı verilmez.
- Yumuşatma: One Euro filter (düşük gecikme) landmark bazında; tekrar tespiti için açı sinyalinde hysteresis'li durum makinesi.

### Maliyet

On-device: **kullanıcı başına 0 TL.** Bulut alternatifi (ör. GPU sunucuda ViTPose) 30 fps video için kullanıcı başına saatte dolar mertebesi + gizlilik yükü — anlamsız.

## 2. Test verisi (doğruluk için şart)

- **Kendi veri setin:** egzersiz başına 30-50 kısa video; ≥ 5 farklı kişi (boy/kilo/kıyafet çeşitliliği), ≥ 3 ortam (salon, oturma odası, düşük ışık), iki açı; her videoda hata etiketleri (valgus var/yok, derinlik yetersiz vb.). Onam formu alınır, yüzler bulanıklaştırılabilir, veri seti şirket içi kalır. Bu veri seti **hendektir** — klonlayanların olmayan şeyi.
- Landmark kayıt/replay aracı (05'te) sayesinde testler videoyu değil JSON landmark dizilerini kullanır → hızlı, deterministik.
- Kamuya açık veri setleri (Fit3D vb.) çoğunlukla araştırma lisanslı → yalnızca dahili değerlendirme için, üründe eğitim/dağıtım için değil; lisansı tek tek oku.

## 3. 3D anatomi varlıkları

| Kaynak | Lisans | Ne var | Not |
|---|---|---|---|
| **BodyParts3D** (DBCLS, Tokyo) | CC BY-SA 2.1 Japan | Tüm vücut, FMA ontolojisiyle isimlendirilmiş binlerce yapı | Ham, ağır mesh'ler; atıf metni zorunlu |
| **Z-Anatomy** (Kervyn, 2021-) | CC BY-SA 4.0 | BodyParts3D'nin retopolojize, materyalli Blender versiyonu; 5.000+ yapı | **Dikkat:** içinde CC BY-NC-SA parçalar var (ör. Dundee'nin iç kulak modeli) → ticari üründe o parçalar **çıkarılır**; kaslar BodyParts3D kökenli, sorun yok |
| **AnatomyTOOL Open3DModel** (LUMC + Hollanda üniversiteleri, 2022-) | CC BY-SA | Z-Anatomy üzerine yeniden retopolojize, eğitim için temizlenmiş; 2026'da aktif | Sana gösterilen demo uygulamanın atıfındaki kaynak tam bu |
| Stock (TurboSquid/CGTrader "anatomy muscle system") | Royalty-free standart lisans | Kas sistemi modelleri 50-500 $ | Kas bazlı ayrıştırma her zaman iyi değil; lisansta "uygulama içinde dağıtım" maddesini oku |
| Kendi modelin (freelance 3D artist) | Tamamen senin | Kas bazında ayrık, düşük poligon, senin stilinde | Tahmini 500-2.000 $, 2-4 hafta; v1'de düşün |

**CC BY-SA'nın anlamı (hukuki görüş değil):** Modeli değiştirip uygulamada dağıtırsan, **değiştirilmiş model dosyalarını** aynı lisansla paylaşman ve atıf vermen gerekir. Uygulama kodun ayrı bir eser; model ayrı yüklenen bir varlık. Yaygın yorum: kod kapalı kalabilir, türev GLB dosyası açık olur. Bizim için kabul edilebilir: türev modelimiz açık olsun, hendeğimiz zaten model değil. Yine de yayına çıkmadan 1 saat avukat.

Atıf örneği (uygulama içi "Hakkında/Lisanslar" ekranı): `3D anatomi modeli: Z-Anatomy (CC BY-SA 4.0), BodyParts3D © The Database Center for Life Science (CC BY-SA 2.1 Japan) türevidir. Değişiklikler: [link]`

### Mobilde 3D render

| Yol | Artı | Eksi | Karar |
|---|---|---|---|
| **WebView + three.js** (GLB, kas başına mesh, highlight materyali) | En hızlı, web demo ile aynı kod, güçlü ekosistem | WebView overhead; Flutter ↔ JS köprüsü | **v0.2 için bu** |
| `flutter_3d_controller` (model-viewer) | Kolay | Kas bazında kontrol sınırlı | Hayır |
| Flutter Scene / Impeller 3D | Native | Deneysel | Takipte |
| Unity as a Library | Güçlü | Ağır, lisans, build karmaşası | Hayır |

Varlık bütçesi: sadece kas + iskelet, ≤ 20 MB (meshopt/Draco sıkıştırma), lazy download (ilk açılışta değil, anatomi sekmesinde). Kas isimleri FMA ID ile eşlenir → egzersiz JSON'unda `primaryMuscles: ["FMA:22356"]` gibi.

## 4. Ses: TTS

| Sağlayıcı | Fiyat | Türkçe | Not |
|---|---|---|---|
| **Cihaz içi** (Android Google TTS, iOS Siri sesleri; Flutter: `flutter_tts`) | Ücretsiz | Var, kalite orta | Dinamik cümleler için yedek |
| **Google Cloud TTS** | Neural2/WaveNet ~16 $/1M karakter; Standard 4 $/1M; **aylık ücretsiz kota** (WaveNet/Neural2 1M, Standard 4M) | Var | Önceden üretim için ideal |
| **Azure Speech** | ~16 $/1M; 500K/ay ücretsiz | Var (neural) | Alternatif |
| ElevenLabs | Abonelik 5 $/ay (30K kr.) → 99 $/ay (500K) | Var; en doğal | Marka sesi istenirse |
| OpenAI TTS | 15-30 $/1M | Var | Gerek yok |
| Amazon Polly | Standard 4 $/1M | Var | Gerek yok |

**Karar (D5): Önceden üretilmiş ses klipleri.** Geri bildirim cümleleri sınırlı ve tekrar eden bir kümedir ("dizlerini dışa aç", "daha derin in", "harika, böyle devam", "3… 2… 1…", sayılar). ~300 cümle × 2 dil ≈ 20-30K karakter → **ücretsiz kotanın içinde, tek seferlik, toplam maliyet ~0**. Klipler uygulamaya asset olarak gömülür (Opus/AAC, ~2-4 MB). Avantajlar: 50 ms altı başlatma gecikmesi (çalışma zamanı TTS'te 300-800 ms), çevrimdışı çalışır, tutarlı ses kişiliği. Dinamik/uzun metin (kaynak özeti okuma) için `flutter_tts` yedek.

Kural: müzik dinleyen kullanıcı için **audio ducking** (Spotify kısılır, cue çalar, geri yükselir). Haptik cue sesle senkron.

TTS sağlayıcı şartları: Google/Azure ile üretilen sesin uygulama içinde dağıtımı standart kullanım; yine de "synthetic voice" maddelerini bir kez oku, sesi "insan" diye pazarlama.

## 5. Ses tanıma (isteğe bağlı)

"Başla / dur / atla" için cihaz içi STT (`speech_to_text` plugin) ücretsiz; müzik ve ortam gürültüsünde güvenilmez → MVP'de yok, v1.x'te büyük dokunmatik buton + sesli komut ikili.

## 6. LLM (v1.x, sohbet koçu için)

MVP'de yok. Gerekirse: kullanıcı başına ayda 20-50 mesaj × ~1.500 token ≈ birkaç sent; kaynak kartları RAG ile bağlanır. Halüsinasyon riski nedeniyle "kaynak dışı iddia yok" sistem promptu ve kaynak kimliği zorunlu.

## 7. Toplam maliyet tablosu (aylık, 10.000 aktif kullanıcı senaryosu)

| Kalem | Maliyet |
|---|---|
| Poz tahmini | 0 (cihazda) |
| TTS | 0 (önceden üretilmiş) |
| Backend (Supabase Pro) | ~25 $ + kullanım |
| Analitik (PostHog cloud ücretsiz kota / Firebase) | 0-50 $ |
| Crash (Sentry/Crashlytics) | 0-26 $ |
| Mağaza hesapları | Apple 99 $/yıl, Google 25 $ tek sefer |
| 3D varlık | 0 (açık) → v1'de 500-2.000 $ tek sefer |
| **Toplam** | **~50-100 $/ay** |

Bu maliyet yapısı freemium'u sürdürülebilir kılar: ücretsiz kullanıcı neredeyse hiç maliyet üretmez.
