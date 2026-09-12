// Apple x Cyberpunk Dynamic Island Telemetry Capsule:
// Compact status pill that expands fluidly with Apple spring physics into detailed instrumentation.
import QtQuick
import "."

Item {
    id: root

    property string label: "SYS"
    property string jp: ""
    property string value: ""
    property string subValue: ""
    property bool   alert: false
    property bool   warn: false
    property color  tint: root.alert ? Theme.alert : (root.warn ? Theme.warn : Theme.laser)
    property bool   expandable: true
    property bool   expanded: false

    default property alias expandedContent: extraSlot.data

    readonly property bool isHovered: mouseArea.containsMouse
    readonly property bool isExpanded: root.expanded || (root.expandable && isHovered)

    implicitWidth: capsule.width
    implicitHeight: 28

    // Tactile Scale on Press (Apple fluid touch response)
    scale: mouseArea.pressed ? 0.965 : (isHovered ? 1.015 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: mouseArea.pressed ? Theme.tapSnapMs : 160
            easing.type: mouseArea.pressed ? Easing.OutQuad : Easing.OutBack
        }
    }

    Rectangle {
        id: capsule
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: root.isExpanded
               ? Math.max(160, baseRow.implicitWidth + extraSlot.implicitWidth + 32)
               : (baseRow.implicitWidth + 20)
        radius: 0 // Sharp precision rectangular telemetry chip

        color: root.alert
               ? Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.22)
               : (root.isHovered ? Theme.glassElevated : Theme.glassCard)
        border.width: 1
        border.color: root.alert ? Theme.alert : (root.isHovered ? Theme.specularCatch : Theme.glassBorder)

        // Apple Fluid Spring Behavior (Damping: 1.0, Response: 0.32s)
        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 120 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        // Top edge specular photon refraction catch
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 1
            height: 1
            radius: 0
            color: "#FFFFFF"
            opacity: root.isHovered ? 0.30 : 0.10
        }

        Row {
            id: contentContainer
            anchors.centerIn: parent
            spacing: 8

            Row {
                id: baseRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                // Glowing optical status bead (sharp micro-pip)
                Rectangle {
                    width: 6; height: 6; radius: 0
                    color: root.tint
                    anchors.verticalCenter: parent.verticalCenter

                    // Subtle breathing pulse on alert/warn
                    SequentialAnimation on opacity {
                        running: root.alert || root.warn
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 450 }
                        NumberAnimation { to: 1.0; duration: 450 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label
                    color: Theme.textSecondary
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.jp !== "" && !root.isExpanded
                    text: root.jp
                    color: Theme.laser
                    opacity: Theme.opacityJP
                    font.family: Theme.fontJP
                    font.pixelSize: Theme.szNano
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.value
                    color: Theme.textPrimary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szValue
                    font.weight: Font.DemiBold
                }
            }

            // Expanded telemetry slot that fades in fluidly
            Row {
                id: extraSlot
                anchors.verticalCenter: parent.verticalCenter
                visible: root.isExpanded && (root.subValue !== "" || children.length > 0)
                opacity: root.isExpanded ? 1.0 : 0.0
                spacing: 6

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.subValue !== ""
                    text: "•"
                    color: Theme.textTertiary
                    font.pixelSize: Theme.szMicro
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.subValue !== ""
                    text: root.subValue
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szTail
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }
}
