import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins

// Tiempo a juego con el reloj y el monitor: icono carmesí, temperatura en pixel, estado y máx/mín en gris. Sin fondo.
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

    minWidth: 180
    minHeight: 100

    readonly property color crimson: theme.accent ?? "#e5383b"
    readonly property color bone: theme.bone ?? "#ece8e4"
    readonly property color ash: theme.ash ?? "#8a8580"
    readonly property string pixel: "Departure Mono"

    readonly property var w: WeatherService.weather
    readonly property bool ready: w.available ?? false
    readonly property var today: (w.forecast ?? [])[0] ?? null

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    // los nombres de DMS van por I18n y pueden salir en inglés; estos son cortos y en español
    function estado(code) {
        const c = Number(code);
        if (c <= 1) return "DESPEJADO";
        if (c === 2) return "POCO NUBOSO";
        if (c === 3) return "NUBLADO";
        if (c === 45 || c === 48) return "NIEBLA";
        if (c >= 51 && c <= 57) return "LLOVIZNA";
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "LLUVIA";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "NIEVE";
        if (c >= 95) return "TORMENTA";
        return "—";
    }

    opacity: ready ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    Column {
        anchors.fill: parent
        spacing: 6

        Row {
            spacing: 12
            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: WeatherService.getWeatherIcon(root.w.wCode, root.w.isDay)
                size: 34
                color: root.crimson
            }
            Text {
                text: root.ready ? Math.round(SettingsData.useFahrenheit ? root.w.tempF : root.w.temp) + "°" : "--°"
                color: root.bone
                font.family: root.pixel
                font.pixelSize: 38
            }
        }

        Text {
            text: root.ready ? root.estado(root.w.wCode) : "SIN DATOS"
            color: root.ash
            font.family: root.pixel
            font.pixelSize: 12
            font.letterSpacing: 2
        }

        Rectangle {
            width: parent.width
            height: 2
            color: root.theme.track ?? "#2a2a30"
            // la barra marca dónde cae la temperatura actual entre la mínima y la máxima del día
            Rectangle {
                readonly property real span: root.today ? Math.max(1, root.today.tempMax - root.today.tempMin) : 1
                height: parent.height
                width: root.today ? parent.width * Math.max(0.04, Math.min(1, (root.w.temp - root.today.tempMin) / span)) : 0
                color: root.crimson
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            visible: root.today !== null
            text: root.today ? "↑" + root.today.tempMax + "° ↓" + root.today.tempMin + "°" + (root.w.city ? "  ·  " + root.w.city.toUpperCase() : "") : ""
            width: parent.width
            elide: Text.ElideRight
            color: root.ash
            font.family: root.pixel
            font.pixelSize: 11
            font.letterSpacing: 1
        }
    }
}
