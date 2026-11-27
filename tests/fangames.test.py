#!/usr/bin/env python3
"""Pruebas de trucha-fangames (catálogo, validación, motores y partidas) con juegos y motores falsos, sin GTK.
  python3 tests/fangames.test.py"""
import importlib.machinery, importlib.util, json, os, stat, subprocess, sys, tempfile, time
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
comprobar("el logo sale como file://", f["logo"] == (carpeta / "logo.png").as_uri())
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

print(f"\n{'Todo bien' if not fallos else f'{fallos} fallos'}")
sys.exit(1 if fallos else 0)
