import QtQuick
import QtQuick.Particles
import QtQuick.Shapes
import Quickshell.Io
import qs.Modules.Plugins

// Pétalos que caen despacio y se mecen con el viento, en el acento del tema activo.
// Pocos y ligeros: los giros van en el hilo de render. Un tema puede apagarlos con "petals": false
// o cambiarlos por ceniza con "particles": "ash".
// Pensado para ocupar toda la pantalla con "clickThrough": true en la instancia.
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
    minHeight: 300

    readonly property bool on: theme.petals ?? true
    readonly property color accent: theme.accent ?? "#e5383b"
    readonly property color accentBright: theme.accentBright ?? "#ff5a5f"
    readonly property bool ash: theme.particles === "ash"
    readonly property color ashColor: theme.ash ?? "#8a8580"

    opacity: on ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 800 } }

    ParticleSystem {
        id: sys
        anchors.fill: parent
        running: root.on
    }

    // nacen por encima del borde superior para que no aparezcan de golpe
    Emitter {
        system: sys
        x: -root.width * 0.15
        y: -30
        width: root.width * 1.1
        height: 10
        emitRate: root.ash ? 0.8 : 0.45
        lifeSpan: root.ash ? 60000 : 30000
        maximumEmitted: root.ash ? 48 : 16
        velocity: AngleDirection {
            angle: 82
            angleVariation: 12
            magnitude: root.ash ? 30 : 38
            magnitudeVariation: 14
        }
    }

    // vaivén lateral y algo de viento hacia la derecha
    Wander {
        system: sys
        xVariance: 60
        pace: 40
        affectedParameter: Wander.Velocity
    }
    Gravity {
        system: sys
        angle: 15
        magnitude: 2
    }

    ItemParticle {
        system: sys
        fade: true
        delegate: Item {
            id: petal
            readonly property real size: root.ash ? 1.5 + Math.random() * 3.5 : 9 + Math.random() * 8
            width: size
            height: size * 0.7
            opacity: 0.45 + Math.random() * 0.4

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // pétalo de cerezo: óvalo con la muesca en la punta
                ShapePath {
                    strokeWidth: -1
                    // ceniza gris con alguna brasa suelta
                    fillColor: root.ash ? (Math.random() < 0.08 ? root.accent : root.ashColor)
                                        : (Math.random() < 0.35 ? root.accentBright : root.accent)
                    startX: 0
                    startY: petal.height / 2
                    PathQuad { x: petal.width * 0.86; y: 0; controlX: petal.width * 0.35; controlY: -petal.height * 0.25 }
                    PathLine { x: petal.width * 0.74; y: petal.height / 2 }
                    PathLine { x: petal.width * 0.86; y: petal.height }
                    PathQuad { x: 0; y: petal.height / 2; controlX: petal.width * 0.35; controlY: petal.height * 1.25 }
                }
            }

            RotationAnimator on rotation {
                from: Math.random() * 360
                to: from + (Math.random() < 0.5 ? -360 : 360)
                duration: 6000 + Math.random() * 6000
                loops: Animation.Infinite
            }
        }
    }
}
