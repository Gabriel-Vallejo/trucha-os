#!/usr/bin/env bash
# Trucha OS! — genera una ISO live propia a partir del perfil "releng" de archiso (en CachyOS/Arch).
# EXPERIMENTAL: lo más sencillo para un USB live es Ventoy + la ISO de CachyOS + `./install.sh --live`
# (ver README). Esta ISO trae los paquetes de Trucha OS! y la configuración en /etc/skel; los fondos
# de Wallpaper Engine NO van dentro (son de sus autores): el primer arranque los importa si los encuentra.
#
#   sudo pacman -S archiso && ./iso/build-iso.sh      → out/trucha-os-*.iso
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$REPO/iso/work"; PROFILE="$WORK/profile"; LOCAL="$WORK/localrepo"; OUT="$REPO/iso/out"
command -v mkarchiso >/dev/null || { echo "Instala archiso: sudo pacman -S archiso"; exit 1; }
AUR=$(command -v paru || command -v yay) || { echo "Hace falta paru o yay para empaquetar lo del AUR"; exit 1; }

rm -rf "$WORK"; mkdir -p "$WORK" "$LOCAL" "$OUT"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# 1. paquetes del AUR → repositorio local dentro de la ISO
grep -vE '^\s*(#|$)' "$REPO/packages/aur.txt" | while read -r p; do
  $AUR -G "$p" --noconfirm >/dev/null 2>&1 || true
  (cd "$p" && makepkg -s --noconfirm --needed && cp ./*.pkg.tar.zst "$LOCAL/") || echo "⚠ no se pudo empaquetar $p"
  rm -rf "$p"
done
repo-add "$LOCAL/trucha-local.db.tar.gz" "$LOCAL"/*.pkg.tar.zst
printf '\n[trucha-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$LOCAL" >> "$PROFILE/pacman.conf"

# 2. lista de paquetes
{ grep -vE '^\s*(#|$)' "$REPO/packages/arch.txt"; grep -vE '^\s*(#|$)' "$REPO/packages/aur.txt"; \
  echo greetd; echo greetd-tuigreet; } >> "$PROFILE/packages.x86_64"

# 3. configuración del usuario live en /etc/skel (las rutas __HOME__ se resuelven en el primer arranque)
SKEL="$PROFILE/airootfs/etc/skel"; mkdir -p "$SKEL/trucha-os"
cp -a "$REPO/dotfiles/." "$SKEL/"
cp -a "$REPO/." "$SKEL/trucha-os/" ; rm -rf "$SKEL/trucha-os/iso/work" "$SKEL/trucha-os/iso/out" "$SKEL/trucha-os/.git"
cat > "$PROFILE/airootfs/etc/profile.d/trucha-primer-arranque.sh" <<'EOF'
# Primer inicio de sesión del usuario live: aplica la configuración de Trucha OS! en su $HOME
if [ ! -f "$HOME/.config/trucha-os/.instalado" ] && [ -x "$HOME/trucha-os/install.sh" ]; then
  "$HOME/trucha-os/install.sh" --solo-config && touch "$HOME/.config/trucha-os/.instalado"
fi
EOF

# 4. usuario live "trucha" con inicio automático en niri (greetd)
mkdir -p "$PROFILE/airootfs/etc/greetd"
cat > "$PROFILE/airootfs/etc/greetd/config.toml" <<'EOF'
[terminal]
vt = 1
[default_session]
command = "tuigreet --cmd niri-session"
user = "greeter"
[initial_session]
command = "niri-session"
user = "trucha"
EOF
cat >> "$PROFILE/airootfs/root/customize_airootfs.sh" 2>/dev/null <<'EOF' || true
useradd -m -G wheel,video,audio,input -s /bin/bash trucha
echo 'trucha:trucha' | chpasswd
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-trucha-live
systemctl enable greetd
EOF
sed -i 's/^iso_name=.*/iso_name="trucha-os"/; s/^iso_label=.*/iso_label="TRUCHA_OS_$(date +%Y%m)"/' "$PROFILE/profiledef.sh"

sudo mkarchiso -v -w "$WORK/mk" -o "$OUT" "$PROFILE"
ls -la "$OUT"
