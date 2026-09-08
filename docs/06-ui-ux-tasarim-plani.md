# 06 — UI/UX Tasarım Planı

## 1. Tasarım ilkeleri

1. **Kameraya en kısa yol.** İlk oturumda kullanıcı 90 saniye içinde geri bildirim almış olmalı. Onboarding ≤ 4 soru, hesap açma sonraya.
2. **Ekrana bakmadan kullanılır.** Antrenman sırasında telefon 2-3 m uzakta: bilgi sesle ve büyük görsellerle; küçük yazı yok, dokunma gerektiren şey yok (bitir/atla için büyük buton + sesli komut sonra).
3. **Tek bir şey söyle.** Aynı anda tek cue, tek sayı, tek renk değişimi.
4. **Güven ver, korkutma.** Hata dili düzeltici, yargılayıcı değil ("dizlerini dışa aç" ✓, "yanlış yapıyorsun" ✗). Her uyarının "neden"i bir dokunuş uzakta.
5. **Gizlilik görünür olsun.** Kamera ekranında kalıcı küçük rozet: "Görüntü cihazından çıkmıyor".
6. **Karanlık mod varsayılan.** Ev/salon ortamı, telefon uzaktayken yüksek kontrast.
7. **İlerleme somut.** Form skoru trendi ve kas kapsama haritası; "toplam set" gibi boş sayılar değil.

## 2. Personalar

- **Deniz (24, İstanbul, ofis çalışanı):** Evde haftada 3 gün 20 dk. YouTube'dan öğrendi, squat'ta dizleri içe kaçıyor ama bilmiyor. Telefonu masaya yaslar. Ödeme: aylık ₺ küçük; yıllık indirim ikna eder.
- **Mert (31, Ankara, salona yeni başlayan):** Boş bakıyor, yanlış yapmaktan utanıyor. Salonda kamera zor, evde ısınma ve teknik çalışması yapar. Form skoru arkadaşlarıyla paylaşır.
- **Ayşe (38, PT, İzmir) — v1.x:** 15 online müşterisi var, WhatsApp'la video alıyor. Müşterinin form skorunu görmek ve program atamak ister.

## 3. Bilgi mimarisi

Alt sekmeler: **Bugün** · **Antrenman** · **Vücut** (anatomi, v0.2) · **İlerleme** · **Profil**

- Bugün: programın bugünkü seansı, "Hızlı form check" (tek egzersiz, 10 tekrar), haftanın bulgusu.
- Antrenman: egzersiz listesi (kamera açısı rozetleri), program seçimi.
- Vücut: 3D model, bu hafta çalışan/ihmal edilen kaslar, egzersiz → kas.
- İlerleme: form skoru trendi, asimetri (v0.2), seans geçmişi.
- Profil: hedef/seviye/ekipman, ses/dil, abonelik, gizlilik, lisanslar.

## 4. Ana akışlar

### 4.1 Onboarding (≤ 60 sn)
1. Hoş geldin (1 ekran, 1 cümle, "Kamerayı dene" ana buton).
2. 3 soru, tek dokunuşluk: hedef (kas / form / sağlık), seviye (yeni / ara sıra / düzenli), ekipman (yok / dambıl).
3. Kamera izni — nedeniyle birlikte ("Hareketini görmek için; görüntü telefondan çıkmaz").
4. **Demo seansı:** 5 squat. Burası aha anı. Bittikten sonra form skoru + 1 düzeltme kartı.
5. Hesap açma ve bildirim izni **sonra**, ilk seans bitince.

### 4.2 Kamera kurulum asistanı (her seansın başı, 20-30 sn hedef)
- Egzersizin açısı gösterilir (ön/yan piktogram).
- Canlı çerçeve: vücut tamamen içerdeyse yeşil, değilse "geri git / telefonu yükselt" oku; landmark `visibility` ile otomatik.
- Işık kontrolü: düşük parlaklık → "biraz daha ışık lazım".
- Hazır → 5 sn geri sayım (sesli), kullanıcı pozisyona geçer.
- Hedef metrik: `camera_setup_completed` ≥ %85; ortalama süre ≤ 30 sn.

