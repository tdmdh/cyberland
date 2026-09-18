// 8-Way Cyberdeck Avionics Radial HUD Wheel for Quickshell Schematic
// Allows rapid, muscle-memory component placement with Tab (hold) + mouse flick.
import QtQuick
import QtQuick.Shapes
import "./common"

Item {
    id: radialRoot

    property bool active: false
    property real centerX: width / 2
    property real centerY: height / 2
    property int  activeSector: -1

    // 8 Architectural component presets
    readonly property var presets: [
        { type: "gateway",  label: "API Gateway",        shape: "box",      tag: "GATEWAY",  jp: "玄関", color: Theme.accent,    icon: "⬡" },
        { type: "service",  label: "Microservice",       shape: "box",      tag: "SERVICE",  jp: "容器", color: "#7aa2f7",         icon: "⚙" },
        { type: "database", label: "PostgreSQL DB",      shape: "cylinder", tag: "DB [( )]", jp: "基盤", color: "#bb9af7",         icon: "🖴" },
        { type: "cache",    label: "Redis Cache",        shape: "cylinder", tag: "CACHE",    jp: "高速", color: "#e0af68",         icon: "⚡" },
        { type: "queue",    label: "Kafka Queue",        shape: "box3d",    tag: "QUEUE",    jp: "行列", color: "#ff007f",         icon: "☵" },
        { type: "decision", label: "Route Valid?",       shape: "diamond",  tag: "DECISION", jp: "判定", color: "#f7768e",         icon: "◇" },
        { type: "client",   label: "Client App",         shape: "oval",     tag: "CLIENT",   jp: "端末", color: "#73daca",         icon: "◎" },
        { type: "extapi",   label: "External API",       shape: "box",      tag: "EXT-API",  jp: "外部", color: "#9ece6a",         icon: "🌐" }
    ]

    signal sectorSelected(int index)
    signal canceled()

    anchors.fill: parent
    visible: opacity > 0.01
    opacity: active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: Theme.easeFastMs; easing.type: Easing.OutQuad } }

    onActiveChanged: {
        if (!active) {
            activeSector = -1;
        }
    }

    function updateFromMouse(mx, my) {
        const dx = mx - centerX;
        const dy = my - centerY;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 32 || dist > 320) {
            activeSector = -1;
            return;
        }
        const deg = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360;
        // Sector 0 is Top (270 deg)
        const rel = (deg - 270 + 22.5 + 360) % 360;
        activeSector = Math.floor(rel / 45);
    }

    function commit() {
        if (activeSector >= 0 && activeSector < presets.length) {
            sectorSelected(activeSector);
        } else {
            canceled();
        }
    }

    // Fullscreen interactive catchment
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: mouse => {
            if (radialRoot.active) {
                radialRoot.updateFromMouse(mouse.x, mouse.y);
            }
        }

        onClicked: mouse => {
            if (radialRoot.active) {
                radialRoot.commit();
            }
        }
    }

    // Translucent HUD Scrim vignette centered on reticle
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.04, 0.05, 0.45)
    }

    // Reticle Background Glow Rings
    Rectangle {
        x: radialRoot.centerX - 160
        y: radialRoot.centerY - 160
        width: 320
        height: 320
        radius: 160
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
    }

    Rectangle {
        x: radialRoot.centerX - 100
        y: radialRoot.centerY - 100
        width: 200
        height: 200
        radius: 100
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
    }

    // Center Targeting Hub
    Item {
        id: centerHub
        x: radialRoot.centerX - 56
        y: radialRoot.centerY - 56
        width: 112
        height: 112

        // Outer rotating avionics ring
        Rectangle {
            anchors.fill: parent
            radius: 56
            color: Theme.layer1
            border.width: 2
            border.color: radialRoot.activeSector >= 0
                        ? radialRoot.presets[radialRoot.activeSector].color
                        : Theme.line

            Behavior on border.color { ColorAnimation { duration: Theme.easeFastMs } }

            // Rotating tick marks
            Item {
                anchors.fill: parent
                RotationAnimation on rotation {
                    from: 0; to: 360; duration: 12000; loops: Animation.Infinite
                }
                Repeater {
                    model: 12
                    Rectangle {
                        x: parent.width / 2 - 1
                        y: 2
                        width: 2
                        height: 5
                        color: Theme.dim
                        transformOrigin: Item.Bottom
                        rotation: index * 30
                    }
                }
            }
        }

        // Inner display readout
        Column {
            anchors.centerIn: parent
            spacing: 2
            width: parent.width - 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: radialRoot.activeSector >= 0
                    ? radialRoot.presets[radialRoot.activeSector].icon
                    : "⌖"
                color: radialRoot.activeSector >= 0
                    ? radialRoot.presets[radialRoot.activeSector].color
                    : Theme.accent
                font.pixelSize: Theme.szValue
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: radialRoot.activeSector >= 0
                    ? radialRoot.presets[radialRoot.activeSector].tag
                    : "HUD READY"
                color: Theme.text
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.szMicro
                font.letterSpacing: Theme.trkLabel
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: radialRoot.activeSector >= 0
                    ? radialRoot.presets[radialRoot.activeSector].jp
                    : "標準"
                color: Theme.dim
                font.pixelSize: Theme.szMicro
            }
        }
    }

    // 8 Sector Peripheral Cards
    Repeater {
        model: radialRoot.presets

        Item {
            id: sectorItem
            required property var modelData
            required property int index

            readonly property real angleDeg: (index * 45 - 90 + 360) % 360
            readonly property real angleRad: angleDeg * Math.PI / 180
            readonly property real radiusDist: 156

            readonly property real cardW: 124
            readonly property real cardH: 46

            x: radialRoot.centerX + radiusDist * Math.cos(angleRad) - cardW / 2
            y: radialRoot.centerY + radiusDist * Math.sin(angleRad) - cardH / 2
            width: cardW
            height: cardH

            readonly property bool isSelected: radialRoot.activeSector === index

            scale: isSelected ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.easeFastMs; easing.type: Easing.OutCubic } }

            // Connecting laser ray from center hub to active sector
            Rectangle {
                visible: sectorItem.isSelected
                x: cardW / 2
                y: cardH / 2
                width: sectorItem.radiusDist - 56
                height: 2
                color: sectorItem.modelData.color
                opacity: 0.8
                transformOrigin: Item.Left
                rotation: sectorItem.angleDeg + 180
            }

            // Tactical Sector Card Box
            Rectangle {
                anchors.fill: parent
                color: sectorItem.isSelected
                    ? Qt.rgba(sectorItem.modelData.color.r, sectorItem.modelData.color.g, sectorItem.modelData.color.b, 0.28)
                    : Theme.layer1
                border.width: sectorItem.isSelected ? 2 : 1
                border.color: sectorItem.isSelected ? sectorItem.modelData.color : Theme.line
                opacity: 0.96

                Behavior on color { ColorAnimation { duration: Theme.easeFastMs } }
                Behavior on border.color { ColorAnimation { duration: Theme.easeFastMs } }

                // Avionics Corner Brackets
                Bracket { corner: "tl"; anchors.left: parent.left; anchors.top: parent.top; visible: sectorItem.isSelected }
                Bracket { corner: "br"; anchors.right: parent.right; anchors.bottom: parent.bottom; visible: sectorItem.isSelected }

                // Top Accent Tag Bar
                Row {
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    spacing: 4

                    Text {
                        text: "[" + (sectorItem.index + 1) + "]"
                        color: sectorItem.isSelected ? sectorItem.modelData.color : Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szMicro
                        font.weight: Font.Bold
                    }

                    Text {
                        text: sectorItem.modelData.tag
                        color: sectorItem.isSelected ? Theme.text : Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szMicro
                        font.letterSpacing: Theme.trkLabel
                        elide: Text.ElideRight
                    }
                }

                // Component Icon & Label
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sectorItem.modelData.icon
                        color: sectorItem.modelData.color
                        font.pixelSize: Theme.szBody
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20
                        text: sectorItem.modelData.label
                        color: sectorItem.isSelected ? Theme.text : Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szBody
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }

            // Direct Click fallback on sector
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: radialRoot.activeSector = sectorItem.index
                onClicked: radialRoot.sectorSelected(sectorItem.index)
            }
        }
    }
}
