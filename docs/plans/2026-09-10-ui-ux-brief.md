# UI/UX bitirme brief'i (10 Eylül 2026)

Bu doküman, UI/UX'i bitiren agent'ların ortak sözleşmesidir. Kaynaklar: docs/06 (tasarım planı),
docs/01 (ilkeler, MVP), docs/02-03 (market). Buradaki her şey o dokümanlardan türetildi; yeni ürün kararı
**yok**. Emin olmadığın bir şeyi uydurma — dokümana bak, yoksa en sade olanı yap ve notunu düş.

## 0. Değişmez kurallar (CLAUDE.md)

- Kullanıcıya görünen **her metin TR + EN** (`apps/mobile/lib/l10n/app_tr.arb` + `app_en.arb`, sonra
  `flutter gen-l10n`). TR birincil. Cue dili: emir kipi, ≤ 4 kelime, yargılamaz.
- Kamera frame'leri Dart'a geçmez; landmark dizileri diske yazılmaz (yalnızca özetler — D19).
- Yeni native bağımlılık **yok** (16 KB hizalaması yeniden doğrulanmalı olurdu). Tek yeni paket:
  `lucide_icons_flutter` (MIT, saf Dart) — Faz 1 ekler.
- Renk/boşluk/yarıçap/süre değerleri **yalnızca `app/theme.dart` token'larından**. Sihirli sayı yok.
- Bitirmeden: `flutter analyze` + `dart run custom_lint` + `flutter test` + `dart format` yeşil.
  Yeni ekrana widget testi. `dart run build_runner build -d` yeni provider'lar için.
- Commit mesajı İngilizce, conventional commits; kod/tanımlayıcı İngilizce, kullanıcı metni TR/EN.

## 1. Tasarım dili ("leziz" ne demek)

**Sinematik karanlık, tek vurgu.** Arka plan `#0B0F14`; kartlar `#141A22`, yükseltilmiş `#1C242E`, 1 px
`#2A3440` kenar. **Gölge yok** — karanlık temada yükseklik renkle verilir. Limon `#C8FF3D` yalnızca "önemli
olan tek sayı" ve birincil aksiyon için; cyan `#5AD8FF` bilgi/tempo; turuncu `#FF8A3D` düzeltme (**asla
kırmızı** — "hata" değil "düzelt" hissi); yeşil `#3DFFB0` temiz tekrar. Bir ekranda tek limon öğe.

**Tipografi.** Manrope (variable, `assets/fonts/Manrope-Variable.ttf`) başlık ve rakamlar — ExtraBold 800,
**tabular rakam** (`FontFeature.tabularFigures()`) sayaç/skor/süre gösteren her yerde. Inter (variable,
`Inter-Variable.ttf`) gövde. Gövde 16-18 px, ikincil 13-14 px, hiçbir okunacak metin < 12 px. HUD sayacı ekran
yüksekliğinin ≥ %25'i (2-3 m'den okunacak). Büyük skor: 96-128 px.

**Boşluk ve biçim.** Ölçek 4/8/12/16/24/32. Yarıçap 16 (kart, buton), 24 (sheet, hero kart). Kenar boşluğu 20.
Buton yüksekliği 56-64, tam genişlik. **Bir ekranda tek dolu (limon) buton**, altta; ikincil `OutlinedButton`.
Yan yana iki dolu buton yok.

**Hareket.** Kısa ve amaçlı: sayaç 120 ms scale pulse (tekrar artınca), skor halkası 400 ms ease-out, cue metni
200 ms fade. `MediaQuery.disableAnimations` / reduce-motion'a saygı (süreyi 0'a indir). Zıplayan/oyun gibi
spring yok — bu bir koç, oyun değil.

**İkon.** Lucide (`package:lucide_icons_flutter/lucide_icons.dart`, `LucideIcons.xxx`), 2 px stroke,
20-24 px. `Icons.*` (Material) kalmayacak. İkon tek başına anlam taşımaz (yanında metin ya da semantics label).

**Ton.** Sakin, doğrudan, ikinci tekil şahıs. Ünlem yok, emoji yok, "harika iş!" yok. Düzeltici, yargılamaz:
"Dizlerini dışa aç" ✓ · "Yanlış yapıyorsun" ✗. Her uyarının "neden"i bir dokunuş uzakta. Boş durum = tek cümle +
onu dolduran aksiyon.

