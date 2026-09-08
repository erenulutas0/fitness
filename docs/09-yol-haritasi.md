# 09 — Yol Haritası (12 hafta + sonrası)

Varsayım: tek kişi, haftada ~40-50 saat, Claude Code ile. İş arayışı devam ediyorsa süreleri ×1,5 yap; kapılar aynı kalır.

Takvim önerisi: **Hafta 0 = 15 Eylül 2026** → soft launch ~ 1-7 Aralık (Ocak sezonuna yetişir).

## Hafta 0 — Keşif ve karar (Kapı 1)
- 5 PT/fizyoterapist + 10 hedef kullanıcı görüşmesi (script: son antrenmanını anlat; formundan nasıl emin oluyorsun; ne için para ödedin).
- Rakip uygulamaları kur, 3'er seans yap, cue dilini/kurulum akışını not al.
- Beta onam formu, landing + bekleme listesi.
- Karar: 5 egzersiz kesinleşir, marka aday listesi.
- **Çıkış:** Kapı 1 kriterleri (00-README).

## Hafta 1-2 — Motor
- Prompt 1-4 (bkz. 10): repo, mimari iskelet, Android `forma_pose` plugin'i (CameraX + MediaPipe), landmark recorder, squat FSM + 3 kural, birim testleri.
- Paralel: `google_mlkit_pose_detection` ile 3 günde "squat sayacı" UX prototipi → 5 kişiye göster.
- TTS klip üretim scripti; ilk 60 Türkçe cue.
- 30 test videosu çekimi başlar (5 kişi × squat/push-up, iki açı, üç ortam).
- **Çıkış:** Android'de squat sayan, valgus ve derinlik uyaran demo, 400 ms altı cue.

## Hafta 3-4 — 5 egzersiz + HUD (Kapı 2)
- Push-up, lunge, plank, glute bridge kuralları; FeedbackScheduler; HUD; kamera kurulum asistanı.
- Eval harness: precision/recall raporu; eşik ayarı.
- iOS plugin başlangıcı (3. hafta sonunda RN'e geçiş kararı noktası).
- Figma 6 ekran + 5 kişilik kullanılabilirlik testi.
- **Çıkış:** Kapı 2 (precision ≥ %80, latency ≤ 400 ms, thermal OK).

## Hafta 5-6 — Beta (Kapı 3)
- Set/seans özeti, ilerleme ekranı, yerel DB, temel program (3 gün/hafta), onboarding.
- Anatomi viewer (WebView + three.js) ilk sürüm: egzersiz → kas highlight (v0.2 çekirdeği).
- 20 beta kullanıcı (Android öncelikli), PostHog funnel, haftalık görüşmeler.
- İçerik: ilk 10 kısa video, build-in-public başlangıcı.
- **Çıkış:** Kapı 3 (D7 ≥ %25, "kalksa üzülürüm" ≥ %40).

## Hafta 7-8 — Kanıt katmanı + para
- Program motoru v0.3: hedef/seviye/gün/ekipman → plan; kaynak kartları (ilk 30 kaynak elle okunmuş).
- RevenueCat, paywall, trial; fiyat hipotezleri.
- Ölçüme dayalı kas haritası (set sonrası), haftalık kapsama.
- iOS parity; cihaz matrisi testleri.

## Hafta 9-10 — Cila ve uyum
- Mağaza varlıkları (ekran görüntüleri, önizleme videosu), ASO metinleri TR/EN.
- KVKK/gizlilik/lisans ekranları, hesap silme, türev 3D model repo'su.
- Performans bütçeleri son kontrol; crash-free ≥ %99,5 beta.
- 30 kısa video birikimi tamam; 5 PT referansı.

## Hafta 11-12 — Soft launch TR (Kapı 4 ölçümü başlar)
- Play open testing → prod; TestFlight → App Store.
- Basın TR, Ekşi/Instagram/Reddit, influencer 3-5.
- Paywall/fiyat A/B; haftalık cohort raporu.
- **Çıkış (4 hafta sonra ölçülür):** D30 ≥ %8, trial→paid ≥ %25.

## Sonrası
- **Ocak (EN lansman):** Product Hunt, EN içerik, EN influencer; Ocak sezonu.
- **Q1 2027:** dambıl hareketleri (RDL, omuz pres, row), asimetri raporu, kamerasız mod, salon modu.
- **Q2 2027:** PT modu (B2B2C), kural DSL'ini açma, sohbet koç (LLM + kaynak RAG).
- Kapı 4 geçilmezse: hedef segmenti daralt (ör. sadece "evde yeni başlayan kadın 25-35" + Instagram), ya da PT B2B2C'ye erken pivot.

## Haftalık ritüel
- Pazartesi: hafta hedefi (tek cümle) + Decision Log gözden geçirme.
- Her gün: 1 test videosu daha, 1 cue daha, 1 kaynak daha (küçük, sürekli).
- Cuma: eval raporu + metrik + build-in-public postu.

## "Bitti" tanımı (her özellik için)
Birim/golden test var · eval raporu güncel · Türkçe+İngilizce metin · analitik olayı var · performans bütçesi içinde · dokümana yansıdı.
