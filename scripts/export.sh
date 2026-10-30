#!/usr/bin/env bash
# Copia la configuración de Trucha OS! del sistema actual al repositorio (dotfiles/ y system/).
# Ejecútalo cuando cambies algo para que el repo siga al día:  ./scripts/export.sh
# - /home/<usuario> se guarda como __HOME__ (el instalador lo cambia por el $HOME de destino).
# - No se exportan fondos de Wallpaper Engine ni imágenes derivadas de ellos: son de sus autores;
#   el instalador los importa de tu Wallpaper Engine y regenera lo derivado.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DOT="$REPO/dotfiles"
cd "$HOME"

FILES=(
  .config/niri/config.kdl .config/niri/crimson.kdl .config/niri/trucha-theme.kdl .config/niri/dms
  .config/dms/settings.json .config/dms/plugin_settings.json .config/dms/themes .config/dms/plugins
  .local/state/dms/session.json
  .config/kitty/kitty.conf .config/kitty/showcase.session
  .config/btop/btop.conf .config/btop/themes/crimson-ink.theme
  .config/cava/config
  .config/fastfetch/config.jsonc .config/fastfetch/torii.txt
  .config/starship.toml .config/mimeapps.list
  .config/trucha-os/themes .config/trucha-os/templates .config/trucha-os/positions-default.json
  .config/systemd/user/dms.service .config/systemd/user/dms.service.d .config/systemd/user/trucha-fondo.service
  .config/environment.d/90-crimson-ink-cursor.conf .config/environment.d/90-crimson-ink-java.conf
  .config/environment.d/91-crimson-ink-apps.conf
  .config/gtk-3.0/gtk.css .config/gtk-3.0/settings.ini .config/gtk-4.0/gtk.css .config/gtk-4.0/settings.ini
  .config/qt5ct/qt5ct.conf .config/qt6ct/qt6ct.conf
  .config/autostart/nm-applet.desktop .config/autostart/org.gnome.Evolution-alarm-notify.desktop
  .config/autostart/nvidia-settings-autostart.desktop
  .local/bin/trucha-theme .local/bin/trucha-theme-assets .local/bin/fondo .local/bin/trucha-clock
  .local/bin/trucha-showcase .local/bin/cyberchef .local/bin/discord .local/bin/niri-nuevo-escritorio
  .local/share/applications/competis.desktop .local/share/applications/cyberchef-offline.desktop
  .local/share/trucha-os
  .icons/default/index.theme
)
# derivados de fondos de Wallpaper Engine (se regeneran con scripts/gen-crimson-assets.py)
EXCLUDE=(
  .local/share/trucha-os/greeter/crimson-ink.jpg
  .local/share/trucha-os/thumbs/crimson-ink.png
  .local/share/trucha-os/refind/background.png
  .local/share/trucha-os/plymouth/watermark.html
)

rm -rf "$DOT"; mkdir -p "$DOT"
for f in "${FILES[@]}"; do
  [ -e "$f" ] || { echo "  (no existe, se omite) $f"; continue; }
  mkdir -p "$DOT/$(dirname "$f")"
  cp -a "$f" "$DOT/$f"
done
for f in "${EXCLUDE[@]}"; do rm -f "$DOT/$f"; done

# bloque Crimson Ink del .bashrc
awk '/^# ─── Crimson Ink/{p=1} p{print} p&&/^# ──────────────────────────────────────────────────────────────$/{exit}' \
  "$HOME/.bashrc" > "$DOT/trucha.bashrc"

# rutas del usuario → __HOME__ (solo ficheros de texto)
grep -rlI "$HOME" "$DOT" | while read -r f; do sed -i "s|$HOME|__HOME__|g" "$f"; done

# partes de sistema
mkdir -p "$REPO/system"
[ -r /etc/keyd/default.conf ] && cp /etc/keyd/default.conf "$REPO/system/keyd.conf"
echo "✔ Exportado a $DOT ($(du -sh "$DOT" | cut -f1))"
