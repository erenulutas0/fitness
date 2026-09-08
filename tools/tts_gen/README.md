# tts_gen

`content/cues/cues.json` → Opus ses klipleri (`apps/mobile/assets/audio/cues/<locale>/<cueId>_<n>.opus`).
Karar D5: klipler bir kez üretilir, uygulamaya gömülür; çalışma zamanında TTS yok (gecikme < 50 ms, çevrimdışı, sıfır maliyet).

```bash
pip install google-cloud-texttospeech
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\service-account.json   # PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS=...
python tools/tts_gen/tts_gen.py --backend dry          # ne üretileceğini listele (API çağrısı yok)
python tools/tts_gen/tts_gen.py                        # tr + en üret
python tools/tts_gen/tts_gen.py --voice tr=tr-TR-Wavenet-E --force   # ses kişiliğini değiştir
```

- Idempotent: `manifest.json` içindeki hash değişmeyen klipleri atlar.
- ffmpeg gerekli (PATH'te). Sessizlik kırpma + `-16 LUFS` loudness + Opus 48 kbps.
- Maliyet: ~120 klip × ~15 karakter ≈ 2 K karakter → Google'ın aylık ücretsiz kotasının (1 M) çok altında.
- Ses seçimi (docs/06 §5): samimi, enerjik, bağırmayan; erkek/kadın seçeneği için ikinci bir voice ile
  `assets/audio/cues/<locale>_f/` üretimi TODO.
- Şartlar: Google TTS ile üretilen sesin uygulama içinde dağıtımı standart kullanım; "gerçek insan sesi" iddiası yok.
