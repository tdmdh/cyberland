// Workspace + scrolling-layout position HUD.
//
// The column tape of the workspace you are on. Workspaces themselves moved to
// the always-on `frame` module -- showing them in both places was two answers
// to one question. The tape still hides itself when there is nothing to say,
// column shows nothing at all.
//
// The scrolling layout puts windows on an infinite horizontal tape, so at any
// moment some columns are off-screen and there is nothing on screen telling you
// how many, or where you are among them. This draws that tape.
//
// Each segment is one column, width proportional to the real column width.
// The focused column is filled; columns currently off-screen are dimmed further.
// It fades in on change and back out, so it is an HUD, not a bar.
//
// Both rows live here rather than in a second module: they want the same
// palette watcher, the same Hyprland event debounce, and the same screen edge.
//
//   run: qs -d -c hud

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "./common"

ShellRoot {
    id: root

    // ---- column model ----------------------------------------------------
    // Hyprland has no "column" concept in its IPC; a column is just a set of
    // windows sharing an x. 40px of slack absorbs gaps and rounding.
    readonly property int xTolerance: 40

    property var columns: []
    property int activeColumn: -1

    function rebuild(): void {
        const ws = Hyprland.focusedWorkspace;
        const mon = Hyprland.focusedMonitor;
        if (!ws || !mon) { root.columns = []; root.activeColumn = -1; return; }

        let cols = [];
        let activeIdx = -1;

        for (const tl of Hyprland.toplevels.values) {
            const o = tl.lastIpcObject;
            if (!o || !o.at || !o.size) continue;
            if (!o.workspace || o.workspace.id !== ws.id) continue;
            // Floating windows overlay the tape, they are not part of it.
            if (o.floating || o.mapped === false) continue;

            const x = o.at[0], w = o.size[0];
            let hit = cols.find(c => Math.abs(c.x - x) <= root.xTolerance);
            if (!hit) {
                hit = { x: x, w: w, count: 0, active: false };
                cols.push(hit);
            }
            hit.count++;
            // A column is as wide as its widest window and starts at its
            // leftmost edge; taking the first window's values is wrong when a
            // column holds windows of differing width.
            hit.x = Math.min(hit.x, x);
            hit.w = Math.max(hit.w, w);
            // focusHistoryID 0 is the focused window. Unlike activeToplevel it
            // is present immediately, without waiting for a focus event.
            if (o.focusHistoryID === 0) hit.active = true;
        }

        cols.sort((a, b) => a.x - b.x);

        // Off-screen columns are the whole point of the HUD, so mark them.
        for (let i = 0; i < cols.length; i++) {
            cols[i].visible = (cols[i].x + cols[i].w > 0) && (cols[i].x < mon.width);
            if (cols[i].active) activeIdx = i;
        }

        root.columns = cols;
        root.activeColumn = activeIdx;
    }

    // Hyprland fires a lot of events; coalesce them into one rebuild.
    Timer {
        id: debounce
        interval: 40
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
            root.rebuild();
            reveal.restart();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { debounce.restart(); }
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        root.rebuild();
    }

    // ---- visibility ------------------------------------------------------
    // One column is nothing to navigate, so there is nothing to draw.
    readonly property bool worthShowing: root.columns.length > 1

    property bool shown: false

    Timer {
        id: reveal
        interval: 1600
        onTriggered: root.shown = false
        onRunningChanged: if (running) root.shown = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:scrollhud"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            exclusiveZone: 0

            anchors { bottom: true; left: true; right: true }
            // Must exceed the stack's bottomMargin (48) by the content
            // height, or the tape is clipped off the bottom of the window.
            implicitHeight: 84

            // Empty mask: the HUD never eats a click.
            mask: Region {}

            Column {
                id: stack
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                // Clears the frame's 40px bottom band (theme.lua gaps_out.bottom),
                // which now carries the BL/BR corner clusters.
                anchors.bottomMargin: 48
                spacing: 12

                opacity: (root.shown && root.worthShowing) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.morphMs; easing.type: Easing.OutCubic } }

                // Slides up a few px as it appears rather than just fading.
                transform: Translate {
                    y: stack.opacity > 0.5 ? 0 : 6
                    Behavior on y { NumberAnimation { duration: Theme.morphMs; easing.type: Easing.OutCubic } }
                }

                // ---- column tape floating capsule -------------------------
                Rectangle {
                    id: tapeCapsule
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tape.width + 20
                    height: 20
                    radius: 0
                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.75)
                    border.width: 1
                    border.color: Theme.edge

                    // Top specular catch
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        color: Theme.accentWash
                    }

                    Item {
                        id: tape
                        anchors.centerIn: parent
                        width: Math.min(win.width * 0.30, 500)
                        height: 12

                        readonly property real totalW: {
                            let t = 0;
                            for (const c of root.columns) t += c.w;
                            return t > 0 ? t : 1;
                        }
                        readonly property real gap: 4

                        Row {
                            anchors.fill: parent
                            spacing: tape.gap

                            Repeater {
                                model: root.columns

                                Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: Math.max(
                                        8,
                                        (tape.width - tape.gap * (root.columns.length - 1))
                                        * (modelData.w / tape.totalW))
                                    height: index === root.activeColumn ? 6 : 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 0

                                    color: index === root.activeColumn
                                           ? Theme.accent
                                           : Theme.text

                                    opacity: index === root.activeColumn ? 1.0
                                             : (modelData.visible ? 0.45 : 0.16)

                                    Behavior on width   { NumberAnimation { duration: Theme.easeMs; easing.type: Easing.OutCubic } }
                                    Behavior on height  { NumberAnimation { duration: Theme.easeMs; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: Theme.easeMs } }
                                    Behavior on color   { ColorAnimation  { duration: Theme.easeMs } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
