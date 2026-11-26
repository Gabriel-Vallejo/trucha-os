import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

// El fondo late con la música: un viñeteado del color de acento que se enciende con los graves.
// Pensado para ocupar toda la pantalla con "clickThrough": true en la instancia.
DesktopPluginComponent {
    id: root

    // tema activo de Trucha OS! (trucha-theme); se recarga solo al cambiar
    property var theme: ({})
    FileView {
        path: "__HOME__/.config/trucha-os/current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.theme = JSON.parse(text()); } catch (e) { root.theme = {}; }
        }
    }

    minWidth: 300
    minHeight: 200

    // envolvente de los graves: sube de golpe con cada golpe y cae poco a poco
    property real nivel: 0

    Process {
        running: true
        command: ["sh", "-c", `conf=$(mktemp --suffix=.trucha-pulso); cat > "$conf" <<'CAVA'
[general]
framerate=40
bars=8
autosens=1
sleep_timer=2
lower_cutoff_freq=30
higher_cutoff_freq=2000

[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
ascii_max_range=1000
channels=mono
mono_option=average
CAVA
exec cava -p "$conf" < /dev/null`]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const v = data.split(";");
                // las dos primeras barras son los graves (bombo y bajo)
                const graves = Math.max(parseInt(v[0], 10) || 0, parseInt(v[1], 10) || 0) / 1000;
                root.nivel = Math.max(graves, root.nivel * 0.86);
            }
        }
    }

    readonly property color acento: theme.accent ?? "#e5383b"

    Shape {
        anchors.fill: parent
        // el borde solo se nota con golpes fuertes: curva cuadrática y tope de 0.7
        opacity: Math.min(0.7, root.nivel * root.nivel * 0.9)
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            startX: 0; startY: 0
            fillGradient: RadialGradient {
                centerX: root.width / 2; centerY: root.height / 2
                focalX: centerX; focalY: centerY
                centerRadius: Math.hypot(root.width, root.height) / 2
                focalRadius: 0
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 0.85; color: Qt.alpha(root.acento, 0.35) }
                GradientStop { position: 1.0; color: root.acento }
            }
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
}
