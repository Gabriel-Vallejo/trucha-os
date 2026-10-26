import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

// Visualizador de audio a lo ancho, con su propio cava (el CavaService de DMS solo da 6 barras)
DesktopPluginComponent {
    id: root

    // tema activo de Trucha OS! (trucha-theme); se recarga solo al cambiar
    property var theme: ({})
    FileView {
        id: themeFile
        path: "__HOME__/.config/trucha-os/current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.theme = JSON.parse(text()); } catch (e) { root.theme = {}; }
        }
    }

    minWidth: 300
    minHeight: 60

    readonly property int bars: 72
    readonly property real gap: 4
    property var values: []

    Process {
        id: cava
        running: true
        command: ["sh", "-c", `conf=$(mktemp --suffix=.trucha-cava); cat > "$conf" <<'CAVA'
[general]
framerate=40
bars=${root.bars}
autosens=1
sleep_timer=2
lower_cutoff_freq=40
higher_cutoff_freq=14000

[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
ascii_max_range=1000
channels=mono
mono_option=average

[smoothing]
noise_reduction=60
monstercat=1
CAVA
exec cava -p "$conf" < /dev/null`]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = data.split(";");
                if (parts.length < root.bars)
                    return;
                root.values = parts.slice(0, root.bars).map(v => (parseInt(v, 10) || 0) / 1000);
            }
        }
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: root.bars

            Rectangle {
                required property int index
                readonly property real level: root.values[index] ?? 0
                readonly property real barW: (root.width - (root.bars - 1) * root.gap) / root.bars

                x: index * (barW + root.gap)
                width: barW
                height: Math.max(3, root.height * level)
                y: root.height - height
                radius: Math.min(barW / 2, 4)
                opacity: 0.35 + 0.55 * level

                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.theme.accentBright ?? "#ff5a5f" }
                    GradientStop { position: 1.0; color: root.theme.accentDark ?? "#a32a2c" }
                }

                Behavior on height {
                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
