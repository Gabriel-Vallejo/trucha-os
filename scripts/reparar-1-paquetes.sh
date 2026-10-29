#!/usr/bin/env bash
# Reparación tras la migración: apps que venían de Flatpak/Steam en Pop y piezas del login
set -euo pipefail
sudo pacman -Syu --needed --noconfirm \
  spotify-launcher steam obsidian discord thunderbird fuse2 seahorse \
  cosmic-files greetd cosmic-greeter
paru -S --needed --noconfirm google-chrome visual-studio-code-bin jetbrains-toolbox
echo; echo "✔ Paquetes instalados. Vuelve a Claude."
