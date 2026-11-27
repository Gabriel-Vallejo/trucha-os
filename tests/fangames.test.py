#!/usr/bin/env python3
"""Pruebas de trucha-fangames (catálogo, validación, motores y partidas) con juegos y motores falsos, sin GTK.
  python3 tests/fangames.test.py"""
import importlib.machinery, importlib.util, json, os, stat, subprocess, sys, tempfile, time, zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "dotfiles/.local/bin/trucha-fangames"
TMP = Path(tempfile.mkdtemp())
os.environ.update(HOME=str(TMP), TRUCHA_FANGAMES_DIR=str(TMP / "Juegos"))
loader = importlib.machinery.SourceFileLoader("fg", str(SCRIPT))
spec = importlib.util.spec_from_loader("fg", loader)
fg = importlib.util.module_from_spec(spec)
loader.exec_module(fg)

fallos = 0


def comprobar(nombre, cond):
    global fallos
    print(("ok   " if cond else "FALLO") + " " + nombre)
    fallos += 0 if cond else 1


def escribir(ruta, texto, ejecutable=False):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text(texto)
    if ejecutable:
        ruta.chmod(ruta.stat().st_mode | stat.S_IXUSR)


# catálogo de serie (copiado del repo) y juegos propios en ~/.config
serie, propios = fg.CATALOGOS
for toml in (REPO / "dotfiles/.local/share/trucha-os/fangames/juegos").glob("*.toml"):
    escribir(serie / toml.name, toml.read_text())
escribir(propios / "mio.toml", 'id = "mio"\nnombre = "Mi Fangame"\nmotor = "mkxp-z"\ncarpeta = "mio"\nlogo = "logo.png"\n')
escribir(propios / "malo.toml", 'id = "malo"\nnombre = "Malo"\nmotor = "mkxp-z"\ncarpeta = "x"\nlogo = "../../etc/passwd"\n')
escribir(propios / "roto.toml", 'id = "roto"\nnombre = = "x"\n')
escribir(propios / "sinexe.toml", 'id = "sinexe"\nnombre = "Sin exe"\nmotor = "opengmk"\ncarpeta = "y"\n')

# ── validación ──
bueno = {"id": "a", "nombre": "A", "motor": "mkxp-z", "carpeta": "a"}
comprobar("manifiesto bueno no tiene errores", fg.validar(bueno) == [])
comprobar("faltan campos obligatorios", len(fg.validar({"id": "a"})) == 3)
comprobar("motor desconocido", any("motor desconocido" in e for e in fg.validar({**bueno, "motor": "dosbox"})))
comprobar("opengmk exige ejecutable", any("ejecutable" in e for e in fg.validar({**bueno, "motor": "opengmk"})))
comprobar("ruta que sale de la carpeta se rechaza", not fg.ruta_segura("../x") and not fg.ruta_segura("/etc/x"))
comprobar("id con espacios se rechaza", fg.validar({**bueno, "id": "a b"}) != [])
comprobar("estado desconocido se rechaza", fg.validar({**bueno, "estado": "terminado"}) != [])

juegos, avisos = fg.leer_catalogo()
comprobar("trae Añil y Reloaded de serie", {"anil", "reloaded"} <= set(juegos))
comprobar("lee el juego propio", "mio" in juegos)
comprobar("descarta los manifiestos malos con aviso", not {"malo", "roto", "sinexe"} & set(juegos) and len(avisos) == 3)

escribir(propios / "anil.toml", (serie / "anil.toml").read_text().replace('nombre = "Pokémon Añil"', 'nombre = "Añil mío"'))
comprobar("~/.config pisa al de serie", fg.leer_catalogo()[0]["anil"]["nombre"] == "Añil mío")
(propios / "anil.toml").unlink()

# ── estado en disco ──
mio = juegos["mio"]
comprobar("sin carpeta no está instalado", not fg.ficha(mio)["instalado"])
carpeta = TMP / "Juegos/mio"
escribir(carpeta / "Game.ini", "[Game]\n")
escribir(carpeta / "logo.png", "png")
f = fg.ficha(mio)
comprobar("con Game.ini está instalado pero falta el motor", f["instalado"] and not f["motor_listo"])
comprobar("el logo sale como file://", f["logo"].startswith((carpeta / "logo.png").as_uri() + "?v="))
comprobar("por_que_no explica qué falta", "falta el motor mkxp-z" in fg.por_que_no(mio))

