#!/usr/bin/env python3
"""Pruebas de trucha-copilot contra un Ollama simulado (HTTP local).  python3 tests/copilot.test.py"""
import contextlib, importlib.machinery, importlib.util, io, json, os, re, tempfile, threading, zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TMP = Path(tempfile.mkdtemp())
VAULT = TMP / "vault"
os.environ.update(HOME=str(TMP), TRUCHA_COPILOT_VAULT=str(VAULT), TRUCHA_COPILOT_MODEL="modelo-falso")
loader = importlib.machinery.SourceFileLoader("tc", str(REPO / "dotfiles/.local/bin/trucha-copilot"))
spec = importlib.util.spec_from_loader("tc", loader)
tc = importlib.util.module_from_spec(spec)
loader.exec_module(tc)

embedded, chats, generated = [], [], []
digest = {"value": "aaa"}   # lo que Ollama dice tener del modelo de embeddings
loaded = []                 # modelos «en la GPU» según /api/ps
reply = {"content": "Usa una cola de prioridad [1]."}


def vector(text, dims=256):
    """Bolsa de palabras con hash: textos con palabras en común quedan cerca (sin la instrucción de consulta)."""
    v = [0.0] * dims
    for word in re.findall(r"\w+", text.removeprefix(tc.QUERY_PREFIX).lower()):
        v[zlib.crc32(word.encode()) % dims] += 1
    return v


