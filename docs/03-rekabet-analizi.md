# 03 — Rekabet Analizi

## Kimlerle rekabet ediyoruz: 4 kategori

Kullanıcının parasını ve zamanını 4 farklı ürün tipi istiyor. Doğrudan rakip A kategorisi; B, C, D dolaylı.

### A) Kamera ile form koçları (doğrudan rakip)

| Ürün | Ne yapıyor | Zayıf noktası / ders |
|---|---|---|
| **Kemtai** | Tarayıcı/telefon kamerasıyla gerçek zamanlı düzeltme; "diz içe kayıyor", "gövde açısı X°" gibi spesifik uyarılar; en geniş egzersiz kütüphanesi | **B2B fizyoterapiye pivot etti** (sağlık sistemleri, klinikler). Tüketici ürünü olarak boşluk bıraktı. Ders: spesifik, ölçülü uyarı standardı bu |
| **FitForm** | Kaldırışını çekip sonra (async) analiz | Gerçek zamanlı değil; barbell odaklı. Ders: async video inceleme ayrı bir mod olabilir (v1.x) |
| **Onyx** | Telefon kamerasıyla vücut ağırlığı/HIIT sayım + form | Uzun süredir ivmesiz; İngilizce |
| **Vi Trainer, BurnAI, Happy Fit AI** | Kamera + program, çeşitli olgunlukta | Küçük ekipler, doğruluk şikayetleri; hepsi İngilizce |
| **AiKYNETIX** | Barbell tekrar analizi (yan açı) | Niş, ileri seviye; bizim segment değil |
| **SensAI** | Foto/klip gönderip sohbet eden "hafızalı koç" | Gerçek zamanlı değil; "koç" modeli. Ders: iki farklı ürün tipi (canlı ayna vs. hafızalı koç) — biz canlı ayna |
| **Asensei** | Beyaz etiket hareket analizi SDK'sı | B2B |
| **Zenia** | Yoga için kamera | Farklı dikey |

**Kritik bulgu (2026 incelemeleri):** Tüketici kamera uygulamaları vücut ağırlığı squat, push-up, lunge, plank, hafif dambıl, mobilite ve yogada iyi çalışıyor; **barbell kaldırışlarda neredeyse evrensel olarak başarısız** (bar noktaları örtüyor, yan açı ağırlık altında bozuluyor); snatch/clean gibi dinamik hareketler hiçbirinde yok. En kötü yorumlar, kapsamını abartan uygulamalarda. → MVP kapsamımız (5 vücut ağırlığı hareketi) tam doğru yerde; "dürüst kapsam" ilkesi rakiplerin hatasından çıkıyor.

### B) Anatomi / eğitim uygulamaları (2. katmanımızın rakibi)

| Ürün | Ne yapıyor | Not |
|---|---|---|
| **Muscle & Motion** | 1.200+ egzersizin 3D anatomik analizi, yaygın hatalar, program oluşturucu, PT→müşteri akışı | Abonelik; kullanıcı yorumlarında fiyat "yüksek" bulunuyor. Antrenman yaptırmıyor, öğretiyor. 2026'da yeni "Workout for Trainers" uygulaması geliyor |
| **Complete Anatomy (Elsevier)** | Tıp eğitimi düzeyinde atlas, hareket simülasyonu | Pahalı, eğitim odaklı |
| **Visible Body, Kenhub** | Atlas + quiz | Eğitim |

Ders: anatomi katmanı **ürün değil özellik**. Biz atlas yapmıyoruz; "bu tekrar neyi çalıştırdı, bu hafta neyi ihmal ettin" sorusuna cevap veren dar bir görselleştirme yapıyoruz.

### C) Program / takip uygulamaları (kullanıcının zamanı için rakip)

| Ürün | Güçlü | Zayıf (bizim için fırsat) |
|---|---|---|
| **Fitbod** | Adaptif program, kas yorgunluğu haritası | Bakmıyor; kas haritası "tahmin", ölçüm değil |
| **Hevy, Strong, JEFIT** | Kayıt/loglama, sosyal | Form yok; ağır kullanıcı için |
| **Freeletics** | AI koç, HIIT | Form yok; İngilizce ağırlıklı |
| **Fitify** | 20M+ kullanıcı, evde ekipmanlı/ekipmansız, Türkçe arayüz | Form yok; TR'de görünürlüğü olan güçlü rakip |
| **GymStreak** | AI program + yemek fotoğrafı | Form yok |
| **Nike Training Club** | Marka, ücretsiz | Form yok |

Ders: bu kategori "AI program" sözünü tüketti. Farkımız programı yazmak değil, **program yapılırken bakmak**.

### D) Donanım (kategori dersi)

Peloton Guide (satış durdu, Temmuz 2025), Tempo Move, Mirror/Tonal. Ders: kullanıcı yeni cihaz almıyor; telefon yeter. Peloton'un "Body Activity — bu hafta hangi kas grupları" görünümü iyi bir fikirdi, biz onu ölçümle yapıyoruz.

