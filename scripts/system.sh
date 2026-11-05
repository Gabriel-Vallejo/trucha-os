#!/usr/bin/env bash
# Trucha OS! — partes de sistema (root): marca, pantalla de arranque, tema de rEFInd, tecla Windows.
# Lo llama install.sh; también se puede ejecutar solo:  sudo -v && ./scripts/system.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SHARE="$HOME/.local/share/trucha-os"
. /etc/os-release
FAMILY=ubuntu; [[ "$ID ${ID_LIKE:-}" == *arch* ]] && FAMILY=arch

# 1. Marca "Trucha OS!": PRETTY_NAME y logo. NAME/ID no se tocan (los usan el gestor de arranque y los paquetes).
sudo install -Dm644 "$SHARE/trucha-os.svg" /usr/local/share/icons/hicolor/scalable/apps/trucha-os.svg
sudo install -Dm644 "$SHARE/trucha-os.png" /usr/local/share/pixmaps/trucha-os.png
sudo tee /usr/local/sbin/trucha-os-branding >/dev/null <<'EOF'
#!/bin/sh
# Trucha OS! — reaplica la marca tras cada actualización de paquetes (hook de apt o pacman)
for SRC in /etc/pop-os/os-release /usr/lib/os-release; do [ -f "$SRC" ] && break; done
[ -f "$SRC" ] || exit 0
VERSION=$(sed -n 's/^VERSION="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$SRC")
mkdir -p /etc/trucha-os
sed -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Trucha OS! ${VERSION}\"/" -e '/^LOGO=/d' "$SRC" > /etc/trucha-os/os-release.new
printf 'LOGO=trucha-os\nVARIANT="Crimson Ink"\nVARIANT_ID=trucha\n' >> /etc/trucha-os/os-release.new
mv /etc/trucha-os/os-release.new /etc/trucha-os/os-release
[ "$(readlink /etc/os-release)" = "trucha-os/os-release" ] || ln -sfn trucha-os/os-release /etc/os-release
exit 0
EOF
sudo chmod 755 /usr/local/sbin/trucha-os-branding
if [ "$FAMILY" = arch ]; then
  sudo install -d /etc/pacman.d/hooks
  sudo tee /etc/pacman.d/hooks/99-trucha-os.hook >/dev/null <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Trucha OS!: reaplicando la marca
When = PostTransaction
Exec = /usr/local/sbin/trucha-os-branding
EOF
else
  echo 'DPkg::Post-Invoke { "/usr/local/sbin/trucha-os-branding || true"; };' | sudo tee /etc/apt/apt.conf.d/99trucha-os >/dev/null
fi
sudo /usr/local/sbin/trucha-os-branding

# 2. Pantalla de arranque (Plymouth two-step)
P=/usr/share/plymouth/themes/trucha-os
if command -v plymouth >/dev/null && [ -d "$SHARE/plymouth" ]; then
  sudo install -d "$P"
  sudo cp "$SHARE"/plymouth/*.png "$SHARE/plymouth/trucha-os.plymouth" "$P/"
  if [ "$FAMILY" = arch ]; then
    # chwd quita kms del initramfs por NVIDIA: se carga solo el driver de la GPU que enciende la pantalla, para que Plymouth pinte
    KMS=""
    for d in /sys/class/drm/card?/device; do
      [ "$(cat "$d/boot_vga" 2>/dev/null)" = 1 ] && KMS=$(basename "$(readlink "$d/driver")")
    done
    if [ -n "$KMS" ] && [ "$KMS" != nvidia ]; then
      echo "MODULES+=($KMS)" | sudo tee /etc/mkinitcpio.conf.d/20-trucha-kms.conf >/dev/null
    fi
    sudo plymouth-set-default-theme -R trucha-os   # regenera el initramfs con mkinitcpio
    # GRUB oculto: 1 s en vez de 0 para que Esc aún abra el menú (snapshots y kernel LTS)
    if [ -f /etc/default/grub ]; then
      sudo sed -i -e 's/plymouth\.use-simpledrm //' -e 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' \
        -e 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
      sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
  else
    sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$P/trucha-os.plymouth" 300
    sudo update-alternatives --set default.plymouth "$P/trucha-os.plymouth"
    sudo update-initramfs -u
  fi
fi

# 3. Tema de rEFInd (solo si rEFInd está instalado en la partición EFI)
ESP=""
for d in /boot/efi/EFI/refind /boot/EFI/refind /efi/EFI/refind; do sudo test -f "$d/refind.conf" && ESP=$d && break; done
if [ -n "$ESP" ]; then
  sudo test -f "$ESP/refind.conf.antes-trucha" || sudo cp "$ESP/refind.conf" "$ESP/refind.conf.antes-trucha"
  sudo rm -rf "$ESP/themes/trucha-os"; sudo install -d "$ESP/themes/trucha-os/icons"
  sudo cp "$SHARE"/refind/*.png "$SHARE/refind/theme.conf" "$ESP/themes/trucha-os/"
  sudo cp "$SHARE"/refind/icons/*.png "$ESP/themes/trucha-os/icons/"
  sudo grep -q "^include themes/trucha-os/theme.conf" "$ESP/refind.conf" || \
    printf '\n# Trucha OS! (tema)\ninclude themes/trucha-os/theme.conf\n' | sudo tee -a "$ESP/refind.conf" >/dev/null
  echo "✔ Tema de rEFInd en $ESP"
else
  echo "· rEFInd no está en la partición EFI: tema no instalado (instálalo con refind-install y repite)"
fi

# 4. Tecla Windows sola = lanzador (keyd)
if command -v keyd >/dev/null; then
  sudo install -Dm644 "$REPO/system/keyd.conf" /etc/keyd/default.conf
  sudo systemctl enable --now keyd
fi

# 5. Grupo wireshark (capturar sin root)
getent group wireshark >/dev/null && sudo usermod -aG wireshark "$USER"

# 6. El arranque no espera a la wifi: con eduroam lenta, network-online retrasaba Docker, graphical.target y DMS
command -v nmcli >/dev/null && sudo systemctl disable NetworkManager-wait-online.service
echo "✔ Partes de sistema aplicadas"
