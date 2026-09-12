import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "CYBERPAD"
    readonly property string panelJp: "電脳卓"
    readonly property string panelHint: "CTRL+S SAVE  •  CTRL+Y COPY  •  CTRL+ENTER RUN  •  ESC CLOSE"
    readonly property int panelWidth: 860
    readonly property int panelHeight: 400
    readonly property string placement: "top"

    signal closeRequested()

    property string buffer: ""
    property bool saved: true
    property bool copied: false
    property bool armedWipe: false

    readonly property int lineCount: buffer.split("\n").length
    readonly property int charCount: buffer.length
    readonly property int wordCount: {
        const trimmed = buffer.trim();
        return trimmed === "" ? 0 : trimmed.split(/\s+/).length;
    }

    function onActivated(): void {
        editor.forceActiveFocus();
    }

    function save(): void {
        store.setText(view.buffer);
        view.saved = true;
    }

    function copyAll(): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", view.buffer]);
        view.copied = true;
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: view.copied = false
    }

    function wipe(): void {
        if (!view.armedWipe) {
            view.armedWipe = true;
            wipeArmTimer.restart();
            return;
        }
        view.buffer = "";
        editor.text = "";
        view.save();
        view.armedWipe = false;
    }

    Timer {
        id: wipeArmTimer
        interval: 3000
        onTriggered: view.armedWipe = false
    }

    function execTerminal(): void {
        const scriptPath = Quickshell.env("XDG_RUNTIME_DIR") + "/cyberpad_exec.sh";
        Quickshell.execDetached(["sh", "-c",
            'printf \'%s\n\' "$1" > "$2" && chmod +x "$2" && kitty --title "CYBERPAD EXEC" bash -c "$2; echo; read -n 1 -s -r -p \"[CYBERPAD] Process finished. Press any key to exit...\"; rm -f \"$2\""',
            "sh", view.buffer, scriptPath]);
    }

    function handleKey(event): void {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
            view.save();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) {
            view.copyAll();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            view.execTerminal();
            event.accepted = true;
        }
    }

    // Dynamic Header Component
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "LINES"
                jp: "行数"
                value: ("00" + view.lineCount).slice(-3)
                subValue: view.saved ? "SAVED" : "DIRTY"
                tint: view.saved ? Theme.laser : Theme.amber
            }
            Btn {
                text: view.copied ? "COPIED" : "COPY"
                jp: "複製"
                active: view.copied
                tint: Theme.laser
                implicitHeight: 22
                onClicked: view.copyAll()
            }
            Btn {
                text: "RUN"
                jp: "実行"
                tint: Theme.accent
                implicitHeight: 22
                onClicked: view.execTerminal()
            }
            Btn {
                text: view.armedWipe ? "CONFIRM" : "CLEAR"
                jp: "消去"
                active: view.armedWipe
                tint: Theme.alert
                implicitHeight: 22
                onClicked: view.wipe()
            }
        }
    }

    // File Store
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/share/hypr/scratchpad.md"
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            const content = text();
            if (content !== view.buffer) {
                view.buffer = content;
                if (editor.text !== content) editor.text = content;
                view.saved = true;
            }
        }
        onLoadFailed: view.buffer = ""
    }

    Timer {
        id: autoSaveTimer
        interval: 600
        repeat: false
        onTriggered: view.save()
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")"; [ -f "$1" ] || printf "# CYBERPAD // 電脳卓\n\n- Ephemeral cyberdeck scratchpad\n- Auto-persists to ~/.local/share/hypr/scratchpad.md\n" > "$1"',
            "sh", store.path]);
    }

    // Editor Canvas
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.glassCard
        border.width: 1
        border.color: view.saved ? Theme.glassBorder : Theme.amber
        clip: true

        ScrollView {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: 10
            clip: true

            TextArea {
                id: editor
                width: scrollArea.width
                text: view.buffer
                placeholderText: "// Enter code, prompts, notes, or shell commands here..."
                placeholderTextColor: Theme.textDim
                color: Theme.textPrimary
                font.family: Theme.fontMono
                font.pixelSize: 13
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                background: null
                selectedTextColor: "#ffffff"
                selectionColor: Theme.accent

                Keys.onEscapePressed: event => {
                    view.closeRequested();
                    event.accepted = true;
                }

                onTextChanged: {
                    if (view.buffer !== text) {
                        view.buffer = text;
                        view.saved = false;
                        autoSaveTimer.restart();
                    }
                }
            }
        }
    }
}