### Türkiye'de yerel rakip

Kamera-tabanlı form koçu yok. TR mağazada görünen ürünlerin hepsi yabancı (Fitify, Freeletics, GymStreak, Fitbod, "Fitness Vücut Geliştirme"); yorumlarda Türkçe talebi ve "hemen ücretli üyelik dayattı" şikayetleri var. MAC+ gibi salon uygulamaları üyeye özel.

## Artılarımız (+)

1. **Gerçekten bakan tek Türkçe ürün.** Yerelleştirme boşluğu araştırmayla teyitli (bkz. 02).
2. **Kombinasyon:** canlı form düzeltme + ölçüme dayalı kas haritası + kaynaklı öneri. Rakiplerin hiçbiri üçünü birleştirmiyor.
3. **Gizlilik-öncelikli mimari** (video cihazdan çıkmaz) — hem pazarlama mesajı hem maliyet avantajı.
4. **Dürüst kapsam** — rakiplerin en büyük şikayet kaynağını baştan kapatıyoruz.
5. **Kurucu uyumu:** poz tahmini ve nesne takibi deneyimi, Flutter, AI ile hızlı üretim.
6. **Sıfır marjinal maliyet:** on-device inference + önceden üretilmiş ses → kullanıcı başına bulut maliyeti ~0.

## Eksilerimiz (−) — dürüst liste

1. Tek kişi; içerik (egzersiz kuralları, test videoları, kaynak kartları) emek yoğun.
2. Marka ve güven yok; sağlık/egzersiz alanında güven pahalı.
3. Klonlanabilir: açık model + açık anatomi + AI kodlama → hendek teknik değil, veri ve dağıtım.
4. Kullanıcı davranışı riski: telefonu 2-3 m uzağa koymak sürtünme; kalabalık salonda kamera açısı zor.
5. Kategori retention'ı yapısal olarak düşük.

## Söylediklerine ek farklılaşma fikirleri

Senin önerdiklerin: kamera form kontrolü + TTS asistan, kaynaklı öneri, anatomi. Buna ek olarak, hepsi aynı veri hattından beslenen fikirler:

| # | Fikir | Neden farklılaştırır | Maliyet |
|---|---|---|---|
| 1 | **Tekrar başına form skoru + haftalık form trendi** | "İlerleme göremiyorum" bırakma nedenine doğrudan cevap; rakipler set sayısı gösteriyor, biz kalite | Düşük (zaten hesaplanıyor) |
| 2 | **Ölçüme dayalı kas haritası** (set sonrası) | Fitbod tahmin ediyor, biz gerçekleşen hareket açıklığından çıkarıyoruz ("bu set kalçan yeterince inmediği için quad ağırlıklıydı") | Orta |
| 3 | **"Neden böyle dedim" kartı** | Her uyarı ve öneri için 2 cümle + kaynak; güven | Düşük (içerik) |
| 4 | **Asimetri raporu** | Sol/sağ lunge, push-up'ta omuz seviyesi farkı; kimse tüketiciye vermiyor | Orta |
| 5 | **Tempo/TUT koçluğu** | "2 saniyede in" gibi sesli tempo, gerçek ölçülen tempo | Düşük |
| 6 | **Kamerasız mod** | Sesli tempo + sayım (ivmeölçer), kamera kurulamadığında akış kopmasın | Düşük |
| 7 | **Türkçe ses kişiliği** | Robot değil, kısa, esprili, yerel bir koç sesi (klipler önceden üretilir) | Düşük |
| 8 | **PT modu (B2B2C)** | PT programı atar, müşterinin form skorlarını görür; TR'de PT'ler WhatsApp'la çalışıyor, araç yok | Orta-Yüksek (v1.x) |
| 9 | **Kaynak okuma "Haftanın bulgusu"** | Uygulama içinde her hafta 1 makale özeti; içerik motoruyla aynı malzeme | Düşük |
| 10 | **Salon modu** | Telefon rafa/çantaya yaslanır, 10 tekrarlık "hızlı form check"; salon QR ortaklıkları | Orta |
| 11 | **Ağrı günlüğü (tıbbi olmayan)** | "Bugün dizim rahatsız" → o gün varyant öner, ağrı sürerse uzman öner; asla tanı | Düşük, hukuki dikkat |
| 12 | **Kural setini topluluğa açmak** | Egzersiz kural DSL'i açık kaynak (kod değil, kural verisi) → PT'ler katkı yapar, güven + içerik | Düşük, stratejik |

Öncelik: 1, 3, 5, 7 MVP'ye bedava girer; 2 ve 4 v0.2; 6 ve 10 v1.0; 8, 11, 12 v1.x.

### Ek farklılaşma fikirleri — 2. tur (Claude Code, 8 Eylül 2026)

