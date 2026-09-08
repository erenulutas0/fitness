# forma_eval

Landmark fixture'larını `forma_rules` hattından geçirip egzersiz ve kural bazında precision / recall / F1,
tekrar sayım MAE'si ve tekrar başına cue sayısı raporlar (docs/10 Prompt 9). Kapı 2 kriteri: precision ≥ %80,
recall ≥ %70 (docs/00).

```bash
cd tools/eval
dart run bin/eval.dart                                  # sentetik fixture'lar → docs/eval/latest.md
dart run bin/eval.dart -f ../../data/fixtures -f ../../packages/forma_rules/test/fixtures --no-smoothing
```

Eşikler otomatik yazılmaz; rapor insan kararının girdisidir. Eşik taraması (grid search önerisi) TODO.
