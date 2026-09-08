# forma_content

Uygulamanın **veri olarak** taşıdığı içerik (D9): kod yok, sadece JSON. Flutter paketi olarak paketlenir ve
uygulamadan `packages/forma_content/exercises/bw_squat.json` yoluyla okunur.

| Klasör | İçerik | Şema |
|---|---|---|
| `exercises/*.json` | Egzersiz tanımları: kamera açıları, tekrar eşikleri, kural DSL'i, skor ağırlıkları, kas listesi | `packages/forma_rules/lib/src/rules/exercise_definition.dart` (docs/05 §4) |
| `cues/cues.json` | Sesli cue metinleri (TR/EN varyantlar, haptik, öncelik) — `tools/tts_gen` bunu klip üretmek için okur | `packages/forma_rules/lib/src/feedback/cue_catalog.dart` |
| `sources/*.json` | Kaynak kartları (makale, DOI, kanıt gücü, 2 cümle özet — **kurucu okuyup doldurur**) | docs/10 Prompt 11 |

Kurallar:
- Her değişiklik `packages/forma_rules` testlerinden geçer (`dart test` içerik dosyalarını doğrular).
- `status`: `draft` (uygulamada gizli) → `beta` (beta kullanıcılarına) → `stable`.
- Eşikleri elle değil `tools/eval` raporuyla ayarla.
- FMA kas id'leri anatomi katmanı (v0.2) gelmeden doğrulanacak (bkz. TODO.md).