class FakeOllama(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        if self.path == "/api/tags":
            models = [{"name": tc.EMBED_MODEL, "digest": digest["value"]}] if digest["value"] else []
            self.wfile.write(json.dumps({"models": models}).encode())
        elif self.path == "/api/ps":
            self.wfile.write(json.dumps({"models": [{"name": m} for m in loaded]}).encode())

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.send_response(200)
        self.end_headers()
        if self.path == "/api/embed":
            embedded.extend(body["input"])
            self.wfile.write(json.dumps({"embeddings": [vector(t) for t in body["input"]]}).encode())
        elif self.path == "/api/chat":
            chats.append(body)
            for part in ({"message": {"thinking": "pienso"}}, {"message": reply},
                         {"done": True}):
                self.wfile.write((json.dumps(part) + "\n").encode())
        elif self.path == "/api/generate":
            generated.append(body)
            self.wfile.write(b"{}")


server = ThreadingHTTPServer(("127.0.0.1", 0), FakeOllama)
threading.Thread(target=server.serve_forever, daemon=True).start()
tc.OLLAMA = f"http://127.0.0.1:{server.server_port}"


def write(rel, text):
    path = VAULT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def run(*args):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = tc.main(["trucha-copilot", *args])
    return code, out.getvalue()


# troceado: sin frontmatter, sin H1 ni 🧭, corta por ## y ###, respeta los bloques de código y el tope
parts = tc.chunks("40_Conocimiento/EDA/Grafos.md", "---\ntipo: fuente\n---\n# Grafos\n🧭 [[Inicio]] › [[EDA]]\n"
                  "Intro.\n## Dijkstra\nCamino mínimo.\n```c\n## no es un título\n```\n### Coste\nO(E log V)\n"
                  "## Largo\n" + ("palabra " * 400 + "\n\n") * 2)
assert parts[0] == "Grafos\n\nIntro.", parts[0]
assert parts[1].startswith("Grafos › Dijkstra\n\nCamino mínimo.") and "## no es un título" in parts[1]
assert parts[2] == "Grafos › Coste\n\nO(E log V)"
assert all(p.startswith("Grafos › Largo") for p in parts[3:]) and len(parts) > 4
assert all(len(p.split("\n\n", 1)[1]) <= tc.MAX_CHARS for p in parts)
assert not any("tipo: fuente" in p or "🧭" in p for p in parts)

# vault de prueba: solo cuentan las notas (ni carpetas ocultas, ni Excalidraw, ni CLAUDE.md)
write("40_Conocimiento/EDA/Dijkstra.md", "# Dijkstra\n## Idea\nEl algoritmo de Dijkstra calcula el camino mínimo "
      "en un grafo con pesos usando una cola de prioridad.")
write("40_Conocimiento/Cálculo/Fourier.md", "# Fourier\n## Serie\nLa serie de Fourier descompone una señal periódica en senos.")
write(".obsidian/plugin.md", "no")
write("Dibujos/mapa.excalidraw.md", "no")
write("CLAUDE.md", "no")
assert set(tc.notes(VAULT)) == {"40_Conocimiento/EDA/Dijkstra.md", "40_Conocimiento/Cálculo/Fourier.md"}

# índice incremental: la segunda vez no se embebe nada; luego solo lo cambiado, y lo borrado desaparece
db = tc.connect()
assert tc.update(db) == 2 and len(embedded) == 2
embedded.clear()
assert tc.update(db) == 0 and not embedded
path = write("40_Conocimiento/EDA/Dijkstra.md", "# Dijkstra\n## Idea\nCamino mínimo en un grafo con pesos, "
             "con una cola de prioridad y relajando aristas.")
os.utime(path, (1, 2))
(VAULT / "40_Conocimiento/Cálculo/Fourier.md").unlink()
assert tc.update(db) == 1 and len(embedded) == 1 and embedded[0].startswith("Dijkstra › Idea")
assert [r[0] for r in db.execute("SELECT DISTINCT path FROM chunks")] == ["40_Conocimiento/EDA/Dijkstra.md"]
write("40_Conocimiento/Cálculo/Fourier.md", "# Fourier\n## Serie\nLa serie de Fourier descompone una señal periódica en senos.")

# búsqueda: la nota relevante sale primero
code, out = run("search", "camino mínimo en un grafo")
assert code == 0 and out.splitlines()[0].split("  ")[1] == "Dijkstra › Idea", out
assert embedded[-1].startswith(tc.QUERY_PREFIX)

# pregunta: manda los fragmentos al modelo elegido y cita solo la fuente usada
code, out = run("ask", "¿cómo", "va", "Dijkstra?")
assert code == 0 and "Usa una cola de prioridad [1]." in out and "pienso" in out, out
assert "Fuentes" in out and "[1] Dijkstra › Idea" in out and "[2]" not in out.split("Fuentes")[1], out
assert chats[-1]["model"] == "modelo-falso" and chats[-1]["options"]["num_ctx"] == tc.NUM_CTX
assert chats[-1]["think"] is False
assert "[1] Dijkstra › Idea" in chats[-1]["messages"][1]["content"]
assert chats[-1]["messages"][1]["content"].endswith("Pregunta: ¿cómo va Dijkstra?")

# con «!» delante razona, con más contexto, y el «!» no llega a la pregunta
assert run("ask", "!", "¿cómo va Dijkstra?")[0] == 0
assert chats[-1]["think"] is True and chats[-1]["options"]["num_ctx"] == tc.THINK_CTX
assert chats[-1]["messages"][1]["content"].endswith("Pregunta: ¿cómo va Dijkstra?")
assert run("ask", "!!")[0] == 2

# citas: no cuentan las de fórmulas, código o índices (a[2]); sí las seguidas [2][1]
reply["content"] = "Mira $x[2]$, `v[2]` y a[2]; lo dice [1]."
out = run("ask", "Dijkstra grafo camino")[1].split("Fuentes")[1]
assert "[1]" in out and "[2]" not in out, out
reply["content"] = "Lo dicen [2][1]."
out = run("ask", "Dijkstra grafo camino")[1].split("Fuentes")[1]
assert "[1]" in out and "[2]" in out, out
reply["content"] = "Usa una cola de prioridad [1]."

# warm carga el modelo de chat; con muchas notas cambiadas se saca de la GPU antes de indexar
assert run("warm")[0] == 0 and generated[-1] == {"model": "modelo-falso", "keep_alive": "10m"}
loaded.append("modelo-falso")
tc.BULK = 1
assert run("index")[0] == 0 and generated[-1] == {"model": "modelo-falso", "keep_alive": 0}
tc.BULK = 20

# si Ollama actualiza el modelo de embeddings (otro digest), se rehace todo; si falta, se avisa
embedded.clear()
digest["value"] = "bbb"
assert tc.update(db) == 2 and len(embedded) == 2
digest["value"] = ""
try:
    tc.update(db)
    raise AssertionError("debía fallar")
except SystemExit as e:
    assert "ollama pull" in str(e), e
digest["value"] = "bbb"

# index rehace todo; sin pregunta o con orden desconocida enseña la ayuda
embedded.clear()
assert run("index")[0] == 0 and len(embedded) == 2
assert run("ask")[0] == 2 and run("borra", "todo")[0] == 2

# Ollama caído: mensaje claro, sin traza
server.shutdown()
server.server_close()
try:
    tc.embed(["hola"])
    raise AssertionError("debía fallar")
except SystemExit as e:
    assert "No puedo hablar con Ollama" in str(e), e
print("OK: trucha-copilot")
