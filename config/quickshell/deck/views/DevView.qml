import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "CYBERDECK"
    readonly property string panelJp: "記憶素子デッキ [SHARD-MATRIX]"
    readonly property string panelHint: view.isArmed
       ? "/// EMERGENCY SHARD PURGE /// PRESS ⇧ENTER TO PURGE " + (view.sel ? view.sel.name : "") + " (" + (view.selLive ? view.selLive.windows : 0) + " THREADS)  •  ESC ABORT"
       : (view.selLive
          ? "↑ ↓ / 1-9 SELECT  •  [ENTER] FOCUS WS  •  [⇧ENTER] PURGE SHARD  •  [T] TTY  •  [ESC] CLOSE"
          : "↑ ↓ / 1-9 SELECT  •  [ENTER] INJECT SHARD  •  [T] TTY  •  [ESC] CLOSE")
    readonly property int panelWidth: Theme.panelM
    readonly property int panelHeight: 720
    readonly property string placement: "center"

    signal closeRequested()

    property string armed: ""
    property var projects: []
    property var pending: []
    property int tick: 0

    readonly property var sel: projectList.currentIndex >= 0 && projectList.currentIndex < view.projects.length
                               ? view.projects[projectList.currentIndex] : null
    readonly property var selLive: view.sel ? (view.live[view.sel.key] ?? null) : null
    readonly property bool isArmed: !!view.sel && view.armed === view.sel.key

    function onActivated(): void {
        view.armed = "";
        if (projectList) projectList.currentIndex = 0;
        view.probe();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            if (view.armed !== "") view.armed = "";
            else view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            view.armed = "";
            if (projectList.currentIndex > 0) projectList.currentIndex--;
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            view.armed = "";
            if (projectList.currentIndex < view.projects.length - 1) projectList.currentIndex++;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const isShift = (event.modifiers & Qt.ShiftModifier) !== 0;
            view.trigger(view.sel, isShift);
            event.accepted = true;
        } else if (event.key === Qt.Key_X || event.key === Qt.Key_K) {
            if (view.selLive) {
                view.trigger(view.sel, true);
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_T || event.key === Qt.Key_O) {
            if (view.sel) view.openTerminal(view.sel);
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            const idx = event.key - Qt.Key_1;
            if (idx < view.projects.length) {
                view.armed = "";
                projectList.currentIndex = idx;
            }
            event.accepted = true;
        }
    }

    // ---- probe process ---------------------------------------------------
    Process {
        id: probeProc
        command: [Quickshell.env("HOME") + "/.config/hypr/bin/devprobe"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.trim()) return;
                try { view.pending.push(JSON.parse(line)); } catch (e) {}
            }
        }
        onExited: {
            view.projects = view.pending.slice();
            view.pending = [];
            view.refreshLive();
        }
    }

    function probe(): void {
        if (probeProc.running) return;
        view.pending = [];
        probeProc.running = true;
    }

    // ---- live sessions ---------------------------------------------------
    readonly property var live: {
        view.tick;
        const keys = view.projects.map(p => p.key);
        let m = {};
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.title) continue;
            const i = o.title.indexOf(":");
            if (i <= 0) continue;
            const key = o.title.slice(0, i).toLowerCase();
            if (keys.indexOf(key) < 0) continue;

            if (!m[key]) m[key] = { windows: 0, ws: 99, spaces: {}, titles: [] };
            m[key].windows += 1;
            m[key].titles.push(o.title);
            const ws = (o.workspace && o.workspace.id > 0) ? o.workspace.id : -1;
            if (ws > 0) {
                m[key].spaces[ws] = true;
                if (ws < m[key].ws) m[key].ws = ws;
            }
        }
        return m;
    }

    readonly property int liveCount: Object.keys(view.live).length

    function refreshLive(): void {
        Hyprland.refreshToplevels();
        view.tick += 1;
    }

    Connections {
        target: Hyprland
        function onRawEvent(_) { if (view.visible) debounce.restart(); }
    }
    Timer { id: debounce; interval: 120; onTriggered: view.refreshLive() }

    // ---- workspace assignment --------------------------------------------
    function assignWs(p): int {
        let taken = {};
        for (const k in view.live) {
            if (k === p.key) continue;
            for (const ws in view.live[k].spaces) taken[ws] = true;
        }
        for (let b = p.base; b < p.base + 20; b++) {
            let free = true;
            for (let i = 0; i < p.span; i++) if (taken[b + i]) { free = false; break; }
            if (free) return b;
        }
        return p.base;
    }

    // ---- actions ---------------------------------------------------------
    function ignite(p): void {
        if (!p) return;
        Quickshell.execDetached(["env", "DEV_WS=" + view.assignWs(p),
                                 p.path + "/dev.sh", "up"]);
        view.closeRequested();
    }

    function focus(p): void {
        if (!p) return;
        const l = view.live[p.key];
        if (l && l.ws < 99)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + l.ws + " })");
        view.closeRequested();
    }

    function teardown(p): void {
        if (!p) return;
        const l = view.live[p.key];
        const ws = (l && l.ws < 99) ? l.ws : p.base;

        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.title || !o.address) continue;
            const i = o.title.indexOf(":");
            if (i <= 0) continue;
            const key = o.title.slice(0, i).toLowerCase();
            if (key === p.key.toLowerCase()) {
                Hyprland.dispatch("hl.dsp.window.close({ window = \"address:" + o.address + "\" })");
            }
        }

        Quickshell.execDetached(["sh", "-c", 'DEV_WS="$1" "$2/dev.sh" down', "sh", "" + ws, p.path]);
        view.armed = "";
        view.closeRequested();
    }

    function openTerminal(p): void {
        if (!p || !p.path) return;
        Quickshell.execDetached(["kitty", "--directory", p.path]);
        view.closeRequested();
    }

    function trigger(p, stop): void {
        if (!p) return;
        const isLive = !!view.live[p.key];
        if (stop) {
            if (!isLive) return;
            if (view.armed === p.key) {
                view.teardown(p);
            } else {
                view.armed = p.key;
            }
            return;
        }
        if (view.armed !== "") {
            view.armed = "";
            return;
        }
        if (isLive) view.focus(p); else view.ignite(p);
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "SHARDS"
                jp: "媒体"
                value: ("0" + view.projects.length).slice(-2)
                subValue: "PROJECTS"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "OVERCLOCK"
                jp: "稼働"
                value: ("0" + view.liveCount).slice(-2)
                subValue: view.liveCount > 0 ? "ACTIVE WS" : "DORMANT"
                tint: view.liveCount > 0 ? Theme.accent : Theme.dim
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: "SYNC"
                jp: "同調"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.probe()
            }
        }
    }

    // ---- Main Mission Deck Body ------------------------------------------
    Row {
        anchors.fill: parent
        spacing: 20

        // Left Column: Fleet Project Roster
        Column {
            width: 350
            height: parent.height
            spacing: 10

            Tag {
                label: "MEMORY SHARD MATRIX"
                jp: "記憶素子スロット [SHARDS]"
            }

            ListView {
                id: projectList
                width: parent.width
                height: parent.height - 30
                clip: true
                model: view.projects
                spacing: 8
                highlightFollowsCurrentItem: true
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: card
                    width: projectList.width
                    height: 72
                    color: view.armed === modelData.key
                        ? Theme.layer2
                        : (ListView.isCurrentItem ? Theme.layer2 : Theme.layer1)
                    border.width: 1
                    border.color: view.armed === modelData.key
                        ? Theme.alert
                        : (ListView.isCurrentItem ? Theme.accent : Theme.line2)

                    readonly property bool isLive: !!view.live[modelData.key]
                    readonly property var liveObj: view.live[modelData.key]

                    // Active indicator rail
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: view.armed === modelData.key
                            ? Theme.alert
                            : (ListView.isCurrentItem ? Theme.accent : (card.isLive ? Theme.accent2 : "transparent"))
                    }

                    // Gold bus pins
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Repeater {
                            model: 4
                            Rectangle {
                                width: 3
                                height: 9
                                color: view.armed === modelData.key
                                    ? Theme.alert
                                    : (card.isLive
                                        ? Theme.accent
                                        : (ListView.isCurrentItem ? Theme.accent : "#C5A059"))
                                opacity: ListView.isCurrentItem ? 1.0 : (card.isLive ? 0.9 : 0.45)
                            }
                        }
                    }

                    // Top-right Hazard stripes
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        spacing: 2
                        visible: view.armed !== modelData.key && !card.isLive
                        Repeater {
                            model: 3
                            Text {
                                text: "/"
                                color: ListView.isCurrentItem ? Theme.accentDim : Theme.line2
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Bracket {
                        corner: "tl"
                        visible: ListView.isCurrentItem
                        anchors.left: parent.left
                        anchors.top: parent.top
                        stroke: view.armed === modelData.key ? Theme.alert : Theme.accent
                    }
                    Bracket {
                        corner: "br"
                        visible: ListView.isCurrentItem
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        stroke: view.armed === modelData.key ? Theme.alert : Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            view.armed = "";
                            projectList.currentIndex = index;
                        }
                        onDoubleClicked: view.trigger(modelData, false)
                    }

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 10
                        anchors.topMargin: 9
                        anchors.bottomMargin: 8
                        spacing: 4

                        Item {
                            width: parent.width
                            height: 22

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "[SLOT " + ("0" + (index + 1)).slice(-2) + "]"
                                    color: ListView.isCurrentItem ? Theme.accent : Theme.dim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.szMicro
                                    font.weight: Font.Bold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: view.armed === modelData.key
                                        ? Theme.alert
                                        : (ListView.isCurrentItem ? Theme.accent : Theme.text)
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.szValue
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: Theme.trkLabel
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.jp
                                    color: Theme.dim
                                    font.family: Theme.fontJP
                                    font.pixelSize: Theme.szMicro
                                }
                            }

                            // Status badge
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 18
                                width: statusRow.implicitWidth + 10
                                color: view.armed === modelData.key
                                    ? Theme.alert
                                    : (card.isLive ? Theme.layer3 : "transparent")
                                border.width: 1
                                border.color: view.armed === modelData.key
                                    ? Theme.alert
                                    : (card.isLive ? Theme.accent : Theme.line2)

                                Row {
                                    id: statusRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: card.isLive && view.armed !== modelData.key
                                        width: 5; height: 5
                                        color: Theme.accent
                                        SequentialAnimation on opacity {
                                            running: card.isLive
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.2; duration: 400 }
                                            NumberAnimation { to: 1.0; duration: 400 }
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: view.armed === modelData.key
                                            ? "/// PURGE ICE? ///"
                                            : ((card.isLive && card.liveObj)
                                                ? "[ OVERCLOCK // WS " + (card.liveObj.ws < 99 ? ("0" + card.liveObj.ws).slice(-2) : ("0" + modelData.base).slice(-2)) + " ]"
                                                : "[ DOCKED // 待機 ]")
                                        color: view.armed === modelData.key
                                            ? Theme.onAccent
                                            : (card.isLive ? Theme.accent : Theme.dim)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szMicro
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }

                        // Git branch, dirty status & description
                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "BR:" + (modelData.branch || "main")
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.dirty !== undefined && modelData.dirty > 0
                                text: "• " + modelData.dirty + " DIRTY"
                                color: Theme.warn
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: card.isLive && !!card.liveObj && card.liveObj.windows > 0
                                text: (card.liveObj && card.liveObj.windows > 0) ? ("• " + card.liveObj.windows + " WINS") : ""
                                color: Theme.accent2
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "• " + modelData.desc
                                color: Theme.dim
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szMicro
                                elide: Text.ElideRight
                                width: parent.width - 150
                            }
                        }
                    }
                }
            }
        }

        // Vertical Divider
        Rectangle {
            width: 1
            height: parent.height
            color: Theme.line2
        }

        // Right Column: Telemetry & Ignition Reticle
        Item {
            width: parent.width - 371
            height: parent.height

            // Empty State
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: view.projects.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO PROJECTS DETECTED"
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szLead
                    font.letterSpacing: Theme.trkWide
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Add a dev.sh manifest under ~/codebase to register a project"
                    color: Theme.dim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szBody
                }
            }

            // Project Details Console
            Column {
                anchors.fill: parent
                spacing: 12
                visible: !!view.sel

                // Header Card
                Item {
                    width: parent.width
                    height: 58

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Row {
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "SHARD DESIGNATION:"
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                                font.letterSpacing: Theme.trkLabel
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: view.sel ? view.sel.name : ""
                                color: view.isArmed ? Theme.alert : Theme.accent
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szLead
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: Theme.trkWide
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: view.sel ? view.sel.jp : ""
                                color: Theme.dim
                                font.family: Theme.fontJP
                                font.pixelSize: Theme.szBody
                            }
                        }

                        Row {
                            spacing: 8
                            Text {
                                text: view.sel ? ("NETRUNNER SHARD-ID: " + view.sel.key.toUpperCase() + "-09X // REV.04") : ""
                                color: view.isArmed ? Theme.alert : Theme.accent2
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                                font.weight: Font.Bold
                            }
                            Text {
                                text: "•"
                                color: Theme.line2
                                font.pixelSize: Theme.szMicro
                            }
                            Text {
                                text: view.sel ? view.sel.path.replace(Quickshell.env("HOME"), "~") : ""
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }
                        }
                    }

                    // State Chip in Top Right
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: stateRow.implicitWidth + 24
                        height: 30
                        color: view.isArmed ? Theme.alert : (view.selLive ? Theme.layer3 : Theme.layer1)
                        border.width: 1
                        border.color: view.isArmed ? Theme.alert : (view.selLive ? Theme.accent : Theme.line2)

                        Row {
                            id: stateRow
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !!view.selLive && !view.isArmed
                                width: 6; height: 6
                                color: Theme.accent
                                SequentialAnimation on opacity {
                                    running: !!view.selLive && !view.isArmed
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.2; duration: 400 }
                                    NumberAnimation { to: 1.0; duration: 400 }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: view.isArmed
                                    ? "/// EMERGENCY PURGE REQUESTED ///"
                                    : (view.selLive
                                        ? "/// OVERCLOCK ACTIVE: " + view.selLive.windows + " DAEMONS ///"
                                        : "[ SHARD DOCKED // STORAGE IDLE ]")
                                color: view.isArmed ? Theme.onAccent : (view.selLive ? Theme.accent : Theme.dim)
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szBody
                                font.letterSpacing: Theme.trkLabel
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                // Description banner
                Rectangle {
                    width: parent.width
                    height: 26
                    color: Theme.layer1
                    border.width: 1
                    border.color: Theme.line2

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 8

                        Text {
                            text: "ROM MANIFEST:"
                            color: Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                            font.letterSpacing: Theme.trkLabel
                        }

                        Text {
                            text: view.sel ? view.sel.desc : ""
                            color: Theme.text
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szBody
                            font.letterSpacing: Theme.trkLabel
                            elide: Text.ElideRight
                            width: parent.parent.width - 140
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.line2 }

                // Middle Section: 5x5 Sigil + 4 Instrument Clusters
                Row {
                    width: parent.width
                    spacing: 18

                    // Sigil Stamp Frame
                    Rectangle {
                        width: 72
                        height: 72
                        color: Theme.layer1
                        border.width: 1
                        border.color: view.isArmed ? Theme.alert : Theme.line2

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            visible: !!view.sel && !!view.sel.sigil

                            Repeater {
                                model: view.sel && view.sel.sigil ? view.sel.sigil : []
                                Row {
                                    id: sRow
                                    required property var modelData
                                    spacing: 2
                                    Repeater {
                                        model: 5
                                        Rectangle {
                                            required property int index
                                            width: 9; height: 9
                                            readonly property bool lit: sRow.modelData.charAt(index) === "1"
                                            color: lit ? (view.isArmed ? Theme.alert : Theme.accent) : "transparent"
                                            border.width: lit ? 0 : 1
                                            border.color: Theme.line2
                                        }
                                    }
                                }
                            }
                        }

                        Bracket { corner: "tl"; anchors.left: parent.left; anchors.top: parent.top; stroke: view.isArmed ? Theme.alert : Theme.line }
                        Bracket { corner: "br"; anchors.right: parent.right; anchors.bottom: parent.bottom; stroke: view.isArmed ? Theme.alert : Theme.line }
                    }

                    // Tactical Clusters Grid
                    Column {
                        width: parent.width - 90
                        spacing: 12

                        Row {
                            spacing: 36
                            Cluster {
                                label: "MEMORY REGION"; jp: "領域"; alwaysOn: true
                                value: {
                                    if (!view.sel) return "--";
                                    const b = view.selLive && view.selLive.ws < 99
                                            ? view.selLive.ws : view.assignWs(view.sel);
                                    return view.sel.span > 1 ? b + "–" + (b + view.sel.span - 1) : String(b);
                                }
                                tail: view.sel ? "SPAN " + view.sel.span : ""
                                valueColor: view.selLive ? Theme.accent : Theme.text
                            }

                            Cluster {
                                label: "LOGICAL BRANCH"; jp: "枝"; alwaysOn: true
                                value: (view.sel && view.sel.branch) ? view.sel.branch : "--"
                                tail: {
                                    if (!view.sel || view.sel.ahead === undefined) return "";
                                    const a = view.sel.ahead, b = view.sel.behind;
                                    return (a > 0 || b > 0) ? "+" + a + "−" + b : "SYNCED";
                                }
                                valueColor: Theme.text
                            }

                            Cluster {
                                label: "UNSAVED DELTA"; jp: "変更"; alwaysOn: true
                                value: (view.sel && view.sel.dirty !== undefined) ? String(view.sel.dirty) : "--"
                                tail: (view.sel && view.sel.dirty > 0) ? "FILES" : ""
                                valueColor: (view.sel && view.sel.dirty > 0) ? Theme.warn : Theme.dim
                            }

                            Cluster {
                                label: "CONTAINER ICE"; jp: "容器"; alwaysOn: true
                                value: (view.sel && view.sel.containers !== undefined) ? String(view.sel.containers) : "--"
                                tail: "CONTAINERS"
                                valueColor: (view.sel && view.sel.containers > 0) ? Theme.accent : Theme.dim
                            }
                        }

                        Row {
                            spacing: 36

                            Cluster {
                                label: "I/O PORTS RADAR"; jp: "港"; alwaysOn: true
                                value: {
                                    if (!view.sel || !view.sel.ports || view.sel.ports.length === 0) return "--";
                                    return view.sel.ports.map(p => p.port).join("  ");
                                }
                                tail: {
                                    if (!view.sel || !view.sel.ports || view.sel.ports.length === 0) return "";
                                    const openCount = view.sel.ports.filter(p => p.open).length;
                                    return openCount + " OF " + view.sel.ports.length + " OPEN";
                                }
                                valueColor: {
                                    if (!view.sel || !view.sel.ports || !view.selLive) return Theme.text;
                                    return view.sel.ports.some(p => !p.open) ? Theme.warn : Theme.accent;
                                }
                            }

                            Cluster {
                                label: "COMMIT TELEMETRY"; jp: "最新"; alwaysOn: true
                                value: (view.sel && view.sel.last) ? view.sel.last + " AGO" : "--"
                                valueColor: Theme.dim
                            }
                        }
                    }
                }

                // Commit Callout
                Rectangle {
                    width: parent.width
                    height: 26
                    color: Theme.layer1
                    border.width: 1
                    border.color: Theme.line2
                    visible: !!view.sel && !!view.sel.subject

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        spacing: 6

                        Text {
                            text: "COMMIT:"
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                            font.letterSpacing: Theme.trkLabel
                        }

                        Text {
                            text: view.sel && view.sel.subject ? view.sel.subject : ""
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                            elide: Text.ElideRight
                            width: parent.parent.width - 80
                        }
                    }
                }

                // Active Windows Titles Preview
                Rectangle {
                    width: parent.width
                    height: 26
                    color: Theme.layer1
                    border.width: 1
                    border.color: Theme.line2
                    visible: !!view.selLive && view.selLive.windows > 0

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        spacing: 6

                        Text {
                            text: "DAEMON THREADS:"
                            color: Theme.accent
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                            font.letterSpacing: Theme.trkLabel
                        }

                        Text {
                            text: view.selLive ? view.selLive.titles.join("  •  ") : ""
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                            elide: Text.ElideRight
                            width: parent.parent.width - 90
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.line2 }

                // Action Ignition Bar
                Row {
                    width: parent.width
                    spacing: 14

                    Rectangle {
                        visible: view.isArmed
                        width: parent.width
                        height: 40
                        color: Theme.alert
                        border.width: 1
                        border.color: Theme.text

                        Row {
                            anchors.centerIn: parent
                            spacing: 16

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "/// WARNING: EMERGENCY SHARD PURGE /// PRESS ⇧ENTER TO CONFIRM DROP (" + (view.selLive ? view.selLive.windows : 0) + " THREADS) ///"
                                color: Theme.onAccent
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szBody
                                font.letterSpacing: Theme.trkLabel
                                font.weight: Font.Bold
                            }

                            Btn {
                                text: "CONFIRM PURGE"
                                jp: "強制排除"
                                tint: Theme.bg
                                onClicked: view.teardown(view.sel)
                            }

                            Btn {
                                text: "ABORT (ESC)"
                                jp: "中断"
                                onClicked: view.armed = ""
                            }
                        }
                    }

                    Row {
                        visible: !view.isArmed
                        spacing: 14

                        Btn {
                            text: view.selLive ? "[ENTER] FOCUS SHARD" : "[ENTER] INJECT SHARD"
                            jp: view.selLive ? "同調" : "点火"
                            tint: Theme.accent
                            onClicked: view.trigger(view.sel, false)
                        }

                        Btn {
                            visible: !!view.selLive
                            text: "[⇧ENTER] PURGE SHARD"
                            jp: "強制排除"
                            tint: Theme.alert
                            onClicked: view.trigger(view.sel, true)
                        }

                        Btn {
                            text: "[T] SPAWN TTY"
                            jp: "端末"
                            onClicked: view.openTerminal(view.sel)
                        }
                    }
                }
            }
        }
    }
}
