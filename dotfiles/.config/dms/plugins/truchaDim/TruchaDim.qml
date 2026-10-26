import QtQuick
import Quickshell.Io
import qs.Modules.Plugins

// Oscurece el fondo animado según el "dim" del tema activo (0 = nada), con viñeta en los bordes
DesktopPluginComponent {
    id: root

    property var theme: ({})
    FileView {
        path: "__HOME__/.config/trucha-os/current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.theme = JSON.parse(text()); } catch (e) { root.theme = {}; }
        }
    }

    minWidth: 100
    minHeight: 100

    readonly property real dim: theme.dim ?? 0
    readonly property color tint: theme.surface ?? "#000000"

    Rectangle {
        anchors.fill: parent
        color: root.tint
        opacity: root.dim
        Behavior on opacity { NumberAnimation { duration: 500 } }
    }
    // viñeta: bordes aún más oscuros
    Rectangle {
        anchors.fill: parent
        opacity: root.dim > 0 ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: 500 } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(root.tint, 0.75) }
            GradientStop { position: 0.28; color: "transparent" }
            GradientStop { position: 0.72; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(root.tint, 0.75) }
        }
    }
}
