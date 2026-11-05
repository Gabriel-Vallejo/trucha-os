import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

// Voz de Discord en la barra: clic abre la llamada, clic derecho silencia el micrófono.
// Los datos los escribe el servicio trucha-discord-voice; sin llamada activa no ocupa sitio.
PluginComponent {
    id: root

    property var voice: ({})
    property var theme: ({})

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/trucha-discord.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.voice = JSON.parse(text()); } catch (e) { root.voice = {}; }
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/trucha-os/current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.theme = JSON.parse(text()); } catch (e) { root.theme = {}; }
        }
    }

    readonly property bool inVoice: voice.inVoice ?? false
    readonly property bool muted: voice.mute ?? false
    readonly property bool deafened: voice.deaf ?? false
    readonly property var members: voice.members ?? []
    readonly property bool someoneSpeaking: members.some(m => m.speaking)
    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string icon: deafened ? "headset_off" : muted ? "mic_off" : "headset_mic"
    readonly property color iconColor: muted || deafened ? crimson : someoneSpeaking ? bone : ash

    onInVoiceChanged: setVisibilityOverride(inVoice)
    Component.onCompleted: setVisibilityOverride(inVoice)

    function run(action) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/trucha-discord-voice", action]);
    }

    pillRightClickAction: () => root.run("mute")

    horizontalBarPill: Component {
        DIcon {
            name: root.icon
            color: root.iconColor
            size: Theme.iconSize - 2
        }
    }
    verticalBarPill: Component {
        DIcon {
            name: root.icon
            color: root.iconColor
            size: Theme.iconSize - 2
        }
    }

    popoutWidth: 300
    popoutHeight: 110 + Math.min(root.members.length, 8) * 34

    popoutContent: Component {
        Column {
            width: parent.width
            spacing: 10

            Text {
                width: parent.width
                text: root.voice.channel ?? ""
                textFormat: Text.PlainText
                color: root.bone
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
            }

            ListView {
                width: parent.width
                height: Math.min(root.members.length, 8) * 34
                clip: true
                interactive: contentHeight > height
                model: root.members

                delegate: Row {
                    required property var modelData
                    height: 34
                    spacing: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: 9
                        radius: 5
                        color: parent.modelData.speaking ? root.crimson : "transparent"
                        border.color: root.ash
                        border.width: parent.modelData.speaking ? 0 : 1
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 210
                        // los nombres los elige cualquiera: nunca como marcado
                        text: parent.modelData.name
                        textFormat: Text.PlainText
                        color: parent.modelData.speaking ? root.bone : root.ash
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.modelData.mute || parent.modelData.deaf
                        name: parent.modelData.deaf ? "headset_off" : "mic_off"
                        color: root.crimson
                        size: 16
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                DIconButton {
                    iconName: root.muted ? "mic_off" : "mic"
                    iconColor: root.muted ? root.crimson : root.bone
                    onClicked: root.run("mute")
                }
                DIconButton {
                    iconName: root.deafened ? "headset_off" : "headset"
                    iconColor: root.deafened ? root.crimson : root.bone
                    onClicked: root.run("deaf")
                }
            }
        }
    }
}
