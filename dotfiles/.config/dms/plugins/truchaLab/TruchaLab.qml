import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

// Cronómetro de trucha-lab en la barra, siempre visible: gris sin reto, carmesí con el tiempo con un reto en marcha.
// Clic: con reto, terminar (escribe el writeup y lo abre en Obsidian), cancelar y abrir el lab;
// sin reto, los pendientes de la semana del plan y los labs, que arrancan al pulsarlos.
PluginComponent {
    id: root

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/trucha-lab"
    property var session: null
    property var theme: ({})
    property real nowMs: Date.now()
    property string weekTitle: ""
    property var pending: []

    // lab.json aparece con `start` y desaparece con `done`/`cancel`; se relee cada segundo
    // porque un archivo que aún no existe no se puede vigilar
    FileView {
        id: labFile
        path: Quickshell.env("HOME") + "/.local/state/trucha-os/lab.json"
        printErrors: false
        onLoaded: {
            try { root.session = JSON.parse(text()); } catch (e) { root.session = null; }
        }
        onLoadFailed: root.session = null
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/trucha-os/current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.theme = JSON.parse(text()); } catch (e) { root.theme = {}; }
        }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            labFile.reload();
            root.nowMs = Date.now();
        }
    }

    // pendientes de la semana: la salida de `trucha-lab plan` («  ⬜ reto  ·  plataforma · …»)
    Process {
        id: planProc
        command: [root.bin, "plan"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                root.weekTitle = (lines[0] ?? "").replace(/: \d+\/\d+ hechos$/, "");
                root.pending = lines.filter(l => l.startsWith("  ⬜ ")).map(l => {
                    const [reto, info] = l.slice(4).split("  ·  ");
                    return { reto: reto, info: info ?? "" };
                });
            }
        }
    }

    readonly property bool active: session !== null && !!session.inicio
    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string pixel: "Departure Mono"
    // «inicio» es hora local sin zona (2026-11-14T18:00:00): Date.parse la toma como local
    readonly property int seconds: active ? Math.max(0, Math.floor((nowMs - Date.parse(session.inicio)) / 1000)) : 0
    readonly property string clock: {
        const h = Math.floor(seconds / 3600), m = Math.floor(seconds % 3600 / 60), s = seconds % 60;
        const mm = String(m).padStart(2, "0"), ss = String(s).padStart(2, "0");
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss;
    }
    readonly property string labUrl: {
        const ports = { "juice-shop": "3000", "dvwa": "8081", "webgoat": "8082/WebGoat" };
        return active && session.lab ? "http://127.0.0.1:" + (ports[session.lab] ?? "") : "";
    }
    readonly property int shown: Math.min(pending.length, 8)

    // al acabar un reto cambia el plan: se vuelve a leer
    onActiveChanged: if (!active) planProc.running = true
    Component.onCompleted: planProc.running = true

    function run(args) {
        Quickshell.execDetached([root.bin].concat(args));
        root.closePopout();
    }

    horizontalBarPill: Component {
        Row {
            spacing: 4
            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "timer"
                color: root.active ? root.crimson : root.ash
                size: Theme.iconSize - 4
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.active
                text: root.clock
                color: root.bone
                font.family: root.pixel
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }
    // barra vertical: no cabe mm:ss, así que van los minutos debajo (como el % de la batería)
    verticalBarPill: Component {
        Column {
            spacing: 0
            DIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "timer"
                color: root.active ? root.crimson : root.ash
                size: Theme.iconSize - 2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.active
                text: root.seconds < 3600 ? String(Math.floor(root.seconds / 60))
                                          : Math.floor(root.seconds / 3600) + "h" + String(Math.floor(root.seconds % 3600 / 60)).padStart(2, "0")
                color: root.bone
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    popoutWidth: 320

    popoutContent: Component {
        Item {
            width: parent.width
            // DMS mide el popout por implicitHeight: el de la columna que se ve
            implicitHeight: root.active ? activeCol.implicitHeight : idleCol.implicitHeight

            // con un reto en marcha
            Column {
                id: activeCol
                visible: root.active
                width: parent.width
                spacing: 8

                Text {
                    width: parent.width
                    text: root.session?.reto ?? ""
                    textFormat: Text.PlainText
                    color: root.bone
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.active ? [root.session.plataforma, root.session.categoria, root.session.dificultad].filter(x => x).join(" · ")
                                        + (root.session.semana ? " · semana " + root.session.semana : "") : ""
                    textFormat: Text.PlainText
                    color: root.ash
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                }
                Text {
                    text: root.clock
                    color: root.crimson
                    font.family: root.pixel
                    font.pixelSize: 38
                }
                Text {
                    visible: root.labUrl !== ""
                    text: root.labUrl
                    color: root.ash
                    font.family: root.pixel
                    font.pixelSize: 12
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24

                    Repeater {
                        model: [
                            { icon: "check_circle", label: "Terminar", args: ["done", "--abrir"], show: true },
                            { icon: "cancel", label: "Cancelar", args: ["cancel"], show: true },
                            { icon: "open_in_browser", label: "Abrir lab", args: [], show: root.labUrl !== "" }
                        ]
                        delegate: Column {
                            required property var modelData
                            visible: modelData.show
                            spacing: 2
                            DIconButton {
                                anchors.horizontalCenter: parent.horizontalCenter
                                iconName: parent.modelData.icon
                                iconColor: parent.modelData.icon === "check_circle" ? root.crimson : root.bone
                                onClicked: parent.modelData.args.length ? root.run(parent.modelData.args)
                                                                         : Quickshell.execDetached(["xdg-open", root.labUrl])
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.modelData.label
                                color: root.ash
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }

            // sin reto: pendientes de la semana y labs; un clic arranca el cronómetro
            Column {
                id: idleCol
                visible: !root.active
                width: parent.width
                spacing: 6

                Text {
                    width: parent.width
                    text: root.weekTitle || "Sin reto en marcha"
                    textFormat: Text.PlainText
                    color: root.bone
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.pending.length ? "Pulsa un reto para empezar" : "Semana completa ✅"
                    color: root.ash
                    font.pixelSize: Theme.fontSizeSmall
                }

                ListView {
                    width: parent.width
                    height: Math.max(root.shown, 1) * 34
                    clip: true
                    interactive: contentHeight > height
                    model: root.pending

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 34
                        radius: 8
                        color: hover.hovered ? (root.theme.card ?? "#1c1c20") : "transparent"
                        HoverHandler { id: hover }
                        TapHandler { onTapped: root.run(["start", parent.modelData.reto]) }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.52
                            text: parent.modelData.reto
                            textFormat: Text.PlainText
                            color: root.bone
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeMedium
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.44
                            horizontalAlignment: Text.AlignRight
                            text: parent.modelData.info
                            textFormat: Text.PlainText
                            color: root.ash
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Repeater {
                        model: ["juice-shop", "dvwa", "webgoat"]
                        delegate: Rectangle {
                            required property string modelData
                            width: label.implicitWidth + 20
                            height: 28
                            radius: 14
                            color: labHover.hovered ? (root.theme.card ?? "#1c1c20") : "transparent"
                            border.color: root.ash
                            border.width: 1
                            HoverHandler { id: labHover }
                            TapHandler { onTapped: root.run(["start", parent.modelData]) }
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: "🧪 " + parent.modelData
                                color: root.bone
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }
}
