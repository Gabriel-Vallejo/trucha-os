import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

// Kanji vertical del tema activo (鱒 en Crimson Ink, 三玖 en Miku Dark) con su lectura en katakana debajo
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

    minWidth: 80
    minHeight: 260

    readonly property color accent: theme.accent ?? "#e5383b"
    readonly property color ash: theme.ash ?? "#9a948f"
    readonly property var kanji: (theme.kanji ?? "鱒").split("")
    readonly property var kana: theme.kana ?? ["ト", "ル", "︱", "チ", "ャ"]
    // con dos kanji se encogen un poco para que quepan
    readonly property real kanjiSize: root.width * (kanji.length > 1 ? 0.62 : 0.78)

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.width * 0.12

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -root.kanjiSize * 0.12
            Repeater {
                model: root.kanji
                Text {
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    color: root.accent
                    font.family: "Noto Serif JP"
                    font.weight: Font.Black
                    font.pixelSize: root.kanjiSize
                    style: Text.Raised
                    styleColor: "#40000000"
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 2
            height: root.width * 0.55
            radius: 1
            color: root.accent
            opacity: 0.55
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            Repeater {
                // ︱ es la forma vertical del alargamiento ー
                model: root.kana
                Text {
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    color: root.ash
                    font.family: "Noto Serif JP"
                    font.weight: Font.Medium
                    font.pixelSize: root.width * 0.26
                }
            }
        }
    }
}
