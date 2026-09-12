// Apple x Cyberpunk Floating Neural-Glass Panel:
// Translucent smoked obsidian, specular laser light catches, and Apple fluid spring motion.
import QtQuick
import "."

Item {
    id: panel

    property string title
    property string jp
    property string hint: "ESC  CLOSE"
    property int    panelWidth: 1080
    property int    panelHeight: -1      // -1 = auto content height, >0 = fixed height
    property bool   scrim: true
    property string scrimMode: "default" // "default" | "none" | "dim" | "opaque"
    property string placement: "center"  // "center" | "right" | "top" | "bottom"
    property bool   fullBleed: false
    property int    pad: 22
    property int    gap: 12

    readonly property string effectiveScrim: {
        if (!panel.scrim) return "none";
        if (panel.scrimMode !== "default") return panel.scrimMode;
        return "dim";
    }

    readonly property real targetScrimOpacity: {
        if (effectiveScrim === "opaque") return 0.95;
        if (effectiveScrim === "dim") return 0.60;
        return 0.0;
    }

    readonly property bool isWindowVisible: panel.Window.window !== null && panel.Window.window.visible && panel.visible

    onIsWindowVisibleChanged: {
        if (isWindowVisible) {
            panel.startEntrance();
        } else {
            panel.resetEntrance();
        }
    }

    default property alias content: body.data
    property alias  headerItems: headerSlot.data

    signal dismissed()

    anchors.fill: parent

    // Full-screen backdrop focus scrim (Pure smoked obsidian glass)
    Rectangle {
        id: scrimRect
        anchors.fill: parent
        color: Theme.obsidianBase
        visible: panel.effectiveScrim !== "none"
        opacity: 0
    }

    // Click outside to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: panel.dismissed()
    }

    Item {
        id: box
        anchors.horizontalCenter: (panel.placement === "center" || panel.placement === "top" || panel.placement === "bottom") ? parent.horizontalCenter : undefined
        anchors.verticalCenter: (panel.placement === "center" || (panel.placement === "right" && panel.panelHeight > 0)) ? parent.verticalCenter : undefined

        anchors.right: panel.placement === "right" ? parent.right : undefined
        anchors.rightMargin: panel.placement === "right" ? 14 : 0

        anchors.top: (panel.placement === "top" || (panel.placement === "right" && panel.panelHeight <= 0)) ? parent.top : undefined
        anchors.topMargin: (panel.placement === "top" || (panel.placement === "right" && panel.panelHeight <= 0)) ? 48 : 0

        anchors.bottom: (panel.placement === "bottom" || (panel.placement === "right" && panel.panelHeight <= 0)) ? parent.bottom : undefined
        anchors.bottomMargin: (panel.placement === "bottom" || (panel.placement === "right" && panel.panelHeight <= 0)) ? 48 : 0

        width: panel.fullBleed ? panel.width - 96 : panel.panelWidth
        readonly property int chrome: panel.pad * 2 + header.height
                                      + 2 * (panel.gap * 2 + 1) + footer.height
        height: (panel.placement === "right" && panel.panelHeight <= 0)
                ? (parent.height - 96)
                : (panel.panelHeight > 0
                   ? panel.panelHeight
                   : (panel.fullBleed
                      ? panel.height - 96
                      : Math.min(box.chrome + body.implicitHeight, panel.height - 120)))

        transform: Translate {
            id: trans
            x: 0
            y: 0
        }
        scale: 1.0
        opacity: 0

        // Smoked Sapphire Glass Chassis
        Rectangle {
            anchors.fill: parent
            radius: 0
            color: panel.effectiveScrim !== "none" ? Theme.glassCard : Theme.glassBg
            border.width: 1
            border.color: Theme.glassBorder

            // Top laser specular reflection catch
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                anchors.margins: 1
                height: 1
                radius: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.15; color: Theme.specularDim }
                    GradientStop { position: 0.50; color: Theme.laser }
                    GradientStop { position: 0.85; color: Theme.specularDim }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Subtle bottom shadow rim
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: Theme.shadowRim
            }
        }

        // Precision Corner Vernier Brackets (1px hairline)
        Bracket { corner: "tl"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.left: parent.left;   anchors.top: parent.top }
        Bracket { corner: "tr"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.right: parent.right; anchors.top: parent.top }
        Bracket { corner: "bl"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.left: parent.left;   anchors.bottom: parent.bottom }
        Bracket { corner: "br"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.right: parent.right; anchors.bottom: parent.bottom }

        // Swallows clicks inside panel
        MouseArea { anchors.fill: parent }

        // ---- Header ------------------------------------------------------
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right
                      margins: panel.pad }
            height: 28

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Glowing Micro-Indicator Pip
                Rectangle {
                    width: 6; height: 6; radius: 0
                    color: Theme.laser
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Cryptographic Glitch Title
                GlitchText {
                    id: glitchTitle
                    text: panel.title
                    jp: panel.jp
                    color: Theme.textPrimary
                    jpColor: Theme.laser
                    pixelSize: 17
                    letterSpacing: 2.2
                    weight: Font.DemiBold
                }

                // High-contrast Mode Tag Capsule
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    width: sysTagText.implicitWidth + 12
                    radius: 0
                    color: Qt.rgba(Theme.laser.r, Theme.laser.g, Theme.laser.b, 0.12)
                    border.width: 1
                    border.color: Theme.specularDim

                    Text {
                        id: sysTagText
                        anchors.centerIn: parent
                        text: "SYS // NOMINAL"
                        color: Theme.laser
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szNano
                        font.letterSpacing: 1.0
                    }
                }
            }

            Row {
                id: headerSlot
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 20
            }
        }

        // Top Division Rule with Laser Pip
        Item {
            id: ruleTopContainer
            anchors { top: header.bottom; topMargin: panel.gap
                      left: parent.left; right: parent.right
                      leftMargin: panel.pad; rightMargin: panel.pad }
            height: 1

            Rectangle {
                anchors.fill: parent
                color: Theme.glassBorder
            }
            Rectangle {
                width: 38
                height: 1
                color: Theme.laser
                anchors.centerIn: parent
                opacity: 0.85
            }
        }

        // ---- Footer ------------------------------------------------------
        Item {
            id: footer
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right
                      margins: panel.pad }
            height: 16

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 5; height: 5; radius: 0
                    color: Theme.laser
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "READY // 待機  •  " + panel.hint
                    color: Theme.textSecondary
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szTail
                    font.letterSpacing: 1.4
                }
            }

            // Right-aligned Telemetry
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "NEURAL DECK // OPTICAL GLASS"
                color: Theme.textTertiary
                font.family: Theme.fontMono
                font.pixelSize: Theme.szNano
                font.letterSpacing: 1.2
            }
        }

        // Bottom Division Rule
        Item {
            id: ruleBottomContainer
            anchors { bottom: footer.top; bottomMargin: panel.gap
                      left: parent.left; right: parent.right
                      leftMargin: panel.pad; rightMargin: panel.pad }
            height: 1

            Rectangle {
                anchors.fill: parent
                color: Theme.glassBorder
            }
            Rectangle {
                width: 30
                height: 1
                color: Theme.specularCatch
                anchors.centerIn: parent
                opacity: 0.5
            }
        }

        // ---- Body --------------------------------------------------------
        Item {
            id: body
            anchors { top: ruleTopContainer.bottom; bottom: ruleBottomContainer.top
                      left: parent.left; right: parent.right
                      topMargin: panel.gap; bottomMargin: panel.gap
                      leftMargin: panel.pad; rightMargin: panel.pad }
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
            clip: true
        }
    }

    // Directional Entrance & Scrim Reveal Animation with Apple Fluid Springs
    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            id: slideXAnim
            target: trans
            property: "x"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideYAnim
            target: trans
            property: "y"
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: scaleAnim
            target: box
            property: "scale"
            from: 0.965
            to: 1.0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: boxOpacityAnim
            target: box
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 200
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: scrimOpacityAnim
            target: scrimRect
            property: "opacity"
            from: 0.0
            to: panel.targetScrimOpacity
            duration: 220
            easing.type: Easing.OutQuad
        }
    }

    function startEntrance() {
        enterAnim.stop();

        let sx = 0;
        let sy = 0;
        if (panel.placement === "right") {
            sx = 120;
        } else if (panel.placement === "left") {
            sx = -120;
        } else if (panel.placement === "top") {
            sy = -70;
        } else if (panel.placement === "bottom") {
            sy = 70;
        } else { // "center"
            sy = 24;
        }

        trans.x = sx;
        trans.y = sy;
        box.scale = 0.965;
        box.opacity = 0.0;
        scrimRect.opacity = 0.0;

        slideXAnim.from = sx;
        slideYAnim.from = sy;
        scrimOpacityAnim.to = panel.targetScrimOpacity;

        enterAnim.start();

        if (typeof glitchTitle !== "undefined" && glitchTitle) {
            glitchTitle.trigger();
        }
    }

    function resetEntrance() {
        enterAnim.stop();
        trans.x = 0;
        trans.y = 0;
        box.scale = 1.0;
        box.opacity = 0.0;
        scrimRect.opacity = 0.0;
    }

    Component.onCompleted: {
        if (panel.isWindowVisible) {
            panel.startEntrance();
        } else {
            panel.resetEntrance();
        }
    }
}
