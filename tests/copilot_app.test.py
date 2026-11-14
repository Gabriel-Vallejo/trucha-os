#!/usr/bin/env python3
"""Pruebas de trucha-copilot-app (chats, memoria y turnos) contra un Ollama simulado, sin GTK.
  python3 tests/copilot_app.test.py"""
import importlib.machinery, importlib.util, json, os, tempfile, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TMP = Path(tempfile.mkdtemp())
VAULT = TMP / "vault"
os.environ.update(HOME=str(TMP), TRUCHA_COPILOT_VAULT=str(VAULT), TRUCHA_COPILOT_MODEL="modelo-falso")
loader = importlib.machinery.SourceFileLoader("app", str(REPO / "dotfiles/.local/bin/trucha-copilot-app"))
spec = importlib.util.spec_from_loader("app", loader)
app = importlib.util.module_from_spec(spec)
loader.exec_module(app)
tc = app.tc

chats, embedded = [], []
reply = ["Con una cola de prioridad ", "[1]."]


class FakeOllama(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({"models": [{"name": tc.EMBED_MODEL, "digest": "d"}]}).encode())

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.send_response(200)
        self.end_headers()
        if self.path == "/api/embed":
            embedded.extend(body["input"])
            self.wfile.write(json.dumps({"embeddings": [[1.0, float(len(t) % 7)] for t in body["input"]]}).encode())
        else:
            chats.append(body)
            self.wfile.write((json.dumps({"message": {"thinking": "hmm"}}) + "\n").encode())
            for text in reply:
                self.wfile.write((json.dumps({"message": {"content": text}}) + "\n").encode())


server = ThreadingHTTPServer(("127.0.0.1", 0), FakeOllama)
threading.Thread(target=server.serve_forever, daemon=True).start()
tc.OLLAMA = f"http://127.0.0.1:{server.server_port}"
(VAULT / "EDA").mkdir(parents=True)
(VAULT / "EDA/Dijkstra.md").write_text("# Dijkstra\n## Idea\nCamino mínimo con cola de prioridad.")
(VAULT / "EDA/Grafos.md").write_text("# Grafos\n## BFS\nRecorrido en anchura.")


def turn(chat, question, think=False, cancelled=lambda: False):
    events = []
    app.run_turn(chat, question, think, lambda kind, data: events.append((kind, data)), cancelled)
    return events


# chats: título recortado, orden por actividad y borrado en cascada
db = app.store()
chat = app.new_chat(db, "¿Cómo   va Dijkstra? " + "x" * 80)
title = app.list_chats(db)[0]["title"]
assert title.startswith("¿Cómo va Dijkstra?") and len(title) == app.TITLE_CHARS and title.endswith("…")

# primer turno: eventos en orden, respuesta guardada con sus fuentes citadas
events = turn(chat, "¿Cómo va Dijkstra?")
kinds = [k for k, _ in events]
assert kinds[0] == "searched" and kinds[1] == "thinking" and kinds[-1] == "done", kinds
done = events[-1][1]
assert done["sources"]["cited"] and [s["n"] for s in done["sources"]["items"]] == [1]
assert not done["confused"] and not done["stopped"]
saved = app.messages(db, chat)
assert [m["role"] for m in saved] == ["user", "assistant"]
assert saved[1]["content"] == "Con una cola de prioridad [1]." and saved[1]["thinking"] == "hmm"
assert saved[1]["sources"]["items"][0]["path"] in ("EDA/Dijkstra.md", "EDA/Grafos.md")
assert chats[-1]["think"] is False and len(chats[-1]["messages"]) == 2   # sistema + pregunta

# segundo turno: el modelo ve lo anterior y la búsqueda usa también la pregunta previa
reply[:] = ["No está en tus apuntes."]
events = turn(chat, "¿Y su coste?", think=True)
msgs = chats[-1]["messages"]
assert [m["role"] for m in msgs] == ["system", "user", "assistant", "user"], [m["role"] for m in msgs]
assert msgs[1]["content"] == "¿Cómo va Dijkstra?" and msgs[-1]["content"].endswith("Pregunta: ¿Y su coste?")
assert chats[-1]["think"] is True
assert embedded[-1].endswith("¿Cómo va Dijkstra?\n¿Y su coste?")
done = events[-1][1]
assert done["confused"] and not done["sources"]["cited"] and len(done["sources"]["items"]) == 2

# el historial se recorta a los últimos HISTORY mensajes
for i in range(4):
    turn(chat, f"pregunta {i}")
assert len(chats[-1]["messages"]) == 1 + app.tc.HISTORY + 1

# parar: corta el stream y guarda lo que hubiera
reply[:] = ["uno ", "dos ", "tres"]
seen = []
events = turn(chat, "larga", cancelled=lambda: len(seen) > 0 or seen.append(1))
assert events[-1][0] == "done" and events[-1][1]["stopped"]
assert app.messages(db, chat)[-1]["content"] == ""

# borrar un chat se lleva sus mensajes
app.delete_chat(db, chat)
assert app.list_chats(db) == [] and db.execute("SELECT count(*) FROM messages").fetchone()[0] == 0

# Ollama caído: evento de error, sin traza ni ventana colgada
chat = app.new_chat(db, "otra")
server.shutdown()
server.server_close()
events = turn(chat, "otra")
assert events == [("error", events[0][1])] and "No puedo hablar con Ollama" in events[0][1], events

# enlace a Obsidian y tema por defecto si no hay current.json
assert app.note_uri("40_Conocimiento/EDA 2/Árbol.md") == \
    "obsidian://open?vault=vault&file=40_Conocimiento%2FEDA%202%2F%C3%81rbol.md"
assert app.theme()["accent"] == "#e5383b"
print("OK: trucha-copilot-app")
