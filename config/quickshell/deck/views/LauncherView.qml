import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Networking
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "LAUNCHER"
    readonly property string panelJp: "起動"
    readonly property string panelHint: "↑ ↓  MOVE  •  ENTER  LAUNCH  •  ESC  CLOSE"
    readonly property int panelWidth: 1080
    readonly property int panelHeight: 760
    readonly property string placement: "center"

    signal closeRequested()

    property string query: ""

    function onActivated(): void {
        input.text = "";
        view.query = "";
        list.currentIndex = 0;
        mouseBat.reload();
        input.forceActiveFocus();
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
            view.launch();
            event.accepted = true;
        }
    }

    function launch(): void {
        const app = view.apps[list.currentIndex];
        if (app) app.execute();
        view.closeRequested();
    }

    // ---- status telemetry ------------------------------------------------
    SystemClock { id: clock; precision: SystemClock.Minutes }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property string volumeText:
        (!sink || !sink.audio) ? "--"
        : sink.audio.muted ? "muted"
        : Math.round(sink.audio.volume * 100) + "%"

    readonly property var netDevices: Networking.devices.values

    readonly property string networkText: {
        const dev = view.netDevices.find(d => d.connected);
        if (!dev) return "offline";
        if (dev.type === DeviceType.Wired) return "wired";
        const net = (dev.networks ? dev.networks.values : []).find(n => n.connected);
        if (!net) return dev.name;
        return net.signalStrength !== undefined
             ? net.name + "   " + Math.round(net.signalStrength * 100) + "%"
             : net.name;
    }

    readonly property int networkSignal: {
        const dev = view.netDevices.find(d => d.connected);
        if (!dev) return 0;
        if (dev.type === DeviceType.Wired) return 100;
        const net = (dev.networks ? dev.networks.values : []).find(n => n.connected);
        return net ? Math.round((net.signalStrength || 0) * 100) : 0;
    }

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null
    readonly property string nowPlaying: (player && player.trackTitle) ? player.trackTitle : "--"

    property string mouseBattery: "--"
    FileView {
        id: mouseBat
        path: "/sys/class/power_supply/hidpp_battery_0/capacity_level"
        onLoaded: view.mouseBattery = text().trim() || "--"
    }

    // ---- app list & ranking ----------------------------------------------
    readonly property var allApps: {
        const alist = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        alist.sort((a, b) => a.name.localeCompare(b.name));
        return alist;
    }

    function rank(name, q) {
        const i = name.indexOf(q);
        if (i < 0) return -1;
        if (i === 0) return 0;
        const prev = name[i - 1];
        if (prev === " " || prev === "-" || prev === "_") return 1;
        return 2;
    }

    readonly property var apps: {
        const q = view.query.trim().toLowerCase();
        if (q === "") return view.allApps;
        const hits = [];
        for (const a of view.allApps) {
            const r = view.rank(a.name.toLowerCase(), q);
            if (r >= 0) hits.push({ r: r, a: a });
        }
        hits.sort((x, y) => x.r - y.r || x.a.name.localeCompare(y.a.name));
        return hits.map(h => h.a);
    }

    readonly property bool searching: view.query.trim() !== ""

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "APPS"
                jp: "応用"
                value: view.searching ? view.apps.length + "/" + view.allApps.length : String(view.allApps.length)
                subValue: view.searching ? "MATCHES" : "TOTAL"
                tint: (view.searching && view.apps.length === 0) ? Theme.alert : Theme.laser
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: "LAUNCH"
                jp: "起動"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.launch()
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Item {
        anchors.fill: parent

        Row {
            anchors.fill: parent
            anchors.bottomMargin: 72
            spacing: 20

            // Left App List Column
            Item {
                width: parent.width - 340
                height: parent.height

                ListView {
                    id: list
                    anchors.fill: parent
                    readonly property int itemWidth: width - 40
                    readonly property int rowH: 36

                    model: view.apps
                    clip: true
                    keyNavigationWraps: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: true
                    currentIndex: 0

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index

                        width: list.width
                        height: list.rowH
                        readonly property bool sel: row.index === list.currentIndex

                        Item {
                            id: mark
                            x: row.sel ? Theme.pad : 0
                            width: Math.min(label.implicitWidth, list.itemWidth) + Theme.gutter * 2
                            height: parent.height

                            Behavior on x {
                                NumberAnimation { duration: Theme.easeMs; easing.type: Easing.OutCubic }
                            }

                            Corners {
                                anchors.fill: parent
                                visible: row.sel
                                arm: 8
                                stroke: Theme.accent
                            }

                            Text {
                                id: label
                                x: Theme.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                width: list.itemWidth
                                elide: Text.ElideRight

                                text: row.modelData.name
                                color: row.sel ? Theme.accent : Theme.text
                                opacity: row.sel ? 1.0 : 0.65
                                font.family: Theme.fontDisplay
                                font.pixelSize: 15
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: row.sel ? Theme.trkWide : Theme.trkLabel

                                Behavior on color   { ColorAnimation  { duration: Theme.easeMs } }
                                Behavior on opacity { NumberAnimation { duration: Theme.easeMs } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = row.index
                            onClicked: view.launch()
                        }
                    }
                }

                Tag {
                    visible: list.count === 0
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.gutter * 2
                    anchors.top: parent.top
                    anchors.topMargin: 40
                    label: "NO MATCH"; jp: "該当なし"
                    size: Theme.szBody
                }
            }

            // Right Status Telemetry Panel
            Item {
                width: 300
                height: parent.height

                Corners { anchors.fill: parent }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.textPrimary
                        font.family: Theme.fontDisplay
                        font.pixelSize: 44
                        font.letterSpacing: Theme.trkDisplay
                        font.weight: Font.Light
                    }

                    Tag {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: Qt.formatDateTime(clock.date, "dddd dd MMMM").toUpperCase()
                        jp: "日付"
                        size: Theme.szBody
                    }

                    Rectangle { width: 280; height: 1; color: Theme.line2; anchors.horizontalCenter: parent.horizontalCenter }

                    Column {
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        DynamicPill {
                            label: "VOL"
                            jp: "音量"
                            value: view.volumeText
                            subValue: (view.sink && view.sink.audio && !view.sink.audio.muted) ? "SPEAKER" : "MUTED"
                            warn: view.sink && view.sink.audio && view.sink.audio.muted
                        }
                        DynamicPill {
                            label: "NET"
                            jp: "通信"
                            value: view.networkText
                            subValue: view.networkSignal > 0 ? view.networkSignal + "% SIG" : "LINK"
                        }
                        DynamicPill {
                            label: "CPU"
                            jp: "演算"
                            value: Sys.cpu < 0 ? "--" : Sys.cpu + "%"
                            subValue: Sys.temp > 0 ? Sys.temp + "°C CORE" : "NOMINAL"
                            alert: Sys.cpu >= 90
                            warn: Sys.cpu >= 75
                        }
                        DynamicPill {
                            label: "MEM"
                            jp: "記憶"
                            value: Sys.mem < 0 ? "--" : Sys.mem + "%"
                            subValue: Sys.memgb > 0 ? Sys.memgb + "G / TOTAL" : ""
                            alert: Sys.mem >= 90
                            warn: Sys.mem >= 80
                        }
                        DynamicPill {
                            label: "MOUSE"
                            jp: "鼠"
                            value: view.mouseBattery.toUpperCase()
                            subValue: "HID++ BATTERY"
                            alert: view.mouseBattery.toLowerCase() === "critical"
                            warn: view.mouseBattery.toLowerCase() === "low"
                        }
                        DynamicPill {
                            label: "NOW"
                            jp: "再生"
                            value: view.nowPlaying
                            subValue: view.player && view.player.trackArtist ? view.player.trackArtist : "MPRIS"
                            tint: view.player ? Theme.laser : Theme.textTertiary
                        }
                    }
                }
            }
        }

        // Bottom Search Box
        ChamferBox {
            id: search
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width - 40
            height: 48
            cut: 8
            cutTopLeft: true
            cutBottomRight: true
            cutTopRight: false
            cutBottomLeft: false
            strokeColor: view.searching ? Theme.laser : Theme.line
            strokeWidth: 1
            fillColor: Theme.glassCard
            notch: true
            notchColor: view.searching ? Theme.laser : Theme.accentDim
            reticles: true
            reticleColor: view.searching ? Theme.laser : Theme.line2

            Tag {
                anchors.centerIn: parent
                visible: !view.searching
                label: "TYPE APPLICATION NAME TO FILTER"
                jp: "検索"
                size: Theme.szBody
            }

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                focus: true
                color: Theme.text
                font.family: Theme.fontDisplay
                font.weight: Font.Light
                font.letterSpacing: Theme.trkWide
                font.pixelSize: 18
                onTextChanged: {
                    view.query = text;
                    list.currentIndex = 0;
                }

                Keys.onEscapePressed: view.closeRequested()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onReturnPressed: view.launch()
                Keys.onEnterPressed: view.launch()
            }
        }
    }
}