**Gizlilik görünür.** Kameranın açık olduğu her ekranda kalıcı küçük rozet: "Görüntü cihazda".

## 2. Market bulgularının tasarıma yansıması (docs/02-03)

- TR mağaza yorumları: **"hemen ücretli üyelik dayattı"** ve **"Türkçe istiyoruz"**. → Aha anı (5 squat demo)
  her şeyden önce; bu geçişte **paywall yok, hesap açma yok**. Türkçe metin kalitesi görsel kadar önemli.
- Kamera-form referansları (Onyx, Kaia) İngilizce ve ivmesiz. Bizim farkımız: TR-first + **90 sn içinde ilk
  geri bildirim** (ilke 1). Onboarding ≤ 60 sn, ≤ 4 dokunuş.
- Persona Deniz: telefonu masaya yaslar, ekrana bakmaz (ilke 2). Persona Mert: skorunu paylaşır (kart var).
- "Toplam set" gibi boş sayılar yerine somut ilerleme (ilke 7): skor trendi, en sık hata.

## 3. Mevcut durum (10 Eylül, commit 376a8f0)

Var: Bugün · HUD (kadraj adımı + geri sayım dahil) · Set özeti (dinlenme sayaçlı) · Seans özeti (paylaşım
kartlı) · İlerleme · debug kayıt ekranları. Motor bitmiş ve ölçülmüş; bu geçiş motoru **değiştirmez**.

Yok: onboarding, alt sekme kabuğu, Antrenman listesi, Egzersiz detay, Profil, Ayarlar, Gizlilik & Lisanslar,
fontlar, hareket, Lucide, yatay HUD, ayar bağlantıları (overlay/az konuş).

## 4. Fazlar ve dosya sahipliği

Çakışmayı önlemek için her agent **yalnızca kendi listesindeki** dosyalara dokunur. Ortak sözleşmeler Faz 1'de
kurulur; Faz 2 agent'ları onları tüketir.

### Faz 1 — Temel (1 agent, ana ağaçta)

Sahip: `apps/mobile/pubspec.yaml`, `apps/mobile/lib/app/theme.dart`, `apps/mobile/lib/app/widgets/**` (yeni),
`apps/mobile/lib/core/settings/**` (yeni), `apps/mobile/lib/core/profile/**` (yeni),
`apps/mobile/lib/features/onboarding/onboarding_routes.dart` (boş stub), tüm `Icons.*` → Lucide değişimleri
(her dosyada yalnızca ikon satırları), `apps/mobile/test/` altına yeni testler.

1. Fontları `pubspec.yaml`'a ekle (`assets/fonts/`, iki variable TTF; OFL dosyaları yanında).
2. `theme.dart`: tam `TextTheme` (display/headline/title Manrope 800 tabular; body/label Inter),
   `FormaSpacing` (4/8/12/16/24/32), `FormaRadius` (16/24), `FormaMotion` (120/200/400 ms + reduce-motion
   yardımcı: `Duration FormaMotion.of(context, Duration)` → disableAnimations ise `Duration.zero`),
   kart kenarı 1 px outline, gölge 0, `NavigationBarTheme`, `SwitchTheme`, `ListTileTheme`.
3. `app/widgets/`: `StatTile` (mevcut üç `_Stat` kopyasının yerine), `ScoreText` (band rengi: ≥85 yeşil,
   ≥60 limon, altı turuncu, null soluk), `ScoreRing` (animasyonlu, 400 ms), `SectionTitle`, `EmptyState`
   (cümle + aksiyon), `PrivacyBadge`, `FormaCard`. Mevcut ekranlardaki kopyaları bunlarla değiştir.
4. `core/settings/`: `AppSettings {soundOn=true, quietMode=false, overlayOn=true, locale: 'tr'|'en'|null}` +
   JSON dosya deposu (`settings.json`, D19 kalıbı, `rootOverride` test dikişi) + `settingsProvider`
   (`AsyncNotifier`, keepAlive) + `SettingsController.update(...)`. **Faz 2-B HUD bunu okuyacak, Faz 2-C
   ayarlar ekranı bunu yazacak.**
5. `core/profile/`: `UserProfile {goal: muscle|form|health, level: new|occasional|regular, equipment:
   none|dumbbell, createdAt}` + JSON deposu (`profile.json`) + `profileProvider` + `hasProfileProvider`
   (`Future<bool>`). **Faz 2-A onboarding yazacak, Faz 2-C profil ekranı okuyacak/düzenleyecek.**
