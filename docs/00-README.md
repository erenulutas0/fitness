# FORMA — Proje Doküman Seti (v0.1, 8 Eylül 2026)

> Geçici kod adı: **FORMA** ("form" + "formda olmak"). Marka adı ayrıca seçilecek (bkz. 07 ve 08).

## Tek cümle

Telefon kamerasıyla hareketini izleyip **anında sesle düzelten**, her setin sonunda **hangi kası çalıştırdığını 3D'de gösteren** ve verdiği her öneride **kaynağını gösteren**, Türkçe birinci sınıf bir kuvvet antrenmanı koçu.

## Felsefe: üç katman, tek sıra

| Katman | Rolü | Öncelik |
|---|---|---|
| 1. Kamera koç (form kontrolü + sesli geri bildirim) | Asıl ürün, asıl hendek | Önce bu |
| 2. Kas-iskelet 3D görselleştirme | Anlama ve vitrin; "bu tekrar neyi çalıştırdı" | Sonra |
| 3. Kaynak gösteren öneri/program motoru | Güven katmanı; "neden bu set/tekrar" | En son |

Sıra bilinçli: 1. katman tek başına gösterilebilir ve satılabilir bir ürün. 2 ve 3 tek başına değil (o alanlar dolu — bkz. 03).

## Doküman haritası

| Dosya | Ne için okunur |
|---|---|
| `01-vizyon-ve-felsefe.md` | Kime, ne, neden; MVP kapsamı; yapmayacaklarımız; başarı tanımı |
| `02-market-arastirmasi.md` | Pazar büyüklüğü (global + Türkiye), retention/abonelik benchmark'ları, zamanlama |
| `03-rekabet-analizi.md` | 4 rakip kategorisi, artılarımız/eksilerimiz, ek farklılaşma fikirleri |
| `04-goruntu-isleme-ve-lisans.md` | Poz tahmini seçenekleri ve lisansları, 3D anatomi varlıkları, TTS, maliyetler |
| `05-teknik-stack-ve-mimari.md` | Stack kararı, mimari, tasarım kalıpları, klasör yapısı, performans bütçeleri, test |
| `06-ui-ux-tasarim-plani.md` | Akışlar, ekranlar, geri bildirim tasarımı, design system, kullanılabilirlik testi |
| `07-pazarlama-ve-buyume.md` | Konumlandırma, kanallar, içerik motoru, ASO, fiyatlama, metrikler |
| `08-hukuk-guvenlik-uyum.md` | KVKK/GDPR, sağlık sorumluluk reddi, mağaza politikaları, lisans yükümlülükleri |
| `09-yol-haritasi.md` | 12 haftalık plan, doğrulama kapıları, sonrası |
| `10-ilk-promptlar.md` | CLAUDE.md + Claude Code için sıralı ilk promptlar |
| `11-kaynaklar.md` | Araştırmada kullanılan tüm kaynaklar, aday makale listesi, araç linkleri |

## Kritik kararlar (Decision Log)

