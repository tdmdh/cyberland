// Alphanumeric hardware scramble / decrypt reveal for cyberdeck headers.
import QtQuick
import "."

Item {
    id: glText

    property string text: ""
    property string jp: ""
    property color color: Theme.accent
    property color jpColor: Theme.line
    property int pixelSize: Theme.szLead
    property real letterSpacing: Theme.trkWide
    property int weight: Font.Medium
    property string fontFamily: Theme.fontDisplay

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property string glyphs: "0123456789ABCDEF!#$/<>[]_+"
    property string displayText: text
    property int scrambleSteps: 0

    function trigger() {
        scrambleSteps = 4;
        scrambleTimer.restart();
    }

    onTextChanged: trigger()
    Component.onCompleted: trigger()

    Timer {
        id: scrambleTimer
        interval: 30
        repeat: true
        onTriggered: {
            if (glText.scrambleSteps <= 0) {
                glText.displayText = glText.text;
                stop();
                return;
            }
            glText.scrambleSteps--;
            let scrambled = "";
            for (let i = 0; i < glText.text.length; i++) {
                const ch = glText.text[i];
                if (ch === " " || ch === "/" || ch === "[" || ch === "]" || ch === ":" || ch === "-") {
                    scrambled += ch;
                } else if (Math.random() < 0.5) {
                    scrambled += glText.glyphs[Math.floor(Math.random() * glText.glyphs.length)];
                } else {
                    scrambled += ch;
                }
            }
            glText.displayText = scrambled;
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: mainText.implicitWidth
            height: mainText.implicitHeight

            // Chromatic aberration: Neon Cyan split (left)
            Text {
                visible: glText.scrambleSteps > 0
                x: -1.5
                y: 0
                text: glText.displayText
                color: Theme.accent
                opacity: 0.75
                font.family: glText.fontFamily
                font.pixelSize: glText.pixelSize
                font.letterSpacing: glText.letterSpacing
                font.weight: glText.weight
            }

            // Chromatic aberration: Neon Magenta split (right)
            Text {
                visible: glText.scrambleSteps > 0
                x: 1.5
                y: 0
                text: glText.displayText
                color: Theme.accent2
                opacity: 0.75
                font.family: glText.fontFamily
                font.pixelSize: glText.pixelSize
                font.letterSpacing: glText.letterSpacing
                font.weight: glText.weight
            }

            // Primary decrypted text
            Text {
                id: mainText
                anchors.fill: parent
                text: glText.displayText
                color: glText.color
                font.family: glText.fontFamily
                font.pixelSize: glText.pixelSize
                font.letterSpacing: glText.letterSpacing
                font.weight: glText.weight
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: glText.jp !== ""
            text: glText.jp
            color: glText.jpColor
            font.family: Theme.fontJP
            font.pixelSize: Math.max(10, glText.pixelSize - 5)
        }
    }
}
