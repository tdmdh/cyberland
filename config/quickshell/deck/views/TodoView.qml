import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "TODO"
    readonly property string panelJp: "予定"
    readonly property string panelHint: "ENTER  ADD / TICK  •  ↑ ↓  MOVE  •  CTRL+D  DEL  •  CTRL+X  CLEAR DONE  •  ESC  CLOSE"
    readonly property int panelWidth: Theme.panelM
    readonly property int panelHeight: 660
    readonly property string placement: "center"

    signal closeRequested()

    property string draft: ""
    property var items: []
    property int seq: 0
    property double now: Date.now()
    property bool armedClear: false

    readonly property int staleDays: 7
    readonly property var open: view.items.filter(i => !i.done)
    readonly property var done: view.items.filter(i => i.done)
    readonly property var ordered: view.open.concat(view.done)

    function onActivated(): void {
        view.draft = "";
        view.now = Date.now();
        view.armedClear = false;
        list.currentIndex = 0;
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
            if (view.draft.trim() !== "") {
                view.add(view.draft);
            } else if (list.currentIndex >= 0 && list.currentIndex < view.ordered.length) {
                view.toggle(view.ordered[list.currentIndex].id);
            }
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_D && list.currentIndex >= 0 && list.currentIndex < view.ordered.length) {
                view.drop(view.ordered[list.currentIndex].id);
                event.accepted = true;
            } else if (event.key === Qt.Key_X) {
                view.clearDone();
                event.accepted = true;
            }
        }
    }

    // ---- store -----------------------------------------------------------
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/share/hypr/todo.json"
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            let v;
            try { v = JSON.parse(text()); } catch (e) { return; }
            view.items = Array.isArray(v) ? v.filter(i => i && typeof i.text === "string") : [];
        }
        onLoadFailed: view.items = []
    }

    function save(): void {
        store.setText(JSON.stringify(view.items, null, 2) + "\n");
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")"; [ -f "$1" ] || printf "[]\n" > "$1"',
            "sh", store.path]);
    }

    // ---- edits -----------------------------------------------------------
    function add(text: string): void {
        const t = text.trim();
        if (t === "") return;
        view.items = view.items.concat([{
            id: Date.now() + "." + (view.seq++),
            text: t, done: false, at: Date.now(), doneAt: 0
        }]);
        view.save();
        view.draft = "";
        list.currentIndex = 0;
    }

    function toggle(id: string): void {
        view.items = view.items.map(i => i.id !== id ? i
            : ({ id: i.id, text: i.text, done: !i.done, at: i.at,
                 doneAt: !i.done ? Date.now() : 0 }));
        view.save();
    }

    function drop(id: string): void {
        view.items = view.items.filter(i => i.id !== id);
        view.save();
        if (list.currentIndex >= view.ordered.length) {
            list.currentIndex = Math.max(0, view.ordered.length - 1);
        }
    }

    function clearDone(): void {
        if (view.done.length === 0) return;
        if (!view.armedClear) {
            view.armedClear = true;
            armedTimer.restart();
            return;
        }
        view.items = view.open;
        view.save();
        view.armedClear = false;
        list.currentIndex = 0;
    }

    Timer {
        id: armedTimer
        interval: 3000
        onTriggered: view.armedClear = false
    }

    function age(i) { return Math.floor((view.now - i.at) / 86400000); }

    function ago(ms): string {
        const s = Math.floor((view.now - ms) / 1000);
        if (s < 3600)  return Math.max(0, Math.floor(s / 60)) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    Timer {
        interval: 60000; repeat: true; running: view.visible
        onTriggered: view.now = Date.now()
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "OPEN"
                jp: "残務"
                value: ("0" + view.open.length).slice(-2)
                subValue: view.open.length > 0 ? "PENDING" : "CLEAR"
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "STALE"
                jp: "滞留"
                visible: staleCount > 0
                readonly property int staleCount: view.open.filter(i => view.age(i) >= view.staleDays).length
                value: ("0" + staleCount).slice(-2)
                subValue: "REVIEW"
                warn: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: view.armedClear ? "CONFIRM" : "CLEAR DONE"
                jp: "済消"
                active: view.armedClear
                tint: Theme.alert
                enabled: view.done.length > 0
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.clearDone()
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 12

        // Input row
        Item {
            width: parent.width
            height: 28

            Text {
                id: caret
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                color: view.draft === "" ? Theme.dim : Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.szValue
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: caret.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                text: view.draft === "" ? "NEW TASK  新規" : view.draft
                color: view.draft === "" ? Theme.dim : Theme.text
                font.family: view.draft === "" ? Theme.fontDisplay : Theme.fontMono
                font.pixelSize: view.draft === "" ? Theme.szBody : Theme.szValue
                font.letterSpacing: view.draft === "" ? Theme.trkWide : Theme.trkTight
                elide: Text.ElideRight
            }

            TextInput {
                id: field
                anchors.fill: parent
                opacity: 0
                focus: true
                text: view.draft
                onTextChanged: {
                    view.draft = text;
                    view.armedClear = false;
                }
                Keys.onEscapePressed: view.closeRequested()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
                onAccepted: {
                    if (view.draft.trim() !== "") {
                        view.add(view.draft);
                    } else if (list.currentIndex >= 0 && list.currentIndex < view.ordered.length) {
                        view.toggle(view.ordered[list.currentIndex].id);
                    }
                }
                Keys.onPressed: e => {
                    if (!(e.modifiers & Qt.ControlModifier)) return;
                    if (e.key === Qt.Key_D && list.currentIndex < view.ordered.length) {
                        view.drop(view.ordered[list.currentIndex].id);
                        e.accepted = true;
                    }
                    if (e.key === Qt.Key_X) {
                        view.clearDone();
                        e.accepted = true;
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.edge }

        // List
        Item {
            width: parent.width
            height: parent.height - 42
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: view.ordered
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: 0

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 34
                    radius: 0

                    readonly property bool sel: index === list.currentIndex
                    readonly property bool stale: !modelData.done && view.age(modelData) >= view.staleDays

                    color: row.sel ? Theme.card : (rowMouse.containsMouse ? Qt.rgba(Theme.layer2.r, Theme.layer2.g, Theme.layer2.b, 0.25) : "transparent")
                    border.width: 1
                    border.color: row.sel ? Theme.edge : "transparent"

                    // Top specular catch
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        visible: row.sel
                        color: Theme.accentEdge
                    }

                    // Left accent indicator
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        anchors.margins: 4
                        width: 2
                        radius: 0
                        color: row.sel ? Theme.accent : "transparent"
                    }

                    // Tactile sharp checkbox
                    Rectangle {
                        id: box
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        width: 14; height: 14
                        radius: 0
                        color: row.modelData.done ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : "transparent"
                        border.width: 1
                        border.color: row.modelData.done ? Theme.accent : (row.sel ? Theme.accent : Theme.line)

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6; height: 6
                            radius: 0
                            color: Theme.accent
                            visible: row.modelData.done
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: box.right
                        anchors.leftMargin: 14
                        anchors.right: agecol.left
                        anchors.rightMargin: 14
                        text: row.modelData.text
                        color: row.modelData.done ? Theme.dim : (row.sel ? Theme.text : Theme.text)
                        font.strikeout: row.modelData.done
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szBody
                        opacity: row.modelData.done ? 0.55 : 1.0
                        elide: Text.ElideRight
                    }

                    Text {
                        id: agecol
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        width: 42
                        horizontalAlignment: Text.AlignRight
                        text: view.ago(row.modelData.done ? row.modelData.doneAt : row.modelData.at)
                        color: row.stale ? Theme.warn : Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szMicro
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            list.currentIndex = row.index;
                            view.toggle(row.modelData.id);
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: view.items.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NOTHING ON THE LIST"
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkWide
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "空"
                    color: Theme.dim
                    font.family: Theme.fontJP
                    font.pixelSize: Theme.szMicro
                }
            }
        }
    }
}
