#!/usr/bin/env python3
"""Pruebas de trucha-discord-voice contra un Discord simulado (socket Unix local).  python3 tests/discord_voice.test.py"""
import importlib.machinery, importlib.util, json, os, socket, stat, struct, sys, tempfile, threading, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TMP = Path(tempfile.mkdtemp())
os.environ.update(HOME=str(TMP), XDG_RUNTIME_DIR=str(TMP))
loader = importlib.machinery.SourceFileLoader("tdv", str(REPO / "dotfiles/.local/bin/trucha-discord-voice"))
spec = importlib.util.spec_from_loader("tdv", loader)
tdv = importlib.util.module_from_spec(spec)
loader.exec_module(tdv)
tdv.WAIT = 0.05

MEMBERS = [{"nick": "Ana", "user": {"id": "1", "username": "ana"}, "voice_state": {"self_mute": True}},
           {"user": {"id": "2", "username": "<img src=x>"}, "voice_state": {"self_deaf": True}}]
received = []


class FakeDiscord(threading.Thread):
    """Habla el protocolo de tramas: op y longitud en little-endian, y JSON."""
    def __init__(self, path, auth_error=None):
        super().__init__(daemon=True)
        self.auth_error = auth_error
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(path)
        self.server.listen()
        self.conn = None

    def send(self, op, body):
        data = json.dumps(body).encode()
        self.conn.sendall(struct.pack("<II", op, len(data)) + data)

    def event(self, evt, data):
        self.send(1, {"cmd": "DISPATCH", "evt": evt, "data": data})

    def recv(self):
        head = self.conn.recv(8, socket.MSG_WAITALL)
        if len(head) < 8:
            return None
        op, size = struct.unpack("<II", head)
        return op, json.loads(self.conn.recv(size, socket.MSG_WAITALL))

    def run(self):
        self.conn, _ = self.server.accept()
        while (frame := self.recv()) is not None:
            op, body = frame
            if op == 0:
                self.send(1, {"cmd": "DISPATCH", "evt": "READY", "data": {"v": 1}})
                continue
            received.append(body)
            reply = {"cmd": body["cmd"], "nonce": body["nonce"], "data": {}}
            if body["cmd"] == "AUTHORIZE":
                if self.auth_error:
                    reply.update(evt="ERROR", data={"code": 5000, "message": self.auth_error})
                else:
                    reply["data"] = {"code": "codigo"}
            elif body["cmd"] == "GET_SELECTED_VOICE_CHANNEL":
                reply["data"] = {"id": "9", "name": "Sala", "voice_states": MEMBERS}
            elif body["cmd"] == "GET_VOICE_SETTINGS":
                reply["data"] = {"mute": False, "deaf": False}
            elif body["cmd"] == "SET_VOICE_SETTINGS":
                reply["data"] = body["args"]
            self.send(1, reply)


def until(fn, seconds=3):
    end = time.time() + seconds
    while time.time() < end:
        if fn():
            return True
        time.sleep(0.02)
    return False


def state():
    try:
        return json.loads(tdv.STATE.read_text())
    except (OSError, ValueError):
        return {}


# credenciales: sin archivo, con permisos abiertos y con datos incompletos
try:
    tdv.load_config(); raise SystemExit("debía fallar sin credenciales")
except tdv.ConfigError:
    pass
tdv.CONFIG.parent.mkdir(parents=True)
tdv.CONFIG.write_text(json.dumps({"client_id": "123", "client_secret": "secreto"}))
tdv.CONFIG.chmod(0o644)
try:
    tdv.load_config(); raise SystemExit("debía rechazar permisos abiertos")
except tdv.ConfigError as e:
    assert "secreto" not in str(e)
tdv.CONFIG.chmod(0o600)
assert tdv.load_config()["client_id"] == "123"

# autorización, canal, eventos y comandos
exchanged = []
tdv.token_request = lambda fields, config: exchanged.append(fields) or {"access_token": "tok", "refresh_token": "ref", "expires_in": 3600}
fake = FakeDiscord(str(TMP / "discord-ipc-0"))
fake.start()
stop = threading.Event()
threading.Thread(target=tdv.run, args=(stop,), daemon=True).start()
assert until(lambda: state().get("inVoice")), state()
s = state()
assert s["connected"] and s["channel"] == "Sala" and not s["mute"]
assert [m["name"] for m in s["members"]] == ["Ana", "<img src=x>"]
assert s["members"][0]["mute"] and s["members"][1]["deaf"]
assert exchanged[0]["grant_type"] == "authorization_code" and exchanged[0]["code"] == "codigo"
assert stat.S_IMODE(tdv.TOKEN.stat().st_mode) == 0o600 and stat.S_IMODE(tdv.STATE.stat().st_mode) == 0o600
subs = {(b["evt"], b["args"].get("channel_id")) for b in received if b["cmd"] == "SUBSCRIBE"}
assert ("SPEAKING_START", "9") in subs and ("VOICE_CHANNEL_SELECT", None) in subs
scopes = next(b for b in received if b["cmd"] == "AUTHORIZE")["args"]["scopes"]
assert set(scopes) == {"rpc", "rpc.voice.read", "rpc.voice.write"}

fake.event("SPEAKING_START", {"user_id": "1", "channel_id": "9"})
assert until(lambda: state()["members"][0]["speaking"])
fake.event("SPEAKING_STOP", {"user_id": "1", "channel_id": "9"})
assert until(lambda: not state()["members"][0]["speaking"])
fake.event("VOICE_STATE_CREATE", {"user": {"id": "3", "username": "eva"}, "voice_state": {}})
assert until(lambda: len(state()["members"]) == 3)
fake.event("VOICE_STATE_DELETE", {"user": {"id": "3"}})
assert until(lambda: len(state()["members"]) == 2)

assert tdv.send_command("mute") == 0
assert until(lambda: state()["mute"])
assert next(b for b in received if b["cmd"] == "SET_VOICE_SETTINGS")["args"] == {"mute": True}
assert tdv.send_command("rm -rf") == 2   # solo órdenes conocidas

fake.event("VOICE_CHANNEL_SELECT", {"channel_id": None})
MEMBERS.clear()
stop.set()
fake.conn.close()
assert until(lambda: not state().get("connected", True)), state()

# setup guarda las claves con permisos 600 y rechaza datos malos
tdv.CONFIG.unlink()
tdv.input = lambda _: "abc"
tdv.getpass.getpass = lambda _: "s3creto"
assert tdv.setup() == 1 and not tdv.CONFIG.exists()
tdv.input = lambda _: "123"
assert tdv.setup() == 0 and stat.S_IMODE(tdv.CONFIG.stat().st_mode) == 0o600
assert tdv.load_config()["client_secret"] == "s3creto" and not tdv.TOKEN.exists()

# rechazar la autorización no debe repetir la ventana en bucle
assert tdv.backoff(tdv.AuthError("no")) > 30 and tdv.backoff(ConnectionError()) <= 10
print("OK: trucha-discord-voice")
