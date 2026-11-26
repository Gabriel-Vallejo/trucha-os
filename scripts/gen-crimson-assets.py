#!/usr/bin/env python3
"""Regenera los recursos de Crimson Ink derivados del fondo del torii (no se guardan en el repo):
login/bloqueo, miniatura del selector, fondo de rEFInd y logo de imagen del fetch.
Necesita ~/.local/share/backgrounds/crimson-ink/torii.jpg (lo crea import-wallpapers.sh), Chrome o Chromium y Pillow."""
import math
import os
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter

HOME = os.path.expanduser("~")
TORII = f"{HOME}/.local/share/backgrounds/crimson-ink/torii.jpg"
OUT = f"{HOME}/.local/share/trucha-os"
FONT = f'@font-face{{font-family:Inter;src:url("file://{HOME}/.local/share/fonts/Inter/InterVariable.ttf");font-weight:100 900}}'
CHROME = next((c for c in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser") if shutil.which(c)), None)


def shot(html, w, h, out, scale=2):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as fh:
        fh.write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={w},{h}",
                    f"--force-device-scale-factor={scale}", f"--screenshot={out}", "file://" + fh.name],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    os.unlink(fh.name)


def kana_column(chars, color):
    return "".join(f'<span style="color:{color}">{c}</span>' for c in chars)


LOGIN = f'''<!doctype html><meta charset="utf-8"><style>{FONT}
html,body{{margin:0;width:1280px;height:800px;overflow:hidden;background:#0c0c0e}}
.bg{{position:absolute;inset:0;background:url("file://{TORII}") center/cover}}
.shade{{position:absolute;inset:0;background:radial-gradient(ellipse at 50% 48%,rgba(12,12,14,.35) 0%,rgba(12,12,14,.55) 45%,rgba(12,12,14,.92) 100%)}}
.k{{position:absolute;right:70px;top:50%;transform:translateY(-50%);display:flex;flex-direction:column;align-items:center;gap:18px}}
.k b{{font:900 120px "Noto Serif JP";color:#e5383b;line-height:1;text-shadow:0 0 30px rgba(229,56,59,.35)}}
.k i{{width:2px;height:80px;background:#e5383b;opacity:.6}}
.k div{{font:500 30px "Noto Serif JP";line-height:1.25;display:flex;flex-direction:column;align-items:center}}
.w{{position:absolute;left:60px;bottom:48px;font:800 30px Inter;color:#ece8e4}}
.w em{{font-style:normal;color:#e5383b}}
.w small{{display:block;font:500 12px Inter;color:#6a6a72;letter-spacing:7px;text-transform:uppercase;margin-top:6px}}
</style><div class="bg"></div><div class="shade"></div>
<div class="k"><b>鱒</b><i></i><div>{kana_column("トル︱チャ", "#9a948f")}</div></div>
<div class="w">Trucha OS<em>!</em><small>crimson ink</small></div>'''

REFIND = f'''<!doctype html><meta charset="utf-8"><style>{FONT}
html,body{{margin:0;width:1280px;height:800px;overflow:hidden;background:#0c0c0e}}
.bg{{position:absolute;inset:0;background:url("file://{TORII}") center/cover;filter:brightness(.55)}}
.shade{{position:absolute;inset:0;background:radial-gradient(ellipse at 50% 55%,rgba(12,12,14,.15),rgba(12,12,14,.6) 50%,rgba(12,12,14,.95) 100%)}}
.band{{position:absolute;left:0;right:0;top:38%;height:30%;background:linear-gradient(180deg,transparent,rgba(12,12,14,.55) 30%,rgba(12,12,14,.55) 70%,transparent)}}
.k{{position:absolute;left:70px;top:50%;transform:translateY(-50%);display:flex;flex-direction:column;align-items:center;gap:14px}}
.k b{{font:900 96px "Noto Serif JP";color:#e5383b;line-height:1.05;text-shadow:0 0 30px rgba(229,56,59,.35)}}
.k i{{width:2px;height:70px;background:#e5383b;opacity:.6}}
.top{{position:absolute;top:56px;left:0;right:0;text-align:center;font:800 40px Inter;color:#ece8e4}}
.top em{{font-style:normal;color:#e5383b}}
.top small{{display:block;font:500 13px Inter;color:#8a8580;letter-spacing:9px;text-transform:uppercase;margin-top:10px}}
.hanko{{position:absolute;right:70px;bottom:60px;width:74px;height:74px;border:4px solid #e5383b;border-radius:10px;display:flex;align-items:center;justify-content:center;font:900 44px "Noto Serif JP";color:#e5383b;transform:rotate(-6deg);opacity:.85}}
</style><div class="bg"></div><div class="shade"></div><div class="band"></div>
<div class="top">Trucha OS<em>!</em><small>elige tu camino</small></div>
<div class="k"><b>鳥</b><b>居</b><i></i></div><div class="hanko">鱒</div>'''


# marca de agua de Plymouth: el kanji del login sobre el negro del arranque (#0c0c0e, el BackgroundStartColor del tema)
PLYMOUTH = f'''<!doctype html><meta charset="utf-8"><style>{FONT}
html,body{{margin:0;width:280px;height:500px;overflow:hidden;background:#0c0c0e}}
.k{{display:flex;flex-direction:column;align-items:center;gap:14px;padding-top:16px}}
.k b{{font:900 140px "Noto Serif JP";color:#e5383b;line-height:1;text-shadow:0 0 30px rgba(229,56,59,.45)}}
.k i{{width:2px;height:40px;background:#e5383b;opacity:.6}}
.k .kana{{font:500 24px "Noto Serif JP";line-height:1.2;display:flex;flex-direction:column;align-items:center}}
.w{{margin-top:14px;text-align:center;font:800 26px Inter;color:#ece8e4}}
.w em{{font-style:normal;color:#e5383b}}
.w small{{display:block;font:500 10px Inter;color:#6a6a72;letter-spacing:6px;text-transform:uppercase;margin-top:5px}}
</style><div class="k"><b>鱒</b><i></i><div class="kana">{kana_column("トル︱チャ", "#9a948f")}</div>
<div class="w">Trucha OS<em>!</em><small>crimson ink</small></div></div>'''
REPO_PLYMOUTH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../dotfiles/.local/share/trucha-os/plymouth")
TRUCHA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../dotfiles/.local/share/trucha-os/trucha.png")
NEGRO = (12, 12, 14, 255)       # #0c0c0e, el fondo del tema de Plymouth
SWIM, MORPH = 48, 36             # fotogramas: nado en bucle (throbber) y paso a kanji (animación final), a 30 fps


def nadando(pez, fase, w, h, cy):
    """La trucha en la fase dada del nado: el cuerpo ondula más hacia la cola (derecha) y sube y baja un poco."""
    pw, ph = pez.size
    malla, tiras = [], 32
    for i in range(tiras):
        x0, x1 = pw * i // tiras, pw * (i + 1) // tiras
        dy = lambda x: 26 * (x / pw) ** 1.6 * math.sin(2 * math.pi * fase - 5 * x / pw)
        malla.append(((x0, 0, x1, ph), (x0, -dy(x0), x0, ph - dy(x0), x1, ph - dy(x1), x1, -dy(x1))))
    cuerpo = pez.transform(pez.size, Image.MESH, malla, Image.BICUBIC)
    lienzo = Image.new("RGBA", (w, h), NEGRO)
    lienzo.alpha_composite(cuerpo, ((w - pw) // 2, int(cy - ph / 2 + 6 * math.sin(2 * math.pi * fase))))
    d = ImageDraw.Draw(lienzo)
    for k in range(3):                      # burbujas que salen de la boca y suben
        p = (fase + k / 3) % 1
        bx, by, r = (w - pw) // 2 + 30 - 10 * math.sin(6 * p + k), cy - 10 - 150 * p, 4 + 4 * p
        a = int(220 * (1 - p))
        d.ellipse((bx - r, by - r, bx + r, by + r), outline=(229, 56, 59, a), width=2)
    return lienzo


def plymouth_frames(kanji_png):
    """Fotogramas del arranque: la trucha nada (throbber-*) y al acabar se deshace en tinta y aparece 鱒 (animation-*)."""
    kanji = Image.open(kanji_png).convert("RGBA")
    w, h = kanji.size
    pez = Image.open(TRUCHA).convert("RGBA")
    pez = pez.crop(pez.getbbox())
    pez = pez.resize((int(w * .8), int(pez.height * w * .8 / pez.width)), Image.LANCZOS)
    cy = int(h * .19)                       # a la altura del kanji, que es donde va a aparecer
    for i in range(SWIM):
        nadando(pez, i / SWIM, w, h, cy).save(f"{REPO_PLYMOUTH}/throbber-{i:04d}.png")
    for i in range(MORPH):
        t = i / (MORPH - 1)
        pez_t = nadando(pez, t * .5, w, h, cy)
        # la trucha se tiñe de carmesí y se emborrona como tinta; el kanji sale del borrón
        tinta = Image.new("RGBA", (w, h), (229, 56, 59, 255))
        tinta.putalpha(pez_t.convert("L").point(lambda v: 255 if v > 20 else 0))
        pez_t = Image.blend(pez_t, Image.alpha_composite(pez_t, tinta), min(1, t * 2.5))
        pez_t = pez_t.filter(ImageFilter.GaussianBlur(24 * min(1, t * 1.6)))
        kan = kanji.filter(ImageFilter.GaussianBlur(14 * (1 - t) ** 2))
        Image.blend(pez_t, kan, min(1, max(0, (t - .25) / .6))).save(f"{REPO_PLYMOUTH}/animation-{i:04d}.png")
    # la marca de agua se queda vacía: el kanji ya lo trae el último fotograma de la animación
    Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(f"{REPO_PLYMOUTH}/watermark.png")


def main():
    if not os.path.exists(TORII):
        raise SystemExit(f"Falta {TORII}: ejecuta antes scripts/import-wallpapers.sh")
    if not CHROME:
        raise SystemExit("Hace falta Chrome o Chromium para renderizar")
    for d in ("greeter", "thumbs", "refind"):
        os.makedirs(f"{OUT}/{d}", exist_ok=True)
    tmp = tempfile.mkdtemp()

    shot(LOGIN, 1280, 800, f"{tmp}/login.png")
    Image.open(f"{tmp}/login.png").convert("RGB").save(f"{OUT}/greeter/crimson-ink.jpg", quality=92)
    shot(REFIND, 1280, 800, f"{OUT}/refind/background.png")
    # esta sí va al repo: system.sh copia las imágenes de Plymouth desde ahí
    shot(PLYMOUTH, 280, 500, f"{tmp}/kanji.png")
    plymouth_frames(f"{tmp}/kanji.png")

    im = Image.open(TORII).convert("RGB")
    w, h = im.size
    # miniatura del selector (recorte central, esquinas redondeadas)
    t = im.crop((int(w * .25), int(h * .12), int(w * .75), int(h * .82))).resize((320, 200), Image.LANCZOS)
    m = Image.new("L", (320, 200), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 319, 199), 18, fill=255)
    o = Image.new("RGBA", (320, 200), (0, 0, 0, 0))
    o.paste(t, (0, 0), m)
    o.save(f"{OUT}/thumbs/crimson-ink.png")
    # logo de imagen del fetch (kitty): torii recortado con borde carmesí
    s = 3840 / w
    f = im.crop((int(1400 / s), int(560 / s), int(2600 / s), int(1760 / s))).resize((600, 600), Image.LANCZOS)
    m = Image.new("L", (600, 600), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 599, 599), radius=48, fill=255)
    o = Image.new("RGBA", (600, 600), (0, 0, 0, 0))
    o.paste(f, (0, 0), m)
    ImageDraw.Draw(o).rounded_rectangle((1, 1, 598, 598), radius=48, outline=(229, 56, 59, 255), width=4)
    os.makedirs(f"{HOME}/.config/fastfetch", exist_ok=True)
    o.save(f"{HOME}/.config/fastfetch/torii.png")
    shutil.rmtree(tmp)
    print("✔ Recursos de Crimson Ink regenerados")


if __name__ == "__main__":
    main()