| # | Karar | Gerekçe | Nerede |
|---|---|---|---|
| D1 | Mobil: **Flutter** + ince native "pose engine" plugin'i (Kotlin/Swift) | Mevcut deneyim Flutter; poz tahmini native'de koşmak zorunda | 05 |
| D2 | Poz motoru: **MediaPipe Pose Landmarker** (Apache 2.0). **YOLO-pose kullanılmayacak** (AGPL-3.0) | Lisans temiz, 33 nokta + world landmarks, Android/iOS/Web | 04 |
| D3 | **Video cihazdan çıkmaz.** Bulutta görüntü işleme yok | Gizlilik, maliyet (0 TL inference), gecikme | 04, 08 |
| D4 | MVP: **5 egzersiz**, vücut ağırlığı + hafif dambıl | Kamera formu bu hareketlerde çalışıyor; barbell'de evrensel olarak başarısız | 01, 03 |
| D5 | Sesli geri bildirim = **önceden üretilmiş ses klipleri** (Google/Azure neural TTS ile bir kez) | Gecikme < 400 ms şartı; çalışma zamanı TTS maliyeti sıfır | 04 |
| D6 | 3D anatomi: Z-Anatomy/BodyParts3D türevi (CC BY-SA), v1'de kendi modeline geçiş değerlendirilir | Sıfır maliyetle başla, share-alike yükümlülüğünü yönet | 04, 08 |
| D7 | Gelir: **Freemium + abonelik** (RevenueCat), TR ₺ + global $ fiyat | Kategori normu; annual plan retention gücü | 07 |
| D8 | Önce **Türkiye/Türkçe** soft launch, İngilizce day-1'de hazır | Yerelleştirme boşluğu gerçek; global pazar ikinci adım | 02, 07 |
| D9 | Egzersiz kuralları **veri olarak** (JSON kural DSL'i), kodda değil | Uygulama yayını olmadan içerik güncelleme; test edilebilirlik | 05 |
| D10 | Antropometri (boy/kilo) sadece **varyant düzeltmesi**; "ideal hareket" iddiası yok | Literatür bunu desteklemiyor | 01, 03 |
| D11 | Monorepo: **Dart pub workspace** (melos yok) | Dart 3.6+ yerleşik, ek global araç yok, tek lockfile; `dart pub get` kökte yeter | CLAUDE.md, 05 |
| D12 | `forma_pose` **tek paket** (federated değil): platform interface + Android + iOS + Fake aynı pakette | Tek geliştirici; 4 paket yerine 1; ileride bölünebilir | 05 |
| D13 | Tekrar sayımı **gevşek eşik** ile, kalite **kurallarla**: kısa squat da tekrar sayılır, `shallow_depth` kuralı uyarır | Sayaç eşiği ile derinlik kuralı çelişmesin; deneme sayılır, kalite puanlanır (aksi halde "kısa" tekrarlar hiç görünmez) | 05 |
| D14 | Kural DSL fazları nötr: `rest / toPeak / peak / toRest` (+ squat takma adları `top / descending / bottom / ascending`) | Glute bridge gibi "yukarı" hareketlerde "descending" kafa karıştırır; motor tek, isimler egzersizden bağımsız | 05 |
| D15 | MVP'ye **el-serbest jest kontrolü** (iki bilek baş üstünde ~1,5 sn = başlat / sonraki set; T-pozu = bitir) ve **poz-tetikli otomatik set başlangıcı** eklendi — *Claude önerisi 8 Eyl 2026, kurucu onayı bekliyor* | "Telefon 2-3 m uzakta" sürtünmesi 01'deki 1 numaralı risk; landmark'lar zaten var, ek maliyet yok | 03 (fikir 13-14) |
| D16 | Android native bağımlılıkları **16 KB sayfa uyumlu** sürümlerde sabit: MediaPipe tasks-vision **1.0.0**, CameraX **1.6.2** (sürüm düşürülmez) | Google Play, Android 15+ hedefleyen uygulamalarda 16 KB desteğini zorunlu kılıyor; eski sürümler (0.10.21 / 1.4.2) Galaxy S23 + Android 16'da uyumsuzluk uyarısı verdi | 05, TODO |
| D17 | Squat **topuk kalkması kuralı kapatıldı** (`enabled: false`, silinmedi); kurallar içerikten açılıp kapatılabilir | İki gerçek kayıtta (topuklar yerde) her tekrarda yanlış alarm verdi; ölçüm squat derinliğiyle birlikte artıyor, aynı örüntü 3B dünya koordinatlarında da var (model derin squat'ta ayak yönelimini kestiremiyor). Dürüst kapsam ilkesi: güvenilir ölçemediğimiz hata üründe olmaz | 01, content/exercises/bw_squat.json |
| D18 | Kritik eklem (omuz, kalça, diz, ayak bileği) **görüntü dışına çıkarsa oturum donar**; kadraj uyarısı ayrı cue ("Biraz geri git") | MediaPipe kadraj dışındaki eklemi tahmin edip yüksek `visibility` veriyor; 26 kayıtta ölçüldü: imkansız diz açısı (3-12°) üreten her klipte eklemler normalize 0-1 aralığının dışındaydı (%59-100 frame), doğru kadrajlı telefon kayıtlarında hiç değildi | 05, exercise_session.dart |

## Doğrulama kapıları (bunlar geçilmeden sonraki faza geçilmez)

1. **Kapı 1 — Keşif (Hafta 0):** 5 PT/fizyoterapist + 10 hedef kullanıcı görüşmesi. Çıkış kriteri: en az 6/10 kullanıcı "formumdan emin değilim" problemini kendiliğinden dile getiriyor ve 3/5 PT "müşterime önerirdim" diyor.
2. **Kapı 2 — Teknik (Hafta 4):** 30 kayıtlı videoda hata tespiti precision ≥ %80, recall ≥ %70; uçtan uca geri bildirim gecikmesi ≤ 400 ms; 10 dk seansta thermal throttling yok.
3. **Kapı 3 — Beta (Hafta 6):** 20 beta kullanıcıda D7 ≥ %25; "bu ürün kalksa çok üzülürüm" ≥ %40.
4. **Kapı 4 — Soft launch (Hafta 12):** D30 ≥ %8 (kategori benchmark'ının ~2 katı), trial→paid ≥ %25.

## Nasıl kullanılır

1. Repo: `github.com/erenulutas0/fitness` — bu set `docs/` altında, `CLAUDE.md` kökte (8 Eylül 2026'da kuruldu).
2. Canlı yapılacaklar listesi kökte `TODO.md`; her Claude Code oturumu oradan başlar ve orayı günceller.
3. Promptlar `10-ilk-promptlar.md`'de; her prompt bir commit/PR. Karar değişirse bu dosyadaki Decision Log'a satır ekle.
4. Her fazın sonunda ilgili dokümanı güncelle (dokümanlar canlı).

## Bu setin sınırları

- Rakamlar 8 Eylül 2026 itibarıyla web araştırmasıdır; pazar raporları arasında 2 kata varan fark var, aralık olarak verildi.
- Lisans ve KVKK bölümleri hukuki görüş değildir; şirket kurmadan ve yayına çıkmadan önce bir avukata 1 saat ayır.
- Egzersiz bilimi bölümündeki kaynaklar **aday** listedir; her biri okunup doğrulanmadan uygulamaya girmez.
