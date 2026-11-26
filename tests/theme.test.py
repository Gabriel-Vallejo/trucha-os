#!/usr/bin/env python3
"""Pruebas del recoloreado de trucha-theme (plantillas → tema).  python3 tests/theme.test.py"""
import importlib.machinery, importlib.util
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("tt", str(REPO / "dotfiles/.local/bin/trucha-theme"))
spec = importlib.util.spec_from_loader("tt", loader)
tt = importlib.util.module_from_spec(spec)
loader.exec_module(tt)

azul = tt.make_mapper({"accent_hue": 200})          # un tema con acento azul
igual = tt.make_mapper({})                            # Crimson Ink: sin cambios

# hex de siempre
assert tt.render("color #e5383b\n", igual) == "color #e5383b\n"
assert tt.render("color #e5383b\n", azul) != "color #e5383b\n"

# colores de los shaders de niri (vec3 con tres números entre 0 y 1)
rojo = "vec3 rojo = vec3(0.898, 0.220, 0.231);\n"
assert tt.render(rojo, igual) == rojo
fuera = tt.render(rojo, azul)
r, g, b = (float(x) for x in fuera.split("vec3(")[1].split(")")[0].split(","))
assert b > r, fuera                                   # el carmesí pasa a azul
# lo que no es un color no se toca
for linea in ("vec3(s, 0.0, 0.0)\n", "vec3(uv, 1.0)\n", "vec3(1.0)\n", "vec2(1.0, -0.42)\n", "vec3(2.0, 0.5, 0.5)\n", "vec3(1.5, 0.5, 0.5)\n"):
    assert tt.render(linea, azul) == linea, linea
# accent_sat apaga el acento (tema sobrio) sin tocar su luz
import colorsys
apagado = tt.make_mapper({"accent_hue": 210, "accent_sat": 0.3})
r, g, b = (c / 255 for c in apagado((229, 56, 59)))
_, l, s = colorsys.rgb_to_hls(r, g, b)
assert s < 0.35 and abs(l - 0.559) < 0.01, (l, s)
assert tt.make_mapper({"accent_hue": 210})((229, 56, 59)) != apagado((229, 56, 59))

# fish: el resaltado sigue al tema, pero el error se queda rojo
fish = (REPO / "dotfiles/.config/trucha-os/templates/fish/conf.d/trucha-tema.fish").read_text(encoding="utf-8")
fuera = tt.render(fish, azul, tt.PROTECT["fish/conf.d/trucha-tema.fish"]).splitlines()
linea = lambda nombre, texto: next(l for l in texto if l.startswith(f"set -g {nombre} "))
assert linea("fish_color_error", fuera) == linea("fish_color_error", fish.splitlines())
assert linea("fish_color_command", fuera) != linea("fish_color_command", fish.splitlines())
print("OK: trucha-theme")
