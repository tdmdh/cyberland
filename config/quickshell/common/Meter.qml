// A segmented bar. Blocks rather than a continuous fill: a gauge that reads
// in discrete steps looks like an instrument, a smooth one looks like a
// progress bar, and this desktop is instruments.
//
// The sweep is on the *displayed* value, not the real one, so a jump from
// 20 to 90 travels through the intervening segments instead of teleporting.
import QtQuick
import "."

Row {
    id: m

    property int   pct: 0
    property int   segs: 5
    property color barColor: Theme.accent

    // What the bar is currently showing, as opposed to what it has been told.
    property real shown: 0
    onPctChanged: m.shown = Math.max(0, Math.min(100, m.pct))
    Behavior on shown {
        NumberAnimation { duration: Theme.countMs; easing.type: Easing.OutCubic }
    }

    readonly property int lit: Math.round(m.shown / 100 * m.segs)

    property bool  slanted: false
    property int   segWidth: m.segs > 12 ? 3 : 4
    property int   segHeight: 10

    spacing: 2

    Repeater {
        model: m.segs
        Rectangle {
            id: seg
            required property int index
            readonly property bool isLit: index < m.lit

            width: m.segWidth
            height: m.segHeight
            radius: 0

            // Optional tactical 18-degree chevron slant if requested
            transform: m.slanted ? slantMatrix : null
            Matrix4x4 {
                id: slantMatrix
                matrix: Qt.matrix4x4(
                    1, -0.32, 0, 0,
                    0,     1, 0, 0,
                    0,     0, 1, 0,
                    0,     0, 0, 1
                )
            }

            // Unlit segments sit in a recessed dark glass socket; lit segments emit photonic laser light
            color: seg.isLit ? m.barColor : Theme.socket
            border.width: 1
            border.color: seg.isLit ? Qt.tint(m.barColor, "#30FFFFFF") : Theme.edge

            Behavior on color { ColorAnimation { duration: Theme.snapMs } }
            Behavior on border.color { ColorAnimation { duration: Theme.snapMs } }

            // Micro-specular glint on lit louvers for authentic optical depth
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                anchors.margins: 1
                height: 1
                radius: 0
                color: "#ffffff"
                opacity: seg.isLit ? 0.45 : 0.0
            }
        }
    }
}
