import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import "competis.js" as C

// Cola de competis: próximos CTF online de CTFtime + tus competis de ~/.config/trucha-os/competis.json,
// con cuenta atrás. Las tuyas llevan ◆ y entran siempre; un clic abre la web del evento.
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

    property var propias: []
    FileView {
        path: "__HOME__/.config/trucha-os/competis.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.propias = C.desdePropias(JSON.parse(text())); } catch (e) { root.propias = []; }
        }
    }

    // CTFtime de los próximos 30 días; se pide al arrancar y cada 3 h
    property var ctf: []
    Process {
        id: ctftime
        running: true
        command: ["sh", "-c", "a=$(date +%s); curl -sf -m 20 -A 'Mozilla/5.0' \"https://ctftime.org/api/v1/events/?limit=40&start=$a&finish=$((a + 2592000))\""]
        stdout: StdioCollector {
            onStreamFinished: {
                // si falla la red se queda la lista anterior
                try { root.ctf = C.desdeCtftime(JSON.parse(this.text)); } catch (e) {}
            }
        }
    }
    Timer {
        interval: 3 * 3600 * 1000
        repeat: true
        running: true
        onTriggered: ctftime.running = true
    }

    property real ahora: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.ahora = Date.now()
    }

    minWidth: 260
    minHeight: 200

    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string pixel: "Departure Mono"
    readonly property var lista: C.cola(propias, ctf, ahora, 5)

    Column {
        anchors.fill: parent
        spacing: 12

        Row {
            spacing: 10
            Text {
                id: kanji
                text: "競技"
                color: root.crimson
                font.family: "Noto Serif JP"
                font.weight: Font.Black
                font.pixelSize: 22
            }
            Text {
                anchors.baseline: kanji.baseline
                text: "COMPETIS"
                color: root.ash
                font.family: root.pixel
                font.pixelSize: 12
                font.letterSpacing: 3
            }
        }

        Text {
            visible: root.lista.length === 0
            text: "SIN COMPETIS A LA VISTA"
            color: root.ash
            font.family: root.pixel
            font.pixelSize: 12
            font.letterSpacing: 2
        }

        Repeater {
            model: root.lista
            Item {
                id: fila
                required property var modelData
                readonly property var c: C.cuenta(modelData, root.ahora)
                width: parent.width
                height: contenido.height

                Column {
                    id: contenido
                    width: parent.width
                    spacing: 4

                    Item {
                        width: parent.width
                        height: tiempo.height
                        Text {
                            anchors.left: parent.left
                            anchors.right: tiempo.left
                            anchors.rightMargin: 10
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            text: (fila.modelData.propia ? "◆ " : "") + fila.modelData.nombre.toUpperCase()
                            // el título viene de CTFtime: nada de HTML
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: fila.modelData.propia ? root.bone : root.ash
                            font.family: root.pixel
                            font.pixelSize: 12
                            font.letterSpacing: 1
                        }
                        Text {
                            id: tiempo
                            anchors.right: parent.right
                            text: fila.c.texto
                            color: fila.c.enCurso ? root.crimson : root.bone
                            font.family: root.pixel
                            font.pixelSize: 18
                        }
                    }
                    // en marcha: barra de lo que lleva; si no, solo la pista
                    Rectangle {
                        width: parent.width
                        height: 2
                        color: root.theme.track ?? "#2a2a30"
                        Rectangle {
                            height: parent.height
                            width: parent.width * fila.c.progreso
                            color: root.crimson
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: fila.modelData.url !== ""
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Qt.openUrlExternally(fila.modelData.url)
                }
            }
        }
    }
}
