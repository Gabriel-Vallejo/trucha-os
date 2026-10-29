#!/usr/bin/env bash
# Reparación tras la migración: el resto de apps y herramientas que había en Pop!_OS
set -euo pipefail
sudo pacman -S --needed --noconfirm \
  github-cli nodejs npm python-pipx yt-dlp pwndbg \
  audacity libreoffice-fresh libreoffice-fresh-es gedit eog evolution
paru -S --needed --noconfirm jd-gui-bin

# herramientas de Python que en Pop vivían en pipx/uv (sus entornos no venían en la copia)
for t in pwntools name-that-hash search-that-hash graphifyy scapy pymupdf pcodedmp; do
  uv tool install --quiet "$t" || echo "⚠ no se pudo instalar $t"
done
# Expo / React Native (eas-cli) en el prefijo del usuario
npm config set prefix "$HOME/.local"
npm install -g eas-cli || echo "⚠ no se pudo instalar eas-cli"

echo; echo "✔ Apps instaladas. Ahora inicia sesión en GitHub:"
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
echo; echo "✔ Todo listo. Vuelve a Claude."
