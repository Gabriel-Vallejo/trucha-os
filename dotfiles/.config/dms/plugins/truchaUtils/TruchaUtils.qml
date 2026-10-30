import QtQuick
import Quickshell
import qs.Services
import "utils.js" as U

// Utilidades Trucha: se abre con "=" en el lanzador (⊞+Espacio).
// Escribe una cuenta, un número, un color #hex, "ts", o cualquier texto (te da base64/hex/rot13/url
// y lo decodifica si puede). Prefijos: b64 · b64d · hex · unhex · rot13 · url · urld · bin · unbin · up · low · rev · len.
// Al elegir un resultado se copia al portapapeles. Vacío: selector de color y capturas.
Item {
    id: root

    property var pluginService: null
    property string trigger: "="
    signal itemsChanged()

    // acción:  copy:<texto> · run:<id de herramienta>
    readonly property var tools: [
        { name: "Selector de color", comment: "Elige un píxel de la pantalla y copia su #hex", icon: "material:colorize", action: "run:pick" },
        { name: "Captura de zona", comment: "Selecciona un área (niri)", icon: "material:screenshot_region", action: "run:shot" },
        { name: "Captura de ventana", comment: "La ventana enfocada", icon: "material:select_window", action: "run:shotwin" },
        { name: "Captura de pantalla", comment: "La pantalla entera", icon: "material:fullscreen", action: "run:shotscreen" },
        { name: "Calculadora · 2^10 / 3", comment: "sqrt, sin, log, pi, 5!, 0xff… · coma o punto decimal", icon: "material:calculate", action: "hint" },
        { name: "Conversiones · b64 hola · unhex 6869", comment: "o escribe texto sin prefijo y salen todas", icon: "material:swap_horiz", action: "hint" },
        { name: "Números y fechas · 255 · ts 1700000000", comment: "dec/hex/bin/oct, carácter y timestamp Unix", icon: "material:pin", action: "hint" }
    ]

    readonly property var commands: ({
        "pick": ["sh", "-c", "c=$(niri msg pick-color | grep -oiE '#[0-9a-f]{6}' | head -1) && [ -n \"$c\" ] && printf %s \"$c\" | wl-copy && notify-send -a 'Trucha OS!' -i colorize \"Color copiado\" \"$c\""],
        "shot": ["niri", "msg", "action", "screenshot"],
        "shotwin": ["niri", "msg", "action", "screenshot-window"],
        "shotscreen": ["niri", "msg", "action", "screenshot-screen"]
    })

    function getItems(query) {
        const q = (query || "").trim();
        if (q === "")
            return tools.map(t => Object.assign({ categories: ["Utilidades Trucha"] }, t));
        return U.results(q, Date.now()).map(r => ({
            name: r.name,
            comment: r.comment + (r.value ? " · Intro para copiar" : ""),
            icon: r.icon,
            action: r.value ? "copy:" + r.value : "hint",
            categories: ["Utilidades Trucha"]
        }));
    }

    function executeItem(item) {
        const action = item.action || "";
        const sep = action.indexOf(":");
        const kind = sep < 0 ? action : action.substring(0, sep);
        const arg = sep < 0 ? "" : action.substring(sep + 1);
        if (kind === "copy") {
            Quickshell.execDetached(["wl-copy", "--", arg]);
            ToastService.showInfo("Copiado", arg.length > 80 ? arg.substring(0, 80) + "…" : arg);
        } else if (kind === "run" && commands[arg]) {
            Quickshell.execDetached(commands[arg]);
        }
    }
}
