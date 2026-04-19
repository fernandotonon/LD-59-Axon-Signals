#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RENDERS_ROOT="${RENDERS_ROOT:-$REPO_ROOT/assets/renders}"
CANVAS="${CANVAS:-640}"
DEFAULT_FILL="${DEFAULT_FILL:-0.90}"

declare -A FILL_BY_MODEL=(
  [ice_cream_truck]=0.94
  [frying_pan]=0.92
  [nailed_plank]=0.96
  [baseball]=0.92
  [apple]=0.93
  [human-brain]=0.93
)

declare -A Y_OFFSET_BY_MODEL=(
  [ice_cream_truck]=-14
  [frying_pan]=-6
  [nailed_plank]=-8
  [baseball]=-8
  [apple]=-10
  [human-brain]=-8
)

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' command is required."
  exit 1
fi

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

shopt -s nullglob
model_dirs=("$RENDERS_ROOT"/*)
shopt -u nullglob

if [[ ${#model_dirs[@]} -eq 0 ]]; then
  echo "No model render directories found under: $RENDERS_ROOT"
  exit 1
fi

for dir in "${model_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  model="$(basename "$dir")"
  shopt -s nullglob
  frames=("$dir"/*.png)
  shopt -u nullglob
  if [[ ${#frames[@]} -eq 0 ]]; then
    continue
  fi

  read -r max_w max_h < <(
    for f in "${frames[@]}"; do
      magick "$f" -alpha extract -trim -format "%w %h\n" info:
    done | awk 'BEGIN{mw=1;mh=1}{if($1>mw)mw=$1;if($2>mh)mh=$2}END{print mw, mh}'
  )

  fill="${FILL_BY_MODEL[$model]:-$DEFAULT_FILL}"
  yoff="${Y_OFFSET_BY_MODEL[$model]:--8}"

  scale="$(awk -v mw="$max_w" -v mh="$max_h" -v c="$CANVAS" -v f="$fill" \
    'BEGIN{s1=(c*f)/mw; s2=(c*f)/mh; s=(s1<s2?s1:s2); printf "%.8f", s}')"
  scaled_w="$(awk -v mw="$max_w" -v s="$scale" 'BEGIN{printf "%d", int(mw*s + 0.5)}')"
  scaled_h="$(awk -v mh="$max_h" -v s="$scale" 'BEGIN{printf "%d", int(mh*s + 0.5)}')"

  if (( yoff >= 0 )); then
    geo="+0+${yoff}"
  else
    geo="+0${yoff}"
  fi

  out_dir="$tmp_root/$model"
  mkdir -p "$out_dir"

  echo "Normalizing $model: max_trim=${max_w}x${max_h} fill=${fill} scale=${scale} out=${scaled_w}x${scaled_h} y=${yoff}"
  for f in "${frames[@]}"; do
    b="$(basename "$f")"
    magick -size "${CANVAS}x${CANVAS}" xc:none \
      \( "$f" -alpha set -trim +repage \
         -gravity center -background none -extent "${max_w}x${max_h}" \
         -resize "${scaled_w}x${scaled_h}" \) \
      -gravity center -geometry "$geo" -composite \
      "$out_dir/$b"
  done
done

for out_dir in "$tmp_root"/*; do
  [[ -d "$out_dir" ]] || continue
  model="$(basename "$out_dir")"
  cp -f "$out_dir"/*.png "$RENDERS_ROOT/$model/"
done

echo "Done. Normalized turntable frames updated under $RENDERS_ROOT"
