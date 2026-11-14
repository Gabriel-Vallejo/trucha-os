import QtQuick
import Quickshell
import qs.Services

// Trucha Copilot: se abre con "?" en el lanzador (⊞+Espacio). Escribe la pregunta y pulsa Intro:
// se abre una ventana de kitty con la respuesta, sacada de tus apuntes con Ollama en local (trucha-copilot).
// Empieza la pregunta por "!" para que el modelo razone antes (más lento, para lo pesado).
// El lanzador se cierra al pulsar Intro, por eso la respuesta va en su propia ventana.
Item {
    id: root

    property var pluginService: null
    property string trigger: "?"
    signal itemsChanged()

    readonly property string home: "__HOME__"

    function getItems(query) {
        const q = (query || "").trim();
        if (q === "")
            return [{ name: "Pregunta a tus apuntes", comment: "Escribe la pregunta y pulsa Intro · con ! delante, razona antes",
                      icon: "material:school", action: "hint", categories: ["Trucha Copilot"] }];
        return [{ name: q, comment: q.startsWith("!") ? "Razonar con tus apuntes · Intro (más lento)" : "Preguntar a tus apuntes · Intro", icon: "material:question_answer",
                  action: "ask:" + q, categories: ["Trucha Copilot"] }];
    }

    function executeItem(item) {
        const action = item.action || "";
        if (!action.startsWith("ask:"))
            return;
        // la pregunta va como argumento, sin pasar por una shell
        Quickshell.execDetached([home + "/.local/bin/kitty", "--class", "trucha-copilot", "--title", "Trucha Copilot",
                                 "--hold", home + "/.local/bin/trucha-copilot", "ask", action.substring(4)]);
    }
}
