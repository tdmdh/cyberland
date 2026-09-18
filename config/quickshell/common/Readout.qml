// LABEL + value, the island's unit of telemetry.
//
// Three of these were written out longhand in compute mode and the hover
// detail wanted three more, each eight lines of two Texts repeating the same
// display/mono font pairing. The pairing is the point: the condensed label
// recedes, the mono value holds its width as digits change.
import QtQuick
import "."

Row {
    id: readout

    property string label: ""
    property string value: ""
    property color  valueColor: Theme.text

    spacing: 4
    anchors.verticalCenter: parent.verticalCenter

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: readout.label
        color: Theme.dim
        font.family: Theme.fontDisplay
        font.pixelSize: Theme.szMicro
        font.weight: Font.Medium
        font.letterSpacing: Theme.trkTight
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: readout.value
        color: readout.valueColor
        font.family: Theme.fontMono
        font.pixelSize: Theme.szMicro
        font.weight: Font.Bold
    }
}
