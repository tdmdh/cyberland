// The persistent desktop frame -- Smart Dynamic Cyber Island.
//
// All perimeter corner nodes have been unified into ONE intelligent, context-aware
// Dynamic Cyber Island sitting at top-center on WlrLayer.Bottom.
//
// LIQUID APPLE SPRING MORPH:
// - Morphs both width and height with physical spring dynamics (Easing.OutBack).
// - Content crossfades internally without width-popping or jarring reflows.
// - Features an orbital multi-band dotted Thinking Orb (inspired by thinking-orbs,
//   engineered natively in QML Scene Graph for 0% CPU overhead).
// - Bottom OSD daemon has been retired in favor of this Island morph.
//
// The island is the ONLY part of the frame that takes input: the mask is the
// hover zone around it, so the rest of the full-screen surface stays
// click-through over the desktop. Sharp corners (radius: 0), wallpaper reactive.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "./common"

ShellRoot {
    id: root

    readonly property int bandTop: 44
    readonly property int bandBottom: 14
    readonly property int gap: 5
    readonly property int inset: 8
    readonly property int pad: 14
    readonly property int islandY: 6
    readonly property int islandH: 28

    // Startup arming guard: prevents transient morphs on boot
    property bool armed: false
    Timer { interval: 900; running: true; onTriggered: root.armed = true }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ---- Audio & OSD Service ---------------------------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted:  (sink && sink.audio) ? sink.audio.muted  : false

    property string osdLabel: "VOL"
    property string osdReadout: "0%"
    property real   osdMeter: 0
    property string osdKind: "volume" // "volume" | "brightness"

    Timer { id: osdTimer; interval: 1500 }

    function triggerOsd(kind, label, readout, meter) {
        if (!root.armed) return;
        root.osdKind = kind;
        root.osdLabel = label;
        root.osdReadout = readout;
        root.osdMeter = meter;
        osdTimer.restart();
    }

    onVolumeChanged: {
        root.triggerOsd("volume", "VOL", Math.round(root.volume * 100) + "%", root.volume);
    }
    onMutedChanged: {
        root.triggerOsd("volume", root.muted ? "MUTED" : "VOL",
                        root.muted ? "—" : Math.round(root.volume * 100) + "%",
                        root.muted ? 0 : root.volume);
    }

    // Public hook for brightness triggers (e.g. from hyprland binds or scripts)
    function showBrightness(pct) {
        const val = Math.max(0, Math.min(100, Math.round(pct)));
        root.triggerOsd("brightness", "BRI", val + "%", val / 100);
    }

    // ---- MPRIS Media Service ---------------------------------------------
    readonly property var player: Mpris.players.values.find(p => p.isPlaying)
                               ?? (Mpris.players.values[0] ?? null)
    readonly property string trackTitle: (player && player.trackTitle) ? player.trackTitle : ""
    readonly property bool isPlaying: player !== null && player.isPlaying
    property string lastTrack: ""

    Timer { id: trackTimer; interval: 2200 }

    onTrackTitleChanged: {
        if (root.armed && root.trackTitle !== "" && root.trackTitle !== root.lastTrack && root.isPlaying) {
            root.lastTrack = root.trackTitle;
            trackTimer.restart();
        }
    }

    // ---- Workspace Transition Service ------------------------------------
    readonly property int focusedWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    Timer { id: wsTimer; interval: 1300 }

    onFocusedWsIdChanged: {
        if (root.armed) {
            wsTimer.restart();
        }
    }

    // ---- Agent Activity Telemetry ----------------------------------------
    property string busyTool: ""
    property double busyAt: 0
    property int    busyErrs: 0

    Process {
        running: true
        command: ["tail", "-F", "-n", "0",
                  (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/agentbus.jsonl"]
        stdout: SplitParser {
            onRead: line => {
                let e; try { e = JSON.parse(line); } catch (err) { return; }
                if (e.ev === "PreToolUse") {
                    root.busyTool = e.tool || "?"; root.busyAt = Date.now();
                } else if (e.ev === "PostToolUse") {
                    root.busyAt = Date.now();
                    if (e.err) root.busyErrs++;
                } else if (e.ev === "Stop" || e.ev === "SessionEnd") {
                    root.busyTool = ""; root.busyErrs = 0;
                }
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: if (root.busyTool !== "" && Date.now() - root.busyAt > 6000)
                         root.busyTool = "";
    }

    // ---- Compute Load State (Schmitt trigger + dwell) --------------------
    // Lives on root, not per-window: one machine for every monitor's island.
    //
    // A single threshold was flicker. sysbus pushes every 2s, so a CPU sitting
    // on 70 morphed the island in and out on every tick, each morph carrying a
    // 1.15 OutBack overshoot. Enter on the hot band, leave only once below the
    // cool band, and hold 4s past the last hot reading so a two-second build
    // does not flash the readout and vanish.
    // ponytail: thresholds and the 4s dwell are hand-tuned against this box's
    // sysbus cadence, and nothing drives them in a test -- checking them would
    // mean an IpcHandler existing only to be poked. Re-tune here if the island
    // twitches; add the handler only if this stops being obvious by reading.
    property bool isHighCompute: false
    readonly property bool computeHot:  (Sys.cpu >= 70 || Sys.gpu >= 60 || Sys.temp >= 75)
    readonly property bool computeCool: (Sys.cpu <  60 && Sys.gpu <  50 && Sys.temp <  70)

    onComputeHotChanged: if (root.computeHot) {
        root.isHighCompute = true;
        computeDwell.restart();
    }

    Timer {
        id: computeDwell
        interval: 4000
        // Fires 4s after the last hot reading. Below the cool band -> drop it.
        // Still in the dead zone between the bands -> keep holding and recheck,
        // rather than dropping into the flicker the two bands exist to prevent.
        onTriggered: {
            if (root.computeCool) root.isHighCompute = false;
            else computeDwell.restart();
        }
    }

    // ---- Peripheral Hardware Telemetry (Mouse Battery) -------------------
    property string mouseBat: ""
    readonly property bool mouseLow: root.mouseBat === "Low" || root.mouseBat === "Critical"
    FileView {
        id: mouseFile
        path: "/sys/class/power_supply/hidpp_battery_0/capacity_level"
        onLoaded: root.mouseBat = text().trim()
        onLoadFailed: root.mouseBat = ""
    }
    Timer {
        interval: 300000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: mouseFile.reload()
    }

    Component.onCompleted: {
        void Sys.cpu;
    }

    // ---- Micro Components ------------------------------------------------
    component Divider: Rectangle {
        width: 1
        height: 12
        radius: 0
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.glassBorder
    }

    // Dotted 3D Orbital Thinking Orb (Inspired by thinking-orbs, hardware-accelerated on QML Scene Graph)
    component ThinkingOrb: Item {
        id: orb
        width: 22
        height: 22
        anchors.verticalCenter: parent.verticalCenter

        // Three rotations and two pulses, all infinite. Ungated they ran for
        // the whole uptime whether or not an agent was working, because the
        // row holding them is always instantiated and only fades to opacity 0
        // -- which stops it drawing but not ticking the render loop.
        //
        // Gating them does not by itself make the island free: resting mode
        // still breathes one pip, and one running animation costs as much as
        // ten. It stops these five from being the reason. See frame/selftest.sh.
        property bool active: true

        property color orbColor: root.busyErrs > 0 ? Theme.alert
                               : (root.busyTool.toLowerCase().includes("think") ? Theme.accent : Theme.neonMagenta)

        // Orbit 1: Outer tilted particle ring (Clockwise, 3200ms)
        Item {
            anchors.centerIn: parent
            width: 20; height: 14
            RotationAnimation on rotation {
                running: orb.active
                loops: Animation.Infinite; from: 0; to: 360; duration: 3200
            }
            Rectangle { width: 2.5; height: 2.5; radius: 0; color: orb.orbColor; x: 0; y: 5 }
            Rectangle { width: 2.5; height: 2.5; radius: 0; color: orb.orbColor; x: 17; y: 5 }
            Rectangle { width: 1.5; height: 1.5; radius: 0; color: "#FFFFFF"; opacity: 0.7; x: 9; y: 0 }
            Rectangle { width: 1.5; height: 1.5; radius: 0; color: orb.orbColor; opacity: 0.5; x: 9; y: 12 }
        }

        // Orbit 2: Counter-tilted orbital ring (Counter-clockwise, 2100ms)
        Item {
            anchors.centerIn: parent
            width: 15; height: 18
            RotationAnimation on rotation {
                running: orb.active
                loops: Animation.Infinite; from: 360; to: 0; duration: 2100
            }
            Rectangle { width: 2; height: 2; radius: 0; color: "#FFFFFF"; x: 6; y: 0 }
            Rectangle { width: 2; height: 2; radius: 0; color: orb.orbColor; x: 6; y: 16 }
            Rectangle { width: 1.5; height: 1.5; radius: 0; color: orb.orbColor; opacity: 0.6; x: 0; y: 8 }
            Rectangle { width: 1.5; height: 1.5; radius: 0; color: orb.orbColor; opacity: 0.6; x: 13; y: 8 }
        }

        // Orbit 3: Fast inner meridian ring (Clockwise, 1400ms)
        Item {
            anchors.centerIn: parent
            width: 10; height: 10
            RotationAnimation on rotation {
                running: orb.active
                loops: Animation.Infinite; from: 0; to: 360; duration: 1400
            }
            Rectangle { width: 1.5; height: 1.5; radius: 0; color: orb.orbColor; x: 0; y: 4 }
            Rectangle { width: 1.5; height: 1.5; radius: 0; color: orb.orbColor; x: 8; y: 4 }
        }

        // Concentric breathing photonic diamond core
        Rectangle {
            width: 5; height: 5; radius: 0
            anchors.centerIn: parent
            color: orb.orbColor

            SequentialAnimation on scale {
                running: orb.active
                loops: Animation.Infinite
                NumberAnimation { to: 1.45; duration: 600; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.70; duration: 600; easing.type: Easing.InOutQuad }
            }
            SequentialAnimation on opacity {
                running: orb.active
                loops: Animation.Infinite
                NumberAnimation { to: 1.0; duration: 600 }
                NumberAnimation { to: 0.40; duration: 600 }
            }
        }
    }

    // ---- Desktop Surface -------------------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Bottom
            // Input only where the island is. Everything else on this
            // full-screen surface stays click-through to the desktop.
            mask: Region { item: hoverZone }

            // Window Area Perimeter Hairline
            Rectangle {
                id: hair
                x: root.inset
                y: root.bandTop - root.gap - 1
                width: win.width - root.inset * 2
                height: win.height - y - (root.bandBottom - root.gap - 1)
                color: "transparent"
                border.width: 1
                border.color: Theme.line2
            }

            // Viewfinder Corner Brackets
            Bracket { corner: "tl"; x: hair.x;                      y: hair.y }
            Bracket { corner: "tr"; x: hair.x + hair.width - width; y: hair.y }
            Bracket { corner: "bl"; x: hair.x;                      y: hair.y + hair.height - height }
            Bracket { corner: "br"; x: hair.x + hair.width - width; y: hair.y + hair.height - height }

            // Midpoint Calibration Reticles
            Rectangle { x: hair.x + (hair.width / 2) - 8; y: hair.y; width: 16; height: 1; color: Theme.line }
            Rectangle { x: hair.x + (hair.width / 2); y: hair.y - 3; width: 1; height: 7; color: Theme.line }
            Rectangle { x: hair.x + (hair.width / 2) - 8; y: hair.y + hair.height - 1; width: 16; height: 1; color: Theme.line }
            Rectangle { x: hair.x + (hair.width / 2); y: hair.y + hair.height - 4; width: 1; height: 7; color: Theme.line }
            Rectangle { x: hair.x - 3; y: hair.y + (hair.height / 2); width: 7; height: 1; color: Theme.line }
            Rectangle { x: hair.x + hair.width - 4; y: hair.y + (hair.height / 2); width: 7; height: 1; color: Theme.line }

            // =================================================================
            // ---- THE SMART DYNAMIC CYBER ISLAND -----------------------------
            // =================================================================
            readonly property bool isDiskWarn: Sys.disk >= 80
            readonly property bool isDiskCrit: Sys.disk >= 90
            readonly property bool isAlert: isDiskCrit || (Sys.temp >= 85) || (root.busyErrs > 0)
            readonly property bool isWarn: isDiskWarn || (Sys.cpu >= 75) || (Sys.temp >= 75) || root.mouseLow

            readonly property string activeMode: {
                if (osdTimer.running) return "osd";
                if (wsTimer.running) return "workspace";
                if (trackTimer.running) return "track";
                if (root.busyTool !== "") return "agent";
                if (root.isHighCompute) return "compute";
                return "resting";
            }

            readonly property color islandAccent: isAlert ? Theme.alert
                                                : (isWarn ? Theme.warn
                                                : (activeMode === "agent" ? (root.busyErrs > 0 ? Theme.alert : Theme.neonMagenta)
                                                : (activeMode === "workspace" ? Theme.accent
                                                : (activeMode === "osd" ? (root.osdKind === "brightness" ? Theme.warn : (root.muted ? Theme.alert : Theme.accent))
                                                : Theme.laser))))

            Rectangle {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter

                // Dynamic height & Y position with Apple fluid spring physics
                height: (win.activeMode === "osd") ? 34
                      : (win.activeMode !== "resting" ? 32 : 28)
                y: (win.activeMode === "osd") ? 4
                 : (win.activeMode !== "resting" ? 5 : root.islandY)

                // Dynamic width with Apple physical spring overshoot
                width: Math.max(140, contentSlot.width + 26 + (diskChip.visible ? diskChip.implicitWidth + 8 : 0) + (mouseChip.visible ? mouseChip.implicitWidth + 8 : 0))

                radius: 0

                // Apple fluid physical spring animations
                Behavior on width {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.15
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.12
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                }

                color: win.isAlert ? Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.26)
                     : (win.isWarn ? Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.20)
                                   : Theme.glassCard)
                border.width: 1
                border.color: win.isAlert ? Theme.alert : (win.isWarn ? Theme.warn : Theme.glassBorder)

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // Top photonic specular catch
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    anchors.margins: 1
                    height: 1
                    radius: 0
                    color: "#FFFFFF"
                    opacity: 0.15
                }

                // Dual laser edge catches
                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                    width: 2
                    radius: 0
                    color: win.islandAccent
                    opacity: 0.85
                }
                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: 2
                    radius: 0
                    color: win.islandAccent
                    opacity: 0.85
                }

                // Master Island Content Row
                Row {
                    id: activeContentRow
                    anchors.centerIn: parent
                    spacing: (diskChip.visible || mouseChip.visible) ? 8 : 0

                    // Centered Fluid Content Slot (Crossfades without double-width glitches)
                    Item {
                        id: contentSlot
                        anchors.verticalCenter: parent.verticalCenter
                        width: currentContentItem ? currentContentItem.implicitWidth : 120
                        height: 20

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.12
                            }
                        }

                        readonly property Item currentContentItem: {
                            if (win.activeMode === "osd") return osdContent;
                            if (win.activeMode === "workspace") return wsContent;
                            if (win.activeMode === "track") return trackContent;
                            if (win.activeMode === "agent") return agentContent;
                            if (win.activeMode === "compute") return computeContent;
                            return restingContent;
                        }

                        // ---------------------------------------------------------
                        // 1. OSD MODE (Volume / Brightness Morph)
                        // ---------------------------------------------------------
                        Row {
                            id: osdContent
                            anchors.centerIn: parent
                            spacing: 8
                            opacity: (contentSlot.currentContentItem === this) ? 1.0 : 0.0
                            scale: (contentSlot.currentContentItem === this) ? 1.0 : 0.86
                            visible: opacity > 0.01

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                            Text {
                                text: root.osdLabel
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szNano
                                font.weight: Font.Bold
                                color: root.osdKind === "brightness" ? Theme.warn : (root.muted ? Theme.alert : Theme.accent)
                                font.letterSpacing: 1.0
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.osdReadout
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szTail
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 90; height: 5; radius: 0
                                color: Theme.line2
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: Math.max(0, Math.min(parent.width, parent.width * root.osdMeter))
                                    radius: 0
                                    color: root.osdKind === "brightness" ? Theme.warn : (root.muted ? Theme.dim : Theme.laser)

                                    Rectangle {
                                        anchors { top: parent.top; left: parent.left; right: parent.right }
                                        height: 1; radius: 0; color: "#FFFFFF"; opacity: 0.35
                                    }
                                }
                            }
                        }

                        // ---------------------------------------------------------
                        // 2. WORKSPACE MORPH (Transient switch banner)
                        // ---------------------------------------------------------
                        Row {
                            id: wsContent
                            anchors.centerIn: parent
                            spacing: 8
                            opacity: (contentSlot.currentContentItem === this) ? 1.0 : 0.0
                            scale: (contentSlot.currentContentItem === this) ? 1.0 : 0.86
                            visible: opacity > 0.01

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                            Text {
                                text: "WORKSPACE"
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szNano
                                font.weight: Font.Medium
                                color: Theme.dim
                                font.letterSpacing: 1.2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "領域"
                                font.family: Theme.fontJP
                                font.pixelSize: Theme.szNano
                                color: Theme.laser
                                opacity: Theme.opacityJP
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 28; height: 16; radius: 0
                                color: Theme.glassActive
                                border.width: 1
                                border.color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors { top: parent.top; left: parent.left; right: parent.right }
                                anchors.margins: 1; height: 1; color: "#FFFFFF"; opacity: 0.4
                            }

                            Text {
                                anchors.centerIn: parent
                                text: ("0" + root.focusedWsId).slice(-2)
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.accent
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // 3. NOW PLAYING TRACK MORPH (Song change banner)
                    // ---------------------------------------------------------
                    Row {
                        id: trackContent
                        anchors.centerIn: parent
                        spacing: 7
                        opacity: (contentSlot.currentContentItem === this) ? 1.0 : 0.0
                        scale: (contentSlot.currentContentItem === this) ? 1.0 : 0.86
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                        Text {
                            text: "♪"
                            color: Theme.accent
                            font.pixelSize: Theme.szTail
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.trackTitle.length > 28 ? root.trackTitle.slice(0, 26) + "…" : root.trackTitle
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szTail
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // ---------------------------------------------------------
                    // 4. AGENT MODE (Dotted Orbital Thinking Orb & Tool Execution)
                    // ---------------------------------------------------------
                    Row {
                        id: agentContent
                        anchors.centerIn: parent
                        spacing: 7
                        opacity: (contentSlot.currentContentItem === this) ? 1.0 : 0.0
                        scale: (contentSlot.currentContentItem === this) ? 1.0 : 0.86
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                        ThinkingOrb { active: agentContent.visible }

                        Row {
                            spacing: 5
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "AGENT"
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szNano
                                font.weight: Font.Bold
                                color: Theme.dim
                                font.letterSpacing: 1.0
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "代理"
                                font.family: Theme.fontJP
                                font.pixelSize: Theme.szNano
                                color: Theme.laser
                                opacity: Theme.opacityJP
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.busyTool.toUpperCase()
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szTail
                                font.weight: Font.DemiBold
                                color: root.busyErrs > 0 ? Theme.alert : Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // 5. COMPUTE MODE (High CPU/GPU/Thermal Avionics)
                    // ---------------------------------------------------------
                    Row {
                        id: computeContent
                        anchors.centerIn: parent
                        spacing: 8
                        opacity: (contentSlot.currentContentItem === this) ? 1.0 : 0.0
                        scale: (contentSlot.currentContentItem === this) ? 1.0 : 0.86
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                        Pip {
                            size: 5
                            minOpacity: 0.3
                            running: computeContent.visible
                            color: (Sys.cpu >= 90 || Sys.temp >= 85) ? Theme.alert : Theme.warn
                        }

                        Readout {
                            label: "CPU"
                            value: Sys.cpu < 0 ? "--" : Sys.cpu + "%"
                            valueColor: Sys.cpu >= 90 ? Theme.alert : (Sys.cpu >= 75 ? Theme.warn : Theme.textPrimary)
                        }

                        Divider {}

                        Readout {
                            label: "GPU"
                            value: Sys.gpu < 0 ? "--" : Sys.gpu + "%"
                            valueColor: Theme.level(Sys.gpu)
                        }

                        Divider {}

                        Readout {
                            label: "TEMP"
                            value: Sys.temp < 0 ? "--" : Sys.temp + "°C"
                            valueColor: Sys.temp >= 85 ? Theme.alert : (Sys.temp >= 75 ? Theme.warn : Theme.laser)
                        }
                    }

                    // ---------------------------------------------------------
                    // 6. RESTING STATE (Node ID • Clock + Ambient Media Wave Beads)
                    // ---------------------------------------------------------
                    Row {
                        id: restingContent
                        anchors.centerIn: parent
                        spacing: 7
                        opacity: (contentSlot.currentContentItem === this) ? 1.0 : 0.0
                        scale: (contentSlot.currentContentItem === this) ? 1.0 : 0.86
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                        // Static node bead. This used to breathe on a 1500ms
                        // loop. A looping fade never lets the compositor idle,
                        // so on a 144Hz screen it held the whole desktop at full
                        // composite rate all day: measured 8% GPU with resting
                        // static against 33% with this one square breathing.
                        // Resting is the all-day state, so it is the one mode
                        // that must not animate. The transient modes still do.
                        Rectangle {
                            width: 4; height: 4; radius: 0
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Host / Node ID
                        Text {
                            text: (Sys.host || "JOYBOY").toUpperCase()
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szTail
                            font.weight: Font.Bold
                            color: Theme.accent
                            font.letterSpacing: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "•"
                            color: Theme.dim
                            font.pixelSize: Theme.szNano
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Clock
                        Text {
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szTail
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Ambient Media Wave Beads (active when playing music)
                        Row {
                            visible: root.isPlaying
                            spacing: 5
                            anchors.verticalCenter: parent.verticalCenter

                            Divider {}

                            // A frozen waveform, not a dancing one. These bars
                            // answer "is something playing", and a static
                            // silhouette answers it just as well -- for the same
                            // reason the bead above stopped breathing, and it
                            // mattered more here, because music plays for hours.
                            Row {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: [9, 14, 6, 11]
                                    Rectangle {
                                        required property var modelData
                                        width: 2
                                        height: modelData
                                        radius: 0
                                        color: Theme.laser
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Hover detail. sysbus already collects all of this and
                        // the island never showed any of it. Resting only: every
                        // other mode is already answering a question, and this is
                        // the one state with nothing to say.
                        //
                        // No width animation of its own -- appearing inside the
                        // Row grows restingContent.implicitWidth, which the
                        // island's existing spring already follows.
                        Row {
                            visible: hoverZone.containsMouse
                            spacing: 7
                            anchors.verticalCenter: parent.verticalCenter

                            Divider {}

                            Readout {
                                label: "MEM"
                                value: Sys.mem < 0 ? "--" : Sys.mem + "%"
                                valueColor: Theme.level(Sys.mem)
                            }

                            Divider {}

                            Readout {
                                label: "NET"
                                value: Sys.rate(Sys.rx) + "\u2193 " + Sys.rate(Sys.tx) + "\u2191"
                                valueColor: Theme.laser
                            }

                            Divider {}

                            Readout {
                                label: "UP"
                                value: Sys.up || "--"
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // 7. THRESHOLD SENTINELS (Disk Warning & Mouse Battery)
                // ---------------------------------------------------------
                // Disk Warning Chip: Surfaces automatically when storage >= 80%
                Row {
                    id: diskChip
                    visible: win.isDiskWarn
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Divider {}

                    Pip {
                        minOpacity: 0.2
                        running: diskChip.visible
                        color: win.isDiskCrit ? Theme.alert : Theme.warn
                    }

                    Text {
                        text: "DISK " + (Sys.disk < 0 ? "--" : Sys.disk + "%")
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szNano
                        font.weight: Font.Bold
                        color: win.isDiskCrit ? Theme.alert : Theme.warn
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Peripheral Mouse Battery Alert
                Row {
                    id: mouseChip
                    visible: root.mouseLow
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Divider {}

                    Pip {
                        minOpacity: 0.2
                        running: mouseChip.visible
                        color: root.mouseBat === "Critical" ? Theme.alert : Theme.warn
                    }

                    Text {
                        text: "MOUSE " + root.mouseBat.toUpperCase()
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szNano
                        font.weight: Font.Bold
                        color: root.mouseBat === "Critical" ? Theme.alert : Theme.warn
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // ---------------------------------------------------------
            // 8. HOVER / CLICK TARGET
            // ---------------------------------------------------------
            // Sibling of the content row, not a child: a Row positions what it
            // holds, and anchors.fill inside one fights the positioner.
            //
            // Overhangs the island by 6px so the edge does not chatter --
            // hovering grows the island, and a zone ending exactly at the
            // resting edge would hand the pointer back and forth across it.
            //
            // ponytail: the hover path is unverified. `hyprctl dispatch
            // movecursor` warps the pointer without producing a pointer-enter
            // on a layer surface, and no input-synthesis tool is installed, so
            // containsMouse could not be driven from a script. The layout it
            // reveals was verified by forcing the detail row visible. If hover
            // turns out dead, the mask is the first thing to suspect.
            MouseArea {
                id: hoverZone
                anchors.fill: island
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(
                    [Quickshell.env("HOME") + "/.config/hypr/bin/qs-panel", "control"])
            }
        }
    }
}
}