### 4.3 Antrenman HUD (ekran 2-3 m uzakta okunacak şekilde)

```
┌───────────────────────────────┐
│ ● Görüntü cihazda   Squat  1/3│  ← küçük, üst şerit
│                               │
│         [kamera görüntüsü]    │
│      (iskelet overlay: ince,  │
│       hata eklemi kısa süre   │
│       turuncu yanar)          │
│                               │
│           ┌───────┐           │
│           │  7    │  ← tekrar sayacı, ekranın %25'i, tabular rakam
│           └───────┘           │
│   form ◐ 82        ⏱ 2s↓ 1s↑  │  ← form skoru halkası, tempo
│  "Dizlerini dışa aç"          │  ← son cue, 3 sn görünür
│ [ Bitir ]           [ Atla ]  │  ← büyük, alt kenar
└───────────────────────────────┘
```

- Yatay/dikey: her ikisi; yatayda sayaç sağda.
- Overlay opsiyonel (ayarlarda kapatılabilir; bazı kullanıcı iskeletten rahatsız olur).
- Düşük güven durumu: sayaç gri, "seni net göremiyorum" tek seferlik cue.

### 4.4 Set sonu özeti (3-5 sn'de taranır)
- Form skoru (büyük), tekrar sayısı, tempo ortalaması.
- En sık 1-2 hata: kısa açıklama + "neden" kartı (kaynak).
- v0.2: kas haritası — bu sette çalışan kaslar (yoğunluk), ölçüme dayalı.
- "Sonraki set" ana buton; dinlenme zamanlayıcısı sesli.

### 4.5 Seans sonu
- Bugünün skoru vs geçen seans; haftalık kas kapsama (v0.2); paylaşılabilir kart (skor + iskelet çizimi, video değil, gizlilik).
- Bildirim izni burada istenir ("sıradaki seansı hatırlatayım mı?").

### 4.6 Program ve kaynak kartı (v0.3)
- Program özeti: haftada X gün, set/tekrar aralıkları, RIR/yaklaşma açıklaması.
- Her parametrenin yanında "?" → kaynak kartı: 2 cümle özet, kaynak adı, yıl, DOI linki; "bu konuda kanıt gücü: orta/yüksek".

## 5. Geri bildirim tasarımı (ses + haptik + görsel)

### Cue yazım kuralları
- Emir kipi, ≤ 4 kelime, tek eylem: "Daha derin in", "Göğsünü dik tut", "Topukları bas".
- Her cue'nun 2-3 varyantı (tekrarda robotluk hissi olmasın).
- Olumlu pekiştirme kısa ve seyrek: "İşte bu", "Temiz", "Böyle devam".
- Sayım: rakam + kısa ünlü ("yedi", "sekiz"); son 2 tekrar "iki kaldı".
- Türkçe ses: samimi, enerjik ama bağırmayan; erkek/kadın seçenek; İngilizce aynı kişilik.

### Modalite öncelik sırası
1. Ses (her zaman).
2. Haptik: hata cue'sunda kısa çift titreşim, tekrar sayımında tek tık (telefon uzaktaysa saat/kulaklık ileride).
3. Görsel: hata ekleminin overlay'de 1 sn turuncu yanması, cue metni 3 sn.

### Sessizlik politikası
- Düşük güven → sessiz.
- Aynı hata 5 tekrar sürerse sus, set sonunda kart.
- Kullanıcı "az konuş" modunu seçebilir (sadece sayım + kritik hatalar).

## 6. Design system

