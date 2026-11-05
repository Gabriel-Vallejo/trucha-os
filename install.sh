#!/usr/bin/env bash
# Trucha OS! — instalador. Convierte una instalación (o un live) de CachyOS/Arch o Ubuntu/Pop!_OS en Trucha OS!.
#
#   ./install.sh               completo: paquetes + configuración + fondos + partes de sistema
#   ./install.sh --live        para un USB live: todo menos arranque/Plymouth/rEFInd/marca (no persisten)
#   ./install.sh --solo-config solo la configuración (sin paquetes ni sudo)
#
# Los fondos de Wallpaper Engine se importan de tu propio Wallpaper Engine (scripts/import-wallpapers.sh).
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
MODE=full
case "${1:-}" in --live) MODE=live ;; --solo-config) MODE=config ;; "") ;; *) sed -n '2,9p' "$0"; exit 1 ;; esac

. /etc/os-release
FAMILY=""
[[ "$ID ${ID_LIKE:-}" == *arch* ]] && FAMILY=arch
[[ "$ID ${ID_LIKE:-}" == *ubuntu* || "$ID ${ID_LIKE:-}" == *debian* ]] && FAMILY=ubuntu
[ -n "$FAMILY" ] || { echo "Distro no soportada: $PRETTY_NAME (Arch/CachyOS o Ubuntu/Pop)"; exit 1; }
say() { printf '\n\033[1;31m鱒\033[0m \033[1m%s\033[0m\n' "$*"; }

# ── 1. Paquetes ─────────────────────────────────────────────────────────────
if [ "$MODE" != config ]; then
  say "Paquetes ($FAMILY)"
  sudo -v
  if [ "$FAMILY" = arch ]; then
    sudo pacman -Syu --needed --noconfirm $(grep -vE '^\s*(#|$)' "$REPO/packages/arch.txt")
    AUR=$(command -v paru || command -v yay || true)
    if [ -z "$AUR" ]; then
      sudo pacman -S --needed --noconfirm base-devel
      tmp=$(mktemp -d); git clone -q https://aur.archlinux.org/paru-bin.git "$tmp/paru"
      (cd "$tmp/paru" && makepkg -si --noconfirm); AUR=paru
    fi
    $AUR -S --needed --noconfirm $(grep -vE '^\s*(#|$)' "$REPO/packages/aur.txt")
  else
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $(grep -vE '^\s*(#|$)' "$REPO/packages/ubuntu.txt")
    "$REPO/scripts/ubuntu-build.sh"   # niri, Quickshell (con Qt 6.11), DMS, kitty, herramientas de terminal
  fi
fi

# ── 2. Fuentes que no están (con el nombre exacto) en los repos ────────────
say "Fuentes"
F="$HOME/.local/share/fonts"; mkdir -p "$F"; tmp=$(mktemp -d)
fc-list | grep -q "Departure Mono" || { curl -sSL -o "$tmp/dm.zip" \
  "$(curl -s https://api.github.com/repos/rektdeckard/departure-mono/releases/latest | python3 -c 'import json,sys;print([a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".zip")][0])')"; \
  unzip -qo "$tmp/dm.zip" -d "$tmp/dm"; mkdir -p "$F/DepartureMono"; find "$tmp/dm" -name '*.otf' -exec cp {} "$F/DepartureMono/" \; ; }
fc-list | grep -q "Noto Serif JP" || { curl -sSL -o "$tmp/sj.zip" \
  https://github.com/notofonts/noto-cjk/releases/download/Serif2.003/12_NotoSerifJP.zip; unzip -qo "$tmp/sj.zip" -d "$tmp/sj"; \
  mkdir -p "$F/NotoSerifJP"; find "$tmp/sj" -name 'NotoSerifJP-*.otf' -exec cp {} "$F/NotoSerifJP/" \; ; }
fc-list | grep -q "Inter Variable" || { curl -sSL -o "$tmp/inter.zip" \
  "$(curl -s https://api.github.com/repos/rsms/inter/releases/latest | python3 -c 'import json,sys;print([a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".zip")][0])')"; \
  unzip -qo "$tmp/inter.zip" -d "$tmp/inter"; mkdir -p "$F/Inter"; find "$tmp/inter" -name 'InterVariable*.ttf' -exec cp {} "$F/Inter/" \; ; }
