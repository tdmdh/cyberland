// The four bracketed corners of a region, as one element.
//
// A bracketed box is the desktop's only container -- see Bracket -- so the
// eight lines it takes to place four of them by hand were the most copied
// eight lines in the config. Fill the thing you want bracketed.
import QtQuick
import "."

Item {
    id: c

    property color stroke: Theme.laser
    property int   arm: 18
    property int   thickness: 1

    Bracket {
        corner: "tl"; stroke: c.stroke; arm: c.arm; thickness: c.thickness
        anchors.left: parent.left; anchors.top: parent.top
    }
    Bracket {
        corner: "tr"; stroke: c.stroke; arm: c.arm; thickness: c.thickness
        anchors.right: parent.right; anchors.top: parent.top
    }
    Bracket {
        corner: "bl"; stroke: c.stroke; arm: c.arm; thickness: c.thickness
        anchors.left: parent.left; anchors.bottom: parent.bottom
    }
    Bracket {
        corner: "br"; stroke: c.stroke; arm: c.arm; thickness: c.thickness
        anchors.right: parent.right; anchors.bottom: parent.bottom
    }
}
