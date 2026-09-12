// The vertical name wheel: entries stack in a column, and the selected one
// eases to mid-height and steps out to the right.
//
// The bulge is the point. A highlight bar says "this row is selected"; a row
// that physically leaves the stack says "this one is locked on", which is the
// same reading a bracketed corner gives and the reason both exist.
//
// Consumers set `model` and `delegate`. The delegate reads PathView.iScale and
// PathView.iOpacity, supplied by the path below. Lives here rather than in one
// module because two now want it, and this desktop has already paid once for
// byte-identical code in two places (see Theme.qml's header).
import QtQuick

PathView {
    id: w

    // Width of one entry. The path runs through delegate CENTRES, so every x
    // below is a left edge plus half of this.
    property real itemWidth: 780
    // Left edge of a resting entry, in the wheel's own coordinates.
    property real inset: 40
    // How far the centred entry travels right, out of the stack.
    property real bulge: 140

    readonly property real inX: w.inset + w.itemWidth / 2
    readonly property real outX: w.inX + w.bulge

    pathItemCount: 9
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange
    snapMode: PathView.SnapToItem
    highlightMoveDuration: 420
    clip: true

    path: Path {
        startX: w.inX
        startY: 0
        PathAttribute { name: "iScale";   value: 0.45 }
        PathAttribute { name: "iOpacity"; value: 0.12 }
        PathQuad {
            x: w.outX; y: w.height / 2
            controlX: w.inX; controlY: w.height / 4
        }
        PathAttribute { name: "iScale";   value: 1.0 }
        PathAttribute { name: "iOpacity"; value: 1.0 }
        PathQuad {
            x: w.inX; y: w.height
            controlX: w.inX; controlY: w.height * 3 / 4
        }
        PathAttribute { name: "iScale";   value: 0.45 }
        PathAttribute { name: "iOpacity"; value: 0.12 }
    }
}