# motor falso: apunta en qué carpeta se ejecutó y sale
marca = TMP / "ejecutado.txt"
escribir(fg.RUNTIMES / "mkxp-z/mkxp-z.x86_64", f'#!/bin/sh\npwd > "{marca}"\nsleep 0.2\n', ejecutable=True)
(fg.RUNTIMES / "mkxp-z/stdlib").mkdir()
comprobar("con el motor ya está listo", fg.ficha(mio)["listo"])

# ── jugar ──
inicio = time.time()
fg.jugar(mio).join(timeout=10)
comprobar("ejecuta el motor dentro de la carpeta del juego", marca.read_text().strip() == str(carpeta))
comprobar("enlaza mkxp-z en el juego sin copiarlo",
          (carpeta / "mkxp-z.x86_64").stat().st_ino == (fg.RUNTIMES / "mkxp-z/mkxp-z.x86_64").stat().st_ino)
comprobar("enlaza stdlib", (carpeta / "stdlib").is_symlink())
comprobar("apunta la última partida", fg.estado()["mio"]["ultima_vez"] >= int(inicio) - 1)
fg.apuntar_partida("mio", 1000, 1000 + 125 * 60)
comprobar("suma los minutos jugados", fg.estado()["mio"]["minutos"] == 125)
comprobar("guarda el log del juego", (fg.LOGS / "mio.log").exists())
comprobar("los listos y recientes van primero", fg.biblioteca()["juegos"][0]["id"] == "mio")

try:
    fg.lanzar(juegos["reloaded"])
    comprobar("no lanza un juego sin instalar", False)
except RuntimeError as e:
    comprobar("no lanza un juego sin instalar", "no encuentro el juego" in str(e))

# ── accesos y CLI ──
accesos = fg.escribir_accesos()
comprobar("crea un .desktop solo para los juegos listos", [a.name for a in accesos] == ["trucha-fangame-mio.desktop"])
comprobar("el .desktop lanza el juego", "Exec=trucha-fangames jugar mio" in accesos[0].read_text())

salida = subprocess.run([sys.executable, str(SCRIPT), "lista"], capture_output=True, text=True, env=os.environ)
comprobar("lista marca listos y no listos", "✔ mio" in salida.stdout and "✘ reloaded" in salida.stdout)
salida = subprocess.run([sys.executable, str(SCRIPT), "jugar", "nada"], capture_output=True, text=True, env=os.environ)
comprobar("jugar con id desconocido sale con 2", salida.returncode == 2)

# ── arte por convención ──
escribir(fg.ARTE / "mio/portada.png", "png")
comprobar("la portada sale de _arte/<id>/portada.png", fg.ficha(mio)["portada"].startswith((fg.ARTE / "mio/portada.png").as_uri()))
comprobar("sin banner no hay banner", fg.ficha(mio)["banner"] is None)
arte = subprocess.run([sys.executable, str(REPO / "dotfiles/.local/bin/trucha-fangames-arte"), "prueba",
                       "--fondo", str(REPO / "dotfiles/.local/share/trucha-os/trucha-os.png"), "--titulo", "Prueba"],
                      capture_output=True, text=True, env=os.environ)
if arte.returncode == 0:
    from PIL import Image
    comprobar("trucha-fangames-arte hace portada 600×900 y banner 1920×640",
              Image.open(fg.ARTE / "prueba/portada.png").size == (600, 900)
              and Image.open(fg.ARTE / "prueba/banner.png").size == (1920, 640))
else:
    comprobar("trucha-fangames-arte funciona (¿falta Pillow?) " + arte.stderr[-200:], "No module named 'PIL'" in arte.stderr)

# ── ajustes ──
comprobar("ajustes por defecto", fg.ajustes()["orden"] == "recientes")
fg.guardar_ajustes({"orden": "nombre", "minimizar_al_jugar": "sí", "inventado": 1})
a = fg.ajustes()
comprobar("guarda claves válidas e ignora tipos malos y claves raras",
          a["orden"] == "nombre" and a["minimizar_al_jugar"] is True and "inventado" not in a)
