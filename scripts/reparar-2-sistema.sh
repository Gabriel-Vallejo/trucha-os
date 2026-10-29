#!/usr/bin/env bash
# Reparación tras la migración: partes de sistema que install.sh no llegó a aplicar
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
sudo -v

# 1. Llavero: el login desbloquea GNOME Keyring (cosmic-greeter autentica con el servicio PAM «login»)
if ! grep -q pam_gnome_keyring /etc/pam.d/login; then
  sudo cp /etc/pam.d/login /etc/pam.d/login.antes-trucha
  sudo tee /etc/pam.d/login >/dev/null <<'PAM'
#%PAM-1.0

auth       requisite    pam_nologin.so
auth       include      system-local-login
-auth      optional     pam_gnome_keyring.so
account    include      system-local-login
session    include      system-local-login
-session   optional     pam_gnome_keyring.so auto_start
password   include      system-local-login
-password  optional     pam_gnome_keyring.so use_authtok
PAM
fi
# el llavero «login» de hoy se creó con otra contraseña: se aparta para que el login cree uno nuevo con la tuya
K="$HOME/.local/share/keyrings/login.keyring"
[ -f "$K" ] && mv "$K" "$K.$(date +%Y%m%d-%H%M).bak"

# 2. Pantalla de login de Trucha OS!: cosmic-greeter (como en Pop) en lugar de SDDM
sudo systemctl disable sddm.service
sudo systemctl enable cosmic-greeter.service cosmic-greeter-daemon.service

# 3. Marca, Plymouth, rEFInd, tecla ⊞ (keyd) y grupo wireshark
"$REPO/scripts/system.sh"

# 4. Tema (escribe también el fondo del login)
"$HOME/.local/bin/trucha-theme" crimson-ink || true
echo; echo "✔ Listo. Reinicia el equipo para ver el login nuevo y que el llavero se desbloquee al entrar."
