import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins

// Reproductor flotante: carátula, título, artista, progreso carmesí y controles.
// Se desvanece cuando no hay ningún reproductor activo.
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
    minHeight: 96

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool active: player !== null && (player.trackTitle ?? "") !== ""
    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"

    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // la posición de MPRIS no se actualiza sola
    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: root.theme.surface ?? "#0c0c0e"
        opacity: 0.74
        border.color: root.crimson
        border.width: 1
    }
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.color: Qt.alpha(root.crimson, 0.28)
        border.width: 1
    }

    Row {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        Rectangle {
            id: art
            width: parent.height
            height: parent.height
            radius: 12
            color: root.theme.card ?? "#1c1c20"
            clip: true

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            DIcon {
                anchors.centerIn: parent
                visible: !(root.player?.trackArtUrl)
                name: "music_note"
                size: parent.width * 0.45
                color: root.crimson
            }
        }

        Column {
            width: parent.width - art.width - parent.spacing
            height: parent.height
            spacing: 4

            Text {
                width: parent.width
                text: root.player?.trackTitle ?? ""
                color: root.bone
                font.family: "Inter Variable"
                font.weight: Font.DemiBold
                font.pixelSize: 15
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.player?.trackArtist ?? ""
                color: root.ash
                font.family: "Inter Variable"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Item { width: 1; height: 4 }

            // progreso
            Rectangle {
                width: parent.width
                height: 3
                radius: 2
                color: root.theme.track ?? "#2a2a30"
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: root.crimson
                    width: (root.player && root.player.length > 0) ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                DIconButton {
                    iconName: "skip_previous"
                    iconColor: root.bone
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player.previous()
                }
                DIconButton {
                    iconName: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                    iconColor: root.crimson
                    onClicked: root.player.togglePlaying()
                }
                DIconButton {
                    iconName: "skip_next"
                    iconColor: root.bone
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player.next()
                }
            }
        }
    }
}
