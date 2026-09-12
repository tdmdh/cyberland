import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Qt.labs.folderlistmodel
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "CONTROL"
    readonly property string panelJp: "制御"
    readonly property string panelHint: "/  SEARCH       ← →  VOLUME       M  MUTE       ESC  CLOSE"
    readonly property int panelWidth: 1080
    readonly property int panelHeight: 1060
    readonly property string placement: "center"

    signal closeRequested()

    // ---- Audio Service ---------------------------------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property real volume: sinkAudio ? sinkAudio.volume : 0
    readonly property bool muted: sinkAudio ? sinkAudio.muted : false

    function setVolume(v: real): void {
        if (view.sinkAudio) view.sinkAudio.volume = Math.max(0, Math.min(1, v));
    }

    readonly property var source: Pipewire.defaultAudioSource
    readonly property var srcAudio: source ? source.audio : null
    readonly property real micVolume: srcAudio ? srcAudio.volume : 0
    readonly property bool micMuted: srcAudio ? srcAudio.muted : false

    // ---- Media -----------------------------------------------------------
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? (players[0] ?? null)

    // ---- Network ---------------------------------------------------------
    readonly property var netDevices: Networking.devices.values
    readonly property var wifiDevice: netDevices.find(d => d.type === DeviceType.Wifi) ?? null

    readonly property var wifiNetworks: {
        if (!view.wifiDevice || !view.wifiDevice.networks) return [];
        const list = view.wifiDevice.networks.values.slice();
        list.sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0));
        return list.slice(0, 6);
    }

    Binding {
        target: view.wifiDevice
        property: "scannerEnabled"
        value: view.visible
        when: view.wifiDevice !== null
    }

    property var pendingNet: null
    property string psk: ""

    function joinPending(): void {
        if (!view.pendingNet || view.psk === "") return;
        view.pendingNet.connectWithPsk(view.psk);
        view.pendingNet = null;
        view.psk = "";
    }

    // ---- Bluetooth -------------------------------------------------------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevices: {
        const list = Bluetooth.devices.values.slice();
        list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired));
        return list.slice(0, 6);
    }

    function btLabel(d): string {
        if (d.connected) return d.batteryAvailable
            ? "CONNECTED  " + Math.round(d.battery * 100) + "%" : "CONNECTED";
        if (d.pairing) return "PAIRING";
        return d.paired ? "PAIRED" : "NEW";
    }

    // ---- Notifications ---------------------------------------------------
    property var notif: ({ dnd: false, count: 0, recent: [] })

    Process {
        id: notifQuery
        command: ["qs", "-c", "notify", "ipc", "call", "notify", "state"]
        stdout: SplitParser {
            onRead: line => {
                try { view.notif = JSON.parse(line); } catch (e) { }
            }
        }
    }

    Process {
        id: notifCmd
        onExited: notifQuery.running = true
    }

    function notifCall(fn: string): void {
        notifCmd.command = ["qs", "-c", "notify", "ipc", "call", "notify", fn];
        notifCmd.running = true;
    }

    // ---- Wallpaper -------------------------------------------------------
    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property string currentWall: ""
    property string wallQuery: ""

    FolderListModel {
        id: walls
        folder: "file://" + view.wallDir
        nameFilters: {
            const q = view.wallQuery.trim();
            const exts = ["jpg", "jpeg", "png", "webp"];
            return exts.map(e => q === "" ? "*." + e : "*" + q + "*." + e);
        }
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
    }

    Process {
        id: wallQueryProc
        command: ["swww", "query"]
        stdout: SplitParser {
            onRead: line => {
                const m = /currently displaying: image: (.*)$/.exec(line.trim());
                if (m) view.currentWall = m[1];
            }
        }
    }

    Timer {
        id: wallPoll
        interval: 1200; repeat: false
        onTriggered: wallQueryProc.running = true
    }

    // ---- Wallpaper Effects -----------------------------------------------
    readonly property string fxOut: Quickshell.env("HOME") + "/.cache/hypr/wallpaper-fx.png"
    readonly property string srcFile: Quickshell.env("HOME") + "/.cache/hypr/wallpaper-source"

    property string wallSource: ""
    property string wallFx: "NONE"
    property bool   fxBusy: false

    readonly property var effects: [
        { id: "NONE",     jp: "無し", op: "" },
        { id: "MONO",     jp: "白黒", op: "-colorspace gray -sigmoidal-contrast 10,40%" },
        { id: "BLUR",     jp: "暈し", op: "-blur 0x10" },
        { id: "CHARCOAL", jp: "炭",   op: "-charcoal 0x5" },
        { id: "EDGE",     jp: "輪郭", op: "-edge 1" },
        { id: "EMBOSS",   jp: "浮彫", op: "-emboss 0x5" },
        { id: "NEGATE",   jp: "反転", op: "-negate" },
        { id: "OIL",      jp: "油彩", op: "-paint 4" },
        { id: "POSTER",   jp: "階調", op: "-posterize 4" },
        { id: "SEPIA",    jp: "褐色", op: "-sepia-tone 65%" },
        { id: "SOLAR",    jp: "露光", op: "-solarize 80%" },
        { id: "SHARPEN",  jp: "鮮明", op: "-sharpen 0x5" },
        { id: "VIGNETTE", jp: "暈影", op: "-background black -vignette 0x3" }
    ]

    FileView {
        id: srcView
        path: view.srcFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: view.wallSource = text().trim()
    }

    Process {
        id: fxProc
        onExited: {
            view.fxBusy = false;
            wallPoll.interval = 800;
            wallPoll.restart();
        }
    }

    function applyFx(fx): void {
        const src = view.wallSource || view.currentWall;
        if (!src || view.fxBusy) return;
        view.wallFx = fx.id;
        if (fx.op === "") { view.applyImage(src); return; }
        view.fxBusy = true;
        fxProc.command = ["sh", "-c",
            'mkdir -p "$(dirname "$2")" && magick "$1" $3 "$2" '
            + '&& swww img "$2" --transition-type any && wallust run "$2"',
            "sh", src, view.fxOut, fx.op];
        fxProc.running = true;
    }

    function applyImage(path: string): void {
        Quickshell.execDetached(["sh", "-c",
            'swww query >/dev/null 2>&1 || setsid -f swww-daemon; '
            + 'swww img "$1" --transition-type any && wallust run "$1"',
            "sh", path]);
        view.currentWall = path;
        wallPoll.interval = 2500;
        wallPoll.restart();
    }

    function setWall(path: string): void {
        view.wallSource = path;
        view.wallFx = "NONE";
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf %s "$1" > "$2"', "sh", path, view.srcFile]);
        view.applyImage(path);
    }

    // ---- Session Actions -------------------------------------------------
    property string armed: ""

    function session(key: string, cmd: var): void {
        if (view.armed !== key) { view.armed = key; return; }
        Quickshell.execDetached(cmd);
        view.closeRequested();
    }

    // ---- Lifecycle Activation --------------------------------------------
    function onActivated(): void {
        wallQueryProc.running = true;
        notifQuery.running = true;
        view.armed = "";
        view.pendingNet = null;
        view.psk = "";
    }

    function handleKey(event): void {
        if (qin.activeFocus || (pskIn && pskIn.activeFocus)) return;
        if (event.key === Qt.Key_Left)  { view.setVolume(view.volume - 0.05); event.accepted = true; }
        if (event.key === Qt.Key_Right) { view.setVolume(view.volume + 0.05); event.accepted = true; }
        if (event.key === Qt.Key_M && view.sinkAudio) {
            view.sinkAudio.muted = !view.sinkAudio.muted; event.accepted = true;
        }
        if (event.key === Qt.Key_Slash) {
            qin.forceActiveFocus();
            event.accepted = true;
        }
        if (event.key !== Qt.Key_Escape) view.armed = "";
    }

    // ---- Dynamic Header Component ----------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 16
            DynamicPill {
                label: "VOL"
                jp: "音量"
                value: view.muted ? "MUTE" : Math.round(view.volume * 100) + "%"
                subValue: view.muted ? "MUTED" : "OUTPUT"
                warn: view.muted
            }
            DynamicPill {
                label: "NET"
                jp: "通信"
                value: {
                    const c = view.wifiNetworks.find(n => n.connected);
                    return Networking.wifiEnabled ? (c ? c.name : "SCAN") : "OFF";
                }
                subValue: Networking.wifiEnabled ? "ACTIVE" : "OFF"
            }
            DynamicPill {
                label: "BT"
                jp: "青歯"
                value: (!view.btAdapter || !view.btAdapter.enabled) ? "OFF"
                       : "" + view.btDevices.filter(d => d.connected).length
                subValue: (view.btAdapter && view.btAdapter.enabled) ? "READY" : "DISABLED"
            }
            DynamicPill {
                label: "NOTIF"
                jp: "通知"
                value: view.notif.dnd ? "DND" : ("0" + view.notif.count).slice(-2)
                warn: view.notif.dnd
            }
        }
    }

    // ---- Section Header Component ----------------------------------------
    component Sect: Item {
        id: sect
        property string label
        property string jp
        width: parent ? parent.width : 0
        height: 18

        Row {
            id: sectRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sect.label
                color: Theme.accent
                font.family: Theme.fontDisplay
                font.pixelSize: 12
                font.letterSpacing: 3
                font.weight: Font.Medium
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sect.jp
                color: Theme.line
                font.family: Theme.fontJP
                font.pixelSize: 10
            }
        }
        Rectangle {
            anchors.left: sectRow.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Theme.line2
        }
    }

    // ---- Scrollable Content Body -----------------------------------------
    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentCol
            width: scroll.width
            spacing: 16

            // ================= AUDIO =================
            Sect { label: "AUDIO"; jp: "音響" }

            Row {
                width: parent.width
                spacing: 16

                Meter {
                    anchors.verticalCenter: parent.verticalCenter
                    segs: 24
                    pct: Math.round(view.volume * 100)
                    barColor: view.muted ? Theme.dim : Theme.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    text: view.muted ? "MUTED" : Math.round(view.volume * 100) + "%"
                    color: view.muted ? Theme.warn : Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                }
                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MUTE"; jp: "消音"
                    active: view.muted
                    tint: Theme.warn
                    onClicked: if (view.sinkAudio) view.sinkAudio.muted = !view.sinkAudio.muted
                }
                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "−"
                    onClicked: view.setVolume(view.volume - 0.05)
                }
                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+"
                    onClicked: view.setVolume(view.volume + 0.05)
                }
            }

            // Microphone Source Row
            Row {
                width: parent.width
                spacing: 16
                visible: view.source !== null

                Meter {
                    anchors.verticalCenter: parent.verticalCenter
                    segs: 24
                    pct: Math.round(view.micVolume * 100)
                    barColor: view.micMuted ? Theme.dim : Theme.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    text: view.micMuted ? "MUTED" : Math.round(view.micVolume * 100) + "%"
                    color: view.micMuted ? Theme.warn : Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                }
                Btn {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MIC"; jp: "録音"
                    active: view.micMuted
                    tint: Theme.warn
                    onClicked: if (view.srcAudio) view.srcAudio.muted = !view.srcAudio.muted
                }
            }

            // ================= MEDIA =================
            Sect { label: "MEDIA"; jp: "再生"; visible: view.player !== null }

            Column {
                width: parent.width
                spacing: 8
                visible: view.player !== null

                Text {
                    width: parent.width
                    text: view.player ? (view.player.trackTitle || view.player.identity) : ""
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Row {
                    spacing: 10
                    Btn { text: "◀◀"; onClicked: if (view.player) view.player.previous() }
                    Btn {
                        text: view.player && view.player.isPlaying ? "❚❚" : "▶"
                        jp: view.player && view.player.isPlaying ? "停止" : "再生"
                        active: !!view.player && view.player.isPlaying
                        onClicked: if (view.player) view.player.togglePlaying()
                    }
                    Btn { text: "▶▶"; onClicked: if (view.player) view.player.next() }
                }
            }

            // ============== NOTIFICATIONS ==============
            Row {
                width: parent.width
                Sect {
                    label: "NOTIFICATIONS"; jp: "通知"
                    width: parent.width - notifBtns.width
                }
                Row {
                    id: notifBtns
                    spacing: 8
                    Btn {
                        text: "DND"; jp: "静音"
                        active: view.notif.dnd
                        tint: Theme.warn
                        onClicked: view.notifCall("dnd")
                    }
                    Btn {
                        text: "CLEAR"; jp: "消去"
                        tint: Theme.alert
                        enabled: view.notif.count > 0
                        onClicked: view.notifCall("clear")
                    }
                    Btn {
                        text: "HISTORY"; jp: "履歴"
                        onClicked: {
                            view.closeRequested();
                            view.notifCall("open");
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6

                Text {
                    visible: view.notif.count === 0
                    text: view.notif.dnd ? "DO NOT DISTURB" : "NOTHING HELD"
                    color: view.notif.dnd ? Theme.warn : Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: 2
                }

                Repeater {
                    model: view.notif.recent

                    Row {
                        required property var modelData
                        width: parent.width
                        spacing: 12
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 130
                            text: (modelData.app || "?").toUpperCase()
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                            font.letterSpacing: Theme.trkLabel
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 144
                            text: modelData.summary
                            color: modelData.crit ? Theme.alert : Theme.text
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szBody
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ================= NETWORK =================
            Row {
                width: parent.width
                Sect { label: "NETWORK"; jp: "通信"; width: parent.width - wifiBtn.width }
                Btn {
                    id: wifiBtn
                    text: Networking.wifiEnabled ? "WIFI ON" : "WIFI OFF"
                    jp: "無線"
                    active: Networking.wifiEnabled
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
            }

            Column {
                width: parent.width
                spacing: 3
                visible: Networking.wifiEnabled

                Repeater {
                    model: view.wifiNetworks
                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 26
                        color: modelData.connected ? Theme.layer2 : "transparent"

                        Rectangle {
                            width: 2; height: parent.height
                            color: modelData.connected ? Theme.accent : "transparent"
                        }
                        Text {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name || "(hidden network)"
                            color: modelData.connected ? Theme.accent
                                 : modelData.known ? Theme.text : Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Meter {
                                anchors.verticalCenter: parent.verticalCenter
                                segs: 5
                                pct: Math.round((modelData.signalStrength || 0) * 100)
                                barColor: modelData.connected ? Theme.accent : Theme.dim
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 92
                                horizontalAlignment: Text.AlignRight
                                text: modelData.connected ? "CONNECTED"
                                    : modelData.known ? "KNOWN"
                                    : view.pendingNet === modelData ? "ENTER KEY"
                                    : "NEEDS KEY"
                                color: modelData.connected ? Theme.accent : Theme.dim
                                font.family: Theme.fontDisplay
                                font.pixelSize: 9
                                font.letterSpacing: 1.4
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) modelData.disconnect();
                                else if (modelData.known) modelData.connect();
                                else {
                                    view.pendingNet = modelData;
                                    view.psk = "";
                                    pskIn.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // Wi-Fi Password Input Box
            Item {
                width: parent.width
                height: 36
                visible: view.pendingNet !== null

                Corners { anchors.fill: parent; arm: 8 }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.pendingNet ? (view.pendingNet.name || "(hidden)") : ""
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 310
                        height: 20

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: view.psk.length === 0
                            text: "PASSWORD  合言葉"
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szBody
                            font.letterSpacing: 2
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            visible: view.psk.length > 0
                            Repeater {
                                model: Math.min(view.psk.length, 40)
                                Rectangle { width: 4; height: 4; color: Theme.accent }
                            }
                        }
                        TextInput {
                            id: pskIn
                            anchors.fill: parent
                            opacity: 0
                            echoMode: TextInput.Password
                            text: view.psk
                            onTextChanged: view.psk = text
                            onAccepted: view.joinPending()
                            Keys.onEscapePressed: { view.pendingNet = null; view.psk = ""; }
                        }
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "JOIN"; jp: "接続"
                        enabled: view.psk.length > 0
                        onClicked: view.joinPending()
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CANCEL"; jp: "取消"
                        tint: Theme.alert
                        onClicked: { view.pendingNet = null; view.psk = ""; }
                    }
                }
            }

            // ================= BLUETOOTH =================
            Row {
                width: parent.width
                Sect { label: "BLUETOOTH"; jp: "青歯"; width: parent.width - btRow.width }
                Row {
                    id: btRow
                    spacing: 8
                    Btn {
                        text: "SCAN"; jp: "探索"
                        enabled: !!view.btAdapter && view.btAdapter.enabled
                        active: !!view.btAdapter && view.btAdapter.discovering
                        onClicked: {
                            const a = view.btAdapter;
                            if (a && a.enabled) a.discovering = !a.discovering;
                        }
                    }
                    Btn {
                        text: view.btAdapter && view.btAdapter.enabled ? "BT ON" : "BT OFF"
                        jp: "電源"
                        active: !!view.btAdapter && view.btAdapter.enabled
                        onClicked: if (view.btAdapter) view.btAdapter.enabled = !view.btAdapter.enabled
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 3
                visible: !!view.btAdapter && view.btAdapter.enabled

                Repeater {
                    model: view.btDevices
                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 26
                        color: modelData.connected ? Theme.layer2 : "transparent"

                        Rectangle {
                            width: 2; height: parent.height
                            color: modelData.connected ? Theme.accent : "transparent"
                        }
                        Text {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name || modelData.address || "Peripheral"
                            color: modelData.connected ? Theme.accent
                                 : modelData.paired ? Theme.text : Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: view.btLabel(modelData)
                            color: modelData.connected ? Theme.accent : Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: 9
                            font.letterSpacing: 1.4
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: modelData.paired ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (modelData.paired) modelData.connected = !modelData.connected
                        }
                    }
                }
            }

            // ================= WALLPAPER =================
            Row {
                width: parent.width
                spacing: 10
                Sect {
                    label: "WALLPAPER"; jp: "壁紙"
                    width: parent.width - find.width - shuf.width - 20
                }

                Item {
                    id: find
                    width: 240
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Bracket { corner: "tl"; anchors.left: parent.left; anchors.top: parent.top; arm: 8; stroke: qin.activeFocus ? Theme.accent : Theme.line }
                    Bracket { corner: "tr"; anchors.right: parent.right; anchors.top: parent.top; arm: 8; stroke: qin.activeFocus ? Theme.accent : Theme.line }
                    Bracket { corner: "bl"; anchors.left: parent.left; anchors.bottom: parent.bottom; arm: 8; stroke: qin.activeFocus ? Theme.accent : Theme.line }
                    Bracket { corner: "br"; anchors.right: parent.right; anchors.bottom: parent.bottom; arm: 8; stroke: qin.activeFocus ? Theme.accent : Theme.line }

                    Text {
                        anchors.centerIn: parent
                        visible: view.wallQuery === "" && !qin.activeFocus
                        text: "SEARCH  検索"
                        color: Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }

                    TextInput {
                        id: qin
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        selectByMouse: true
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        text: view.wallQuery
                        onTextChanged: view.wallQuery = text
                        onAccepted: if (walls.count > 0) view.setWall(view.wallDir + "/" + walls.get(0, "fileName"))
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        cursorShape: Qt.IBeamCursor
                    }
                }

                Btn {
                    id: shuf
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SHUFFLE"; jp: "無作為"
                    enabled: walls.count > 0
                    onClicked: if (walls.count > 0)
                        view.setWall(view.wallDir + "/" + walls.get(Math.floor(Math.random() * walls.count), "fileName"))
                }
            }

            ListView {
                id: strip
                width: parent.width
                height: 90
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: walls
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    required property string fileName
                    required property url fileUrl
                    readonly property string path: view.wallDir + "/" + fileName
                    readonly property bool current: view.currentWall === path

                    width: 136
                    height: strip.height

                    Image {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: 4
                        source: fileUrl
                        sourceSize.width: 272
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: current ? 1.0 : 0.60
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    Bracket { corner: "tl"; anchors.left: parent.left; anchors.top: parent.top; visible: parent.current; arm: 12 }
                    Bracket { corner: "tr"; anchors.right: parent.right; anchors.top: parent.top; visible: parent.current; arm: 12 }
                    Bracket { corner: "bl"; anchors.left: parent.left; anchors.bottom: parent.bottom; visible: parent.current; arm: 12 }
                    Bracket { corner: "br"; anchors.right: parent.right; anchors.bottom: parent.bottom; visible: parent.current; arm: 12 }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: thumb.opacity = 1.0
                        onExited: thumb.opacity = parent.current ? 1.0 : 0.60
                        onClicked: view.setWall(parent.path)
                    }
                }
            }

            Text {
                width: parent.width
                text: walls.count + (view.wallQuery === "" ? " IMAGES" : " MATCHES")
                      + "   ·   CLICK OR ENTER TO APPLY   ·   SETS THE PALETTE FOR THE WHOLE DESKTOP"
                color: Theme.dim
                font.family: Theme.fontDisplay
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }

            // ================= EFFECT =================
            Row {
                width: parent.width
                Sect { label: "EFFECT"; jp: "効果"; width: parent.width - fxState.width }
                Text {
                    id: fxState
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.fxBusy ? "RENDERING…" : view.wallFx
                    color: view.fxBusy ? Theme.warn : (view.wallFx === "NONE" ? Theme.dim : Theme.accent)
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: view.effects
                    Btn {
                        required property var modelData
                        text: modelData.id
                        jp: modelData.jp
                        active: view.wallFx === modelData.id
                        enabled: !view.fxBusy
                        onClicked: view.applyFx(modelData)
                    }
                }
            }

            Text {
                width: parent.width
                text: "APPLIED TO THE ORIGINAL, NOT THE LAST RESULT   ·   SOURCE: "
                      + (view.wallSource === "" ? "--" : view.wallSource.split("/").pop())
                color: Theme.dim
                font.family: Theme.fontDisplay
                font.pixelSize: 10
                font.letterSpacing: 1.4
                elide: Text.ElideRight
            }

            // ================= SESSION =================
            Sect { label: "SESSION"; jp: "終了" }

            Row {
                width: parent.width
                spacing: 10

                Btn {
                    text: "LOCK"; jp: "施錠"
                    onClicked: {
                        Quickshell.execDetached(["qs", "-c", "lock", "ipc", "call", "lock", "engage"]);
                        view.closeRequested();
                    }
                }
                Btn {
                    text: view.armed === "logout" ? "CONFIRM" : "LOG OUT"
                    jp: "退出"
                    active: view.armed === "logout"
                    tint: Theme.warn
                    onClicked: view.session("logout", ["uwsm", "stop"])
                }
                Btn {
                    text: view.armed === "suspend" ? "CONFIRM" : "SUSPEND"
                    jp: "休止"
                    active: view.armed === "suspend"
                    onClicked: view.session("suspend", ["systemctl", "suspend"])
                }
                Btn {
                    text: view.armed === "reboot" ? "CONFIRM" : "REBOOT"
                    jp: "再起動"
                    active: view.armed === "reboot"
                    tint: Theme.warn
                    onClicked: view.session("reboot", ["systemctl", "reboot"])
                }
                Btn {
                    text: view.armed === "poweroff" ? "CONFIRM" : "POWER OFF"
                    jp: "電源断"
                    active: view.armed === "poweroff"
                    tint: Theme.alert
                    onClicked: view.session("poweroff", ["systemctl", "poweroff"])
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: view.armed !== ""
                    text: "PRESS AGAIN TO CONFIRM"
                    color: Theme.warn
                    font.family: Theme.fontDisplay
                    font.pixelSize: 10
                    font.letterSpacing: 1.8
                }
            }

            // Bottom Spacing Margin
            Item { width: parent.width; height: 10 }
        }
    }
}
