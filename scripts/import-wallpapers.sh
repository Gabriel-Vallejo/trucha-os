#!/usr/bin/env bash
# Importa de TU Wallpaper Engine los fondos de los temas de Trucha OS! (no van en el repo: son de sus autores).
#   ./scripts/import-wallpapers.sh [carpeta steamapps]
# Busca steamapps en: el argumento, Steam de Linux, Steam en una partición de Windows montada.
set -euo pipefail
DATA="$HOME/.local/share/wallpaperengine"
declare -A WALLS=( [torii]=3404531656 [miku]=2397088460 [nino]=2376540588 [marin]=3489782387 )

find_steamapps() {
  local c
  for c in "${1:-}" "$HOME/.local/share/Steam/steamapps" "$HOME/.steam/steam/steamapps" \
           "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps" \
           /media/*/*/"Program Files (x86)/Steam/steamapps" /mnt/*/"Program Files (x86)/Steam/steamapps"; do
    [ -n "$c" ] && [ -d "$c/workshop/content/431960" ] && { echo "$c"; return; }
  done
  return 1
}

STEAMAPPS=$(find_steamapps "${1:-}") || {
  echo "No encuentro Wallpaper Engine (steamapps/workshop/content/431960)."
  echo "Monta la partición de Windows (p. ej. udisksctl mount -b /dev/nvme0n1p3) o pásame la carpeta steamapps."
  exit 1
}
WS="$STEAMAPPS/workshop/content/431960"
echo "Wallpaper Engine: $STEAMAPPS"

mkdir -p "$DATA/wallpapers"
[ -d "$DATA/assets" ] || cp -r "$STEAMAPPS/common/wallpaper_engine/assets" "$DATA/assets"

for name in "${!WALLS[@]}"; do
  id=${WALLS[$name]}
  if [ ! -d "$WS/$id" ]; then echo "  ✘ $name ($id): no está suscrito en Wallpaper Engine"; continue; fi
  rm -rf "$DATA/wallpapers/$name"; cp -r "$WS/$id" "$DATA/wallpapers/$name"
  echo "  ✔ $name ($id)"
done

# torii: vídeo 4K → 2844x1600 (menos GPU) y fotograma fijo para bloqueo/login
T="$DATA/wallpapers/torii"
if [ -d "$T" ] && ! ls "$T"/torii-1600p.mp4 >/dev/null 2>&1; then
  src=$(ls "$T"/*.mp4 | head -1)
  ffmpeg -loglevel error -y -i "$src" -vf "scale=2844:1600:flags=lanczos" -c:v libx264 -preset slow -crf 19 \
         -pix_fmt yuv420p -an -movflags +faststart "$T/torii-1600p.mp4"
  rm -f "$src"
  sed -i 's|"file" : ".*"|"file" : "torii-1600p.mp4"|' "$T/project.json"
fi
mkdir -p "$HOME/.local/share/backgrounds/crimson-ink"
[ -f "$T/torii-1600p.mp4" ] && ffmpeg -loglevel error -y -ss 3 -i "$T/torii-1600p.mp4" -frames:v 1 -q:v 2 \
  "$HOME/.local/share/backgrounds/crimson-ink/torii.jpg"
echo "✔ Fondos importados en $DATA/wallpapers"
