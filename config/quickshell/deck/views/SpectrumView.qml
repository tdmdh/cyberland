import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "SPECTRUM"
    readonly property string panelJp: "周波数音響"
    readonly property string panelHint: "← → / WHEEL  VOLUME  •  M  MUTE  •  1-6  PRESETS  •  TAB  CYCLE SINK  •  SPACE  PLAY/PAUSE  •  ESC  CLOSE"
    readonly property int panelWidth: Theme.panelM
    readonly property int panelHeight: 600
    readonly property string placement: "center"

    signal closeRequested()

    // ---- Pipewire Audio Integration --------------------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property real volume: sinkAudio ? sinkAudio.volume : 0
    readonly property bool muted: sinkAudio ? sinkAudio.muted : false

    function setMasterVolume(v: real): void {
        const clamped = Math.max(0, Math.min(1.5, v));
        if (view.sinkAudio) {
            view.sinkAudio.volume = Math.min(1.0, clamped);
        }
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", Math.round(clamped * 100) + "%"]);
    }

    function stepVolume(delta: real): void {
        view.setMasterVolume(view.volume + delta);
    }

    function toggleMute(): void {
        if (view.sinkAudio) {
            view.sinkAudio.muted = !view.sinkAudio.muted;
        }
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    // ---- MPRIS Media Integration -----------------------------------------
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? (players[0] ?? null)
    readonly property bool isPlaying: player !== null && player.isPlaying
    readonly property string trackTitle: player ? (player.trackTitle || "Audio Stream") : "No Active Stream"
    readonly property string trackArtist: player ? (player.trackArtist || "") : ""

    // ---- Audio Telemetry via audioprobe ----------------------------------
    property var audioData: ({ sinks: [], streams: [], default_sink: "" })

    Process {
        id: probeProc
        command: [Quickshell.env("HOME") + "/.config/hypr/bin/audioprobe"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    view.audioData = JSON.parse(text);
                } catch (e) {
                    console.warn("SPECTRUM probe parse error:", e);
                }
            }
        }
    }

    function refreshAudio(): void {
        if (!probeProc.running) probeProc.running = true;
    }

    Timer {
        interval: 1600
        running: view.visible
        repeat: true
        onTriggered: view.refreshAudio()
    }

    function onActivated(): void {
        view.refreshAudio();
    }

    Component.onCompleted: {
        view.refreshAudio();
    }

    function switchSink(sinkName: string): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/bin/audioprobe", "set-sink", sinkName]);
        Qt.callLater(view.refreshAudio);
    }

    function setStreamVol(streamIdx: int, pct: int): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/bin/audioprobe", "set-stream-volume", streamIdx.toString(), pct.toString()]);
        Qt.callLater(view.refreshAudio);
    }

    function toggleStreamMute(streamIdx: int): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/bin/audioprobe", "toggle-stream-mute", streamIdx.toString()]);
        Qt.callLater(view.refreshAudio);
    }

    // ---- Keyboard Navigation ---------------------------------------------
    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            view.stepVolume(-0.02);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            view.stepVolume(0.02);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            view.stepVolume(-0.05);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            view.stepVolume(0.05);
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            view.toggleMute();
            event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            if (view.player) view.player.playPause();
            event.accepted = true;
        } else if (event.key === Qt.Key_1) {
            view.setMasterVolume(0.20);
            event.accepted = true;
        } else if (event.key === Qt.Key_2) {
            view.setMasterVolume(0.40);
            event.accepted = true;
        } else if (event.key === Qt.Key_3) {
            view.setMasterVolume(0.60);
            event.accepted = true;
        } else if (event.key === Qt.Key_4) {
            view.setMasterVolume(0.80);
            event.accepted = true;
        } else if (event.key === Qt.Key_5) {
            view.setMasterVolume(1.00);
            event.accepted = true;
        } else if (event.key === Qt.Key_6) {
            view.setMasterVolume(1.50);
            event.accepted = true;
        } else if (event.key === Qt.Key_0) {
            view.setMasterVolume(0.0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            // Cycle output sink
            const sinks = view.audioData.sinks || [];
            if (sinks.length > 1) {
                const curIdx = sinks.findIndex(s => s.is_default);
                const nextIdx = (curIdx + 1) % sinks.length;
                view.switchSink(sinks[nextIdx].name);
            }
            event.accepted = true;
        }
    }

    // Helper: calculate dB from 0..1 ratio
    function volumeToDb(v: real): string {
        if (v <= 0.0001) return "-∞ dB";
        const db = 20 * Math.log10(v);
        return (db >= 0 ? "+" : "") + db.toFixed(1) + " dB";
    }

    // ---- Dynamic Header Component ----------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8

            DynamicPill {
                label: "VOL"
                jp: "音量"
                value: view.muted ? "MUTED" : Math.round(view.volume * 100) + "%"
                subValue: view.volumeToDb(view.volume)
                tint: view.muted ? Theme.alert : (view.volume > 1.0 ? Theme.warn : Theme.accent)
                anchors.verticalCenter: parent.verticalCenter
            }

            DynamicPill {
                label: "OUTPUT"
                jp: "出力"
                value: {
                    const def = (view.audioData.sinks || []).find(s => s.is_default);
                    return def ? def.label : "DEFAULT"
                }
                subValue: {
                    const def = (view.audioData.sinks || []).find(s => s.is_default);
                    return def ? (def.nick || "AUDIO") : "SINK"
                }
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            DynamicPill {
                label: "EQUALIZER"
                jp: "音響解析"
                value: view.isPlaying ? "ACTIVE" : "STANDBY"
                subValue: "32-BAND FFT"
                tint: view.isPlaying ? Theme.accent : Theme.dim
                anchors.verticalCenter: parent.verticalCenter
            }

            Btn {
                text: view.muted ? "UNMUTE" : "MUTE"
                jp: "消音"
                active: view.muted
                tint: view.muted ? Theme.alert : Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.toggleMute()
            }
        }
    }

    // ---- Main Panel Body -------------------------------------------------
    Item {
        anchors.fill: parent

        // Mouse wheel over entire panel adjusts volume
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                view.stepVolume(delta);
            }
        }

        Column {
            id: contentCol
            anchors.fill: parent
            spacing: 14

            // =============================================================
            // SECTION 1: 32-BAND REALTIME SPECTRUM ANALYZER
            // =============================================================
            Item {
                width: parent.width
                height: 120

                // Background Glass Frame for Spectrum
                Rectangle {
                    anchors.fill: parent
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.edge

                    // Top Specular Highlight
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Theme.accentEdge }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // Background ISO Frequency Grid Guidelines
                    Row {
                        anchors { fill: parent; margins: 10 }
                        Repeater {
                            model: 7
                            Item {
                                width: (parent.width) / 7
                                height: parent.height
                                Rectangle {
                                    anchors.right: parent.right
                                    width: 1; height: parent.height
                                    color: Theme.edge
                                    opacity: 0.35
                                }
                            }
                        }
                    }

                    // dB Scale Reference Lines
                    Column {
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 16 }
                        spacing: 20
                        Repeater {
                            model: 3
                            Rectangle {
                                width: parent.width; height: 1
                                color: Theme.accentWash
                                opacity: 0.25
                            }
                        }
                    }

                    // Spectrum Header Overlay
                    Row {
                        anchors { top: parent.top; left: parent.left; margins: 8 }
                        spacing: 8
                        Text {
                            text: "// 32-BAND FREQUENCY SPECTRUM //"
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                            font.letterSpacing: Theme.trkLabel
                            font.weight: Font.Bold
                        }
                        Text {
                            text: view.isPlaying ? (view.trackTitle + (view.trackArtist ? " — " + view.trackArtist : "")).toUpperCase() : "ACOUSTIC STANDBY"
                            color: view.isPlaying ? Theme.accent : Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                            font.letterSpacing: Theme.trkLabel
                            elide: Text.ElideRight
                            width: 480
                        }
                    }

                    // 32-Band Visualizer Canvas
                    Item {
                        id: specField
                        anchors {
                            left: parent.left; right: parent.right
                            bottom: parent.bottom; top: parent.top
                            leftMargin: 12; rightMargin: 12
                            topMargin: 24; bottomMargin: 16
                        }

                        property var levels: [
                            0.04, 0.05, 0.07, 0.08, 0.12, 0.16, 0.22, 0.28,
                            0.35, 0.42, 0.48, 0.52, 0.50, 0.44, 0.38, 0.34,
                            0.30, 0.28, 0.26, 0.24, 0.22, 0.20, 0.18, 0.16,
                            0.14, 0.12, 0.10, 0.08, 0.07, 0.06, 0.05, 0.04
                        ]
                        property var peaks: [
                            0.08, 0.09, 0.11, 0.12, 0.16, 0.20, 0.26, 0.32,
                            0.39, 0.46, 0.52, 0.56, 0.54, 0.48, 0.42, 0.38,
                            0.34, 0.32, 0.30, 0.28, 0.26, 0.24, 0.22, 0.20,
                            0.18, 0.16, 0.14, 0.12, 0.11, 0.10, 0.09, 0.08
                        ]
                        property int simStep: 0

                        Timer {
                            interval: 32
                            running: view.visible
                            repeat: true
                            onTriggered: {
                                specField.simStep++;
                                const step = specField.simStep;
                                const volMult = view.muted ? 0.02 : Math.min(1.2, view.volume);
                                const isLive = view.isPlaying;
                                const newL = [];
                                const newP = [];

                                for (let i = 0; i < 32; i++) {
                                    let raw = 0.04;
                                    if (isLive) {
                                        // Harmonic multi-frequency oscillator simulation
                                        const f1 = Math.sin(step * 0.18 + i * 0.42);
                                        const f2 = Math.cos(step * 0.11 - i * 0.31);
                                        const f3 = Math.sin(step * 0.34 + i * 0.85);
                                        const f4 = Math.cos(step * 0.07 + i * 0.15);

                                        // Sub-bass boost in lower bands (0..7), vocal/snare presence (8..18), cymbal highs (19..31)
                                        const curve = i < 8 ? (0.85 + 0.15 * Math.sin(step * 0.25))
                                                    : (i < 20 ? (0.75 + 0.20 * Math.cos(step * 0.20))
                                                    : 0.55);
                                        const wave = (f1 * 0.38 + f2 * 0.28 + f3 * 0.20 + f4 * 0.14 + 1.0) * 0.5;
                                        const noise = (Math.random() * 0.08 - 0.04);
                                        raw = Math.max(0.04, Math.min(0.96, wave * curve * volMult + noise));
                                    } else {
                                        // Ambient low idle breathing floor
                                        const idleWave = (Math.sin(step * 0.05 + i * 0.2) + 1.0) * 0.06;
                                        raw = Math.max(0.03, idleWave * volMult);
                                    }
                                    newL.push(raw);

                                    // Peak hold with gravitational decay
                                    const prevPeak = specField.peaks[i] || 0.06;
                                    const nextPeak = Math.max(raw, prevPeak - 0.028);
                                    newP.push(nextPeak);
                                }
                                specField.levels = newL;
                                specField.peaks = newP;
                            }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: 4

                            Repeater {
                                model: 32

                                Item {
                                    id: barCol
                                    required property int index
                                    width: (specField.width - 31 * 4) / 32
                                    height: specField.height

                                    // Bar Body (Color segmented by frequency spectrum band)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(2, (specField.levels[index] || 0.04) * parent.height)
                                        radius: 0
                                        color: {
                                            if (view.muted) return Theme.dim;
                                            if (index < 6) return Theme.accent;           // Sub-bass & Bass
                                            if (index < 18) return Theme.accent;             // Midrange & Vocal
                                            if (index < 26) return Theme.accent2;       // High-Mid
                                            return Theme.accent2;                           // Presence & Treble
                                        }
                                        opacity: 0.88
                                    }

                                    // Peak Needle (Bright glowing cap holding peaks)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: Math.min(parent.height - 2, Math.max(2, (specField.peaks[index] || 0.06) * parent.height))
                                        width: parent.width
                                        height: 1
                                        color: {
                                            if (view.muted) return Theme.dim;
                                            if (index < 6) return Theme.accent;
                                            if (index < 18) return "#FFFFFF";
                                            return Theme.accent2;
                                        }
                                        opacity: 0.95
                                    }
                                }
                            }
                        }
                    }

                    // Base Frequency Labels
                    Row {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; bottomMargin: 2; leftMargin: 14; rightMargin: 14 }
                        Item { width: parent.width * 0.15; height: 10; Text { text: "20 Hz"; color: Theme.dim; font.pixelSize: Theme.szMicro; font.family: Theme.fontMono } }
                        Item { width: parent.width * 0.20; height: 10; Text { text: "125 Hz"; color: Theme.dim; font.pixelSize: Theme.szMicro; font.family: Theme.fontMono } }
                        Item { width: parent.width * 0.25; height: 10; Text { text: "1 kHz"; color: Theme.dim; font.pixelSize: Theme.szMicro; font.family: Theme.fontMono } }
                        Item { width: parent.width * 0.25; height: 10; Text { text: "8 kHz"; color: Theme.dim; font.pixelSize: Theme.szMicro; font.family: Theme.fontMono } }
                        Item { width: parent.width * 0.15; height: 10; Text { text: "20 kHz"; color: Theme.dim; font.pixelSize: Theme.szMicro; font.family: Theme.fontMono; anchors.right: parent.right } }
                    }
                }
            }

            // =============================================================
            // SECTION 2: MASTER COCKPIT VOLUME CONTROLLER
            // =============================================================
            Rectangle {
                width: parent.width
                height: 104
                color: Theme.card
                border.width: 1
                border.color: Theme.edge

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1
                    color: Theme.accentWash
                }

                Column {
                    anchors { fill: parent; margins: 14 }
                    spacing: 10

                    // Top Row: Readout, Decibels, Status Tag, and Preset Buttons
                    Item {
                        width: parent.width
                        height: 28

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Text {
                                text: "MASTER VOLUME"
                                color: Theme.dim
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szBody
                                font.letterSpacing: Theme.trkLabel
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Big Numerical Readout
                            Text {
                                text: view.muted ? "MUTED" : Math.round(view.volume * 100) + "%"
                                color: view.muted ? Theme.alert : (view.volume > 1.0 ? Theme.warn : Theme.accent)
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szValue
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Decibel Readout
                            Text {
                                text: "[" + view.volumeToDb(view.volume) + "]"
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szBody
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Quick Preset Chips
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Btn {
                                text: "0%"
                                active: view.volume === 0 || view.muted
                                tint: Theme.alert
                                onClicked: view.setMasterVolume(0)
                            }
                            Btn {
                                text: "25%"
                                active: !view.muted && Math.round(view.volume * 100) === 25
                                tint: Theme.accent
                                onClicked: { if (view.muted) view.toggleMute(); view.setMasterVolume(0.25); }
                            }
                            Btn {
                                text: "50%"
                                active: !view.muted && Math.round(view.volume * 100) === 50
                                tint: Theme.accent
                                onClicked: { if (view.muted) view.toggleMute(); view.setMasterVolume(0.50); }
                            }
                            Btn {
                                text: "75%"
                                active: !view.muted && Math.round(view.volume * 100) === 75
                                tint: Theme.accent
                                onClicked: { if (view.muted) view.toggleMute(); view.setMasterVolume(0.75); }
                            }
                            Btn {
                                text: "100%"
                                active: !view.muted && Math.round(view.volume * 100) === 100
                                tint: Theme.accent
                                onClicked: { if (view.muted) view.toggleMute(); view.setMasterVolume(1.00); }
                            }
                            Btn {
                                text: "+5dB BOOST"
                                active: !view.muted && view.volume > 1.0
                                tint: Theme.warn
                                onClicked: { if (view.muted) view.toggleMute(); view.setMasterVolume(1.50); }
                            }
                            Btn {
                                text: view.muted ? "UNMUTE" : "MUTE"
                                active: view.muted
                                tint: view.muted ? Theme.alert : Theme.line
                                onClicked: view.toggleMute()
                            }
                        }
                    }

                    // Bottom Row: Precision Interactive Tactile Slider
                    Item {
                        width: parent.width
                        height: 36

                        // Background Groove
                        Rectangle {
                            id: trackGroove
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 12
                            radius: 0
                            color: Theme.layer2
                            border.width: 1
                            border.color: Theme.line2

                            // 100% Unity Gain Notch Marker
                            Rectangle {
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                x: (trackGroove.width / 1.5) - 1
                                width: 2
                                color: Theme.warn
                                opacity: 0.7
                                z: 3
                            }

                            // Interactive Fill Bar
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: Math.max(0, Math.min(trackGroove.width, (view.volume / 1.5) * trackGroove.width))
                                radius: 0
                                color: {
                                    if (view.muted) return Theme.dim;
                                    if (view.volume > 1.0) return Theme.warn;
                                    return Theme.accent;
                                }

                                // Specular Top Line on fill
                                Rectangle {
                                    anchors { top: parent.top; left: parent.left; right: parent.right }
                                    height: 1
                                    color: "#FFFFFF"
                                    opacity: 0.35
                                }
                            }

                            // Multi-segment Hairline Hatch Marks
                            Row {
                                anchors.fill: parent
                                spacing: (parent.width - 60 * 1) / 59
                                Repeater {
                                    model: 60
                                    Rectangle {
                                        width: 1; height: parent.height
                                        color: Theme.bg
                                        opacity: 0.5
                                    }
                                }
                            }
                        }

                        // Draggable Thumb Handle
                        Rectangle {
                            id: thumbHandle
                            x: Math.max(0, Math.min(parent.width - width, (view.volume / 1.5) * (parent.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 26
                            radius: 0
                            color: view.muted ? Theme.dim : (view.volume > 1.0 ? Theme.warn : Theme.accent)
                            border.width: 1
                            border.color: "#FFFFFF"

                            Rectangle {
                                anchors.centerIn: parent
                                width: 2; height: 14
                                color: Theme.bg
                            }
                        }

                        // Scrub & Drag Interaction MouseArea
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function updateFromMouse(mouseX: real): void {
                                const ratio = Math.max(0, Math.min(1.0, mouseX / width));
                                const targetVol = ratio * 1.5;
                                if (view.muted) view.toggleMute();
                                view.setMasterVolume(targetVol);
                            }

                            onPressed: mouse => updateFromMouse(mouse.x)
                            onPositionChanged: mouse => {
                                if (pressed) updateFromMouse(mouse.x);
                            }
                            onWheel: wheel => {
                                const delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                                view.stepVolume(delta);
                            }
                        }
                    }
                }
            }

            // =============================================================
            // SECTION 3: HARDWARE SINKS & APP STREAMS (2-COLUMNS)
            // =============================================================
            Row {
                width: parent.width
                height: contentCol.height - 260
                spacing: 14

                // ---- Left: Hardware Output Sinks (Device Switcher) ----
                Rectangle {
                    width: (parent.width - 14) / 2
                    height: parent.height
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.edge

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 1; color: Theme.accentWash
                    }

                    Column {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8

                        Row {
                            spacing: 8
                            Text {
                                text: "// AUDIO OUTPUT DEVICES //"
                                color: Theme.dim
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szMicro
                                font.letterSpacing: Theme.trkLabel
                                font.weight: Font.Bold
                            }
                            Text {
                                text: (view.audioData.sinks || []).length + " DETECTED"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }
                        }

                        Flickable {
                            width: parent.width
                            height: parent.height - 24
                            contentWidth: width
                            contentHeight: sinkListCol.implicitHeight
                            clip: true

                            Column {
                                id: sinkListCol
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: view.audioData.sinks || []

                                    Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 52
                                        color: modelData.is_default ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Theme.layer2
                                        border.width: 1
                                        border.color: modelData.is_default ? Theme.accent : Theme.line2

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: view.switchSink(modelData.name)
                                        }

                                        Item {
                                            anchors { fill: parent; margins: 10 }

                                            Row {
                                                anchors.left: parent.left
                                                anchors.right: statusCol.left
                                                anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 10

                                                // Active Indicator Pip
                                                Rectangle {
                                                    width: 6; height: 6; radius: 0
                                                    color: modelData.is_default ? Theme.accent : Theme.dim
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 2
                                                    width: parent.width - 20

                                                    Text {
                                                        text: modelData.label
                                                        color: modelData.is_default ? Theme.text : Theme.dim
                                                        font.family: Theme.fontDisplay
                                                        font.pixelSize: Theme.szBody
                                                        font.weight: modelData.is_default ? Font.Bold : Font.Normal
                                                        font.letterSpacing: Theme.trkLabel
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                    Text {
                                                        text: modelData.desc
                                                        color: Theme.dim
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.szMicro
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                }
                                            }

                                            // Volume percentage & status badge
                                            Column {
                                                id: statusCol
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Text {
                                                    text: modelData.is_default ? "ACTIVE // 稼働" : "SET ACTIVE"
                                                    color: modelData.is_default ? Theme.accent : Theme.dim
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.szMicro
                                                    font.letterSpacing: Theme.trkLabel
                                                    anchors.right: parent.right
                                                }
                                                Text {
                                                    text: (modelData.mute ? "MUTED" : modelData.volume + "%") + " (" + modelData.db + ")"
                                                    color: modelData.mute ? Theme.alert : Theme.text
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.szBody
                                                    font.weight: Font.DemiBold
                                                    anchors.right: parent.right
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Right: Application Audio Streams Mixer ----
                Rectangle {
                    width: (parent.width - 14) / 2
                    height: parent.height
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.edge

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 1; color: Theme.accentWash
                    }

                    Column {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8

                        Row {
                            spacing: 8
                            Text {
                                text: "// ACTIVE APPLICATION STREAMS //"
                                color: Theme.dim
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szMicro
                                font.letterSpacing: Theme.trkLabel
                                font.weight: Font.Bold
                            }
                            Text {
                                text: (view.audioData.streams || []).length + " ACTIVE"
                                color: Theme.accent2
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }
                        }

                        // If no active streams: Standby Card
                        Item {
                            width: parent.width
                            height: parent.height - 24
                            visible: (view.audioData.streams || []).length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "NO APPLICATION STREAMS ACTIVE"
                                    color: Theme.dim
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.szBody
                                    font.letterSpacing: Theme.trkLabel
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "Applications playing audio (Browser, Spotify, Games) will appear here for individual stream volume balancing."
                                    color: Theme.faint
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.szMicro
                                    width: 380
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // If active streams: List of Application Stream Controls
                        Flickable {
                            width: parent.width
                            height: parent.height - 24
                            contentWidth: width
                            contentHeight: streamListCol.implicitHeight
                            clip: true
                            visible: (view.audioData.streams || []).length > 0

                            Column {
                                id: streamListCol
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: view.audioData.streams || []

                                    Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 52
                                        color: Theme.layer2
                                        border.width: 1
                                        border.color: Theme.line2

                                        Row {
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 10

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2
                                                width: 140

                                                Text {
                                                    text: modelData.app
                                                    color: Theme.text
                                                    font.family: Theme.fontDisplay
                                                    font.pixelSize: Theme.szBody
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                                Text {
                                                    text: modelData.media ? modelData.media : "Playback"
                                                    color: Theme.dim
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.szMicro
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }

                                            // Stream Volume Meter & Controls
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                Meter {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    pct: modelData.mute ? 0 : modelData.volume
                                                    segs: 12
                                                    segWidth: 5
                                                    segHeight: 10
                                                    barColor: modelData.mute ? Theme.dim : Theme.accent2
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.mute ? "MUTED" : modelData.volume + "%"
                                                    color: modelData.mute ? Theme.alert : Theme.text
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.szBody
                                                    width: 48
                                                }

                                                Btn {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "−"
                                                    onClicked: view.setStreamVol(modelData.index, Math.max(0, modelData.volume - 5))
                                                }
                                                Btn {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "+"
                                                    onClicked: view.setStreamVol(modelData.index, Math.min(150, modelData.volume + 5))
                                                }
                                                Btn {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.mute ? "ON" : "MUT"
                                                    active: modelData.mute
                                                    tint: modelData.mute ? Theme.alert : Theme.line
                                                    onClicked: view.toggleStreamMute(modelData.index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
