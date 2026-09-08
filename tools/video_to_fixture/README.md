# video_to_fixture

Sıradan bir video → FORMA landmark fixture'ı (`docs/fixtures-schema.md`).

Telefonda kayıt almak her seferinde uygulamayı açmayı, kadraja girmeyi, durdurmayı ve etiketlemeyi gerektiriyor.
Normal video çekip burada dönüştürmek çok daha az iş; ayrıca elde duran eski çekimler de kullanılabilir.
Android motorundaki **aynı MediaPipe modeli** çalıştığı için landmark'lar cihaz kaydıyla karşılaştırılabilir.

```bash
pip install mediapipe opencv-python

python tools/video_to_fixture/video_to_fixture.py squat.mp4 \
    --exercise bw_squat --view side --person p01 --environment living_room \
    --reps 5 --label 2:shallow_depth --label 3:shallow_depth,knee_valgus \
    --preview
```

Çıktı: `data/fixtures/<egzersiz>_<açı>_<kişi>_<ortam>_<zaman>.json` (repo dışı, `data/` gitignore'da).

## Neden `--preview`

`--preview` iskeleti videonun üzerine çizip `<ad>.skeleton.mp4` üretir. **Bir kuralı açmadan önce modelin
gerçekten ne gördüğünü gözle doğrulamanın en hızlı yolu budur.** Ayak noktaları (topuk, parmak) turuncu çizilir;
topuk kalkması gibi tartışmalı kurallarda model tahmininin gerçeğe uyup uymadığı buradan anlaşılır.

## Seçenekler

| Bayrak | Ne için |
|---|---|
| `--exercise`, `--view` | `content/exercises/*.json` içindeki id ve kamera açısı |
| `--person`, `--environment`, `--notes` | fixture meta verisi; kişi kodu anonim (`p01`) |
| `--reps`, `--hold-ms` | gerçekte yapılan tekrar sayısı / tutuş süresi (etiket) |
| `--label REP:kural[,kural]` | tekrar bazında gerçek hatalar; birden fazla kez verilebilir |
| `--rotate 0/90/180/270` | telefon videosu yan geldiyse |
| `--max-width` | inference öncesi küçültme (varsayılan 640, telefondaki gibi) |
| `--start`, `--end` | videonun sadece bir aralığını al (saniye) |
| `--model lite/full` | cihazdakiyle aynı model dosyası |

Model dosyası yoksa: `pwsh tools/fetch_models.ps1`.

## Sonra

```bash
cd tools/eval
dart run bin/inspect.dart ../../data/fixtures/<dosya>.json    # tekrar tekrar döküm
dart run bin/eval.dart -f ../../data/fixtures                  # precision / recall raporu
```

## Sınırlar

- Masaüstü MediaPipe ile Android MediaPipe aynı modeli çalıştırır ama ön işleme birebir aynı değildir;
  eşik kararlarını cihaz kayıtlarıyla da doğrula.
- Video repoya kopyalanmaz, yalnızca eklem koordinatları yazılır. Başkasını çekiyorsan onam al (docs/08).
