#!/bin/bash
# Upscale undersized wallpapers via Upscayl, then re-encode as JPEG.
# Runs at the end of `omarchy theme set <name>`.

set -u

: "${OMARCHY_UPSCALE_DISABLE:=0}"
: "${OMARCHY_UPSCALE_MODEL:=high-fidelity-4x}"
: "${OMARCHY_UPSCALE_MODELS_DIR:=/usr/share/upscayl/models}"
: "${OMARCHY_UPSCALE_QUALITY:=95}"
: "${OMARCHY_UPSCALE_NOTIFY:=1}"

[[ $OMARCHY_UPSCALE_DISABLE == 1 ]] && exit 0

# --- parent: re-exec child detached, then return immediately ------------------
if [[ ${OMARCHY_UPSCALE_CHILD:-} != 1 ]]; then
  THEME_NAME="${1:-}"
  [[ -z $THEME_NAME ]] && exit 0
  command -v setsid >/dev/null || exit 0
  setsid -f env OMARCHY_UPSCALE_CHILD=1 bash "$0" "$THEME_NAME" \
    </dev/null >/dev/null 2>&1
  exit 0
fi

# --- child: do the work synchronously in its own session ----------------------
THEME_NAME="${1:-}"
BG_DIR="$HOME/.config/omarchy/current/theme/backgrounds"
CACHE_DIR="$HOME/.cache/omarchy-wallpaper-upscale"
LOG_FILE="$CACHE_DIR/last-run.log"

[[ -z $THEME_NAME || ! -d $BG_DIR ]] && exit 0

for cmd in upscayl-ncnn identify magick hyprctl jq sha256sum; do
  command -v "$cmd" >/dev/null || exit 0
done

mkdir -p "$CACHE_DIR"
exec >>"$LOG_FILE" 2>&1
echo "=== $(date -Iseconds) theme=$THEME_NAME ==="

TARGET_W=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[].width]  | max // empty')
TARGET_H=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[].height] | max // empty')
[[ -z ${TARGET_W:-} || -z ${TARGET_H:-} ]] && { echo "no target resolution"; exit 0; }
echo "target=${TARGET_W}x${TARGET_H} model=$OMARCHY_UPSCALE_MODEL q=$OMARCHY_UPSCALE_QUALITY"

processed=0
upscaled=0
shopt -s nullglob nocaseglob
for img in "$BG_DIR"/*.{png,jpg,jpeg,webp}; do
  [[ -f $img ]] || continue
  processed=$((processed+1))

  read -r w h < <(identify -format '%w %h\n' "${img}[0]" 2>/dev/null) || { echo "identify failed: $img"; continue; }
  if (( w >= TARGET_W && h >= TARGET_H )); then
    echo "skip $(basename "$img") ${w}x${h}"
    continue
  fi

  # aspect-preserving "cover" — pin dominant axis to target exactly
  read -r ow oh < <(awk -v tw="$TARGET_W" -v th="$TARGET_H" -v w="$w" -v h="$h" 'BEGIN{
    sw = tw/w; sh = th/h
    if (sw >= sh) { print tw, int(h*sw + 0.999) }
    else          { print int(w*sh + 0.999), th }
  }')

  src_hash=$(sha256sum "$img" | cut -c1-16)
  key="${src_hash}_${ow}x${oh}_${OMARCHY_UPSCALE_MODEL}_q${OMARCHY_UPSCALE_QUALITY}"
  cached="$CACHE_DIR/${key}.jpg"

  if [[ ! -s $cached ]]; then
    tmp_png=$(mktemp -p /tmp "upscayl.XXXXXX.png") || continue
    echo "upscale $(basename "$img") ${w}x${h} -> ${ow}x${oh}"
    if ! upscayl-ncnn -i "$img" -o "$tmp_png" \
          -n "$OMARCHY_UPSCALE_MODEL" \
          -m "$OMARCHY_UPSCALE_MODELS_DIR" \
          -r "${ow}x${oh}:default" -f png \
       || [[ ! -s $tmp_png ]]; then
      echo "  upscayl failed"
      rm -f "$tmp_png"; continue
    fi
    if ! magick "$tmp_png" -quality "$OMARCHY_UPSCALE_QUALITY" "$cached" \
       || [[ ! -s $cached ]]; then
      echo "  magick failed"
      rm -f "$tmp_png" "$cached"; continue
    fi
    rm -f "$tmp_png"
  else
    echo "cache hit $(basename "$img") -> $key"
  fi

  # JPEG bytes overwrite the original filename; swaybg/gdk-pixbuf sniff by magic
  cp -f "$cached" "$img"
  upscaled=$((upscaled+1))
done

echo "done: upscaled=$upscaled processed=$processed"

if (( upscaled > 0 )); then
  link="$HOME/.config/omarchy/current/background"
  if [[ -L $link ]]; then
    bg=$(readlink -f "$link")
    [[ -f $bg ]] && omarchy-theme-bg-set "$bg" || true
  fi
  if [[ $OMARCHY_UPSCALE_NOTIFY == 1 ]] && command -v notify-send >/dev/null; then
    notify-send "Wallpapers upscaled" \
      "$upscaled/$processed for $THEME_NAME → ${TARGET_W}x${TARGET_H}" \
      -t 4000 -i image-x-generic || true
  fi
fi
