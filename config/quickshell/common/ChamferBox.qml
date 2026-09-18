// 45-degree tactical cut-corner chamfered frame for military cyberdecks.
import QtQuick
import QtQuick.Shapes
import "."

Item {
    id: root

    property int cut: 12
    property bool cutTopLeft: false
    property bool cutTopRight: true
    property bool cutBottomLeft: true
    property bool cutBottomRight: false

    property color strokeColor: Theme.line
    property int strokeWidth: 1
    property color fillColor: "transparent"

    // Optional tactical cyberdeck accents
    property bool reticles: false
    property color reticleColor: root.strokeColor
    property bool notch: false
    property color notchColor: Theme.accent

    default property alias content: contentSlot.data

    Shape {
        id: shape
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        // Primary chamfered chassis outline
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            fillColor: root.fillColor
            joinStyle: ShapePath.MiterJoin

            startX: root.cutTopLeft ? root.cut : 0
            startY: 0

            PathLine { x: root.cutTopRight ? root.width - root.cut : root.width; y: 0 }
            PathLine { x: root.width; y: root.cutTopRight ? root.cut : 0 }

            PathLine { x: root.width; y: root.cutBottomRight ? root.height - root.cut : root.height }
            PathLine { x: root.cutBottomRight ? root.width - root.cut : root.width; y: root.height }

            PathLine { x: root.cutBottomLeft ? root.cut : 0; y: root.height }
            PathLine { x: 0; y: root.cutBottomLeft ? root.height - root.cut : root.height }

            PathLine { x: 0; y: root.cutTopLeft ? root.cut : 0 }
            PathLine { x: root.cutTopLeft ? root.cut : 0; y: 0 }
        }

        // Top laser edge rim highlight (photonic top-glass catch)
        ShapePath {
            strokeColor: Theme.accentWash
            strokeWidth: 1
            fillColor: "transparent"

            startX: root.cutTopLeft ? root.cut : 0
            startY: 0

            PathLine { x: root.cutTopRight ? root.width - root.cut : root.width; y: 0 }
        }
    }

    // Tactical Status Notch
    Rectangle {
        visible: root.notch
        width: 3
        height: Math.min(20, Math.max(12, root.height * 0.35))
        color: root.notchColor
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        // Status notch micro-glint
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: "#ffffff"
            opacity: 0.5
        }
    }

    // Tactical corner avionics ticks (uncut corners)
    // Top-Left
    Item {
        visible: root.reticles && !root.cutTopLeft
        anchors.left: parent.left; anchors.top: parent.top
        anchors.margins: 3
        width: 6; height: 6
        Rectangle { width: 5; height: 1; color: root.reticleColor; opacity: 0.75 }
        Rectangle { width: 1; height: 5; color: root.reticleColor; opacity: 0.75 }
    }
    // Top-Right
    Item {
        visible: root.reticles && !root.cutTopRight
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 3
        width: 6; height: 6
        Rectangle { anchors.right: parent.right; width: 5; height: 1; color: root.reticleColor; opacity: 0.75 }
        Rectangle { anchors.right: parent.right; width: 1; height: 5; color: root.reticleColor; opacity: 0.75 }
    }
    // Bottom-Left
    Item {
        visible: root.reticles && !root.cutBottomLeft
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.margins: 3
        width: 6; height: 6
        Rectangle { anchors.bottom: parent.bottom; width: 5; height: 1; color: root.reticleColor; opacity: 0.75 }
        Rectangle { anchors.bottom: parent.bottom; width: 1; height: 5; color: root.reticleColor; opacity: 0.75 }
    }
    // Bottom-Right
    Item {
        visible: root.reticles && !root.cutBottomRight
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 3
        width: 6; height: 6
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 5; height: 1; color: root.reticleColor; opacity: 0.75 }
        Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1; height: 5; color: root.reticleColor; opacity: 0.75 }
    }

    Item {
        id: contentSlot
        anchors.fill: parent
    }
}
