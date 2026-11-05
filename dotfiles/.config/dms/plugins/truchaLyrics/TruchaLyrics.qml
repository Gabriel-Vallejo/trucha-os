import QtQuick
import Quickshell.Io
import qs.Services
import qs.Modules.Plugins

// Letra de lo que suena: línea actual y la siguiente, en la fuente pixel del reloj.
// La busca el LyricsService de DMS; sin letra sincronizada o en pausa se desvanece.
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
    minHeight: 60

    readonly property string pixel: "Departure Mono"
    readonly property var player: MprisController.activePlayer
    readonly property var controller: LyricsService.controller
    readonly property string currentLine: lineAt(controller.activeIndex)
    readonly property string nextLine: lineAt(controller.activeIndex + 1)

    // las voces de fondo llegan en otra línea del mismo grupo
    function lineAt(index) {
        if (!controller.synced)
            return "";
        return (controller.lines[index]?.x ?? "").replace(/\n/g, " · ").trim();
    }

    LyricsSubscription {
        active: root.player !== null
    }

    opacity: (player?.isPlaying ?? false) && currentLine !== "" ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 8

        Text {
            width: parent.width
            text: root.currentLine
            textFormat: Text.PlainText
            color: root.theme.bone ?? "#ece8e4"
            font.family: root.pixel
            font.pixelSize: 26
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            style: Text.Outline
            styleColor: root.theme.surface ?? "#0c0c0e"
        }

        Text {
            width: parent.width
            text: root.nextLine
            textFormat: Text.PlainText
            color: root.theme.ash ?? "#8a8580"
            font.family: root.pixel
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            style: Text.Outline
            styleColor: root.theme.surface ?? "#0c0c0e"
        }
    }
}
