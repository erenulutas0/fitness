#!/usr/bin/env python3
"""Generate FORMA voice-cue clips from content/cues/cues.json (docs/10 Prompt 6).

Pipeline per (locale, cue, variant):
  text → Google Cloud Text-to-Speech (Neural2 / WaveNet) → WAV
       → ffmpeg: trim silence, loudness-normalise to -16 LUFS, encode Opus 48 kbps
       → apps/mobile/assets/audio/cues/<locale>/<cueId>_<n>.opus

Idempotent: a manifest (assets/audio/cues/manifest.json) stores a hash of
(text, voice, backend); unchanged entries are skipped.

Cost: ~300 phrases × 2 locales ≈ 20–30 K characters → inside Google's monthly
free tier (1 M chars Neural2/WaveNet). Run once per content change.

Usage:
  pip install google-cloud-texttospeech
  export GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json
  python tools/tts_gen/tts_gen.py --locales tr en
  python tools/tts_gen/tts_gen.py --backend dry   # list what would be generated, no API calls

Backends: "google" (default), "azure" (interface stubbed — see AzureBackend), "dry".
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CUES_JSON = ROOT / "content" / "cues" / "cues.json"
OUT_DIR = ROOT / "apps" / "mobile" / "assets" / "audio" / "cues"
MANIFEST = OUT_DIR / "manifest.json"

DEFAULT_VOICES = {
    # Google Cloud TTS voice names. Pick the persona once; changing it regenerates everything.
    "tr": {"languageCode": "tr-TR", "name": "tr-TR-Wavenet-B", "ssmlGender": "MALE"},
    "en": {"languageCode": "en-US", "name": "en-US-Neural2-D", "ssmlGender": "MALE"},
}


@dataclass(frozen=True)
class Job:
    locale: str
    cue_id: str
    variant: int
    text: str

    @property
    def clip_name(self) -> str:
        return f"{self.cue_id}_{self.variant}.opus"

    def digest(self, voice: dict, backend: str) -> str:
        h = hashlib.sha1()
        h.update(f"{backend}|{json.dumps(voice, sort_keys=True)}|{self.text}".encode("utf-8"))
        return h.hexdigest()


class Backend:
    name = "base"

    def synthesize(self, job: Job, voice: dict, wav_path: Path) -> None:  # pragma: no cover
        raise NotImplementedError


class DryBackend(Backend):
    name = "dry"

    def synthesize(self, job: Job, voice: dict, wav_path: Path) -> None:
        print(f"  [dry] {job.locale}/{job.clip_name}: {job.text!r}")


class GoogleBackend(Backend):
    name = "google"

    def __init__(self) -> None:
        try:
            from google.cloud import texttospeech  # type: ignore
        except ImportError as e:  # pragma: no cover
            sys.exit("pip install google-cloud-texttospeech  (and set GOOGLE_APPLICATION_CREDENTIALS)")
        self._tts = texttospeech
        self._client = texttospeech.TextToSpeechClient()

    def synthesize(self, job: Job, voice: dict, wav_path: Path) -> None:
        tts = self._tts
        response = self._client.synthesize_speech(
            input=tts.SynthesisInput(text=job.text),
            voice=tts.VoiceSelectionParams(language_code=voice["languageCode"], name=voice["name"]),
            audio_config=tts.AudioConfig(
                audio_encoding=tts.AudioEncoding.LINEAR16,
                sample_rate_hertz=24000,
                speaking_rate=1.05,   # coach: slightly brisk
                pitch=0.0,
            ),
        )
        wav_path.write_bytes(response.audio_content)


class AzureBackend(Backend):
    """Placeholder for Azure Speech (docs/04 §4 alternative). Same interface."""

    name = "azure"

    def synthesize(self, job: Job, voice: dict, wav_path: Path) -> None:  # pragma: no cover
        raise NotImplementedError("Azure backend not implemented yet; use --backend google")


def load_jobs(locales: list[str]) -> list[Job]:
    data = json.loads(CUES_JSON.read_text(encoding="utf-8"))
    jobs: list[Job] = []
    for cue_id, cue in data["cues"].items():
        for locale in locales:
            variants = cue.get(locale) or []
            if isinstance(variants, str):
                variants = [variants]
            for i, text in enumerate(variants):
                jobs.append(Job(locale, cue_id, i, text))
    return jobs


def post_process(wav_path: Path, out_path: Path, bitrate: str = "48k") -> None:
    """Trim leading/trailing silence, normalise loudness, encode Opus."""
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg not found on PATH")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    filters = (
        "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,"
        "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse,"
        "loudnorm=I=-16:TP=-1.5:LRA=7"
    )
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-af", filters,
         "-c:a", "libopus", "-b:a", bitrate, "-application", "voip", str(out_path)],
        check=True,
    )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--locales", nargs="+", default=["tr", "en"])
    ap.add_argument("--backend", choices=["google", "azure", "dry"], default="google")
    ap.add_argument("--voice", action="append", default=[], metavar="LOCALE=VOICE_NAME",
                    help="override a voice, e.g. tr=tr-TR-Wavenet-E")
    ap.add_argument("--force", action="store_true", help="regenerate everything")
    ap.add_argument("--only", help="only this cue id")
    args = ap.parse_args()

    voices = {k: dict(v) for k, v in DEFAULT_VOICES.items()}
    for spec in args.voice:
        loc, name = spec.split("=", 1)
        voices[loc]["name"] = name

    backend: Backend = {"google": GoogleBackend, "azure": AzureBackend, "dry": DryBackend}[args.backend]()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {"clips": {}}
    clips: dict = manifest.setdefault("clips", {})

    jobs = load_jobs(args.locales)
    if args.only:
        jobs = [j for j in jobs if j.cue_id == args.only]
    total_chars = sum(len(j.text) for j in jobs)
    print(f"{len(jobs)} clips, {total_chars} characters ({args.backend})")

    generated = skipped = 0
    with tempfile.TemporaryDirectory() as tmp:
        for job in jobs:
            voice = voices[job.locale]
            key = f"{job.locale}/{job.clip_name}"
            digest = job.digest(voice, backend.name)
            out_path = OUT_DIR / job.locale / job.clip_name
            if not args.force and clips.get(key, {}).get("hash") == digest and out_path.exists():
                skipped += 1
                continue
            if backend.name == "dry":
                backend.synthesize(job, voice, Path(tmp))
                continue
            wav = Path(tmp) / f"{job.locale}_{job.cue_id}_{job.variant}.wav"
            backend.synthesize(job, voice, wav)
            post_process(wav, out_path)
            clips[key] = {"hash": digest, "text": job.text, "voice": voice["name"], "backend": backend.name}
            generated += 1
            print(f"  wrote {key}")

    if backend.name != "dry":
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        manifest["voices"] = voices
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"generated {generated}, skipped {skipped}")


if __name__ == "__main__":
    main()
