import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

// Botón de Trucha Copilot en la barra: abre el lanzador (⊞+Espacio) con «¿» ya escrito.
PluginComponent {
    id: root

    property var theme: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.config/trucha-os/current.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.theme = JSON.parse(text()); } catch (e) { root.theme = {}; }
        }
    }

    pillClickAction: () => Quickshell.execDetached(["dms", "ipc", "call", "spotlight", "toggleQuery", "¿"])

    horizontalBarPill: Component {
        DIcon { name: "psychology"; color: root.theme.bone ?? "#ece8e4"; size: Theme.iconSize - 2 }
    }
    verticalBarPill: Component {
        DIcon { name: "psychology"; color: root.theme.bone ?? "#ece8e4"; size: Theme.iconSize - 2 }
    }
}
