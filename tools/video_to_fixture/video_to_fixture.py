#!/usr/bin/env python3
"""Turn an ordinary video into a FORMA landmark fixture (docs/fixtures-schema.md).

Recording on the phone means opening the app, framing, capturing and labelling
for every take. Shooting a normal video and converting it here is far less
work, and it also lets an existing clip be used. The same MediaPipe Pose
Landmarker model as the Android engine runs over the frames, so the landmarks
are comparable with a device recording.

    python tools/video_to_fixture/video_to_fixture.py squat.mp4 \
        --exercise bw_squat --view side --person p01 --environment living_room \
        --reps 5 --label 2:shallow_depth --label 3:shallow_depth,knee_valgus \
        --preview

`--preview` writes a copy of the video with the skeleton drawn on it, which is
the fastest way to see whether the model actually saw what you did (a heel
leaving the floor, a knee caving in) before trusting a rule.

The video itself is never copied into the repo; only joint coordinates are
written, and `data/` is gitignored.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import cv2
    import numpy as np
except ImportError:  # pragma: no cover
    sys.exit('pip install opencv-python')
try:
    import mediapipe as mp
    from mediapipe.tasks import python as mp_python
    from mediapipe.tasks.python import vision as mp_vision
except ImportError:  # pragma: no cover
    sys.exit('pip install mediapipe')

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / 'packages' / 'forma_pose' / 'assets' / 'models'
LANDMARKS = 33

# Drawn skeleton, same edges as the app's overlay.
EDGES = [
    (11, 12), (11, 13), (13, 15), (12, 14), (14, 16),
    (11, 23), (12, 24), (23, 24),
    (23, 25), (25, 27), (24, 26), (26, 28),
    (27, 29), (29, 31), (27, 31), (28, 30), (30, 32), (28, 32),
    (0, 2), (0, 5), (2, 7), (5, 8),
]


def parse_labels(specs: list[str]) -> list[dict]:
    """`--label 2:shallow_depth,knee_valgus` -> [{'rep': 2, 'rules': [...]}]"""
    by_rep: dict[int, list[str]] = {}
    for spec in specs:
        rep, _, rules = spec.partition(':')
        if not rules:
            sys.exit(f'bad --label "{spec}", expected REP:rule[,rule]')
        by_rep.setdefault(int(rep), []).extend(
            r.strip() for r in rules.split(',') if r.strip()
        )
    return [{'rep': r, 'rules': sorted(set(v))} for r, v in sorted(by_rep.items())]


def rotate(frame, degrees: int):
    if degrees == 90:
        return cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
    if degrees == 180:
        return cv2.rotate(frame, cv2.ROTATE_180)
    if degrees == 270:
        return cv2.rotate(frame, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return frame


def draw(frame, landmarks, min_visibility: float):
    h, w = frame.shape[:2]
    pts = [(int(l['x'] * w), int(l['y'] * h), l['visibility']) for l in landmarks]
    for a, b in EDGES:
        if pts[a][2] < min_visibility or pts[b][2] < min_visibility:
            continue
        cv2.line(frame, pts[a][:2], pts[b][:2], (61, 255, 200), 2)
    for i, (x, y, v) in enumerate(pts):
        if v < min_visibility:
            continue
        # feet in orange: the landmarks a heel-rise rule depends on
        colour = (61, 138, 255) if i in (29, 30, 31, 32) else (255, 216, 90)
        cv2.circle(frame, (x, y), 4, colour, -1)
    return frame


def main() -> None:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument('video', type=Path)
    ap.add_argument('--exercise', default='bw_squat')
    ap.add_argument('--view', default='side', choices=['side', 'front'])
    ap.add_argument('--person', default='p01', help='anonymous participant code')
    ap.add_argument('--environment', default='unknown')
    ap.add_argument('--model', default='lite', choices=['lite', 'full', 'heavy'])
    ap.add_argument('--reps', type=int, help='how many reps were really performed')
    ap.add_argument('--hold-ms', type=int, help='how long the hold really lasted')
    ap.add_argument('--label', action='append', default=[], metavar='REP:rules',
                    help='ground truth, e.g. 2:shallow_depth,knee_valgus')
    ap.add_argument('--notes')
    ap.add_argument('--rotate', type=int, default=0, choices=[0, 90, 180, 270],
                    help='rotate frames before inference (phone videos)')
    ap.add_argument('--max-width', type=int, default=640,
                    help='downscale before inference, like the phone does')
    ap.add_argument('--start', type=float, default=0, help='skip the first N seconds')
    ap.add_argument('--end', type=float, help='stop at N seconds')
    ap.add_argument('--sheet', action='store_true',
                    help='write one numbered picture per detected rep (its lowest point) '
                         'so labelling is "look at N pictures and tick the bad ones". '
                         'Implies --preview.')
    ap.add_argument('--preview', action='store_true',
                    help='also write <name>.skeleton.mp4 with the skeleton drawn')
    ap.add_argument('--out', type=Path, default=ROOT / 'data' / 'fixtures')
    args = ap.parse_args()
    if args.sheet:
        args.preview = True

    if not args.video.exists():
        sys.exit(f'no such video: {args.video}')
    model_path = MODELS / f'pose_landmarker_{args.model}.task'
    if not model_path.exists():
        sys.exit(f'model missing: {model_path}\nrun tools/fetch_models.ps1')

    cap = cv2.VideoCapture(str(args.video))
    if not cap.isOpened():
        sys.exit(f'cannot open {args.video}')
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)

    options = mp_vision.PoseLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=str(model_path)),
        running_mode=mp_vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
        output_segmentation_masks=False,
    )

    frames: list[dict] = []
    writer = None
    detected = 0
    index = -1
    with mp_vision.PoseLandmarker.create_from_options(options) as landmarker:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            index += 1
            t_ms = int(index * 1000 / fps)
            if t_ms / 1000 < args.start:
                continue
            if args.end is not None and t_ms / 1000 > args.end:
                break

            frame = rotate(frame, args.rotate)
            h, w = frame.shape[:2]
            if w > args.max_width:
                scale = args.max_width / w
                frame = cv2.resize(frame, (int(w * scale), int(h * scale)))
                h, w = frame.shape[:2]

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
            result = landmarker.detect_for_video(mp_image, t_ms)

            brightness = float(rgb[::16, ::16].mean() / 255.0)
            record: dict = {'t': t_ms - int(args.start * 1000), 'w': w, 'h': h,
                            'fps': round(fps, 2), 'br': round(brightness, 4)}

            if result.pose_landmarks:
                detected += 1
                lms = result.pose_landmarks[0]
                flat: list[float] = []
                drawn = []
                for l in lms[:LANDMARKS]:
                    vis = float(getattr(l, 'visibility', 1.0) or 0.0)
                    pres = float(getattr(l, 'presence', 1.0) or 0.0)
                    flat += [round(float(l.x), 6), round(float(l.y), 6),
                             round(float(l.z), 6), round(vis, 6), round(pres, 6)]
                    drawn.append({'x': float(l.x), 'y': float(l.y), 'visibility': vis})
                record['lm'] = flat
                if result.pose_world_landmarks:
                    world: list[float] = []
                    for l in result.pose_world_landmarks[0][:LANDMARKS]:
                        world += [round(float(l.x), 6), round(float(l.y), 6),
                                  round(float(l.z), 6)]
                    record['world'] = world
            else:
                record['lm'] = [0.0] * (LANDMARKS * 5)
                drawn = []

            frames.append(record)

            if args.preview:
                if writer is None:
                    out_video = args.video.with_suffix('.skeleton.mp4')
                    writer = cv2.VideoWriter(
                        str(out_video), cv2.VideoWriter_fourcc(*'mp4v'), fps, (w, h)
                    )
                if drawn:
                    draw(frame, drawn, 0.5)
                cv2.putText(frame, f'{t_ms/1000:5.1f}s', (8, 20),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
                writer.write(frame)

            if total and index % 60 == 0:
                pct = 100 * index / total
                print(f'\r  {pct:5.1f}%  {len(frames)} frames', end='', flush=True)

    cap.release()
    if writer is not None:
        writer.release()
    print()

    if not frames:
        sys.exit('no frames read')

    now = datetime.now(timezone.utc).astimezone()
    stamp = now.strftime('%Y%m%d-%H%M%S')
    fixture = {
        'schemaVersion': 1,
        'id': f'{args.exercise}_{args.view}_{args.person}_{int(now.timestamp() * 1000)}',
        'exerciseId': args.exercise,
        'view': args.view,
        'person': args.person,
        'environment': args.environment,
        'device': f'video:{args.video.name}',
        'modelVariant': args.model,
        'recordedAt': now.isoformat(),
        'synthetic': False,
        'errorLabels': parse_labels(args.label),
        'frames': frames,
    }
    if args.reps is not None:
        fixture['expectedReps'] = args.reps
    if args.hold_ms is not None:
        fixture['expectedHoldMs'] = args.hold_ms
    if args.notes:
        fixture['notes'] = args.notes

    args.out.mkdir(parents=True, exist_ok=True)
    out_path = args.out / f'{args.exercise}_{args.view}_{args.person}_{args.environment}_{stamp}.json'
    out_path.write_text(json.dumps(fixture), encoding='utf-8')

    size_mb = out_path.stat().st_size / (1024 * 1024)
    print(f'{len(frames)} frames, pose found in {detected} '
          f'({100 * detected / len(frames):.0f}%), {size_mb:.2f} MB')
    print(f'wrote {out_path}')
    if args.preview:
        print(f'preview {args.video.with_suffix(".skeleton.mp4")}')
    print('\ninspect it with:')
    if out_path.is_relative_to(ROOT):
        target = f'../../{out_path.relative_to(ROOT).as_posix()}'
    else:
        target = out_path.as_posix()
    print(f'  cd tools/eval && dart run bin/inspect.dart {target}')

    if args.sheet:
        write_rep_sheet(out_path, args.video.with_suffix('.skeleton.mp4'))


def write_rep_sheet(fixture_path: Path, preview_path: Path) -> None:
    """One picture per rep, at the bottom of the movement, numbered.

    Labelling is the step that keeps getting skipped, and the reason is that
    it asks you to remember which rep was which. This turns it into looking
    at N pictures. The rep boundaries come from the engine itself (via
    `inspect --rep-times`), so the picture is the frame the engine scored.
    """
    import shutil
    import subprocess

    if not preview_path.exists():
        print()
        print(f'no preview video at {preview_path}; skipping the rep sheet')
        return
    eval_dir = ROOT / 'tools' / 'eval'
    # Windows needs the resolved path: `dart` is a .bat and bare exec fails.
    dart = shutil.which('dart')
    if dart is None:
        print()
        print('dart is not on PATH; skipping the rep sheet')
        return
    try:
        proc = subprocess.run(
            [dart, 'run', 'bin/inspect.dart', str(fixture_path.resolve()),
             '--rep-times', '-c', str((ROOT / 'content').resolve())],
            cwd=eval_dir, capture_output=True, text=True, timeout=600,
        )
    except (OSError, subprocess.SubprocessError) as e:
        print()
        print(f'could not run the inspector for the rep sheet: {e}')
        return
    if proc.returncode != 0:
        print()
        print('inspector failed, no rep sheet:')
        print(proc.stderr.strip()[:400])
        return

    reps = []
    for line in proc.stdout.splitlines():
        parts = line.strip().split(',')
        if len(parts) == 3 and parts[0].isdigit():
            reps.append((int(parts[0]), int(parts[1]), parts[2]))
    if not reps:
        print()
        print('no reps detected, so no rep sheet')
        return

    cap = cv2.VideoCapture(str(preview_path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    tiles = []
    for index, t_ms, depth in reps:
        cap.set(cv2.CAP_PROP_POS_FRAMES, int(round(t_ms / 1000 * fps)))
        ok, frame = cap.read()
        if not ok:
            continue
        h = 360
        scale = h / frame.shape[0]
        frame = cv2.resize(frame, (int(frame.shape[1] * scale), h))
        cv2.rectangle(frame, (0, 0), (frame.shape[1], 26), (0, 0, 0), -1)
        cv2.putText(frame, f'rep {index}  {t_ms/1000:.1f}s  {depth}',
                    (6, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)
        tiles.append(frame)
    cap.release()
    if not tiles:
        print()
        print('could not read frames for the rep sheet')
        return

    width = min(4, len(tiles))
    rows = []
    for i in range(0, len(tiles), width):
        row = tiles[i:i + width]
        while len(row) < width:
            row.append(np.zeros_like(row[0]))
        rows.append(np.hstack(row))
    sheet_path = preview_path.with_suffix('.reps.jpg')
    cv2.imwrite(str(sheet_path), np.vstack(rows))
    print()
    print(f'rep sheet {sheet_path} ({len(tiles)} reps)')
    print('look at each rep and label the bad ones, e.g. --label 2:shallow_depth')


if __name__ == '__main__':
    main()
