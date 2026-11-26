#!/usr/bin/env bash
# Pruebas de trucha-cava con pactl y cava falsos (no toca el audio).  bash tests/cava.test.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# pactl falso: la salida por defecto es lo que haya en $T/sink
printf '#!/bin/sh\n[ "$1" = get-default-sink ] && cat "%s/sink"\n' "$T" > "$T/pactl"
# cava falso: apunta de qué monitor escucha y se queda vivo
printf '#!/bin/sh\ngrep "^source=" "$2" >> "%s/log"\nexec sleep 1001\n' "$T" > "$T/cava"
chmod +x "$T/pactl" "$T/cava"
printf '[general]\nbars=8\n' > "$T/conf"

echo altavoces > "$T/sink"
PATH="$T:$PATH" TRUCHA_CAVA_POLL=0.2 "$REPO/dotfiles/.local/bin/trucha-cava" "$T/conf" & yo=$!
sleep 0.7
echo buds > "$T/sink"; sleep 0.7                 # cambio de salida: cava vuelve a arrancar con el monitor nuevo
pkill -f "sleep 1001"; sleep 0.7                 # si cava se cae, se vuelve a lanzar
kill "$yo"; wait "$yo" 2>/dev/null || true; sleep 0.2

diff <(cat "$T/log") <(printf 'source=altavoces.monitor\nsource=buds.monitor\nsource=buds.monitor\n')
! pgrep -f "sleep 1001" >/dev/null                # al parar no deja cava huérfano
echo "OK: trucha-cava"
