import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Red a juego con el monitor: bajada y subida en pixel y una gráfica fina de los últimos ~2 min. Sin fondo.
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

    minWidth: 180
    minHeight: 90

    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string pixel: "Departure Mono"

    // DgopService refresca cada 3 s: 40 muestras ≈ 2 min
    readonly property int samples: 40
    property var rx: []
    property var tx: []

    Component.onCompleted: DgopService.addRef(["network"])
    Component.onDestruction: DgopService.removeRef(["network"])

    Connections {
        target: DgopService
        function onNetworkRxRateChanged() {
            root.rx = root.rx.concat([DgopService.networkRxRate]).slice(-root.samples);
            root.tx = root.tx.concat([DgopService.networkTxRate]).slice(-root.samples);
            graph.requestPaint();
        }
    }

    function rate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(bps >= 10485760 ? 0 : 1) + " MB/s";
        if (bps >= 1024) return Math.round(bps / 1024) + " KB/s";
        return Math.round(bps) + " B/s";
    }

    component Rate: Row {
        property string label
        property string value
        property color tint
        spacing: 8
        Text {
            anchors.baseline: val.baseline
            text: parent.label
            color: parent.tint
            font.family: root.pixel
            font.pixelSize: 12
        }
        Text {
            id: val
            text: parent.value
            color: root.bone
            font.family: root.pixel
            font.pixelSize: 18
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width
            height: down.height
            Rate {
                id: down
                label: "↓"
                value: root.rate(DgopService.networkRxRate)
                tint: root.crimson
            }
            Rate {
                anchors.right: parent.right
                label: "↑"
                value: root.rate(DgopService.networkTxRate)
                tint: root.ash
            }
        }

        Canvas {
            id: graph
            width: parent.width
            height: parent.height - down.height - parent.spacing
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                // línea base, como las barras de 2 px del resto de widgets
                ctx.fillStyle = String(root.theme.track ?? "#2a2a30");
                ctx.fillRect(0, height - 2, width, 2);
                const peak = Math.max(1024, ...root.rx, ...root.tx);
                const step = width / (root.samples - 1);
                const pts = (arr) => arr.map((v, i) => [width - (arr.length - 1 - i) * step, height - 2 - (height - 6) * v / peak]);

                const down = pts(root.rx);
                if (down.length > 1) {
                    const grad = ctx.createLinearGradient(0, 0, 0, height);
                    grad.addColorStop(0, Qt.alpha(root.crimson, 0.45));
                    grad.addColorStop(1, Qt.alpha(root.crimson, 0));
                    ctx.beginPath();
                    ctx.moveTo(down[0][0], height - 2);
                    down.forEach(p => ctx.lineTo(p[0], p[1]));
                    ctx.lineTo(down[down.length - 1][0], height - 2);
                    ctx.closePath();
                    ctx.fillStyle = grad;
                    ctx.fill();
                    ctx.beginPath();
                    down.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]));
                    ctx.strokeStyle = String(root.crimson);
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
                const up = pts(root.tx);
                if (up.length > 1) {
                    ctx.beginPath();
                    up.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]));
                    ctx.strokeStyle = String(root.ash);
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                }
            }
        }
    }
}
