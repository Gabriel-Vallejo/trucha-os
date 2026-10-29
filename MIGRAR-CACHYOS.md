# Migrar Trucha OS! de Pop!_OS a CachyOS (sustituyendo a Pop)

Windows **no se toca**. La copia de seguridad está en la partición de Windows:
`TruchaBackup/home-trucha-AAAA-MM-DD.tar.zst` (datos, claves, correo, perfiles) y `TruchaBackup/docker/`
(volúmenes de n8n y volcado MySQL de style-scent-engine).

## 0. Antes de empezar

- Copia hecha y verificada (`zstd -t` correcto).
- Cargador conectado (la instalación tarda un rato).
- USB Ventoy con `cachyos-desktop-linux-*.iso`.
- Internet: una wifi normal o el móvil. eduroam no estará configurado durante la instalación.

## 1. Arrancar el instalador

1. Reinicia con el USB puesto. Si rEFInd no muestra el USB, usa el menú de arranque de la BIOS (F12/F8).
2. En el menú de Ventoy elige **cachyos-desktop-linux**.
3. En el live, abre **Install CachyOS** (Calamares).

## 2. Instalación (Calamares)

- **Idioma / zona / teclado:** Español · Europe/Madrid · `es`.
- **Particiones → Particionado manual.** ⚠ Es el paso delicado: toca **solo** estas dos.

| Partición | Tamaño | Qué es | Qué hacer |
|---|---|---|---|
| `nvme0n1p6` | ~341 GB | Pop!_OS (ext4) | Editar → **Formatear**, sistema **btrfs**, punto de montaje **/** |
| `nvme0n1p5` | 1024 MB | EFI (vfat) | Editar → **NO formatear**, punto de montaje **/boot/efi** |
| `nvme0n1p1` · `p2` · `p3` · `p4` | 100 MB · 16 MB · 610 GB · 930 MB | **Windows** | **No tocar** |

  btrfs permite instantáneas: si una actualización rompe algo, se vuelve atrás.
- **Cargador de arranque:** **rEFInd**. Es el que ya usas, y así el tema de Trucha OS! sigue.
- **Escritorio:** **niri** si aparece. Si no aparece, cualquiera (por ejemplo KDE): el instalador de Trucha OS! pondrá niri.
- **Usuario:** `imtrucha` · equipo: `trucha-os`.
- Revisa el resumen. Debe decir que **solo formatea nvme0n1p6**. Después, Instalar.

## 3. Primer arranque en CachyOS

Reinicia, quita el USB y elige CachyOS en rEFInd. Abre una terminal y ejecuta:

```bash
# 1. partición de Windows (copia de seguridad y fondos de Wallpaper Engine)
udisksctl mount -b /dev/nvme0n1p3
B=$(ls -d /run/media/$USER/*/TruchaBackup)

# 2. repositorio desde la copia (sin iniciar sesión en GitHub)
cp -r "$B/trucha-os" ~/trucha-os && cd ~/trucha-os

# 3. Trucha OS! completo (paquetes, configuración, fondos, Plymouth, rEFInd, tecla ⊞)
./install.sh

# 4. tus datos y los volúmenes de Docker: siempre DESPUÉS de install.sh
./scripts/restore-backup.sh "$B"
```

El orden importa: `restore-backup.sh` necesita Docker ya instalado para los volúmenes, y retira los
binarios que Pop compilaba a mano en `~/.local/bin` (quickshell, niri, dms…), que taparían los de CachyOS.

Para usar GitHub en lugar de la copia: `sudo pacman -S github-cli && gh auth login && gh repo clone Gabriel-Vallejo/trucha-os ~/trucha-os`.

Cierra sesión y entra en **niri**.

## 4. Después

- **eduroam:** EAP-TTLS + PAP, identidad anónima `cat.20200723@usal.es`, CA en `~/.config/cat_installer/ca.pem`
  (ya viene restaurada con la copia) y dominio `jaspe.usal.es;mica.usal.es`. También vale el instalador oficial de eduroam CAT.
- **Grupo `docker`:** vuelve a entrar en la sesión para usar `docker` sin `sudo`.
- **MySQL de style-scent-engine:** levanta su `docker compose` y ejecuta el comando que imprime `restore-backup.sh`.
- **JetBrains:** instala JetBrains Toolbox y vuelve a instalar las IDE (no se copiaron: 28 GB). Tus ajustes sí están en `~/.config/JetBrains`.
- **Restos de Pop en la partición EFI** (`EFI/Pop_OS-*`, `EFI/systemd`): rEFInd ya los oculta.
  Cuando todo vaya bien, se pueden borrar.

## Si algo sale mal

- **No arranca CachyOS:** arranca otra vez desde el USB (live) y pásale a Claude el error.
- **Windows** sigue en rEFInd, en su sitio.
- **La copia** está intacta en `TruchaBackup` hasta que tú la borres.
