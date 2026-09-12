// Neo-Kabuki cyberdeck targeting bracket with avionics crosshair calibration marks.
import QtQuick
import "."

Item {
    id: br

    // "tl" | "tr" | "bl" | "br"
    property string corner: "tl"
    property int    arm: 18
    property int    thickness: 1
    property color  stroke: Theme.laser
    property bool   reticle: true

    readonly property bool isRight:  br.corner === "tr" || br.corner === "br"
    readonly property bool isBottom: br.corner === "bl" || br.corner === "br"

    implicitWidth: br.arm
    implicitHeight: br.arm

    // Horizontal arm
    Rectangle {
        width: br.arm
        height: br.thickness
        color: br.stroke
        x: br.isRight ? br.width - br.arm : 0
        y: br.isBottom ? br.height - br.thickness : 0
    }

    // Vertical arm
    Rectangle {
        width: br.thickness
        height: br.arm
        color: br.stroke
        x: br.isRight ? br.width - br.thickness : 0
        y: br.isBottom ? br.height - br.arm : 0
    }

    // Precision Optical Reticle calibration bead
    Rectangle {
        visible: br.reticle
        width: 2
        height: 2
        radius: 0
        color: br.stroke
        x: br.isRight ? br.width - 4 : 2
        y: br.isBottom ? br.height - 4 : 2
    }
}
