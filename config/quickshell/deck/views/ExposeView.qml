import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "EXPOSE"
    readonly property string panelJp: "一覧"
    readonly property string panelHint: "1-9  JUMP TO WORKSPACE  •  CLICK  FOCUS  •  ESC  CLOSE"
    readonly property int panelWidth: 1440
    readonly property int panelHeight: 820
    readonly property bool fullBleed: true
    readonly property string placement: "center"

    signal closeRequested()

    property var spaces: []

    function onActivated(): void {
        view.rebuild();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + (event.key - Qt.Key_0) + " })");
            view.closeRequested();
            event.accepted = true;
        }
    }

    function rebuild(): void {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();

        let onScreen = {};
        for (const m of Hyprland.monitors.values) {
            if (m.activeWorkspace) onScreen[m.activeWorkspace.id] = true;
        }
        const focused = Hyprland.focusedWorkspace;

        let byWs = {};
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.workspace || o.workspace.id < 0) continue;
            if (!byWs[o.workspace.id]) byWs[o.workspace.id] = [];
            byWs[o.workspace.id].push({
                address: o.address,
                cls: (o.class || o.initialClass || "?").toLowerCase(),
                title: o.title || "",
                x: o.at ? o.at[0] : 0,  y: o.at ? o.at[1] : 0,
                w: o.size ? o.size[0] : 1, h: o.size ? o.size[1] : 1,
                focused: !!o.focusHistoryID && o.focusHistoryID === 0
            });
        }

        let list = [];
        for (const ws of Hyprland.workspaces.values) {
            const o = ws.lastIpcObject;
            if (!o || o.id < 0) continue;
            const wins = byWs[o.id] || [];
            wins.sort((a, b) => a.x - b.x);
            list.push({
                id: o.id,
                label: ("0" + o.id).slice(-2),
                focused: !!focused && focused.id === o.id,
                onScreen: !!onScreen[o.id],
                windows: wins
            });
        }
        list.sort((a, b) => a.id - b.id);
        view.spaces = list;
    }

    Connections {
        target: Hyprland
        function onRawEvent(_) { if (view.visible) debounce.restart(); }
    }
    Timer { id: debounce; interval: 60; onTriggered: view.rebuild() }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "SPACES"
                jp: "領域"
                value: ("0" + view.spaces.length).slice(-2)
                subValue: "WORKSPACES"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "WINDOWS"
                jp: "窓"
                value: ("0" + view.spaces.reduce((n, w) => n + w.windows.length, 0)).slice(-2)
                subValue: "TOPLEVELS"
                tint: Theme.laser
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: grid.height + 40
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Flow {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 22

            readonly property int cellW: 320
            readonly property int perRow: Math.max(1, Math.min(
                view.spaces.length,
                Math.floor((view.width - 40 + spacing) / (cellW + spacing))))
            width: grid.perRow * (cellW + spacing) - spacing

            Repeater {
                model: view.spaces

                Item {
                    id: cell
                    required property var modelData
                    width: grid.cellW
                    height: 232

                    scale: cellMouse.pressed ? 0.98 : (cellMouse.containsMouse ? 1.015 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 0
                        color: cell.modelData.focused ? Theme.glassCard : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.25)
                        border.width: 1
                        border.color: cell.modelData.focused ? Theme.accent : Theme.glassBorder
                        clip: true

                        // Top specular catch
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 1
                            visible: cell.modelData.focused
                            color: Theme.specularCatch
                        }
                    }

                    // Workspace id
                    Row {
                        x: 16; y: 14
                        spacing: 6
                        Text {
                            text: cell.modelData.focused ? "[" + cell.modelData.label + "]"
                                                         : " " + cell.modelData.label + " "
                            color: cell.modelData.focused ? Theme.accent
                                 : cell.modelData.onScreen ? Theme.text : Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "作業領域"
                            color: Theme.line
                            font.family: Theme.fontJP
                            font.pixelSize: Theme.szMicro
                        }
                    }

                    // Windows representation
                    Row {
                        id: winRow
                        x: 16
                        y: 52
                        width: cell.width - 32
                        height: 118
                        spacing: 4

                        readonly property real total:
                            cell.modelData.windows.reduce((n, c) => n + Math.max(c.w, 1), 0) || 1

                        Repeater {
                            model: cell.modelData.windows
                            Rectangle {
                                required property var modelData
                                width: Math.max(26, (winRow.width - (cell.modelData.windows.length - 1) * 4)
                                                    * modelData.w / winRow.total)
                                height: winRow.height
                                radius: 0
                                color: modelData.focused ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Theme.glassCard
                                border.width: 1
                                border.color: modelData.focused ? Theme.accent : Theme.glassBorder

                                Rectangle {
                                    anchors { top: parent.top; left: parent.left; right: parent.right }
                                    anchors.margins: 4
                                    height: 1
                                    color: Theme.specularDim
                                }

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.cls
                                    color: modelData.focused ? Theme.accent : Theme.dim
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: 11
                                    font.letterSpacing: 1.2
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Text {
                        x: 16
                        y: 182
                        width: cell.width - 32
                        text: cell.modelData.windows.length === 0 ? "EMPTY"
                              : cell.modelData.windows.map(c => c.cls).join(" · ")
                        color: Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: 11
                        font.letterSpacing: 1.0
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Hyprland.dispatch("hl.dsp.focus({ workspace = " + cell.modelData.id + " })");
                            view.closeRequested();
                        }
                    }
                }
            }
        }
    }
}