6. `features/onboarding/onboarding_routes.dart`: `final List<RouteBase> onboardingRoutes = <RouteBase>[];`
   (Faz 2-A dolduracak, Faz 2-C router'a bağlayacak — ikisi de derlensin diye stub şimdi).
7. Tüm `Icons.*` → `LucideIcons.*`. Mevcut ekranlar yeni tema/widget'larla çalışır ve testler yeşil kalır.
8. Testler: settings/profile depoları round-trip; `ScoreText` band renkleri; `FormaMotion.of` reduce-motion.

Commit **yok** — orkestratör inceleyip commit'ler.

### Faz 2 — Ekranlar (3 agent, ayrı worktree'lerde, paralel)

Her agent kendi worktree'sinde çalışır, işini **tek commit** ile kendi dalına yazar ve dal adını + worktree
yolunu raporlar. `.arb` dosyalarına **yalnızca yeni anahtar ekler** (mevcut anahtarı değiştirmez);
birleştirmede birleşim alınır. `router.dart`'a yalnızca 2-C dokunur.

**2-A Onboarding** (docs/06 §4.1). Sahip: `features/onboarding/**` (stub dosyası dahil), `.arb` ekleri.
- 1 hoş geldin ekranı (1 cümle, "Kamerayı dene" tek limon buton, altta "Zaten biliyorum, atla" ikincil).
- 3 soru, her biri tek dokunuş, büyük seçenek kartları (hedef / seviye / ekipman); ilerleme noktaları.
- Kamera izni ekranı: neden ("Hareketini görmek için; görüntü telefondan çıkmaz") + izin iste (plugin
  `requestCameraPermission()`); reddedilirse neden + tekrar dene + "kamerasız devam" (ayarlara derin link
  **yok** — native bağımlılık gerektirir).
- Demo seans: `workoutSessionController.begin('bw_squat', CameraView.side)` → `setTotal(1)` →
  `Routes.hud('bw_squat', CameraView.side, targetReps: 5)` (2-B bu parametreyi uyguluyor; HUD 5 tekrarda
  kendini bitirir, olağan set/seans özeti akışı çalışır). Profili demo **öncesinde** yaz ki seans özetinden
  "Bugünlük bu kadar" ile Bugün'e dönünce onboarding bir daha açılmasın.
- Toplam ≤ 60 sn, ≤ 4 dokunuş demoya kadar. Widget testi: 3 soru → profil yazıldı → HUD rotasına gidildi.
- `onboardingRoutes` listesini `/onboarding`, `/onboarding/goal|level|equipment|camera` ile doldur.

**2-B HUD ve antrenman cilası** (docs/06 §4.3, §5, §7, §8). Sahip: `features/workout/presentation/hud_screen.dart`,
`rest_timer.dart`, `skeleton_painter.dart`, `features/workout/application/workout_controller.dart`,
`app/router.dart` **hariç** — `Routes.hud` imzasına `targetReps` eklemek için `router.dart`'a **dokunma**;
bunun yerine `HudScreen({required exerciseId, required view, int? targetReps})` + `/workout/:exerciseId/:view?reps=5`
query'sini `HudScreen` içinde `GoRouterState`'ten oku (2-C router'da `Routes.hud` yardımcısına `targetReps`
parametresi ekleyecek; sözleşme: query anahtarı `reps`).
- Hareket: tekrar artınca 120 ms scale pulse; skor halkası 400 ms ease-out; cue metni 200 ms fade;
  reduce-motion → 0.
- Yatay mod: `OrientationBuilder`, yatayda sayaç sağda, butonlar sağ altta. Portre yolu değişmez.
- `settingsProvider`: `overlayOn=false` → iskelet çizilmez; `quietMode=true` →
  `FeedbackPolicy(quietMode: true)` (scheduler'a geçir); `soundOn=false` → cue player sessiz (haptik kalır).
- Düşük güven: sayaç soluk gri, "seni net göremiyorum" tek seferlik (zaten var — görselini tamamla).
- Arka plana geçiş (§7): `WidgetsBindingObserver` → paused'da motor durur, o ana kadarki set kaydedilir
  (`finish()` + `recordSet`), geri gelince set özetine düşer. Kamera arka planda **asla** açık kalmaz.
- `targetReps`: sayaç hedefe ulaşınca `finish()` ve olağan özet navigasyonu; HUD'da "5 / 5" gibi hedef
  göstergesi.
- Semantics: sayaç, skor, cue için `Semantics(label:)`; TalkBack'te "7 tekrar" okunur.
- Widget testi: targetReps ile otomatik bitiş; overlay kapalıyken `SkeletonPainter` yok; yatay düzen.

**2-C Kabuk, Ayarlar, Profil, Antrenman, Egzersiz detay, Lisanslar** (docs/06 §3, §9). Sahip: `app/router.dart`,
`app/shell.dart` (yeni), `features/today/**`, `features/training/**` (yeni), `features/settings/**` (yeni),
`features/profile/**` (yeni), `features/legal/**` (yeni), `.arb` ekleri.
- Alt sekme kabuğu (`StatefulShellRoute`): **Bugün · Antrenman · İlerleme · Profil** (Vücut v0.2, yok). HUD ve
  onboarding kabuk dışında tam ekran. Lucide ikonlar + etiket.
- Router: `redirect` → `hasProfileProvider` false ve konum `/onboarding` ile başlamıyorsa `/onboarding`.
  `...onboardingRoutes` bağla. `Routes.hud(exerciseId, view, {int? targetReps})` → `?reps=` query.
- Bugün: "Hızlı form kontrolü" hero (tek limon buton), bugünün seansı yer tutucusu (program v0.3 — "program
  yakında" **deme**, sadece hızlı form check + son seansın tek cümlelik bulgusu: "Geçen seansta en sık: diz içe
  çökme" — `sessionHistoryProvider`'dan), egzersiz listesi Antrenman sekmesine taşınır.
- Antrenman: egzersiz listesi, kamera açısı rozetleri (ön/yan), `status == draft` rozeti, ekipmana göre
  filtre (profil `equipment`). Karta dokun → Egzersiz detay.
- Egzersiz detay: ad, açıklama, açı piktogramı (basit çizim ya da ikon), tespit edilen hatalar listesi
  (`rulesFor(view)` + `explain` metni), birincil/ikincil kaslar (id'leri okunur ada çevirmeden ham id gösterme;
  yoksa bölümü gizle), "Başla" → kamera açısı seçimi → HUD. Video yok.
- Ayarlar: ses aç/kapa, "az konuş", overlay aç/kapa, dil (TR/EN — `localeControllerProvider`), hepsi
  `settingsProvider` üzerinden; Gizlilik & Lisanslar'a bağlantı; "Verilerimi sil" (sessions/ + profile.json +
  settings.json siler, onay diyaloğu, sonra onboarding'e döner).
- Profil: hedef/seviye/ekipman gösterir ve düzenler (`profileProvider`).
- Gizlilik & Lisanslar: gizlilik özeti (görüntü cihazdan çıkmaz; ne saklanır — docs/05 §9), sonra
  `LicenseRegistry` tabanlı liste + elle eklenen satırlar: MediaPipe (Apache 2.0), CameraX (Apache 2.0),
  Manrope & Inter (SIL OFL), Lucide (ISC). docs/08 tablosuna sadık.
- Widget testleri: kabuk 4 sekme; profil yoksa onboarding'e yönlendirme; ayar değişince deponun yazması.

### Faz 3 — Eleştirmen (1 agent, birleştirilmiş ana ağaçta)

Bütün uygulamayı docs/06 §1 ilkeleri, §7 durumları, §8 erişilebilirlik, bu brief'in §1-2'si ve CLAUDE.md
kurallarına karşı okur. Bulduğunu **düzeltir** (kapsam içi ve küçükse) ya da raporlar (büyükse). Özellikle:
her ekranda tek limon buton mu; metin < 12 px var mı; `Icons.*` kaldı mı; sihirli renk/sayı var mı; her string
TR+EN mi; boş durumlar; reduce-motion; semantics; Türkçe metin doğallığı. Sonunda analyze/test/lint/format yeşil.

## 5. Doğrulama (orkestratör)

Her fazdan sonra tam test seti + cihazda (Galaxy S23, demo motoru) ekran ekran görsel doğrulama; TODO.md ve
docs/06 §9 envanteri güncellenir; commit + push.
