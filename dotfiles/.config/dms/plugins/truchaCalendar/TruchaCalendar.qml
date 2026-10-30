import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

// Mes en curso: el mes en kanji (十月) y el año en pixel, semana de lunes a domingo y hoy en un cuadro carmesí. Sin fondo.
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

    minWidth: 200
    minHeight: 200

    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string pixel: "Departure Mono"
    readonly property var kanjiMeses: ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    readonly property var nombresMeses: ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"]

    // basta con revisar cada minuto para cambiar de día a medianoche
    property date now: new Date()
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    readonly property int year: now.getFullYear()
    readonly property int month: now.getMonth()
    readonly property int today: now.getDate()
    // huecos antes del día 1 con la semana empezando en lunes
    readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    readonly property real cell: width / 7

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width
            height: kanji.height
            Text {
                id: kanji
                text: root.kanjiMeses[root.month]
                color: root.crimson
                font.family: "Noto Serif JP"
                font.weight: Font.Black
                font.pixelSize: 30
            }
            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                Text {
                    anchors.right: parent.right
                    text: root.nombresMeses[root.month]
                    color: root.bone
                    font.family: root.pixel
                    font.pixelSize: 12
                    font.letterSpacing: 2
                }
                Text {
                    anchors.right: parent.right
                    text: root.year
                    color: root.ash
                    font.family: root.pixel
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 2
            color: root.theme.track ?? "#2a2a30"
            Rectangle {
                height: parent.height
                width: parent.width * root.today / root.daysInMonth
                color: root.crimson
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }

        Row {
            Repeater {
                model: ["L", "M", "X", "J", "V", "S", "D"]
                Text {
                    required property string modelData
                    required property int index
                    width: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? root.crimson : root.ash
                    opacity: index >= 5 ? 0.8 : 1
                    font.family: root.pixel
                    font.pixelSize: 11
                }
            }
        }

        Grid {
            columns: 7
            Repeater {
                model: root.offset + root.daysInMonth
                Item {
                    required property int index
                    readonly property int day: index - root.offset + 1
                    readonly property bool isToday: day === root.today
                    width: root.cell
                    height: Math.min(root.cell, 26)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        radius: 4
                        color: root.crimson
                        visible: parent.isToday
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: parent.day > 0
                        text: parent.day
                        color: parent.isToday ? (root.theme.surface ?? "#0c0c0e") : (parent.day < root.today ? root.ash : root.bone)
                        opacity: parent.day < root.today && !parent.isToday ? 0.55 : 1
                        font.family: root.pixel
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
