# Downloads MediaPipe Pose Landmarker models (Apache 2.0) into apps/mobile/assets/models.
# Source: https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker#models
param([string]$Variant = "lite,full")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root "apps/mobile/assets/models"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($v in $Variant.Split(",")) {
  $v = $v.Trim()
  $url = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_$v/float16/latest/pose_landmarker_$v.task"
  $out = Join-Path $dest "pose_landmarker_$v.task"
  Write-Host "Downloading $url -> $out"
  Invoke-WebRequest -Uri $url -OutFile $out
  Write-Host ("  {0:N1} MB" -f ((Get-Item $out).Length / 1MB))
}
Write-Host "Done. Models are gitignored; run this after a fresh clone."