comprobar("ordenar por nombre", [j["nombre"] for j in fg.biblioteca()["juegos"]][:1] == ["Mi Fangame"])
fg.guardar_ajustes({"orden": "raro"})
comprobar("un orden desconocido vuelve a recientes", fg.ajustes()["orden"] == "recientes")
fg.guardar_ajustes({"mostrar_no_listos": False})
comprobar("ocultar juegos no listos", [j["id"] for j in fg.biblioteca()["juegos"]] == ["mio"])
fg.guardar_ajustes({"mostrar_no_listos": True})

# ── detectar motor e importar ──
fuente = TMP / "fuentes"
escribir(fuente / "rmxp/Mi Juego RMXP/Game.ini", "[Game]\n")
escribir(fuente / "rmxp/Mi Juego RMXP/Data/Scripts.rxdata", "x")
escribir(fuente / "gm8/juego.exe", "MZ" + "\\Software\\Game Maker\\" + "TRunnerForm")
escribir(fuente / "otro/Juego.exe", "MZ nada")
escribir(fuente / "otro/unins000.exe", "MZ")
comprobar("detecta RPG Maker → mkxp-z", fg.detectar_motor(fuente / "rmxp/Mi Juego RMXP")["motor"] == "mkxp-z")
d = fg.detectar_motor(fuente / "gm8")
comprobar("detecta Game Maker 8 → opengmk", d["motor"] == "opengmk" and d["ejecutable"] == "juego.exe")
d = fg.detectar_motor(fuente / "otro")
comprobar("un .exe desconocido queda con wine y salta el desinstalador", d["motor"] == "wine" and d["ejecutable"] == "Juego.exe")
comprobar("slug sin tildes ni espacios", fg.slug("Pokémon Añil: Edición ¡Final!") == "pokemon-anil-edicion-final")

zip_bueno = TMP / "Mi Juego RMXP.zip"
with zipfile.ZipFile(zip_bueno, "w") as z:
    for p in (fuente / "rmxp").rglob("*"):
        if p.is_file():
            z.write(p, p.relative_to(fuente / "rmxp"))
lineas = []
nuevo_id = fg.importar(zip_bueno, avisar=lineas.append)
comprobar("importa el zip con id sacado del nombre", nuevo_id == "mi-juego-rmxp")
comprobar("aplana la carpeta única del zip", (fg.JUEGOS / nuevo_id / "Game.ini").exists())
creado = fg.leer_catalogo()[0].get(nuevo_id, {})
comprobar("deja un manifiesto válido en ~/.config en pruebas",
          creado.get("motor") == "mkxp-z" and creado.get("estado") == "en pruebas")
comprobar("importar dos veces no pisa: añade sufijo", fg.importar(zip_bueno, avisar=lineas.append) == "mi-juego-rmxp-2")
zip_malo = TMP / "malo.zip"
with zipfile.ZipFile(zip_malo, "w") as z:
    z.writestr("../../fuera.txt", "x")
try:
    fg.importar(zip_malo, avisar=lineas.append)
    comprobar("rechaza un zip que escribe fuera (zip slip)", False)
except ValueError:
    comprobar("rechaza un zip que escribe fuera (zip slip)", not (TMP / "fuera.txt").exists()
              and not list(fg.JUEGOS.glob(".importando-*")))

# ── Claude ──
orden = fg.orden_claude(nuevo_id)
comprobar("la orden de Claude es headless, acotada y con el manifiesto",
          orden[:2] == ["claude", "-p"] and "--allowedTools" in orden and "Bash(trucha-fangames:*)" in orden
          and "Bash" not in orden and str(fg.PROPIOS / f"{nuevo_id}.toml") in orden[2])
comprobar("resume eventos de herramienta", fg.resumen_evento(json.dumps({"type": "assistant", "message": {"content": [
    {"type": "tool_use", "name": "Bash", "input": {"command": "trucha-fangames lista"}}]}})) == "→ Bash trucha-fangames lista")
comprobar("resume el resultado final", fg.resumen_evento(json.dumps({"type": "result", "result": "Listo"})) == "✔ Listo")
comprobar("marca como fallo un resultado con error", fg.resumen_evento(json.dumps(
    {"type": "result", "subtype": "success", "is_error": True, "result": "Failed to authenticate"})) == "✘ Failed to authenticate")
comprobar("ignora líneas que no son JSON", fg.resumen_evento("ruido") is None)

print(f"\n{'Todo bien' if not fallos else f'{fallos} fallos'}")
sys.exit(1 if fallos else 0)
