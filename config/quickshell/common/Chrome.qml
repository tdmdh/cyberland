// A panel's chassis: the glass card, corner brackets and, unless bare, the
// title row, rules and key-hint footer. The deck and Panel both draw with it;
// before, each carried its own copy, and the two had drifted (blinking pip
// in one, static in the other, 16px footer against 20px, 12px body margins
// against 14px).
//
// Children go into the body. `chrome` is the height everything around the
// body takes, for a container sizing itself to its content.
import QtQuick
import "."

Item {
    id: ch

    property string title
    property string jp
    property string hint
    property bool   bare: false     // card and brackets only; the body fills it
    property bool   dark: false     // nothing dims the desktop behind: use the darker card
    property int    pad: 22
    property int    gap: 12

    default property alias content: body.data
    property alias headerItems: headerSlot.data
    readonly property alias bodyItem: body
    readonly property real  bodyImplicitHeight: body.implicitHeight
    readonly property int   chrome: ch.bare ? 0
        : 2 * ch.pad + header.height + footer.height + 4 * ch.gap + 2   // + two 1px rules

    signal backgroundClicked()

    function glitch(): void { titleText.trigger(); }

    Rectangle {
        anchors.fill: parent
        color: ch.dark ? Theme.cardDark : Theme.card
        border.width: 1
        border.color: Theme.edge

        // Top edge light catch
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.15; color: Theme.accentWash }
                GradientStop { position: 0.50; color: Theme.accent }
                GradientStop { position: 0.85; color: Theme.accentWash }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.shadow
        }

        // Swallows clicks on the card itself; the body's children sit above it.
        MouseArea {
            anchors.fill: parent
            onClicked: ch.backgroundClicked()
        }
    }

    Corners { anchors.fill: parent; arm: 14; stroke: Theme.accentEdge }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: ch.pad }
        height: 28
        visible: !ch.bare

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 6; height: 6
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            GlitchText {
                id: titleText
                text: ch.title
                jp: ch.jp
                color: Theme.text
                jpColor: Theme.accent
                pixelSize: Theme.szValue
                letterSpacing: Theme.trkWide
                weight: Font.DemiBold
            }
        }

        Row {
            id: headerSlot
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 20
        }
    }

    component Rule: Item {
        property real accentOpacity: 0.7
        height: 1
        visible: !ch.bare
        Rectangle { anchors.fill: parent; color: Theme.edge }
        Rectangle {
            width: 30; height: 1
            anchors.centerIn: parent
            color: Theme.accent
            opacity: parent.accentOpacity
        }
    }

    Rule {
        id: ruleTop
        anchors { top: header.bottom; topMargin: ch.gap; left: parent.left; right: parent.right
                  leftMargin: ch.pad; rightMargin: ch.pad }
    }

    Item {
        id: body
        anchors {
            top: ch.bare ? parent.top : ruleTop.bottom
            bottom: ch.bare ? parent.bottom : ruleBottom.top
            left: parent.left
            right: parent.right
            topMargin: ch.bare ? 0 : ch.gap
            bottomMargin: ch.bare ? 0 : ch.gap
            leftMargin: ch.bare ? 0 : ch.pad
            rightMargin: ch.bare ? 0 : ch.pad
        }
        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        clip: true
    }

    Rule {
        id: ruleBottom
        accentOpacity: 0.4
        anchors { bottom: footer.top; bottomMargin: ch.gap; left: parent.left; right: parent.right
                  leftMargin: ch.pad; rightMargin: ch.pad }
    }

    Item {
        id: footer
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: ch.pad }
        height: 20
        visible: !ch.bare

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 4; height: 4
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ch.hint
                color: Theme.dim
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.szMicro
                font.letterSpacing: Theme.trkLabel
            }
        }
    }
}