| Token | Değer (öneri) | Not |
|---|---|---|
| Arka plan | `#0B0F14` | Near-black, kamera görüntüsüyle uyumlu |
| Yüzey | `#141A22` / `#1C242E` | Kartlar |
| Birincil vurgu | `#C8FF3D` (elektrik limon) | Sayaç, ilerleme; karanlıkta uzaktan seçilir |
| İkincil | `#5AD8FF` | Tempo, bilgi |
| Uyarı (hata cue) | `#FF8A3D` (turuncu) | Kırmızı değil: "hata" değil "düzelt" hissi |
| Başarı | `#3DFFB0` | Temiz tekrar |
| Metin | `#F3F6F9` / `#A7B1BD` | Kontrast ≥ 7:1 birincil |
| Tipografi | **Manrope** (başlık, tabular rakam) + **Inter** (gövde) | Sayaç 96-128 px |
| Köşe | 16 / 24 px | |
| Motion | Sayaç: 120 ms scale pulse; skor halkası: 400 ms ease-out; cue metni: fade 200 ms | Reduce-motion'a saygı |
| İkon | Lucide, 2 px stroke | |
| Kas haritası renk skalası | Gri → limon (yoğunluk) | Renk körlüğü: yoğunluk ayrıca desen/etiketle |

Aydınlık tema: v1.x, karanlık öncelikli.

## 7. Durumlar ve kenar koşulları

| Durum | UX |
|---|---|
| Kamera izni reddedildi | Neden + ayarlara git; **kamerasız mod** teklif et (sesli tempo/sayım) |
| Düşük ışık | Kurulumda uyarı; seans içinde güven düşükse sessiz + gri sayaç |
| Kadraj dışına çıkma | "Biraz geri gel" tek cue, 5 sn'de bir tekrar, sayım durur |
| Birden fazla kişi | En büyük/merkezi kişi izlenir; uyarı rozeti |
| Arama/bildirim gelmesi | Seans duraklar, geri dönünce "devam?" |
| Arka plana geçiş | Kamera kapanır, set kaydedilir |
| Cihaz ısındı | Model lite'a düşer, bilgilendirme |
| Ekipman yok/var | Egzersiz listesi filtrelenir |
| Boş ilerleme | "İlk seansını yap, skorun burada görünecek" + hızlı form check butonu |

## 8. Erişilebilirlik

- Tüm cue'lar hem ses hem metin; sesi kapatan kullanıcı için görsel cue büyütülür.
- Dinamik yazı boyutu; VoiceOver/TalkBack etiketleri; renk tek başına anlam taşımaz.
- Sol/sağ el, ayakta/yerde egzersizler için yönerge piktogramları.

## 9. Ekran envanteri (v1.0)

Splash/bootstrap · Onboarding ×4 · Kamera izni · Kamera kurulum · HUD · Set özeti · Seans özeti · Bugün · Antrenman listesi · Egzersiz detay (açı, hatalar, kaslar, video) · Program (v0.3) · Kaynak kartı · İlerleme · Vücut/anatomi (v0.2) · Profil · Ayarlar (ses/dil/overlay/az konuş) · Paywall · Gizlilik & lisanslar · Veri silme.

## 10. Prototip ve kullanılabilirlik testi planı

1. **Hafta 1:** Figma'da 6 ana ekran (onboarding, kurulum, HUD, set özeti, seans özeti, paywall) — düşük sadakat.
2. **Hafta 2:** 5 kullanıcıyla moderatörlü test (Zoom + telefon): görev = "ilk seansı yap". Ölçülen: kurulum tamamlama, ilk cue'ya tepki, HUD'daki sayıyı uzaktan okuma, "cue rahatsız etti mi".
3. **Hafta 5-6 (beta):** 20 kullanıcı, PostHog funnel + 10 dk görüşme. Kritik metrik: `time_to_first_feedback` ≤ 90 sn; `setup_abandon` ≤ %15.
4. Her test sonrası tek sayfalık bulgu → Decision Log.

## 11. Ölçülecek UX metrikleri

`time_to_first_feedback`, `setup_completion_rate`, `setup_duration`, `cues_per_rep` (hedef 0,3-0,6), `silence_ratio_low_confidence`, `set_summary_dwell`, `why_card_open_rate`, `overlay_disabled_rate`, `quiet_mode_rate`.
