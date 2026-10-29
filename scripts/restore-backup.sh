#!/usr/bin/env bash
# Restaura la copia de seguridad hecha antes de migrar (TruchaBackup en la partición de Windows):
# datos personales, claves, correo, perfiles y volúmenes de Docker.  Uso: ./scripts/restore-backup.sh [carpeta TruchaBackup]
set -euo pipefail
B="${1:-}"
[ -n "$B" ] || for c in /run/media/*/*/TruchaBackup /media/*/*/TruchaBackup /mnt/*/TruchaBackup; do [ -d "$c" ] && B=$c && break; done
[ -d "${B:-}" ] || { echo "No encuentro TruchaBackup: monta la partición de Windows (udisksctl mount -b /dev/nvme0n1p3)"; exit 1; }
ARCH=$(ls -t "$B"/home-trucha-*.tar.zst | head -1)
echo "Restaurando $ARCH en $HOME"
# --keep-newer-files: no pisa lo que el sistema nuevo ya haya creado más reciente
tar --zstd -xf "$ARCH" -C "$HOME" --keep-newer-files 2>&1 | grep -v "is newer or same age" || true
chmod 700 "$HOME/.ssh" "$HOME/.gnupg" 2>/dev/null || true

if command -v docker >/dev/null && [ -d "$B/docker" ]; then
  sudo systemctl enable --now docker
  for t in "$B"/docker/*.tgz; do
    v=$(basename "$t" .tgz); docker volume create "$v" >/dev/null
    docker run --rm -v "$v":/v -v "$B/docker":/b alpine sh -c "cd /v && tar xzf /b/$v.tgz"
    echo "  ✔ volumen $v"
  done
  echo "  MySQL de style-scent-engine: levanta su docker compose y después:"
  echo "    zstd -dc $B/docker/style-scent-mysql.sql.zst | docker exec -i style_scent_db sh -c 'mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\"'"
fi
echo "✔ Copia restaurada"
