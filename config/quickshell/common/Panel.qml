// A standalone modal panel: scrim, placement and entrance animation around a
// Chrome. The deck morphs one Chrome between its views; this is for a module
// that owns a single panel of its own (the auth card).
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

    default property alias content: box.content
    property alias  headerItems: box.headerItems

    signal dismissed()

    anchors.fill: parent

    Rectangle {
        id: scrimRect
        anchors.fill: parent
        color: Theme.bg
        visible: panel.effectiveScrim !== "none"
        opacity: 0
    }

    // Click outside to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: panel.dismissed()
    }

    Chrome {
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
        height: (panel.placement === "right" && panel.panelHeight <= 0)
                ? (parent.height - 96)
                : (panel.panelHeight > 0
                   ? panel.panelHeight
                   : (panel.fullBleed
                      ? panel.height - 96
                      : Math.min(box.chrome + box.bodyImplicitHeight, panel.height - 120)))

        transform: Translate { id: trans }
        opacity: 0

        title: panel.title
        jp: panel.jp
        hint: panel.hint
        pad: panel.pad
        gap: panel.gap
        dark: panel.effectiveScrim === "none"
    }

    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            id: slideXAnim
            target: trans
            property: "x"
            to: 0
            duration: Theme.morphMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: slideYAnim
            target: trans
            property: "y"
            to: 0
            duration: Theme.morphMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: box
            property: "scale"
            from: 0.965
            to: 1.0
            duration: Theme.morphMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: box
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: Theme.easeMs
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            id: scrimOpacityAnim
            target: scrimRect
            property: "opacity"
            from: 0.0
            to: panel.targetScrimOpacity
            duration: Theme.easeMs
            easing.type: Easing.OutQuad
        }
    }

    function startEntrance() {
        enterAnim.stop();

        let sx = 0;
        let sy = 24;    // "center"
        if (panel.placement === "right") { sx = 120; sy = 0; }
        else if (panel.placement === "left") { sx = -120; sy = 0; }
        else if (panel.placement === "top") sy = -70;
        else if (panel.placement === "bottom") sy = 70;

        trans.x = sx;
        trans.y = sy;
        box.scale = 0.965;
        box.opacity = 0.0;
        scrimRect.opacity = 0.0;

        slideXAnim.from = sx;
        slideYAnim.from = sy;
        scrimOpacityAnim.to = panel.targetScrimOpacity;

        enterAnim.start();
        box.glitch();
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
