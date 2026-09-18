import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "KEYBINDS"
    readonly property string panelJp: "割当"
    readonly property string panelHint: "TYPE  FILTER       ESC  CLOSE"
    readonly property int panelWidth: Theme.panelM
    readonly property int panelHeight: 720
    readonly property string placement: "center"

    signal closeRequested()

    property var binds: []
    property string query: ""
    readonly property int columns: 2

    function onActivated(): void {
        view.query = "";
        field.forceActiveFocus();
        if (!probe.running) probe.running = true;
    }

    function handleKey(event): void {
        // Text input handles standard characters
    }

    function mods(m) {
        let out = [];
        if (m & 64) out.push("SUPER");
        if (m & 4)  out.push("CTRL");
        if (m & 8)  out.push("ALT");
        if (m & 1)  out.push("SHIFT");
        return out;
    }

    function keyName(k) {
        switch (k) {
            case "Return": return "RET";
            case "space":  return "SPC";
            case "slash":  return "/";
            case "Delete": return "DEL";
            case "XF86AudioRaiseVolume": return "VOL+";
            case "XF86AudioLowerVolume": return "VOL-";
            case "XF86AudioMute":        return "MUTE";
            case "XF86AudioMicMute":     return "MIC MUTE";
            case "XF86AudioPlay":        return "PLAY";
            case "XF86AudioNext":        return "NEXT";
            case "XF86AudioPrev":        return "PREV";
            case "XF86MonBrightnessUp":  return "BRI+";
            case "XF86MonBrightnessDown":return "BRI-";
            default:       return k.length === 1 ? k.toUpperCase() : k;
        }
    }

    Process {
        id: probe
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onDataChanged: {
                try {
                    const raw = JSON.parse(data);
                    const list = [];
                    for (const b of raw) {
                        if (!b.description || b.description === "") continue;
                        const m = view.mods(b.modmask);
                        const k = view.keyName(b.key);
                        const chord = (m.length > 0 ? m.join("+") + "+" : "") + k;
                        list.push({ chord: chord, desc: b.description.toUpperCase() });
                    }
                    view.binds = list;
                } catch (e) { }
            }
        }
    }

    readonly property var shown: {
        const q = view.query.trim().toLowerCase();
        if (q === "") return view.binds;
        return view.binds.filter(b =>
            b.chord.toLowerCase().indexOf(q) >= 0 ||
            b.desc.toLowerCase().indexOf(q) >= 0
        );
    }

    function slice(col) {
        const per = Math.ceil(view.shown.length / view.columns);
        return view.shown.slice(col * per, (col + 1) * per);
    }

    // Dynamic Header Component
    property Component headerComponent: Component {
        Row {
            spacing: 16
            DynamicPill {
                label: "SHOWN"
                jp: "表示"
                value: view.shown.length + ""
                subValue: "OF " + view.binds.length
                tint: view.shown.length === 0 ? Theme.alert : Theme.accent
            }
        }
    }

    Component.onCompleted: probe.running = true

    // ---- Content Column --------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 12

        // Filter Bar
        Item {
            width: parent.width
            height: 24

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
                text: view.query === "" ? "FILTER KEYBIND  絞込" : view.query
                color: view.query === "" ? Theme.dim : Theme.text
                font.family: view.query === "" ? Theme.fontDisplay : Theme.fontMono
                font.pixelSize: Theme.szBody
                font.letterSpacing: view.query === "" ? Theme.trkLabel : Theme.trkTight
            }

            TextInput {
                id: field
                anchors.fill: parent
                opacity: 0
                focus: true
                text: view.query
                onTextChanged: view.query = text
                Keys.onEscapePressed: event => {
                    view.closeRequested();
                    event.accepted = true;
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.line2 }

        // Keybind grid. Scrolls: 130 binds never fit, and without this
        // everything past the first screenful was simply cut off.
        Flickable {
            width: parent.width
            height: parent.height - y
            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: grid
                width: parent.width
                spacing: 18

                Repeater {
                    model: view.columns

                    Column {
                        required property int index
                        width: (parent.width - 18 * (view.columns - 1)) / view.columns
                        spacing: 4

                        Repeater {
                            model: view.slice(parent.index)

                            Item {
                                required property var modelData
                                width: parent.width
                                height: 22

                                Rectangle {
                                    id: chordPill
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    width: Math.min(parent.width * 0.44, chordText.implicitWidth + 14)
                                    height: 18
                                    radius: 0
                                    color: Qt.rgba(Theme.layer2.r, Theme.layer2.g, Theme.layer2.b, 0.4)
                                    border.width: 1
                                    border.color: Theme.edge

                                    Text {
                                        id: chordText
                                        anchors.centerIn: parent
                                        text: modelData.chord
                                        color: Theme.accent
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szMicro
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        width: parent.width - 6
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: chordPill.right
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    text: modelData.desc
                                    color: Theme.text
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.szBody
                                    font.letterSpacing: Theme.trkLabel
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
