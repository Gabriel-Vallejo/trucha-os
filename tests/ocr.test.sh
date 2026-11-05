#!/usr/bin/env bash
# Pruebas de trucha-ocr con dms y wl-copy falsos (no toca el portapapeles).  bash tests/ocr.test.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cat > "$T/dms" <<'S'
#!/bin/sh
[ "$1" = screenshot ] && { [ "$FAKE" = cancel ] && exit 1; [ "$FAKE" = empty ] || cat "$FAKE"; exit 0; }
shift; echo "$*" >> "$OUT.notify"
S
printf '#!/bin/sh\ncat > "$OUT.clip"\n' > "$T/wl-copy"; chmod +x "$T/dms" "$T/wl-copy"
magick -size 700x90 xc:white -fill black -pointsize 40 -annotate +20+60 'TRUCHA flag 1337' "$T/texto.png"
magick -size 300x90 xc:white "$T/blanco.png"
run() { rm -f "$T/o.clip" "$T/o.notify"; FAKE="$1" OUT="$T/o" PATH="$T:$PATH" "$REPO/dotfiles/.local/bin/trucha-ocr"; }

run "$T/texto.png"; grep -q 'TRUCHA flag 1337' "$T/o.clip"; grep -q 'caracteres' "$T/o.notify"
! grep -q 'TRUCHA' "$T/o.notify"   # el texto no pasa por las notificaciones
run "$T/blanco.png"; [ ! -e "$T/o.clip" ]; grep -q 'No se ha encontrado texto' "$T/o.notify"
run cancel; [ ! -e "$T/o.clip" ]; [ ! -e "$T/o.notify" ]
run empty; [ ! -e "$T/o.clip" ]; [ ! -e "$T/o.notify" ]
echo "OK: trucha-ocr"
