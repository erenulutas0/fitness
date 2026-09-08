#!/usr/bin/env sh
# Downloads MediaPipe Pose Landmarker models (Apache 2.0) into apps/mobile/assets/models.
# Source: https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker#models
set -eu
VARIANTS="${1:-lite full}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/apps/mobile/assets/models"
mkdir -p "$DEST"
for v in $VARIANTS; do
  URL="https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_$v/float16/latest/pose_landmarker_$v.task"
  echo "Downloading $URL"
  curl -L -o "$DEST/pose_landmarker_$v.task" "$URL"
done
echo "Done. Models are gitignored; run this after a fresh clone."
