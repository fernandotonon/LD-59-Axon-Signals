#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="$REPO_ROOT/assets"
OUT_ROOT="$ASSETS_DIR/renders"
BLENDER_BIN="${BLENDER_BIN:-}"

FRAMES="${FRAMES:-24}"
SIZE="${SIZE:-640}"
MODEL_TILT_DEG="${MODEL_TILT_DEG:--8}"

if [[ -z "$BLENDER_BIN" ]]; then
  if command -v blender >/dev/null 2>&1; then
    BLENDER_BIN="$(command -v blender)"
  elif [[ -x /snap/bin/blender ]]; then
    BLENDER_BIN="/snap/bin/blender"
  else
    echo "Could not find Blender. Set BLENDER_BIN=/path/to/blender"
    exit 1
  fi
fi

mkdir -p "$OUT_ROOT"

shopt -s nullglob
MODELS=("$ASSETS_DIR"/*.glb "$ASSETS_DIR"/*.gltf)
shopt -u nullglob

if [[ ${#MODELS[@]} -eq 0 ]]; then
  echo "No .glb/.gltf models found under $ASSETS_DIR"
  exit 1
fi

for model in "${MODELS[@]}"; do
  stem="$(basename "${model%.*}")"
  out_dir="$OUT_ROOT/$stem"
  mkdir -p "$out_dir"
  echo "=== Rendering $stem -> $out_dir ==="
  "$BLENDER_BIN" -b -P "$REPO_ROOT/tools/blender_turntable.py" -- \
    --input "$model" \
    --output-dir "$out_dir" \
    --frames "$FRAMES" \
    --size "$SIZE" \
    --model-tilt-deg "$MODEL_TILT_DEG"
done

echo "Done. Turntables are in: $OUT_ROOT"
