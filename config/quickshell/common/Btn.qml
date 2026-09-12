// Apple x Cyberpunk tactile button: instant pointer-down press, optical squircle glass, and specular laser catch.
import QtQuick
import "."

Rectangle {
    id: btn

    property string text
    property string jp: ""
    property bool   active: false
    property color  tint: Theme.accent
    property bool   enabled: true

    signal clicked()

    implicitWidth: label.implicitWidth + (jpLabel.visible ? jpLabel.implicitWidth + 7 : 0) + 30
    implicitHeight: 28
    radius: 0

    // Tactile Scale: Compresses on pointer-down instantly (45ms), springs back with inertia
    scale: !btn.enabled ? 1.0 : (mouseArea.pressed ? 0.962 : (mouseArea.containsMouse ? 1.015 : 1.0))
    Behavior on scale {
        NumberAnimation {
            duration: mouseArea.pressed ? Theme.tapSnapMs : 160
            easing.type: mouseArea.pressed ? Easing.OutQuad : Easing.OutBack
        }
    }

    // Smoked sapphire glass chassis
    color: !btn.enabled ? Qt.rgba(Theme.layer1.r, Theme.layer1.g, Theme.layer1.b, 0.35)
         : (btn.active ? btn.tint
         : (mouseArea.pressed ? Theme.glassPressed
         : (mouseArea.containsMouse ? Theme.glassElevated : Theme.glassCard)))

    border.width: 1
    border.color: !btn.enabled ? Theme.line2
                : (btn.active ? btn.tint
                : (mouseArea.containsMouse ? Theme.specularCatch : Theme.glassBorder))
    opacity: btn.enabled ? 1.0 : 0.45

    Behavior on color { ColorAnimation { duration: 110 } }
    Behavior on border.color { ColorAnimation { duration: 110 } }

    // Top specular light catch (Apple glass optical reflection)
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: 1
        height: 1
        radius: 0
        color: "#FFFFFF"
        opacity: btn.active ? 0.40 : (mouseArea.containsMouse ? 0.28 : 0.08)
    }

    // Dynamic tactical status notch / pip (smoothly elongates on hover / active)
    Rectangle {
        id: notch
        width: 3
        height: btn.active ? (parent.height - 8) : (mouseArea.containsMouse ? 12 : 5)
        radius: 0
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        color: btn.active ? Theme.onAccent : btn.tint
        opacity: btn.active ? 1.0 : (mouseArea.containsMouse ? 0.95 : 0.50)
        Behavior on height { NumberAnimation { duration: Theme.snapMs; easing.type: Easing.OutCubic } }
    }

    // Top-right micro-reticle tick
    Rectangle {
        width: 4; height: 1
        color: btn.active ? Theme.onAccent : btn.tint
        anchors.right: parent.right; anchors.rightMargin: 3
        anchors.top: parent.top; anchors.topMargin: 3
        opacity: btn.active ? 0.9 : (mouseArea.containsMouse ? 0.75 : 0.35)
    }
    Rectangle {
        width: 1; height: 4
        color: btn.active ? Theme.onAccent : btn.tint
        anchors.right: parent.right; anchors.rightMargin: 3
        anchors.top: parent.top; anchors.topMargin: 3
        opacity: btn.active ? 0.9 : (mouseArea.containsMouse ? 0.75 : 0.35)
    }

    Row {
        anchors.centerIn: parent
        spacing: 7

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            color: btn.active ? Theme.onAccent : Theme.textPrimary
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.szBody
            font.letterSpacing: 1.2
            font.weight: btn.active ? Font.DemiBold : Font.Medium
        }

        Text {
            id: jpLabel
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.jp !== ""
            text: btn.jp
            color: btn.active ? Theme.onAccent : btn.tint
            opacity: btn.active ? 0.90 : Theme.opacityJP
            font.family: Theme.fontJP
            font.pixelSize: Theme.szNano
            font.weight: Theme.weightJP
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: btn.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
