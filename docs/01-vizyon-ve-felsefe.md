# 01 — Vizyon ve Felsefe

## Problem

Evde ya da salonda **tek başına** antrenman yapan başlangıç-orta seviye kişi:

- Hareketi YouTube/Instagram videosundan öğreniyor, kendini göremiyor, "doğru yapıyor muyum?" sorusuna cevap alamıyor.
- Form hatası → verimsiz set, ağrı, sakatlık korkusu → bırakma. (Fitness uygulamalarında D30 retention %3-4; bırakma nedenleri arasında "kişiselleştirme/ilerleme eksikliği" %12, "salona kıyasla maliyet" %18 — bkz. 02.)
- PT pahalı; Türkiye'de düzenli spor yapan oranı düşük ama gençlerde dijital uygulama kullanımı hızla artıyor (bkz. 02).
- Mevcut uygulamalar ya program veriyor ama bakmıyor (Fitbod, Freeletics), ya anatomi öğretiyor ama antrenman yaptırmıyor (Muscle & Motion), ya da kamerayla bakıyor ama İngilizce ve/veya B2B'ye kaymış (Kemtai).

## Hedef kullanıcı

**Birincil (ICP):** 18-34 yaş, Türkiye, evde vücut ağırlığı/dambılla çalışan, koçu olmayan, sosyal medyadan öğrenen, telefonu her zaman yanında. Motivasyon: "sağlıklı/enerjik olmak" ve "formu korumak" (Türkiye Hareket Haritası 2024 sıralamasıyla uyumlu). Ödeme kapasitesi sınırlı; aylık ₺ fiyatına duyarlı.

**İkincil:** Salona yeni başlayan, "boş bakan" kişi. Kamera açısı kalabalık salonda zor; bu segment için önce evde ısınma/mobilite ve ders modu.

**Üçüncül (v1 sonrası):** PT ve fizyoterapistler. B2B2C: PT program atar, müşterinin form skorlarını görür. Muscle & Motion'ın "trainer → client" modeli buradaki referans.

