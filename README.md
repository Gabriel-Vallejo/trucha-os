# 🐟 Trucha OS!

Mi Linux personalizado: **niri** (tiling con scroll) + **DankMaterialShell**, tema **Crimson Ink**
(negro tinta y carmesí, estética japonesa) y temas intercambiables de anime en modo dark.

| | |
|---|---|
| Gestor de ventanas | niri v26.04 |
| Interfaz | DankMaterialShell 2.0 (barra, dock, lanzador, notificaciones, bloqueo) |
| Terminal | kitty + starship + fastfetch (con el torii) |
| Temas | Crimson Ink · Miku Dark · Nino Dark · Marin Dark · Resident Evil (`trucha-theme`, ⊞+Alt+T) |
| Escritorio | fondo animado (linux-wallpaperengine), reloj pixel, kanji vertical, visualizador cava, monitor, tiempo, calendario (十月), pétalos de sakura |
| Arranque | Plymouth con la trucha · tema de rEFInd |
| Extras | pestaña **Competis** (ciberseguridad y hackatones, ⊞+Shift+Espacio) · **Utilidades** con `=` en el lanzador · tecla ⊞ sola = lanzador |

## Instalar

Funciona sobre **CachyOS / Arch** (recomendado: todo viene de repos/AUR) y **Ubuntu 24.04 / Pop!_OS**
(niri y Quickshell se compilan).

```bash
git clone <este-repo> ~/trucha-os
cd ~/trucha-os
./install.sh
```

Después cierra sesión y entra en **niri**.

### Pasarse a CachyOS

1. Instala CachyOS (edición **niri**, o cualquiera y el instalador pone niri).
2. Monta la partición de Windows si tus fondos de Wallpaper Engine están allí:
   `udisksctl mount -b /dev/nvmeXnYpZ`
3. `./install.sh`. Hace en este orden:
   1. Instala paquetes con pacman y paru.
   2. Descarga las fuentes.
   3. Copia tu configuración.
   4. Importa los fondos y regenera los recursos derivados.
   5. Aplica la marca y los temas de Plymouth y rEFInd, y configura la tecla ⊞.

### USB live

**Opción fácil (recomendada):** Ventoy + la ISO oficial de CachyOS.
1. Graba [Ventoy](https://www.ventoy.net) en el USB y copia dentro la ISO de CachyOS.
2. Si quieres que los cambios se guarden, añade un fichero de persistencia de Ventoy.
3. Arranca el USB, conéctate a internet y ejecuta `./install.sh --live`.
   Instala todo menos lo que no tiene sentido en un live (marca del sistema, Plymouth y rEFInd).

**Opción ISO propia (experimental):** `./iso/build-iso.sh` (en CachyOS/Arch, con `archiso`).
Genera `iso/out/trucha-os-*.iso`, con los paquetes dentro y un usuario live `trucha`/`trucha`
que entra directamente en niri.

## Fondos de Wallpaper Engine

**No están en el repo**, porque son de sus autores. `scripts/import-wallpapers.sh` los copia
de **tu** Wallpaper Engine: Steam de Linux o la partición de Windows.

| Tema | ID del workshop |
|---|---|
| Crimson Ink (torii) | 3404531656 |
| Miku Dark | 2397088460 |
| Nino Dark | 2376540588 |
| Marin Dark | 3489782387 |
| Resident Evil (Leon · Requiem) | 3665954520 |

Lo que deriva de ellos lo regenera `scripts/gen-crimson-assets.py`: el login de Crimson,
su miniatura, el fondo de rEFInd y el logo del fetch.

## Mantener el repo al día

Cuando cambies algo en tu sistema:

```bash
./scripts/export.sh && git add -A && git commit -m "Actualizar configuración"
```

Las rutas `/home/<tú>` se guardan como `__HOME__` y el instalador las adapta al usuario de destino.

## Estructura

```
install.sh                instalador (modo completo, --live, --solo-config)
packages/                 arch.txt · aur.txt · ubuntu.txt
dotfiles/                 tu $HOME de Trucha OS! (niri, DMS, kitty, temas, widgets, scripts…)
system/keyd.conf          tecla ⊞ sola = lanzador
scripts/export.sh         sistema → repo
scripts/import-wallpapers.sh   Wallpaper Engine → ~/.local/share/wallpaperengine
scripts/gen-crimson-assets.py  recursos derivados del torii
scripts/system.sh         marca, Plymouth, rEFInd, keyd (root)
scripts/ubuntu-build.sh   compilaciones para Ubuntu/Pop
iso/build-iso.sh          ISO live propia (archiso, experimental)
```

## Widgets y utilidades

| Widget | Qué hace |
|---|---|
| Tiempo | temperatura, estado y máx/mín del día (servicio del tiempo de DMS) |
| Calendario | mes con su kanji, semana de lunes a domingo, hoy en carmesí |
| Pétalos | caen despacio con el acento del tema; no bloquean clics (`clickThrough`) |

**Utilidades** (`=` en el lanzador; el resultado se copia al elegirlo):
- vacío → selector de color y capturas (zona, ventana, pantalla);
- `2^10/3`, `sqrt(2)`, `5!`, `3,5*2` → calculadora (sin `eval`);
- `255`, `0xff`, `0b1010` → decimal/hex/binario/octal y carácter;
- `ts` o `ts 1700000000` → timestamp Unix ↔ fecha;
- `#e5383b` → rgb y hsl;
- texto libre → base64, hex, rot13 y url, y lo decodifica si puede;
- prefijos: `b64` `b64d` `hex` `unhex` `rot13` `url` `urld` `bin` `unbin` `up` `low` `rev` `len`.

## Añadir un tema

1. Copia el fondo a `~/.local/share/wallpaperengine/wallpapers/<nombre>`.
2. Crea `~/.config/trucha-os/themes/<id>.json` con estos campos:
   - `accent_hue`;
   - `kanji` y `kana`;
   - `dim`, para oscurecer el fondo;
   - `positions`, opcional, si el personaje tapa los widgets;
   - `petals`, opcional (`false` apaga los pétalos en ese tema).
   - `wallpaper_properties`, opcional: propiedades de la escena para `fondo` (p. ej. `{"clock": false}` apaga el reloj que traiga el fondo).
3. Ejecuta `trucha-theme-assets <id>` (genera el logo, el login y la miniatura) y elige el tema con ⊞+Alt+T.

## Personalizaciones alternativas

[**SekaiPop**](https://github.com/Blapples/SekaiPop): shell de Quickshell para **Hyprland**, inspirada en
Project Sekai, con barra y dock configurables, dos pantallas de bloqueo y sistema de plugins.

No forma parte de Trucha OS! ni se instala con `install.sh`: necesita Hyprland 0.55 o superior y sustituye
a niri + DMS, así que los temas y widgets de este repo no funcionan con ella. Su instalador tiene modo
de prueba y guarda tu configuración de Hyprland en una copia (`./install.sh --restore` la recupera).
