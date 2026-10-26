import QtQuick
import Quickshell
import Quickshell.Io

// Lista los temas de Trucha OS! y aplica el elegido con trucha-theme.
// Se abre con "%" en el lanzador o con ⊞+Alt+T. Lee el índice que mantiene trucha-theme.
Item {
    id: root

    property var pluginService: null
    property string trigger: "%"
    signal itemsChanged()

    FileView {
        id: index
        path: "__HOME__/.config/trucha-os/index.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: {
            reload();
            root.itemsChanged();
        }
    }

    function getItems(query) {
        let data;
        try {
            data = JSON.parse(index.text());
        } catch (e) {
            return [];
        }
        const q = (query || "").toLowerCase();
        return data.themes.filter(t => !q || t.label.toLowerCase().includes(q) || (t.description || "").toLowerCase().includes(q)).map(t => ({
            name: (t.id === data.current ? "● " : "") + t.label,
            comment: t.description || "",
            icon: t.thumbnail || "material:palette",
            action: "theme:" + t.id,
            categories: ["Temas de Trucha OS!"]
        }));
    }

    function executeItem(item) {
        const id = item.action.substring(item.action.indexOf(":") + 1);
        Quickshell.execDetached(["__HOME__/.local/bin/trucha-theme", id]);
    }
}
