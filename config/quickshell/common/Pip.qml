// The blinking status bead.
//
// Written out four times inside the island alone, each time with its own
// SequentialAnimation. One component because `running` has to be gated per
// mode: an animation on an item whose opacity is 0 still ticks the render
// loop, and the render loop is very nearly all-or-nothing. Measured on the
// island: no animation running at all is 0.00% CPU, and any animation
// running at all is 1-2%, near enough regardless of how many. So a pip that
// blinks where nobody can see it costs the same as one that blinks on screen.
import QtQuick

Rectangle {
    id: pip

    property int  size:       4
    property real minOpacity: 0.25
    property int  period:     400    // ms per half-cycle
    property bool running:    true

    width: size
    height: size
    radius: 0
    anchors.verticalCenter: parent.verticalCenter

    // Stopping an animation leaves the property wherever it was; without this
    // a pip that stops mid-blink stays half-lit the next time it is shown.
    onRunningChanged: if (!pip.running) pip.opacity = 1.0;

    SequentialAnimation on opacity {
        running: pip.running
        loops: Animation.Infinite
        NumberAnimation { to: pip.minOpacity; duration: pip.period }
        NumberAnimation { to: 1.0;            duration: pip.period }
    }
}
