import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "NOTIFICATIONS"
    readonly property string panelJp: "通知"
    readonly property string panelHint: "D  DO NOT DISTURB  •  C  CLEAR ALL  •  ↑ ↓  NAVIGATE  •  DEL/X  DISMISS  •  ESC  CLOSE"
    readonly property int panelWidth: 840
    readonly property int panelHeight: 880
    readonly property string placement: "right"
    readonly property bool fullBleed: false

    signal closeRequested()

    property bool dnd: false
    property var items: []

    function onActivated(): void {
        view.refresh();
        notifList.forceActiveFocus();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_D) {
            view.toggleDnd();
            event.accepted = true;
        } else if (event.key === Qt.Key_C) {
            view.clearAll();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            notifList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            notifList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_X) {
            if (notifList.currentIndex >= 0 && notifList.currentIndex < view.items.length) {
                view.dismissItem(view.items[notifList.currentIndex].id);
                event.accepted = true;
            }
        }
    }

    // ---- IPC Integration with Notification Daemon ------------------------
    Process {
        id: notifListQuery
        command: ["qs", "-c", "notify", "ipc", "call", "notify", "list"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line.trim());
                    view.dnd = !!data.dnd;
                    view.items = data.items || [];
                } catch (e) { }
            }
        }
    }

    Process {
        id: notifCmd
        onExited: notifListQuery.running = true
    }

    function refresh(): void {
        notifListQuery.running = true;
    }

    function toggleDnd(): void {
        notifCmd.command = ["qs", "-c", "notify", "ipc", "call", "notify", "dnd"];
        notifCmd.running = true;
    }

    function clearAll(): void {
        view.items = [];
        notifCmd.command = ["qs", "-c", "notify", "ipc", "call", "notify", "clear"];
        notifCmd.running = true;
    }

    function dismissItem(id): void {
        view.items = view.items.filter(it => it.id !== id);
        notifCmd.command = ["qs", "-c", "notify", "ipc", "call", "notify", "dismiss", "" + id];
        notifCmd.running = true;
    }

    function invokeAction(id, actionId): void {
        notifCmd.command = ["qs", "-c", "notify", "ipc", "call", "notify", "invoke", "" + id, actionId];
        notifCmd.running = true;
    }

    Timer {
        interval: 1000
        repeat: true
        running: view.visible
        onTriggered: view.refresh()
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8

            DynamicPill {
                label: "HELD"
                jp: "件数"
                value: ("0" + view.items.length).slice(-2)
                subValue: view.dnd ? "DND ACTIVE" : (view.items.length > 0 ? "NOTIFICATIONS" : "ALL CLEAR")
                warn: view.dnd
                anchors.verticalCenter: parent.verticalCenter
            }

            Btn {
                text: "DND"
                jp: "静音"
                active: view.dnd
                tint: Theme.warn
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.toggleDnd()
            }

            Btn {
                text: "CLEAR"
                jp: "消去"
                tint: Theme.alert
                enabled: view.items.length > 0
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.clearAll()
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Item {
        anchors.fill: parent

        // Empty state indicator
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: view.items.length === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: view.dnd ? "DO NOT DISTURB" : "NOTHING HELD"
                color: view.dnd ? Theme.warn : Theme.dim
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.szBody + 2
                font.letterSpacing: Theme.trkWide
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: view.dnd ? "静音モード有効" : "通知なし • 全てクリア"
                color: Theme.line
                font.family: Theme.fontJP
                font.pixelSize: Theme.szMicro
                font.letterSpacing: 1.2
            }
        }

        // Notification List
        ListView {
            id: notifList
            anchors.fill: parent
            clip: true
            spacing: 6
            model: view.items
            boundsBehavior: Flickable.StopAtBounds
            visible: view.items.length > 0

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: notifList.width
                implicitHeight: rowCard.implicitHeight + 4
                height: implicitHeight

                readonly property bool crit: !!modelData.crit
                readonly property bool isSelected: notifList.currentIndex === index

                Rectangle {
                    id: rowCard
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    implicitHeight: rowCol.implicitHeight + 24
                    height: implicitHeight

                    color: rowMouse.containsMouse || row.isSelected ? Theme.layer1 : "transparent"
                    border.width: 1
                    border.color: row.crit ? Theme.alert : (rowMouse.containsMouse || row.isSelected ? Theme.glassBorder : "transparent")

                    Behavior on color { ColorAnimation { duration: 110 } }
                    Behavior on border.color { ColorAnimation { duration: 110 } }

                    // Critical or active urgency spine indicator
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 3
                        visible: row.crit || row.isSelected
                        color: row.crit ? Theme.alert : Theme.accent
                    }

                    // Card Content
                    Column {
                        id: rowCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 16
                            rightMargin: 16
                        }
                        spacing: 6

                        // Metadata header row
                        Item {
                            width: parent.width
                            height: rowTag.height

                            Tag {
                                id: rowTag
                                label: (row.modelData.appName || "UNKNOWN").toUpperCase()
                                jp: row.crit ? "重要" : ""
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: rowTag.verticalCenter
                                spacing: 14

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.timeAgo || ""
                                    color: Theme.line
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.szMicro
                                }

                                Text {
                                    id: closeBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✕"
                                    color: closeMouse.containsMouse ? Theme.alert : Theme.line2
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.szTail

                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.dismissItem(row.modelData.id)
                                    }
                                }
                            }
                        }

                        // Summary
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.summary || ""
                            color: row.crit ? Theme.alert : Theme.text
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szBody + 2
                            font.letterSpacing: 0.4
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Body
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.body || ""
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szBody
                            textFormat: Text.StyledText
                            linkColor: Theme.accent
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 3
                        }

                        // Action Buttons
                        Row {
                            spacing: 8
                            topPadding: 2
                            visible: row.modelData.actions && row.modelData.actions.length > 0

                            Repeater {
                                model: row.modelData.actions || []
                                Btn {
                                    required property var modelData
                                    text: (modelData.text || "").toUpperCase()
                                    onClicked: view.invokeAction(row.modelData.id, modelData.id)
                                }
                            }
                        }
                    }

                    // Background click area for row selection & dismiss
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        z: -1
                        onClicked: notifList.currentIndex = row.index
                    }
                }

                // Row Divider Line
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Theme.line2
                }
            }
        }
    }
}
