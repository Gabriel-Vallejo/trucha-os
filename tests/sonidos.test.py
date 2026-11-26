#!/usr/bin/env python3
"""Pruebas de trucha-sonidos con eventos de niri inventados (no suena nada).  python3 tests/sonidos.test.py"""
import importlib.machinery, importlib.util, json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("ts", str(REPO / "dotfiles/.local/bin/trucha-sonidos"))
spec = importlib.util.spec_from_loader("ts", loader)
ts = importlib.util.module_from_spec(spec)
loader.exec_module(ts)

ev = lambda **k: json.dumps(k)
win = lambda i, titulo="x": {"id": i, "title": titulo}
eventos = [
    "no es json",
    ev(WindowsChanged={"windows": [win(1), win(2)]}),          # las que ya había: no suenan
    ev(WindowOpenedOrChanged={"window": win(1, "otro título")}),  # cambio de título: no suena
    ev(WindowOpenedOrChanged={"window": win(3)}),               # nueva: suena
    ev(WindowOpenedOrChanged={"window": win(3, "cargada")}),    # la misma cambia: no suena
    ev(WindowFocusChanged={"id": 3}),
    ev(WindowClosed={"id": 2}),                                  # cerrada: suena
    ev(WindowClosed={"id": 99}),                                 # desconocida: no suena
]
assert list(ts.sonidos(eventos)) == ["window-new", "window-close"], list(ts.sonidos(eventos))

# respeta el interruptor de sonidos de DMS
assert ts.activados('{"soundsEnabled": false}') is False
assert ts.activados('{"soundsEnabled": true}') is True
assert ts.activados("{}") is True          # DMS los trae activados por defecto
assert ts.activados("roto") is True
print("OK: trucha-sonidos")