Hepsi mevcut landmark hattından beslenir; yeni sensör/model gerektirmez. Ortak tema: rakipler "ne kadar" sayıyor, biz "ne kadar iyi" ölçüyoruz ve telefon uzaktayken **hiç dokunmadan** kullanılıyoruz.

| # | Fikir | Neden farklılaştırır | Maliyet | Sürüm |
|---|---|---|---|---|
| 13 | **El-serbest jest kontrolü**: iki bilek baş üstünde ~1,5 sn → başlat / sonraki set; T-pozu (kollar yana) 1,5 sn → seti bitir; tek el yukarı → duraklat | 01'deki 1 numaralı risk "telefonu 2-3 m uzağa koymak" — dokunma ihtiyacını sıfırlar; ses tanıma gürültüde çöker, jest çökmez; demo videosunda "büyü" etkisi | Düşük (landmark zaten var; küçük bir jest FSM'i) | **MVP** |
| 14 | **Poz-tetikli otomatik set başlangıcı + dinlenme sayacı**: dinlenmeden sonra başlangıç pozisyonuna dönünce geri sayım kendiliğinden başlar | "Sonraki set" butonuna dokunmak için telefona gitme sürtünmesi kalkar; akış kopmaz | Düşük | **MVP** |
| 15 | **Kişisel taban çizgisi (kalibrasyon)**: ilk seansta kullanıcının kendi hareket açıklığı ölçülür; eşikler evrensel "90°" değil, "senin en temiz derinliğinin %90'ı" | D10 ile uyumlu (ideal hareket iddiası yok); yanlış uyarıyı azaltır; "ilerleme" kişiye göre tanımlanır (mobilite kısıtı olan kullanıcı cezalandırılmaz) | Orta (eşik = f(baseline) desteği DSL'de) | v0.2 |
| 16 | **Hayalet iskelet tekrarı**: set sonrası kullanıcının iskelet animasyonu, referans iskeletin yanında (video değil) — "senin tekrarın vs temiz tekrar"; paylaşılabilir animasyonlu kart | Gizlilik korunarak viral format; "neden 72 aldım"ı 3 saniyede gösterir | Orta (landmark dizisi zaten kaydediliyor; CustomPaint animasyon) | v0.2 |
| 17 | **Hız kaybına dayalı yorgunluk / RIR tahmini**: tekrar hızı set içinde %20+ düşünce "2 tekrar kaldı" / "seti bitir" — velocity-based training literatürüne kaynak kartıyla bağlı | Kamerayla vücut ağırlığında bunu kimse yapmıyor; 3. katman (kanıt) ile doğal bağ; "failure'a gitmeden dur" mesajı 11'deki meta-analizlerle uyumlu | Düşük-Orta (landmark hızı zaten FeatureExtractor'da) | v0.3 |
| 18 | **Silüet modu**: kamera önizlemesi yerine sadece iskelet/silüet | Kendini görmek istemeyen kullanıcı; içerik üreticiler odayı göstermeden kayıt alır (UGC'yi büyütür) | Düşük | v1.0 |
| 19 | **Temiz tekrar serisi (quality streak)**: gün serisi yerine "üst üste 85+ skorlu tekrar/set" | Streak mekaniğini kaliteye bağlar; sadece "açtım kapadım" streak'i sahte motivasyon | Düşük | v0.2 |
| 20 | **Koç ses paketleri** (TR kişilikler: sakin / enerjik / "hoca"), önceden üretilmiş | Engagement + küçük ek gelir; içerik motoru ile aynı üretim hattı | Düşük (tts_gen parametre) | v1.x |
| 21 | **Web demo = büyüme motoru**: tarayıcıda 10 squat challenge, skor kartı paylaşımı, indirmesiz "aha" | 07'de var; ek: paylaşım linki `?ref=` ile beta davet zinciri | Düşük-Orta (forma_rules dart2js + MediaPipe Web) | v1.0 |

Öneri: 13 ve 14 MVP'ye girsin (D15 — kurucu onayı bekliyor); 15, 16, 19 v0.2; 17 v0.3; 18, 21 v1.0; 20 v1.x.

## Konumlandırma cümlesi

> Evde tek başına antrenman yapan ve "doğru yapıyor muyum" diye endişelenenler için FORMA, telefon kamerasıyla her tekrarı izleyip anında sesle düzelten bir antrenman koçudur. Program yazan uygulamaların aksine FORMA gerçekten bakar; anatomi uygulamalarının aksine öğretmekle kalmaz, seninle birlikte çalışır. Görüntün telefonundan hiç çıkmaz.

## İzleme listesi (çeyrekte bir bak)

Kemtai tüketiciye döner mi; Muscle & Motion "Workout for Trainers" (2026) form kontrolü ekler mi; Apple/Google fitness uygulamalarına kamera form koçluğu ekler mi (Apple'ın Vision 3D body pose API'si var, Fitness+ için mantıklı adım); Fitify kamera ekler mi.
