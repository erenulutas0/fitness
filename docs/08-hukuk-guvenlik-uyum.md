# 08 — Hukuk, Güvenlik, Uyum

> Bu doküman hukuki görüş değildir. Şirket kurma, KVKK metinleri ve lisans yorumları için yayına çıkmadan önce bir avukatla 1-2 saat görüş. Buradaki amaç doğru soruları önceden hazırlamak.

## 1. Kişisel veri: KVKK (TR) ve GDPR (EN pazar)

**Ne işliyoruz?**
- Kamera görüntüsü: cihazda, bellekte, anlık; **kaydedilmez, iletilmez** (kullanıcı klip kaydını açmadıkça).
- İskelet noktaları (landmark): cihazda; buluta gitmez. Buluta giden: tekrar sayısı, skorlar, hata sayaçları, egzersiz/tarih.
- Profil: hedef, seviye, ekipman, dil; isteğe bağlı boy/kilo (varyant düzeltmesi için). Sağlık verisi (hastalık, sakatlık, ağrı) **tutulmaz**; "ağrı günlüğü" (v1.x) tasarlanırsa cihazda kalır ve ayrı açık rıza ister.

**Biyometrik veri sorusu:** Vücut iskeleti tek başına kimlik doğrulamaya yaramaz; ama "kişinin fiziksel özelliklerine ilişkin veri" tartışması var. En güvenli yol: iskelet verisini **hiç sunucuya göndermemek** (mimarimiz zaten bu) ve aydınlatma metninde açıkça yazmak. Bu, KVKK'da "özel nitelikli veri" tartışmasını pratikte kapatır.

**Yapılacaklar:**
- Aydınlatma metni + açık rıza akışı (kamera izni ekranında kısa, ayarlarda tam metin).
- Veri envanteri (VERBİS gerekip gerekmediğini avukata sor; çalışan sayısı/ciro eşikleri).
- Veri silme: uygulama içi tek buton; 30 gün içinde tüm sunucu verisi silinir; Apple "account deletion" zorunluluğu.
- Çocuk kullanıcı: 18 yaş altı için hesap açılmaz (mağaza yaş sınıflandırması 17+/"Mature" değil, ama kayıt akışında yaş beyanı).
- Analitik olaylarında görüntü/landmark yok; PostHog session replay yalnızca UI (kamera görünümü maskeli).
- GDPR için: DPA'lar (Supabase, RevenueCat, PostHog, Sentry) imzalı; AB kullanıcısı için veri konumu (Supabase EU bölgesi).

## 2. Sağlık ve sorumluluk

- Ürün **tıbbi cihaz değildir**; tanı, tedavi, rehabilitasyon vaadi yok. Dil: "form ipucu", "antrenman koçu". "Sakatlığı önler" gibi sonuç iddiaları yok.
- İlk açılışta ve seans başında kısa uyarı: "Ağrı hissedersen dur. Sağlık sorunun varsa önce doktoruna danış." Uzun sorumluluk reddi metni ayarlarda.
- Egzersiz önerileri "genel eğitim amaçlı" etiketiyle; kaynak kartları bunu destekler (bilgi verir, reçete yazmaz).
- Kullanım şartları: kullanıcının kendi sorumluluğunda egzersiz yaptığı, form tespitinin hata payı olduğu.
- ABD pazarında (EN) genel wellness/fitness uygulamaları FDA kapsamı dışında kalır; rehabilitasyon vaat etmedikçe böyle kalır. "Fizyoterapi" kelimesini pazarlamada kullanma.

## 3. Mağaza politikaları

