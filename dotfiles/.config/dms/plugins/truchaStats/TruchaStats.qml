import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Monitor mínimo a juego con el reloj: etiqueta gris, valor en pixel y barra carmesí de 2 px. Sin fondo.
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

    minWidth: 160
    minHeight: 120

    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string pixel: "Departure Mono"

    Component.onCompleted: DgopService.addRef(["cpu", "memory"])
    Component.onDestruction: DgopService.removeRef(["cpu", "memory"])

    component Stat: Column {
        id: stat
        property string label
        property string value
        property real ratio: 0
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: valueText.height
            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                text: stat.label
                color: root.ash
                font.family: root.pixel
                font.pixelSize: 12
                font.letterSpacing: 2
            }
            Text {
                id: valueText
                anchors.right: parent.right
                text: stat.value
                color: root.bone
                font.family: root.pixel
                font.pixelSize: 22
            }
        }
        Rectangle {
            width: parent.width
            height: 2
            color: root.theme.track ?? "#2a2a30"
            Rectangle {
                anchors.right: parent.right
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, stat.ratio))
                color: root.crimson
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }

    function pad(n) { return (n < 10 ? "0" : "") + Math.round(n); }

    Column {
        anchors.fill: parent
        spacing: 14

        Stat {
            label: "CPU"
            value: root.pad(DgopService.cpuUsage) + "%"
            ratio: DgopService.cpuUsage / 100
        }
        Stat {
            label: "RAM"
            value: root.pad(DgopService.memoryUsage) + "%"
            ratio: DgopService.memoryUsage / 100
        }
        Stat {
            label: "TEMP"
            value: Math.round(DgopService.cpuTemperature) + "°"
            ratio: (DgopService.cpuTemperature - 30) / 70
        }
    }
}
