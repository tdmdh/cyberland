// EN label + JP micro-label. The pair is this desktop's unit of "this readout
// is called X", and it was inlined in Cluster while frame, dev and the
// launcher each hand-rolled their own copy -- which is how four call sites
// ended up with three different spacings for the same two words.
//
// Tracking is derived, not passed: a condensed face needs 1.6 at label size
// and 4 once it is big enough to read as a heading. One knob, not two.
import QtQuick
import "."

Row {
    id: t

    property string label
    property string jp
    property int    size: Theme.szMicro

    readonly property real tracking: t.size >= Theme.szBody ? Theme.trkWide
                                                            : Theme.trkLabel
    spacing: Theme.gap

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: t.label
        color: Theme.dim
        font.family: Theme.fontDisplay
        font.pixelSize: t.size
        font.letterSpacing: t.tracking
        font.weight: Font.Medium
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: t.jp !== ""
        text: t.jp
        color: Theme.line
        opacity: Theme.opacityJP
        font.family: Theme.fontJP
        font.pixelSize: Theme.szMicro
        font.weight: Theme.weightJP
    }
}
