import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

// Pomodoro 25/5 (15 tras la cuarta ronda): anillo carmesí que se vacía, tiempo en pixel y la fase en kanji.
// Clic: empezar/pausar · clic derecho: reiniciar · al acabar una fase avisa y espera al siguiente clic.
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

    minWidth: 120
    minHeight: 120

    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string pixel: "Departure Mono"

    readonly property int focusSecs: 25 * 60
    readonly property int shortSecs: 5 * 60
    readonly property int longSecs: 15 * 60

    property bool onBreak: false
    property int round: 1               // 1..4
    property bool running: false
    property int total: focusSecs
    property int remaining: focusSecs
    property real deadline: 0           // ms; se cuenta contra el reloj para no acumular deriva

    readonly property real progress: remaining / total

    function toggle() {
        if (running) {
            running = false;
        } else {
            deadline = Date.now() + remaining * 1000;
            running = true;
        }
    }

    function reset() {
        running = false;
        onBreak = false;
        round = 1;
        total = focusSecs;
        remaining = focusSecs;
    }

    function finishPhase() {
        running = false;
        if (onBreak) {
            onBreak = false;
            round = round % 4 + 1;
            total = focusSecs;
            Quickshell.execDetached(["notify-send", "-a", "Trucha OS!", "-i", "timer", "Descanso terminado", "Ronda " + round + " de 4 · clic en el pomodoro para seguir"]);
        } else {
            onBreak = true;
            total = round === 4 ? longSecs : shortSecs;
            Quickshell.execDetached(["notify-send", "-a", "Trucha OS!", "-i", "timer", "Ronda " + round + " completada", (round === 4 ? "Descanso largo" : "Descanso") + " de " + total / 60 + " min · clic para empezarlo"]);
        }
        remaining = total;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            root.remaining = Math.max(0, Math.round((root.deadline - Date.now()) / 1000));
            if (root.remaining === 0)
                root.finishPhase();
        }
    }

    function mmss(s) {
        const m = Math.floor(s / 60), r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    Item {
        id: dial
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        scale: mouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        property real stroke: mouse.containsMouse ? 5 : 3
        Behavior on stroke { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // pista
            ShapePath {
                strokeColor: root.theme.track ?? "#2a2a30"
                strokeWidth: 2
                fillColor: "transparent"
                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - 4
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 360
                }
            }
            // tiempo restante; en descanso pasa a gris
            ShapePath {
                strokeColor: root.onBreak ? root.ash : root.crimson
                strokeWidth: dial.stroke
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    id: arc
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - 4
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * root.progress
                    Behavior on sweepAngle { NumberAnimation { duration: root.running ? 1000 : 450; easing.type: root.running ? Easing.Linear : Easing.OutCubic } }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.onBreak ? "休憩" : "集中"
                color: root.onBreak ? root.ash : root.crimson
                font.family: "Noto Serif JP"
                font.weight: Font.Black
                font.pixelSize: dial.width * 0.13
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.mmss(root.remaining)
                color: root.bone
                opacity: root.running ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: 250 } }
                font.family: root.pixel
                font.pixelSize: dial.width * 0.2
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                topPadding: 4
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 5
                        height: 5
                        radius: 1
                        color: index < root.round - (root.onBreak ? 0 : 1) ? root.crimson : (root.theme.track ?? "#2a2a30")
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => event.button === Qt.RightButton ? root.reset() : root.toggle()
        }
    }
}