**Kime değil:** Barbell ile ağır kaldıranlar (kamera formu barbell'de güvenilir değil — bkz. 03), yoga/pilates (Zenia vb. var), sporcu performansı.

## Değer önerisi

> "Kamerayı aç, hareketi yap; tek başına değilsin: hatanı anında söyler, neyi çalıştırdığını gösterir, neden öyle dediğini kaynağıyla anlatır."

**Aha anı (ilk 90 saniye):** Onboarding bitmeden kamera açılır, kullanıcı 3 squat yapar, ikinci tekrarda "dizlerini dışa aç" der, üçüncü tekrarda "işte bu" der. Kullanıcı ilk oturumda bunu yaşamazsa ürün başarısız (aktivasyon metriği budur).

## Ürün ilkeleri

1. **Gizlilik varsayılan.** Görüntü cihazdan çıkmaz. Sadece iskelet noktaları/skorlar, o da isteğe bağlı olarak buluta.
2. **Dürüst kapsam.** Yalnızca güvenilir tespit edebildiğimiz hareket ve hatalar üründe. "Her hareketi düzeltir" iddiası yok; barbell yok.
3. **Kaynak göster.** Program/set/tekrar önerilerinin yanında kaynak kartı. Halüsinasyon riskine karşı kaynak elle küratör edilir.
4. **Az ama doğru.** 5 egzersiz mükemmel > 50 egzersiz vasat. Egzersiz eklemek bir "kural seti" + "test videoları seti" işidir.
5. **Ses önce, ekran sonra.** Antrenman sırasında ekrana bakılmaz; geri bildirim önce sesle, sonra haptik, en son görselle.
6. **Türkçe birinci sınıf.** Türkçe ses, Türkçe komut, Türkçe kaynak özeti. İngilizce day-1'de hazır ama ikinci sırada.
7. **Tıbbi iddia yok.** Ağrı/sakatlık konusunda yönlendirme: "bugün bu hareketi atla, ağrı sürerse uzmana git". Tanı yok.

## MVP kapsamı (v0.1 — "Kamera Koç")

**5 egzersiz** (kamera açısıyla birlikte):

| Egzersiz | Kamera | Tespit edilen hatalar (ilk sürüm) | Sayılan şey |
|---|---|---|---|
| Bodyweight squat | Ön veya yan | Diz içe çökme (valgus), yetersiz derinlik, gövde öne aşırı eğilme, topuk kalkması (yan) | Tekrar, tempo |
| Push-up | Yan | Bel çökmesi/kalça yükselmesi, yetersiz derinlik, dirsek aşırı açılması (ön) | Tekrar, tempo |
| Reverse lunge | Ön veya yan | Ön diz içe kayma, gövde eğilmesi, adım kısa | Tekrar (bacak başına) |
| Plank | Yan | Kalça çökmesi/yükselmesi, baş sarkması | Süre |
| Glute bridge | Yan | Yetersiz kalça ekstansiyonu, bel hiperekstansiyonu | Tekrar, üst pozisyon bekleme |

Neden bunlar: hepsi vücut ağırlığı, tek kişi, ekipman yok, kamera formu bu sınıfta güvenilir; birlikte tam vücut başlangıç programı oluşturuyorlar.

**Bugün gerçekten açık olanlar** (9 Eylül 2026 — tablo hedefi gösterir, bu paragraf durumu; ilke 2 "dürüst
kapsam" gereği ikisini ayrı tutuyoruz): squat'ta valgus, yetersiz derinlik (ön ve yan) ve gövde eğilmesi;
push-up'ta bel çökmesi, kalça yükselmesi ve yetersiz derinlik; plank'ta kalça çökmesi/yükselmesi ve baş
sarkması; glute bridge'de yetersiz kalça ekstansiyonu.
Ölçüp **kapattıklarımız**: squat'ta topuk kalkması — özellik topuk kalkmasından değil squat'a inmekten
büyüyor, dünya koordinatlarında da aynı (D17); glute bridge'de bel hiperekstansiyonu — 2D'de ayırt edilemiyor,
kural hiç yazılmadı. **Henüz yazılmadı**: push-up'ta dirsek aşırı açılması (ön açı gerçekçi mi, keşifte
sorulacak) ve reverse lunge kuralları (sentetik iskelet yok, gerçek kayıt şart).
Kapatılan kural silinmiyor: `content/exercises/*.json` içinde `enabled: false` ve gerekçesiyle duruyor,
ölçüm değişirse geri açılıyor.

**MVP'de olan:** Onboarding (≤60 sn) → kamera yerleşim asistanı → antrenman HUD'u (sayaç + sesli cue + haptik) → set özeti (form skoru, hata listesi) → basit 3 gün/hafta program → ilerleme.

**MVP'de olmayan:** 3D anatomi (v0.2), kaynaklı öneri motoru (v0.3), beslenme, sosyal, wearable, barbell, yoga, PT modu, sohbet asistanı.

## Sürüm merdiveni

- **v0.1 Kamera Koç** — 5 egzersiz, sesli düzeltme, form skoru. Tek başına gösterilebilir.
- **v0.2 Anatomi** — Her egzersiz ve set sonrası "bu tekrar neyi çalıştırdı" 3D kas haritası; haftalık kas kapsama görünümü.
- **v0.3 Kanıt** — Program motoru (hedef, seviye, gün sayısı, ekipman), her öneride kaynak kartı.
- **v1.0 Lansman** — TR soft launch → EN. Paywall, RevenueCat, analitik, onboarding polish.
- **v1.x** — Dambıl hareketleri (RDL, omuz pres, row), PT modu, sohbet koç (LLM), asimetri raporu.

## Antropometri konusunda net duruş

"Boy/kilo oranına göre ideal hareket" bir ürün vaadi olmayacak. Literatürde bunu destekleyen sağlam bir zemin yok; olan şey uzuv uzunluğuna (femur/gövde oranı) göre varyant tercihi düzeyinde koçluk sezgileri. Ürün dili: "senin oranlarında squat'ta biraz daha geniş duruş genelde daha rahat olur — deneyip form skoruna bak". Yani varyant önerisi + kullanıcının kendi verisi; iddia değil hipotez.

## Başarı tanımı (12 hafta)

- Aktivasyon: ilk oturumda geri bildirimli ≥ 3 tekrar tamamlayan kullanıcı ≥ %60.
- D7 ≥ %25 (beta), D30 ≥ %8 (soft launch).
- Trial→paid ≥ %25; aylık churn ≤ %12.
- Kural doğruluğu: 30 test videosunda precision ≥ %80.
- Nitel: 20 beta kullanıcıdan 8'i "kalksa çok üzülürüm".

## Varsayımlar ve riskler

| Varsayım | Nasıl test edilir | Yanlışsa plan B |
|---|---|---|
| Kullanıcı telefonu 2-3 m uzağa koyup antrenman yapmaya razı | Keşif görüşmeleri + beta oturum kayıtları (kurulum tamamlama oranı) | Ses-öncelikli "kamerasız mod" (tempo/sayım) + kısa "form check" modu (10 tekrar) |
| Form düzeltme tek başına ödeme gerekçesi | Paywall testi (v1.0), "kalksa üzülürüm" anketi | Program + anatomi paketiyle bundle, PT B2B2C |
| Tek kamera ile 5 egzersizde ≥ %80 precision | Kayıtlı video eval harness (05) | Hata setini daralt, açı kısıtla, "emin değilim" durumunda sus |
| Türkçe yerelleştirme gerçek bir tercih nedeni | TR mağaza yorumları, keşif görüşmeleri | EN'e erken geçiş |
| Ev ışığı/kıyafet/ortam kabul edilebilir doğruluk verir | Beta cihaz-ortam matrisi | Kurulum asistanında ışık uyarısı, düşük güven → geri bildirimi kıs |

## Yapmayacaklarımız (bilinçli)

- Barbell form analizi (bar oklüzyonu + yan açı problemi; rakiplerde de başarısız).
- Görüntüyü buluta gönderip orada işlemek.
- Anatomi atlası olmak (Complete Anatomy/Muscle & Motion ile yarışmak).
- "Yapay zeka koç" sohbet ekranını MVP'ye koymak.
- Tıbbi tanı ya da rehabilitasyon vaadi.
