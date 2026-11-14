#!/usr/bin/env python3
"""Pruebas de trucha-lab con un vault de juguete y un docker falso.  python3 tests/lab.test.py"""
import contextlib, datetime as dt, importlib.machinery, importlib.util, io, os, tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TMP = Path(tempfile.mkdtemp())
VAULT = TMP / "vault"
CTX = VAULT / "20_Contexto"
CTX.mkdir(parents=True)
BIN = TMP / "bin"
BIN.mkdir()
DOCKER_LOG = TMP / "docker.log"
# docker falso: apunta los argumentos y responde bien
(BIN / "docker").write_text(f'#!/bin/sh\necho "$@" >> "{DOCKER_LOG}"\n')
(BIN / "docker").chmod(0o755)
os.environ.update(HOME=str(TMP), TRUCHA_LAB_VAULT=str(VAULT), PATH=f"{BIN}:{os.environ['PATH']}")
os.environ.pop("XDG_STATE_HOME", None)

loader = importlib.machinery.SourceFileLoader("lab", str(REPO / "dotfiles/.local/bin/trucha-lab"))
spec = importlib.util.spec_from_loader("lab", loader)
lab = importlib.util.module_from_spec(spec)
loader.exec_module(lab)

PLAN = CTX / "Plan de práctica de 8 semanas - CTF.md"
PLAN.write_text("""---
tipo: contexto
---

# Plan de práctica de 8 semanas - CTF

Fórmula que no se puede romper: $\\frac{a}{b}$ y \\rightarrow.

## Semana 3 (2–8 nov): reversing I

| Plataforma | Reto | Categoría | Dificultad | Hecho |
|---|---|---|---|---|
| picoCTF | vault-door-1 | Reversing (Java) | Medium | ⬜ |

## Semana 4 (9–15 nov): pwn I

| Plataforma | Reto | Categoría | Dificultad | Hecho |
|---|---|---|---|---|
| picoCTF | buffer overflow 0 | Pwn | Easy | ✅ |
| picoCTF | buffer overflow 1 | Pwn (ret2win) | Medium | ⬜ |
| picoCTF | Buffer overflow 1 extra | Pwn | Hard | ⬜ |
""", encoding="utf-8")
ORIGINAL = PLAN.read_text(encoding="utf-8")

clock = {"t": dt.datetime(2026, 11, 12, 18, 0)}
lab.now = lambda: clock["t"]


def run(*args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            code = lab.main(list(args))
        except SystemExit as e:
            code = e.code if isinstance(e.code, int) else 1
            if not isinstance(e.code, int):
                print(e.code)
    return code, out.getvalue()


def docker_calls():
    return DOCKER_LOG.read_text().splitlines() if DOCKER_LOG.exists() else []


# plan: la semana 4 (12 nov) con lo pendiente, sin lo hecho ni otras semanas
code, out = run("plan")
assert code == 0, out
assert "Semana 4" in out and "buffer overflow 1" in out and "1/3" in out, out
assert "vault-door-1" not in out and "buffer overflow 0" not in out, out
assert "vault-door-1" in run("plan", "--semana", "3")[1]

# sin sesión: status lo dice y done falla con mensaje
assert "No hay ninguna sesión" in run("status")[1]
code, out = run("done")
assert code == 1 and "No hay ninguna sesión" in out, out

# start busca la fila exacta del plan (sin distinguir mayúsculas), aunque otra la contenga
code, out = run("start", "BUFFER", "overflow", "1")
assert code == 0 and "picoCTF" in out and "Pwn (ret2win)" in out, out
code, out = run("start", "otra")
assert code == 1 and "buffer overflow 1" in out, out  # una sola sesión a la vez

clock["t"] += dt.timedelta(minutes=37, seconds=20)
assert "37:20" in run("status")[1]

# done: writeup en el vault, ✅ en el plan con enlace y tiempo, línea en el hub
code, out = run("done")
assert code == 0, out
WU = CTX / "Writeups de práctica"
text = (WU / "Writeup - buffer overflow 1.md").read_text(encoding="utf-8")
assert text.startswith("---\ntipo: contexto\n"), text
assert "plataforma: picoCTF" in text and "tiempo: 37 min" in text and "fecha: 2026-11-12" in text, text
assert "\n🧭 [[Inicio]] › Contexto › [[Writeups de práctica - CTF]]\n" in text, text
assert "## Lo aprendido" in text, text
plan = PLAN.read_text(encoding="utf-8")
assert "| picoCTF | buffer overflow 1 | Pwn (ret2win) | Medium | ✅ [[Writeup - buffer overflow 1]] (37 min) |" in plan, plan
assert "| Buffer overflow 1 extra | Pwn | Hard | ⬜ |" in plan, plan
# solo cambia esa fila: el resto del archivo (LaTeX incluido) queda igual byte a byte
assert [l for l in plan.splitlines() if "| buffer overflow 1 |" not in l] == \
       [l for l in ORIGINAL.splitlines() if "| buffer overflow 1 |" not in l]
assert plan.endswith("\n")
hub = (CTX / "Writeups de práctica - CTF.md").read_text(encoding="utf-8")
assert "\n🧭 " in hub and "- [[Writeup - buffer overflow 1]] · picoCTF · Pwn (ret2win) · Medium · 37 min · 2026-11-12" in hub, hub
assert "No hay ninguna sesión" in run("status")[1]
assert "2/3" in run("plan")[1]

# laboratorio Docker: solo escucha en 127.0.0.1; cancel lo para y no escribe nada
code, out = run("start", "juice-shop")
assert code == 0 and "http://127.0.0.1:3000" in out, out
run_call = docker_calls()[-1]
assert run_call.startswith("run ") and "-p 127.0.0.1:3000:3000" in run_call and "--name trucha-lab-juice-shop" in run_call, run_call
code, out = run("cancel")
assert code == 0 and docker_calls()[-1] == "stop trucha-lab-juice-shop", docker_calls()
assert not list(WU.glob("*juice*"))

# reto libre fuera del plan con caracteres que Obsidian no admite; el plan no cambia
before = PLAN.read_text(encoding="utf-8")
code, out = run("start", "reto: raro/feo#1")
assert code == 0 and "fuera del plan" in out, out
clock["t"] += dt.timedelta(minutes=5)
assert run("done")[0] == 0
assert (WU / "Writeup - reto raro feo 1.md").exists(), list(WU.iterdir())
assert PLAN.read_text(encoding="utf-8") == before

# repetir un reto no pisa el writeup anterior: el segundo lleva la fecha
clock["t"] = dt.datetime(2026, 11, 14, 10, 0)
run("start", "reto: raro/feo#1")
clock["t"] += dt.timedelta(minutes=1)
assert run("done")[0] == 0
assert (WU / "Writeup - reto raro feo 1 (2026-11-14).md").exists(), list(WU.iterdir())

# un lab que falla al arrancar no deja sesión colgada
(BIN / "docker").write_text("#!/bin/sh\necho 'port is already allocated' >&2\nexit 1\n")
code, out = run("start", "dvwa")
assert code == 1 and "port is already allocated" in out, out
assert "No hay ninguna sesión" in run("status")[1]

# labs y ayuda
assert all(n in run("labs")[1] for n in ("juice-shop", "dvwa", "webgoat"))
assert run()[0] == 2 and run("vuela")[0] == 2
print("OK: trucha-lab")