fc-list | grep -q "JetBrainsMono Nerd Font" || { mkdir -p "$F/JetBrainsMonoNerd"; curl -sSL \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C "$F/JetBrainsMonoNerd" --wildcards '*.ttf'; }
rm -rf "$tmp"; fc-cache -f >/dev/null

# ── 3. Configuración ────────────────────────────────────────────────────────
say "Configuración"
(cd "$REPO/dotfiles" && find . -type f -o -type l) | sed 's|^\./||' | grep -v '^trucha.bashrc$' | while read -r f; do
  dst="$HOME/$f"; mkdir -p "$(dirname "$dst")"
  [ -e "$dst" ] && [ ! -e "$dst.antes-trucha" ] && cp -a "$dst" "$dst.antes-trucha"   # copia de lo que hubiera
  cp -a "$REPO/dotfiles/$f" "$dst"
done
grep -rlI "__HOME__" "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/trucha-os" "$HOME/.local/share/applications" \
  "$HOME/.local/state/dms" 2>/dev/null | while read -r f; do sed -i "s|__HOME__|$HOME|g" "$f"; done
chmod +x "$HOME"/.local/bin/{trucha-theme,trucha-ocr,trucha-discord-voice,trucha-theme-assets,fondo,trucha-clock,trucha-showcase,cyberchef,discord,niri-nuevo-escritorio}
install -Dm644 "$REPO/dotfiles/trucha.bashrc" "$HOME/.config/trucha-os/trucha.bashrc"
grep -q "trucha-os/trucha.bashrc" "$HOME/.bashrc" 2>/dev/null || \
  printf '\n# Trucha OS!\n[ -f ~/.config/trucha-os/trucha.bashrc ] && . ~/.config/trucha-os/trucha.bashrc\n' >> "$HOME/.bashrc"

# las configuraciones llaman a ~/.local/bin/{kitty,btop,dms}: enlaza los del sistema si no hay copia propia
for b in kitty btop dms; do
  [ -x "$HOME/.local/bin/$b" ] || { p=$(command -v "$b" || true); [ -n "$p" ] && ln -sf "$p" "$HOME/.local/bin/$b"; }
done
mkdir -p "$HOME/Imágenes/Capturas"
# Nautilus (libadwaita) lee el tema de iconos de gsettings, no de settings.ini; carpetas de Papirus en rojo
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
command -v papirus-folders >/dev/null && sudo papirus-folders -C red --theme Papirus-Dark >/dev/null 2>&1 || true
xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true

# DMS arranca con niri
systemctl --user daemon-reload
systemctl --user add-wants niri.service dms.service 2>/dev/null || true
systemctl --user add-wants niri.service trucha-discord-voice.service 2>/dev/null || true
# plugins de terceros del registro de DMS (no se guardan en el repo)
"$HOME/.local/bin/dms" plugins install quickCapture >/dev/null 2>&1 || echo "  (no se pudo instalar quickCapture; luego: dms plugins install quickCapture)"

# ── 4. Fondos (de tu Wallpaper Engine) y recursos derivados ────────────────
say "Fondos"
if "$REPO/scripts/import-wallpapers.sh"; then
  python3 "$REPO/scripts/gen-crimson-assets.py"
else
  echo "Sin fondos por ahora: cuando tengas Wallpaper Engine a mano ejecuta scripts/import-wallpapers.sh"
  echo "y después scripts/gen-crimson-assets.py"
fi
ln -sfn "$HOME/.config/fastfetch/torii.png" "$HOME/.config/fastfetch/logo.png"

# ── 5. Sistema ──────────────────────────────────────────────────────────────
if [ "$MODE" = full ]; then
  say "Sistema (marca, arranque, rEFInd, tecla Windows)"
  "$REPO/scripts/system.sh"
fi

# ── 6. Tema ─────────────────────────────────────────────────────────────────
say "Tema Crimson Ink"
if [ -n "${NIRI_SOCKET:-}" ]; then
  "$HOME/.local/bin/trucha-theme" crimson-ink
else
  echo "Entra en la sesión niri y ejecuta:  trucha-theme crimson-ink"
fi

say "Listo 🐟  Cierra sesión y entra en «niri» (o reinicia). ⊞+Alt+T cambia de tema."