| Konu | Apple | Google |
|---|---|---|
| Kamera izni | Amaç metni net (`NSCameraUsageDescription`): "Egzersiz formunu analiz etmek için; görüntü cihazdan çıkmaz" | Runtime izin + rasyonel ekran |
| Sağlık & fitness kategorisi | Sağlık verisi iddiaları için kanıt; HealthKit kullanılırsa ayrı kurallar (MVP'de yok) | Health apps policy: kapsam beyanı; hassas izinlerde form |
| Abonelik | Fiyat, süre, otomatik yenileme açıkça; trial şartları; "abonelik yönet" linki | Aynı; Play Billing |
| Hesap silme | Zorunlu | Zorunlu (veri silme beyanı) |
| Gizlilik etiketi / Data safety | "Kamera verisi cihazda işlenir, toplanmaz" doğru beyanı | Data safety formu: kamera verisi toplanmıyor |
| İçerik | Egzersiz videoları kendi çekimin veya lisanslı; kas modeli atıflı | Aynı |

## 4. Lisans yükümlülükleri (tablo)

| Bileşen | Lisans | Yükümlülük |
|---|---|---|
| MediaPipe (kod + modeller) | Apache 2.0 | Uygulama içi "Lisanslar" ekranında NOTICE/atıf; değişiklik varsa belirt |
| Flutter, paketler | BSD/MIT çoğunlukla | Lisans ekranı (flutter `LicenseRegistry` otomatik) |
| CameraX (AndroidX) | Apache 2.0 | Lisans ekranı |
| `just_audio`, `audio_session`, `flutter_tts` | MIT / BSD | Lisans ekranı; cihaz TTS'i yalnızca yedek (D5) |
| `share_plus`, `path_provider` | BSD-3 | Lisans ekranı |
| Cihaz TTS sesi (Android/iOS) | Platform bileşeni | Üretilen ses uygulama içinde kalır; klip olarak dağıtılmaz |
| Google Cloud TTS ile üretilen klipler | Hizmet şartları | Uygulama içi dağıtım standart kullanım; "gerçek insan sesi" iddiası yok |
| Z-Anatomy / BodyParts3D / AnatomyTOOL | CC BY-SA 4.0 / 2.1 JP | Atıf (metin + link); **türev 3D model dosyalarını aynı lisansla yayınla** (repo linki); NC lisanslı alt parçaları çıkar |
| Fontlar (Manrope, Inter) | SIL OFL | Atıf, yeniden satma yok |
| İkonlar (Lucide) | ISC | Atıf |
| Ses klipleri (Google/Azure TTS) | Sağlayıcı şartları | Uygulama içinde dağıtım serbest; "gerçek insan sesi" iddiası yok; şartları bir kez oku |
| Egzersiz kural verileri | Senin | İstersen CC BY-SA ile açarsın (03'teki fikir 12) |
| Makale özetleri | Telif | Özet ve alıntı kısa; tam metin yok; DOI linki; açık erişimli olanlar tercih |
| **Kullanmayacaklarımız** | Ultralytics YOLO (AGPL-3.0), Sapiens (CC BY-NC) | Kapalı ticari üründe kullanılmaz |

## 5. Marka ve şirket

- **İsim:** TR ve EN'de söylenebilir, `.com`/`.app` alınabilir, App Store'da aynı isimle rakip yok; Türk Patent + EUIPO/USPTO ön arama (ücretsiz veritabanları). "Forma" jenerik ve başka sektörlerde kullanılıyor → marka olarak muhtemelen zayıf, kod adı olarak kalsın; alternatif isim listesi hazırla (Türkçe kökenli, kısa, "koç/form/hareket" çağrışımı).
- **Şirket:** Mağaza hesapları bireysel de açılabilir; gelir başlayınca şahıs şirketi → limited (avukat/muhasebeci). Apple Developer Program ve Play Console kurumsal hesap için vergi numarası/DUNS (Apple) gerekir. Dijital hizmet vergisi/KDV muhasebeciye.
- **Sözleşmeler:** Beta katılımcı onam formu (video kaydı ve etiketleme için ayrı rıza), influencer anlaşması (basit), PT pilot anlaşması.

## 6. Güvenlik

- Supabase RLS: kullanıcı yalnızca kendi satırlarını görür; service key mobilde yok.
- API anahtarları: RevenueCat public key mobilde; diğer her şey Edge Function'da.
- Sertifika pinning MVP'de yok (karmaşıklık), TLS + RLS yeter.
- Bağımlılık taraması (GitHub Dependabot), gizli bilgi taraması.
- Olay planı: veri ihlali şüphesinde 72 saat bildirim kuralı (KVKK/GDPR) — zaten kişisel veri minimum.

## 7. Yayın öncesi uyum kontrol listesi

- [ ] Aydınlatma metni + gizlilik politikası (TR/EN) yayında ve uygulamada
- [ ] Kullanım şartları + sağlık sorumluluk reddi
- [ ] Hesap ve veri silme çalışıyor
- [ ] Lisanslar ekranı (MediaPipe, anatomi, fontlar, paketler)
- [ ] Türev 3D model repo'su yayınlandı (CC BY-SA) ve uygulamadan link
- [ ] Mağaza gizlilik beyanları mimariyle tutarlı ("kamera verisi toplanmaz")
- [ ] Beta onam formları imzalı, test videoları güvenli depoda
- [ ] Marka ön araması yapıldı
