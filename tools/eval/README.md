# forma_eval

Landmark fixture'larını `forma_rules` hattından geçirip egzersiz ve kural bazında precision / recall / F1,
tekrar sayım MAE'si ve tekrar başına cue sayısı raporlar (docs/10 Prompt 9). Kapı 2 kriteri: precision ≥ %80,
recall ≥ %70 (docs/00).

```bash
cd tools/eval
dart run bin/eval.dart                                  # sentetik fixture'lar → docs/eval/latest.md
dart run bin/eval.dart -f ../../data/fixtures -f ../../packages/forma_rules/test/fixtures --no-smoothing
```

## Tek kayda bakmak

```bash
dart run bin/inspect.dart ../../data/fixtures/take_212256.json
```

Tekrar tekrar döküm: başlangıç, süre, eksantrik/konsantrik tempo, derinlik, skor, tetiklenen kurallar,
insan etiketleri ve canlı cue'lar.

## Eşik taraması (grid search)

Bir parametreyi aralıkta tarar, her değer için tüm korpusu yeniden oynatır ve en iyi skoru veren değeri
**önerir**. `content/` dosyalarına asla yazmaz (CLAUDE.md: "eşikleri elle ayarlama; `tools/eval` ile ayarla" —
ayarlamak demek, aracın raporuna bakıp kararı insanın vermesi demek).

```bash
# squat'ta "sığ" sınırı gerçekten 105° mi?
dart run bin/sweep.dart -e bw_squat -f ../../data/fixtures -s rules.shallow_depth.threshold=95:120:2.5

# tekrar sayımı: iki FSM eşiği birlikte, rep MAE üzerinden
dart run bin/sweep.dart -e bw_squat -s rep.side.restThreshold=145:165:5 -s rep.side.peakThreshold=115:135:5

# sinyal ne kadar yumuşatma istiyor?
dart run bin/sweep.dart -e bw_squat -s smoothing.minCutoff=0.5:3:0.5 -s smoothing.beta=0:0.3:0.1
```

Yollar (`--sweep <yol>=<aralık>`, birden fazla verilirse kartezyen çarpım):

| Yol | Ne | Örnek |
|---|---|---|
| `rep.<görüş>.<alan>` | tekrar FSM'i | `rep.side.peakThreshold` |
| `rules.<id>.threshold` | kural ifadesindeki sayı | `rules.shallow_depth.threshold` |
| `rules.<id>.threshold@<v>` | ifadede birden çok sayı varsa hangisi | `rules.x.threshold@0.85` |
| `rules.<id>.<alan>` | `minConfidence`, `minFraction`, `minConsecutiveFrames`, ... | `rules.knee_valgus.minFraction` |
| `hold.<alan>` | `minHoldMs`, `exitGraceMs` | `hold.minHoldMs` |
| `score.<alan>` | `cleanThreshold`, `defaultWeight`, `weights.<ruleId>` | `score.cleanThreshold` |
| `smoothing.<alan>` | One Euro: `minCutoff`, `beta`, `dCutoff` | `smoothing.beta` |
| `session.<alan>` | `minSignalConfidence`, `maxShinThighRatio`, ... | `session.maxShinThighRatio` |

Aralık: `başlangıç:bitiş:adım` ya da `1,2,3`. Farklı bir egzersizin parametresini oynatmak için yolun başına
`<exerciseId>/` yaz. `--objective` ile hedef seçilir (`f1`, `precision`, `recall`, `rep-mae`,
`rule-f1:<kuralId>`); verilmezse taranan şeye göre seçilir ve raporun başında yazar.

**Korpus soruyu cevaplayamıyorsa araç öneri vermez.** Hiçbir kayıtta hata etiketi yoksa "en yüksek F1"
yalnızca "hiç uyarmayan değer" demektir; bu durumda tablo bilgi olarak basılır ama kazanan ilan edilmez.
Etiketli tekrar sayısı 10'un altındaysa da uyarı çıkar. Yani anlamlı bir tarama için önce **kasten hatalı
kayıt** gerekiyor (bkz. TODO "Şimdi").
