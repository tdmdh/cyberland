import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "CLIPBOARD"
    readonly property string panelJp: "切抜"
    readonly property string panelHint: "↑ ↓  MOVE  •  ENTER  COPY  •  CTRL+D  DEL  •  CTRL+W  WIPE  •  ESC  CLOSE"
    readonly property int panelWidth: 1080
    readonly property int panelHeight: 640
    readonly property string placement: "center"

    signal closeRequested()

    property string query: ""
    property var entries: []
    property bool armedWipe: false

    function onActivated(): void {
        view.query = "";
        view.armedWipe = false;
        list.currentIndex = 0;
        if (!lister.running) lister.running = true;
        field.forceActiveFocus();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            list.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            list.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (list.currentIndex >= 0 && list.currentIndex < view.shown.length) {
                view.copy(view.shown[list.currentIndex].id);
            }
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_D && list.currentIndex >= 0 && list.currentIndex < view.shown.length) {
                view.drop(view.shown[list.currentIndex].id);
                event.accepted = true;
            } else if (event.key === Qt.Key_W) {
                view.wipe();
                event.accepted = true;
            }
        }
    }

    // ---- store -----------------------------------------------------------
    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = [];
                for (const line of text.split("\n")) {
                    if (line === "") continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    out.push({ id: line.slice(0, tab),
                               preview: line.slice(tab + 1) });
                }
                view.entries = out;
            }
        }
    }

    readonly property var shown: {
        const q = view.query.trim().toLowerCase();
        if (q === "") return view.entries;
        return view.entries.filter(e => e.preview.toLowerCase().indexOf(q) >= 0);
    }

    // ---- actions ---------------------------------------------------------
    function copy(id: string): void {
        Quickshell.execDetached(["sh", "-c",
            'cliphist decode "$1" | wl-copy', "sh", id]);
        view.closeRequested();
    }

    function drop(id: string): void {
        const e = view.entries.find(x => x.id === id);
        if (!e) return;
        Quickshell.execDetached(["sh", "-c",
            'printf "%s\\t%s\\n" "$1" "$2" | cliphist delete', "sh", e.id, e.preview]);
        view.entries = view.entries.filter(x => x.id !== id);
    }

    function wipe(): void {
        if (!view.armedWipe) {
            view.armedWipe = true;
            wipeTimer.restart();
            return;
        }
        Quickshell.execDetached(["cliphist", "wipe"]);
        view.entries = [];
        view.armedWipe = false;
    }

    Timer {
        id: wipeTimer
        interval: 3000
        onTriggered: view.armedWipe = false
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "HELD"
                jp: "件数"
                value: ("0" + view.shown.length).slice(-2)
                subValue: view.query === "" ? "IN BUFFER" : "OF " + view.entries.length
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: view.armedWipe ? "CONFIRM" : "WIPE"
                jp: "全消"
                active: view.armedWipe
                tint: Theme.alert
                enabled: view.entries.length > 0
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.wipe()
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 12

        // Search Field Row
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
                text: view.query === "" ? "FILTER  絞込" : view.query
                color: view.query === "" ? Theme.dim : Theme.text
                font.family: view.query === "" ? Theme.fontDisplay : Theme.fontMono
                font.pixelSize: view.query === "" ? Theme.szBody : Theme.szValue
                font.letterSpacing: view.query === "" ? 3 : 0.5
                elide: Text.ElideRight
            }

            TextInput {
                id: field
                anchors.fill: parent
                opacity: 0
                focus: true
                text: view.query
                onTextChanged: {
                    view.query = text;
                    view.armedWipe = false;
                    list.currentIndex = 0;
                }
                Keys.onEscapePressed: view.closeRequested()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
                onAccepted: {
                    if (list.currentIndex >= 0 && list.currentIndex < view.shown.length) {
                        view.copy(view.shown[list.currentIndex].id);
                    }
                }
                Keys.onPressed: e => {
                    if (e.modifiers & Qt.ControlModifier) {
                        if (e.key === Qt.Key_D && list.currentIndex >= 0 && list.currentIndex < view.shown.length) {
                            view.drop(view.shown[list.currentIndex].id);
                            e.accepted = true;
                        }
                        if (e.key === Qt.Key_W) {
                            view.wipe();
                            e.accepted = true;
                        }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.glassBorder }

        // Entries List View
        Item {
            width: parent.width
            height: parent.height - 42
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: view.shown
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: true
                currentIndex: 0

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 30
                    radius: 0

                    readonly property bool sel: index === list.currentIndex

                    color: row.sel ? Theme.glassCard : (rowMouse.containsMouse ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.25) : "transparent")
                    border.width: 1
                    border.color: row.sel ? Theme.glassBorder : "transparent"

                    // Top specular catch
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        visible: row.sel
                        color: Theme.specularCatch
                    }

                    // Left accent spine
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        anchors.margins: 4
                        width: 2
                        radius: 0
                        color: row.sel ? Theme.accent : "transparent"
                    }

                    Text {
                        id: num
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        width: 34
                        text: ("0" + (row.index + 1)).slice(-2)
                        color: row.sel ? Theme.accent : Theme.line
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szTail
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: num.right
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        text: row.modelData.preview
                        color: row.sel ? Theme.text : Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szBody
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            list.currentIndex = row.index;
                            view.copy(row.modelData.id);
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: view.shown.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: view.entries.length === 0 ? "NOTHING COPIED YET" : "NO MATCH"
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkWide
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "空"
                    color: Theme.line
                    font.family: Theme.fontJP
                    font.pixelSize: Theme.szMicro
                }
            }
        }
    }
}
