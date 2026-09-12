// One readout: EN label, Japanese micro-label, a value, an optional meter.
//
// Every instrument on the desktop is one of these, which is what makes four
// scattered corners read as a single machine rather than four widgets.
//
// The reactive behaviour lives here too: a value rests at Theme.ghost and
// snaps to full for Theme.holdMs whenever it changes, then decays back. So
// the chrome is always crisp and only the things that just moved are bright.
import QtQuick
import "."

Column {
    id: cl

    property string label
    property string jp
    property string value: ""
    property string tail: ""
    property color  valueColor: Theme.text
    property bool   pulsing: false
    property bool   alignRight: false

    // -1 = no meter. Otherwise 0..100; the bar sweeps and takes its colour
    // from the threshold, so amber/red appear without anyone deciding to.
    property int    pct: -1
    property int    segs: 5
    property bool   autoColor: false      // let the threshold drive valueColor

    // Never ghost this one (used for the clock, which is always true).
    property bool   alwaysOn: false

    spacing: Theme.gap / 2

    // ---- freshness -------------------------------------------------------
    property bool fresh: false
    onValueChanged: cl.mark()
    onPctChanged: cl.mark()
    function mark() { cl.fresh = true; hold.restart(); }
    Timer { id: hold; interval: Theme.holdMs; onTriggered: cl.fresh = false }

    readonly property color effColor: cl.autoColor && cl.pct >= 0
                                      ? Theme.level(cl.pct) : cl.valueColor

    // ---- label row -------------------------------------------------------
    Tag {
        label: cl.label
        jp: cl.jp
        anchors.right: cl.alignRight ? parent.right : undefined
    }

    // ---- value row -------------------------------------------------------
    Row {
        spacing: Theme.gap + 2
        anchors.right: cl.alignRight ? parent.right : undefined

        // Ghost/snap applies to the data only. The labels above stay at full
        // strength so the frame never looks like it is fading out.
        opacity: (cl.alwaysOn || cl.fresh) ? 1.0 : Theme.ghost
        Behavior on opacity {
            NumberAnimation {
                duration: cl.fresh ? Theme.snapMs : Theme.decayMs
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: pip
            visible: cl.pulsing
            width: 5; height: 5
            anchors.verticalCenter: parent.verticalCenter
            color: cl.effColor
            SequentialAnimation on opacity {
                running: pip.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.15; duration: 620 }
                NumberAnimation { to: 1.0;  duration: 620 }
            }
        }

        Meter {
            visible: cl.pct >= 0
            anchors.verticalCenter: parent.verticalCenter
            pct: cl.pct
            segs: cl.segs
            barColor: cl.effColor
        }

        Text {
            id: valueText
            text: cl.value
            color: cl.effColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.szValue
            font.letterSpacing: Theme.trkTight
        }

        Text {
            visible: text !== ""
            text: cl.tail
            color: Theme.dim
            anchors.baseline: valueText.baseline
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.szTail
            font.letterSpacing: Theme.trkLabel
        }
    }
}
