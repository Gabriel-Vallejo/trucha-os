#!/usr/bin/env python3
"""wpe-ocultar.py <scene.pkg> <nombre>... — oculta objetos de una escena de Wallpaper Engine.
linux-wallpaperengine no hereda la visibilidad de los grupos que la escena ata a sus propiedades
(p. ej. el reproductor de "Katana Girl"), y salen sin textura: un cuadrado blanco. Aquí se marcan
"visible": false en scene.json y se vuelve a empaquetar el .pkg en el mismo sitio."""
import json
import struct
import sys


def leer(datos):
    """(cabecera, [(nombre, bytes)]) de un .pkg: cadena de versión, nº de ficheros, índice y datos."""
    u32 = lambda o: struct.unpack_from("<I", datos, o)[0]
    n = u32(0)
    version, o = datos[4:4 + n], 4 + n
    cuantos, o = u32(o), o + 4
    indice = []
    for _ in range(cuantos):
        ln = u32(o)
        nombre = datos[o + 4:o + 4 + ln].decode()
        o += 4 + ln
        indice.append((nombre, u32(o), u32(o + 4)))
        o += 8
    return version, [(nombre, datos[o + off:o + off + ln]) for nombre, off, ln in indice]


def escribir(version, ficheros):
    cab = struct.pack("<I", len(version)) + version + struct.pack("<I", len(ficheros))
    cuerpo, off = b"", 0
    for nombre, contenido in ficheros:
        nb = nombre.encode()
        cab += struct.pack("<I", len(nb)) + nb + struct.pack("<II", off, len(contenido))
        cuerpo += contenido
        off += len(contenido)
    return cab + cuerpo


def main(pkg, nombres):
    version, ficheros = leer(open(pkg, "rb").read())
    ocultos = []
    for i, (nombre, contenido) in enumerate(ficheros):
        if nombre == "scene.json":
            escena = json.loads(contenido)
            for ob in escena["objects"]:
                if ob.get("name") in nombres:
                    ob["visible"] = False
                    ocultos.append(ob["name"])
            ficheros[i] = (nombre, json.dumps(escena).encode())
    nuevo = escribir(version, ficheros)
    # comprobación: el paquete nuevo se lee igual, con los mismos ficheros y en el mismo orden
    assert [n for n, _ in leer(nuevo)[1]] == [n for n, _ in ficheros]
    open(pkg, "wb").write(nuevo)
    print(f"ocultos {len(ocultos)}: {', '.join(sorted(set(ocultos)))}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], set(sys.argv[2:]))
