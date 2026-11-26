#!/usr/bin/env python3
"""Sintetiza el tema de sonido "trucha-os" (todo original, sin muestras de nadie) y lo deja en
dotfiles/.local/share/sounds/trucha-os/. Solo usa la biblioteca estándar y ffmpeg para pasar a .oga.
    python3 scripts/gen-sonidos.py
Cuerda pulsada tipo koto (Karplus-Strong) en escala japonesa (in), taiko y un "shing" de katana."""
import math
import os
import random
import struct
import subprocess
import tempfile
import wave

SR = 48000
DEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../dotfiles/.local/share/sounds/trucha-os")
random.seed(1337)  # mismo resultado en cada ejecución


def nota(n):
    """Frecuencia de una nota MIDI."""
    return 440.0 * 2 ** ((n - 69) / 12)


def koto(f, seg, brillo=0.5, decae=0.996):
    """Cuerda pulsada: ruido que se filtra solo en un bucle de retardo (Karplus-Strong)."""
    n = max(2, int(SR / f))
    buf = [random.uniform(-1, 1) for _ in range(n)]
    out = []
    for i in range(int(SR * seg)):
        a = buf[i % n]
        b = buf[(i + 1) % n]
        buf[i % n] = decae * ((1 - brillo) * a + brillo * (a + b) / 2)
        out.append(a)
    return out


def campana(parciales, seg, decaimiento):
    """Suma de senos inarmónicos con caída exponencial (metal)."""
    return [sum(amp * math.sin(2 * math.pi * f * t / SR) for f, amp in parciales) * math.exp(-t / SR / decaimiento)
            for t in range(int(SR * seg))]


def taiko(seg=0.6):
    """Golpe grave: seno que baja de 110 a 55 Hz y un poco de ruido en el ataque."""
    out, fase = [], 0.0
    for t in range(int(SR * seg)):
        s = t / SR
        fase += 2 * math.pi * (55 + 55 * math.exp(-s * 18)) / SR
        out.append(math.sin(fase) * math.exp(-s * 6) + random.uniform(-1, 1) * 0.3 * math.exp(-s * 60))
    return out


def soplo(seg, f0, f1):
    """Ruido filtrado con un paso banda que barre de f0 a f1 Hz (whoosh)."""
    out, y1, y2 = [], 0.0, 0.0
    total = int(SR * seg)
    for t in range(total):
        p = t / total
        f = f0 + (f1 - f0) * p
        r = 0.97
        c = 2 * r * math.cos(2 * math.pi * f / SR)
        y = random.uniform(-1, 1) * (1 - r) + c * y1 - r * r * y2
        y2, y1 = y1, y
        out.append(y * math.sin(math.pi * p) * 18)
    return out


def mezcla(*pistas):
    """Suma pistas dadas como (desfase_en_segundos, muestras, ganancia)."""
    largo = max(int(SR * d) + len(m) for d, m, _ in pistas)
    out = [0.0] * largo
    for d, m, g in pistas:
        o = int(SR * d)
        for i, v in enumerate(m):
            out[o + i] += v * g
    return out


def normaliza(m, pico=0.5):
    """Deja el pico en `pico` (≈ -6 dBFS) y suaviza el final para que no haga clic."""
    top = max(abs(v) for v in m) or 1.0
    m = [v * pico / top for v in m]
    cola = min(len(m), int(SR * 0.02))
    for i in range(cola):
        m[-1 - i] *= i / cola
    return m


def guarda(nombre, m):
    os.makedirs(os.path.join(DEST, "stereo"), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as fh:
        wav = fh.name
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in m))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "2", "-c:a", "libvorbis", "-q:a", "5",
                    os.path.join(DEST, "stereo", nombre + ".oga")], check=True)
    os.unlink(wav)


# escala in (miyako-bushi) sobre mi: mi fa la si do
MI4, FA4, LA4, SI4, DO5 = 64, 65, 69, 71, 72
SONIDOS = {
    # notificación: dos pulsos de koto que suben
    "message": lambda: mezcla((0, koto(nota(SI4 + 12), 0.9), 1), (0.09, koto(nota(MI4 + 24), 1.0), 0.9)),
    # notificación crítica: taiko y tres pulsos tensos (fa, el semitono de la escala in)
    "message-new-instant": lambda: mezcla((0, taiko(), 1.2), (0.05, koto(nota(FA4 + 12), 0.8), 0.7),
                                          (0.17, koto(nota(FA4 + 12), 0.8), 0.7), (0.29, koto(nota(MI4 + 12), 1.0), 0.8)),
    # volumen: golpecito de madera muy corto
    "audio-volume-change": lambda: koto(nota(LA4 + 24), 0.09, brillo=0.9, decae=0.97),
    # cargador: arpegio que sube / que baja
    "power-plug": lambda: mezcla((0, koto(nota(MI4 + 12), 0.6), 1), (0.08, koto(nota(LA4 + 12), 0.7), 1)),
    "power-unplug": lambda: mezcla((0, koto(nota(LA4 + 12), 0.6), 1), (0.08, koto(nota(MI4 + 12), 0.7), 1)),
    # login: escala in entera en arpegio, con un taiko suave al principio
    "desktop-login": lambda: mezcla((0, taiko(0.9), 0.6), *[(0.12 + 0.11 * i, koto(nota(n), 1.6), 0.9)
                                                            for i, n in enumerate([MI4, FA4, LA4, SI4, DO5, MI4 + 12])]),
    # ventana abierta: soplo que sube y "shing" metálico de katana
    "window-new": lambda: mezcla((0, soplo(0.09, 1500, 6000), 0.6),
                                 (0.07, campana([(2793, 1), (4186, 0.6), (6272, 0.35), (8372, 0.2)], 0.45, 0.09), 0.9)),
    # ventana cerrada: soplo que baja y golpe sordo
    "window-close": lambda: mezcla((0, soplo(0.14, 4000, 700), 0.7), (0.1, taiko(0.25), 0.35)),
}

INDEX = """[Sound Theme]
Name=Trucha OS!
Comment=Sonidos de Trucha OS!: koto, taiko y katana (sintetizados por gen-sonidos.py)
Directories=stereo

[stereo]
OutputProfile=stereo
"""


def main():
    for nombre, hacer in SONIDOS.items():
        guarda(nombre, normaliza(hacer()))
    with open(os.path.join(DEST, "index.theme"), "w", encoding="utf-8") as fh:
        fh.write(INDEX)
    print(f"✔ {len(SONIDOS)} sonidos en {os.path.normpath(DEST)}")


if __name__ == "__main__":
    main()
