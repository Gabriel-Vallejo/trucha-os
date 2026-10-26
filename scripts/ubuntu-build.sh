#!/usr/bin/env bash
# Trucha OS! en Ubuntu 24.04 / Pop!_OS: lo que no está en apt (o está demasiado viejo).
# Reproduce cómo se montó el Trucha OS! original:
#   Qt 6.11 (aqtinstall) + libwayland 1.24 → Quickshell 0.3.2 · niri v26.04 · xwayland-satellite · DMS 2.0
#   kitty, starship, fastfetch, eza, bat, zoxide, fzf, btop, matugen, keyd
set -euo pipefail
SRC="$HOME/.local/src/crimson-ink"; mkdir -p "$SRC" "$HOME/.local/bin"
QT="$HOME/.local/opt/Qt/6.11.3/gcc_64"; WL="$HOME/.local/opt/wayland"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
gh_asset() { curl -s "https://api.github.com/repos/$1/releases/latest" | python3 -c 'import json,sys,re;p=re.compile(sys.argv[1]);print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if p.search(a["name"])))' "$2"; }
tmp=$(mktemp -d)

# Rust y uv
command -v cargo >/dev/null || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh

# Qt 6.11 + libwayland 1.24 (Ubuntu trae Qt 6.4 y libwayland 1.22, insuficientes para Quickshell)
[ -d "$QT" ] || uvx --from aqtinstall aqt install-qt linux desktop 6.11.3 linux_gcc_64 \
  -m qtshadertools qtmultimedia qt5compat qtimageformats -O "$HOME/.local/opt/Qt"
if [ ! -f "$WL/lib/libwayland-client.so.0" ]; then
  git clone -q --depth 1 -b 1.24.0 https://gitlab.freedesktop.org/wayland/wayland.git "$tmp/wayland"
  (cd "$tmp/wayland" && uvx meson setup build --prefix="$WL" --libdir=lib -Ddocumentation=false -Dtests=false -Ddtd_validation=false \
     && uvx meson install -C build)
fi

# Quickshell
if ! command -v quickshell >/dev/null; then
  git clone -q --depth 1 -b v0.3.2 https://git.outfoxxed.me/quickshell/quickshell "$SRC/quickshell"
  (cd "$SRC/quickshell" && PATH="$WL/bin:$PATH" PKG_CONFIG_PATH="$WL/lib/pkgconfig" cmake -GNinja -B build \
     -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH="$WL;$QT" -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
     -DCMAKE_INSTALL_RPATH="$WL/lib;$QT/lib" -DINSTALL_QML_PREFIX=lib/qml -DCRASH_HANDLER=OFF \
   && PATH="$WL/bin:$PATH" cmake --build build -j"$(nproc)" && cmake --install build)
fi

# niri + xwayland-satellite (+ sesión en el login)
if ! command -v niri >/dev/null; then
  git clone -q --depth 1 -b v26.04 https://github.com/YaLTeR/niri "$SRC/niri"
  (cd "$SRC/niri" && cargo build --release)
  git clone -q --depth 1 https://github.com/Supreeeme/xwayland-satellite "$SRC/xwayland-satellite"
  (cd "$SRC/xwayland-satellite" && git fetch -q --depth 1 origin tag v0.8.3 && git checkout -q v0.8.3 && cargo build --release)
  sudo install -m755 "$SRC/niri/target/release/niri" "$SRC/niri/resources/niri-session" /usr/local/bin/
  sudo install -m755 "$SRC/xwayland-satellite/target/release/xwayland-satellite" /usr/local/bin/
  sudo install -Dm644 "$SRC/niri/resources/niri.service" /etc/systemd/user/niri.service
  sudo sed -i 's|^ExecStart=niri --session|ExecStart=/usr/local/bin/niri --session|' /etc/systemd/user/niri.service
  sudo install -Dm644 "$SRC/niri/resources/niri-shutdown.target" /etc/systemd/user/niri-shutdown.target
  sudo install -Dm644 "$SRC/niri/resources/niri-portals.conf" /usr/local/share/xdg-desktop-portal/niri-portals.conf
  printf '[Desktop Entry]\nName=Trucha OS!\nComment=niri + DankMaterialShell\nExec=/usr/local/bin/niri-session\nType=Application\nDesktopNames=niri\n' \
    | sudo tee /usr/share/wayland-sessions/niri.desktop >/dev/null
fi

# DMS (binarios oficiales) + dgop, dsearch, matugen
if [ ! -x "$HOME/.local/bin/dms" ]; then
  for pair in "AvengeMedia/DankMaterialShell:^dms-cli-amd64\.gz$:dms" "AvengeMedia/dgop:^dgop-linux-amd64\.gz$:dgop" \
              "AvengeMedia/danksearch:^dsearch-linux-amd64\.gz$:dsearch"; do
    IFS=: read -r repo pat name <<<"$pair"
    curl -sSL "$(gh_asset "$repo" "$pat")" | gunzip > "$HOME/.local/bin/$name"; chmod +x "$HOME/.local/bin/$name"
  done
  curl -sSL "$(gh_asset InioX/matugen 'x86_64\.tar\.gz$')" | tar -xz -C "$tmp"; install -m755 "$(find "$tmp" -name matugen -type f | head -1)" "$HOME/.local/bin/"
  install -Dm644 "$(dirname "$0")/../dotfiles/.config/systemd/user/dms.service" "$HOME/.config/systemd/user/dms.service" 2>/dev/null || true
fi

# kitty y herramientas de terminal
command -v kitty >/dev/null || { curl -sL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n; \
  ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/"; }
command -v starship >/dev/null || curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null
for spec in "fastfetch-cli/fastfetch:linux-amd64\.tar\.gz$:fastfetch" "eza-community/eza:^eza_x86_64-unknown-linux-gnu\.tar\.gz$:eza" \
            "sharkdp/bat:x86_64-unknown-linux-gnu\.tar\.gz$:bat" "ajeetdsouza/zoxide:x86_64-unknown-linux-musl\.tar\.gz$:zoxide" \
            "junegunn/fzf:linux_amd64\.tar\.gz$:fzf" "aristocratos/btop:^btop-x86_64-unknown-linux-musl\.tar\.gz$:btop"; do
  IFS=: read -r repo pat name <<<"$spec"
  command -v "$name" >/dev/null && continue
  d="$tmp/$name"; mkdir -p "$d"; curl -sSL "$(gh_asset "$repo" "$pat")" | tar -xz -C "$d"
  install -m755 "$(find "$d" -type f -name "$name" | head -1)" "$HOME/.local/bin/$name"
done

# keyd (tecla Windows sola = lanzador)
if ! command -v keyd >/dev/null; then
  git clone -q --depth 1 -b v2.6.0 https://github.com/rvaiya/keyd "$SRC/keyd"
  (cd "$SRC/keyd" && make && sudo make install)
fi

# linux-wallpaperengine: compilación manual (ver https://github.com/Almamu/linux-wallpaperengine)
command -v linux-wallpaperengine >/dev/null || [ -x /opt/linux-wallpaperengine/linux-wallpaperengine ] || \
  echo "⚠ Falta linux-wallpaperengine: compílalo según su README (los fondos animados lo necesitan)."
rm -rf "$tmp"
echo "✔ Componentes de Ubuntu listos"
