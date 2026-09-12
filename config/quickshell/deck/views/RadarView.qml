import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "RADAR"
    readonly property string panelJp: "端口"
    readonly property string panelHint: view.armedPid > 0
        ? "CONFIRM KILL: PRESS K AGAIN TO TERMINATE PID " + view.armedPid + "  •  ESC CLOSE"
        : "↑ ↓  MOVE  •  ENTER / O  BROWSER  •  K  KILL PID  •  R  REFRESH  •  /  FILTER  •  ESC  CLOSE"
    readonly property int panelWidth: 960
    readonly property int panelHeight: 640
    readonly property string placement: "center"

    signal closeRequested()

    property string query: ""
    property var sockets: []
    property int armedPid: 0

    function onActivated(): void {
        view.query = "";
        view.armedPid = 0;
        view.probe();
        filterInput.forceActiveFocus();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            socketList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            socketList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_O) {
            if (socketList.currentIndex >= 0 && socketList.currentIndex < view.shown.length) {
                const s = view.shown[socketList.currentIndex];
                view.openBrowser(s.port, s.bind);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_K) {
            if (socketList.currentIndex >= 0 && socketList.currentIndex < view.shown.length) {
                const s = view.shown[socketList.currentIndex];
                if (s.pid > 0) view.killPid(s.pid);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            view.probe();
            event.accepted = true;
        }
    }

    // ---- probe process ---------------------------------------------------
    Process {
        id: probeProc
        command: [Quickshell.env("HOME") + "/.config/hypr/bin/portprobe"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    try {
                        list.push(JSON.parse(line));
                    } catch (e) { /* ignore partial */ }
                }
                view.sockets = list;
            }
        }
    }

    function probe(): void {
        if (!probeProc.running) {
            probeProc.running = true;
        }
    }

    readonly property var shown: {
        const q = view.query.trim().toLowerCase();
        if (q === "") return view.sockets;
        return view.sockets.filter(s => {
            return ("" + s.port).indexOf(q) >= 0
                || (s.proc && s.proc.toLowerCase().indexOf(q) >= 0)
                || (s.bind && s.bind.toLowerCase().indexOf(q) >= 0)
                || (s.user && s.user.toLowerCase().indexOf(q) >= 0)
                || (s.container && s.container.toLowerCase().indexOf(q) >= 0);
        });
    }

    readonly property int countPublic: view.sockets.filter(s => s.public).length
    readonly property int countDev: view.sockets.filter(s => s.port >= 1024 && s.port <= 9999).length

    // ---- actions ---------------------------------------------------------
    function openBrowser(port: int, bind: string): void {
        const host = (bind === "0.0.0.0" || bind === "::" || bind === "*") ? "localhost" : bind;
        Quickshell.execDetached(["xdg-open", "http://" + host + ":" + port]);
        view.closeRequested();
    }

    function killPid(pid: int): void {
        if (pid <= 1) return;
        if (view.armedPid !== pid) {
            view.armedPid = pid;
            return;
        }
        Quickshell.execDetached(["kill", "-15", "" + pid]);
        view.armedPid = 0;
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 400
        repeat: false
        onTriggered: view.probe()
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "SOCKETS"
                jp: "総数"
                value: ("0" + view.shown.length).slice(-2)
                subValue: view.query === "" ? "LISTENING" : "OF " + view.sockets.length
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "PUBLIC"
                jp: "公開"
                value: ("0" + view.countPublic).slice(-2)
                subValue: view.countPublic > 0 ? "EXPOSED" : "SECURE"
                warn: view.countPublic > 0
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "DEV"
                jp: "開発"
                value: ("0" + view.countDev).slice(-2)
                subValue: "LOCAL"
                tint: Theme.laser
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: "REFRESH"
                jp: "更新"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.probe()
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 12

        // Search / Filter row
        Item {
            width: parent.width
            height: 28

            Text {
                id: caret
                anchors.verticalCenter: parent.verticalCenter
                text: "/"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.szValue
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: caret.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                text: view.query === "" ? "FILTER PORT / PROCESS / USER  絞込" : view.query
                color: view.query === "" ? Theme.dim : Theme.text
                font.family: view.query === "" ? Theme.fontDisplay : Theme.fontMono
                font.pixelSize: view.query === "" ? Theme.szBody : Theme.szValue
                font.letterSpacing: view.query === "" ? 3 : 0.5
                elide: Text.ElideRight
            }

            TextInput {
                id: filterInput
                anchors.fill: parent
                opacity: 0
                focus: true
                text: view.query
                onTextChanged: {
                    view.query = text;
                    view.armedPid = 0;
                    socketList.currentIndex = 0;
                }
                Keys.onEscapePressed: view.closeRequested()
                Keys.onUpPressed: socketList.decrementCurrentIndex()
                Keys.onDownPressed: socketList.incrementCurrentIndex()
                onAccepted: {
                    if (socketList.currentIndex >= 0 && socketList.currentIndex < view.shown.length) {
                        const s = view.shown[socketList.currentIndex];
                        view.openBrowser(s.port, s.bind);
                    }
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_O) {
                        if (socketList.currentIndex >= 0 && socketList.currentIndex < view.shown.length) {
                            const s = view.shown[socketList.currentIndex];
                            view.openBrowser(s.port, s.bind);
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        if (socketList.currentIndex >= 0 && socketList.currentIndex < view.shown.length) {
                            const s = view.shown[socketList.currentIndex];
                            if (s.pid > 0) view.killPid(s.pid);
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_R) {
                        view.probe();
                        event.accepted = true;
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.glassBorder }

        // Sockets List View
        Item {
            width: parent.width
            height: parent.height - 42
            clip: true

            ListView {
                id: socketList
                anchors.fill: parent
                clip: true
                model: view.shown
                spacing: 2
                highlightFollowsCurrentItem: true
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    readonly property var itemData: modelData
                    width: socketList.width
                    height: 36
                    radius: 0
                    color: ListView.isCurrentItem ? Theme.glassCard : (rowMouse.containsMouse ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.3) : "transparent")
                    border.width: 1
                    border.color: view.armedPid === modelData.pid ? Theme.alert : (ListView.isCurrentItem ? Theme.glassBorder : "transparent")

                    // Top specular hairline catch
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        visible: ListView.isCurrentItem
                        color: Theme.specularCatch
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: socketList.currentIndex = index
                        onDoubleClicked: view.openBrowser(modelData.port, modelData.bind)
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        spacing: 12

                        // Proto Badge
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 18
                            radius: 0
                            color: modelData.proto === "tcp" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Qt.rgba(Theme.amber.r, Theme.amber.g, Theme.amber.b, 0.18)
                            border.width: 1
                            border.color: modelData.proto === "tcp" ? Theme.accent : Theme.amber

                            Text {
                                anchors.centerIn: parent
                                text: modelData.proto.toUpperCase()
                                color: modelData.proto === "tcp" ? Theme.accent : Theme.amber
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                                font.weight: Font.Bold
                            }
                        }

                        // Port
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64
                            text: "" + modelData.port
                            color: ListView.isCurrentItem ? Theme.accent : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szValue
                            font.weight: Font.DemiBold
                        }

                        // Binding
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 92
                            height: 18
                            radius: 0
                            color: modelData.public ? Qt.rgba(Theme.amber.r, Theme.amber.g, Theme.amber.b, 0.18) : "transparent"
                            border.width: modelData.public ? 1 : 0
                            border.color: Theme.amber

                            Text {
                                anchors.centerIn: parent
                                text: modelData.public ? "PUBLIC " + modelData.bind : modelData.bind
                                color: modelData.public ? Theme.warn : Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }
                        }

                        // Process Name
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 140
                            text: modelData.proc
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szBody
                            elide: Text.ElideRight
                        }

                        // PID
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 70
                            text: modelData.pid > 0 ? "PID " + modelData.pid : "--"
                            color: view.armedPid === modelData.pid ? Theme.alert : Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                            font.weight: view.armedPid === modelData.pid ? Font.Bold : Font.Normal
                        }

                        // Container Badge if present
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.container !== ""
                            width: cText.implicitWidth + 8
                            height: 18
                            color: Theme.layer3
                            border.width: 1
                            border.color: Theme.accent2

                            Text {
                                id: cText
                                anchors.centerIn: parent
                                text: modelData.container
                                color: Theme.accent2
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }
                        }

                        // User / Owner
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.user
                            color: Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                        }
                    }

                    // Action Hint / Armed status
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        visible: ListView.isCurrentItem
                        text: view.armedPid === modelData.pid
                            ? "PRESS K TO KILL"
                            : (modelData.pid > 0 ? "[K] KILL  •  [ENTER] HTTP" : "[ENTER] HTTP")
                        color: view.armedPid === modelData.pid ? Theme.alert : Theme.accent2
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szMicro
                        font.letterSpacing: 1.5
                    }
                }
            }
        }
    }
}
