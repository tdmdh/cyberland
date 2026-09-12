import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "MUSIC DECK"
    readonly property string panelJp: "音響"
    readonly property string panelHint: "SPACE PLAY/PAUSE  •  ←/→ SKIP  •  ↑/↓ VOL  •  S SHUFFLE  •  L LOOP  •  ESC CLOSE"
    readonly property int panelWidth: 920
    readonly property int panelHeight: 330
    readonly property string placement: "center"

    signal closeRequested()

    // ---- MPRIS Player Tracking -------------------------------------------
    readonly property var players: Mpris.players.values
    property var selectedPlayer: null

    readonly property var player: {
        if (selectedPlayer && players.indexOf(selectedPlayer) !== -1) {
            return selectedPlayer;
        }
        return players.find(p => p.isPlaying) ?? (players[0] ?? null);
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.isPlaying
    readonly property string trackTitle: hasPlayer && player.trackTitle ? player.trackTitle : ""
    readonly property string trackArtist: hasPlayer && (player.trackArtist || player.trackArtists) ? (player.trackArtist || player.trackArtists) : ""
    readonly property string trackAlbum: hasPlayer && player.trackAlbum ? player.trackAlbum : ""
    readonly property string trackArtUrl: hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real trackLength: hasPlayer && player.length > 0 ? player.length : 0

    // ---- Scrubbing State -------------------------------------------------
    property real currentPos: 0
    property bool isScrubbing: false
    property real lastVolume: 0.85

    Connections {
        target: view.player
        function onPositionChanged() {
            if (!view.isScrubbing && view.player) {
                view.currentPos = view.player.position;
            }
        }
    }

    onTrackTitleChanged: {
        if (!view.isScrubbing && view.player) {
            view.currentPos = view.player.position || 0;
        }
        if (titleGlitch) titleGlitch.trigger();
    }

    function formatTime(secs: real): string {
        if (isNaN(secs) || secs < 0) secs = 0;
        const s = Math.floor(secs);
        const m = Math.floor(s / 60);
        const rem = s % 60;
        return m + ":" + (rem < 10 ? "0" : "") + rem;
    }

    function cycleLoop(): void {
        if (!view.player) return;
        if (view.player.loopStatus === LoopStatus.None) view.player.loopStatus = LoopStatus.Track;
        else if (view.player.loopStatus === LoopStatus.Track) view.player.loopStatus = LoopStatus.Playlist;
        else view.player.loopStatus = LoopStatus.None;
    }

    function toggleMute(): void {
        if (!view.player) return;
        if (view.player.volume > 0.01) {
            view.lastVolume = view.player.volume;
            view.player.volume = 0;
        } else {
            view.player.volume = view.lastVolume > 0.05 ? view.lastVolume : 0.85;
        }
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Space) {
            if (view.player) view.player.togglePlaying();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (view.player) view.player.previous();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (view.player) view.player.next();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            if (view.player) view.player.volume = Math.min(1.0, view.player.volume + 0.05);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (view.player) view.player.volume = Math.max(0.0, view.player.volume - 0.05);
            event.accepted = true;
        } else if (event.key === Qt.Key_S) {
            if (view.player) view.player.shuffle = !view.player.shuffle;
            event.accepted = true;
        } else if (event.key === Qt.Key_L) {
            view.cycleLoop();
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            view.toggleMute();
            event.accepted = true;
        }
    }

    // Dynamic Header Component
    property Component headerComponent: Component {
        Row {
            spacing: 16
            DynamicPill {
                label: "STATUS"
                jp: "状態"
                value: view.isPlaying ? "PLAYING" : (view.hasPlayer ? "PAUSED" : "IDLE")
                subValue: view.hasPlayer ? (view.trackArtist ? view.trackArtist : "AUDIO") : "STANDBY"
                tint: view.isPlaying ? Theme.neonGreen : (view.hasPlayer ? Theme.neonYellow : Theme.dim)
            }
            DynamicPill {
                label: "SOURCE"
                jp: "音源"
                value: view.hasPlayer ? (view.player.identity ? view.player.identity.toUpperCase() : "MPRIS") : "NONE"
                subValue: view.hasPlayer ? "48kHz STEREO" : "NO STREAM"
                tint: Theme.laser
            }
        }
    }

    // ---- Main Content ----------------------------------------------------
    Row {
        anchors.fill: parent
        spacing: 18

        // Left Art Chamber (160x160)
        ChamferBox {
            width: 160
            height: 160
            cut: 8
            strokeColor: view.isPlaying ? Theme.neonCyan : Theme.line
            strokeWidth: 1
            fillColor: Theme.layer2
            reticles: true
            notch: true
            notchColor: view.isPlaying ? Theme.neonGreen : Theme.line

            Image {
                id: albumArt
                anchors.fill: parent
                visible: view.trackArtUrl !== "" && status === Image.Ready
                source: view.trackArtUrl
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true

                Scanlines { opacity: 0.04 }
                Bracket { corner: "tl"; anchors.left: parent.left; anchors.top: parent.top }
                Bracket { corner: "br"; anchors.right: parent.right; anchors.bottom: parent.bottom }
            }

            // Fallback Animated Cassette
            Item {
                anchors.fill: parent
                visible: !albumArt.visible

                Rectangle {
                    anchors.centerIn: parent
                    width: 136; height: 106
                    color: Theme.layer1
                    border.color: Theme.line2
                    radius: 0

                    Rectangle {
                        anchors.top: parent.top; anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 16; height: 22
                        color: Qt.rgba(Theme.neonMagenta.r, Theme.neonMagenta.g, Theme.neonMagenta.b, 0.12)
                        border.color: Theme.line

                        Text {
                            anchors.centerIn: parent
                            text: "D-TAPE // HI-FI"
                            color: Theme.neonCyan
                            font.family: Theme.fontDisplay
                            font.pixelSize: 8
                            font.letterSpacing: 1.5
                            font.weight: Font.Bold
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 8
                        spacing: 28

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: Theme.bg
                            border.width: 2
                            border.color: view.isPlaying ? Theme.neonCyan : Theme.line

                            Item {
                                anchors.fill: parent
                                RotationAnimation on rotation {
                                    from: 0; to: 360; duration: 2200
                                    loops: Animation.Infinite
                                    running: view.isPlaying
                                }
                                Rectangle { width: 2; height: parent.height; color: Theme.neonCyan; anchors.centerIn: parent; opacity: 0.8 }
                                Rectangle { width: parent.width; height: 2; color: Theme.neonCyan; anchors.centerIn: parent; opacity: 0.8 }
                                Rectangle { width: 10; height: 10; radius: 5; color: Theme.bg; border.color: Theme.neonCyan; anchors.centerIn: parent }
                            }
                        }

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: Theme.bg
                            border.width: 2
                            border.color: view.isPlaying ? Theme.neonMagenta : Theme.line

                            Item {
                                anchors.fill: parent
                                RotationAnimation on rotation {
                                    from: 0; to: 360; duration: 2200
                                    loops: Animation.Infinite
                                    running: view.isPlaying
                                }
                                Rectangle { width: 2; height: parent.height; color: Theme.neonMagenta; anchors.centerIn: parent; opacity: 0.8 }
                                Rectangle { width: parent.width; height: 2; color: Theme.neonMagenta; anchors.centerIn: parent; opacity: 0.8 }
                                Rectangle { width: 10; height: 10; radius: 5; color: Theme.bg; border.color: Theme.neonMagenta; anchors.centerIn: parent }
                            }
                        }
                    }
                }
            }

            // Floating Status Pill
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 6
                width: miniStatus.implicitWidth + 10
                height: 16
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85)
                border.color: view.isPlaying ? Theme.neonCyan : Theme.line2

                Row {
                    id: miniStatus
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        width: 5; height: 5; radius: 0
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.isPlaying ? Theme.neonGreen : Theme.dim
                    }
                    Text {
                        text: view.isPlaying ? "LIVE" : "IDLE"
                        color: view.isPlaying ? Theme.neonGreen : Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // Right Info & Controls Column
        Column {
            width: parent.width - 160 - 18
            height: 160
            spacing: 7

            // Stream / Player Tag
            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.hasPlayer
                              ? ("// " + (view.player.identity ? view.player.identity.toUpperCase() : "MPRIS") + " //")
                              : "// STANDBY //"
                        color: view.isPlaying ? Theme.neonCyan : Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        font.weight: Font.Bold
                    }

                    Repeater {
                        model: view.players.length > 1 ? view.players : []
                        Btn {
                            required property var modelData
                            text: (modelData.identity || "PLAYER").toUpperCase() + (modelData.isPlaying ? " ●" : "")
                            active: view.player === modelData
                            tint: modelData.isPlaying ? Theme.neonGreen : Theme.neonCyan
                            implicitHeight: 20
                            onClicked: view.selectedPlayer = modelData
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.hasPlayer ? "STEREO • 48kHz" : "AUDIO BUS READY"
                    color: Theme.line
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                }
            }

            // Track Title & Artist
            Column {
                width: parent.width
                spacing: 2

                GlitchText {
                    id: titleGlitch
                    width: parent.width
                    text: view.hasPlayer && view.trackTitle !== "" ? view.trackTitle : "NO ACTIVE AUDIO STREAM"
                    jp: view.trackArtist !== "" ? view.trackArtist : "待機"
                    color: Theme.text
                    jpColor: Theme.dim
                    pixelSize: 17
                    letterSpacing: 2
                    weight: Font.Bold
                }

                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        text: view.trackArtist !== "" ? view.trackArtist : "System Idle"
                        color: Theme.neonCyan
                        font.family: Theme.fontDisplay
                        font.pixelSize: 12
                        font.letterSpacing: 1.4
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: view.trackAlbum !== ""
                        text: "•"
                        color: Theme.dim
                        font.pixelSize: 10
                    }
                    Text {
                        visible: view.trackAlbum !== ""
                        text: view.trackAlbum
                        color: Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: parent.width - 200
                    }
                }
            }

            // Mini 20-band Spectrum Analyzer
            Item {
                id: specRow
                width: parent.width
                height: 20

                property var levels: [
                    0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05,
                    0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05
                ]
                property var peaks: [
                    0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08,
                    0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08
                ]
                property int simStep: 0

                Timer {
                    interval: 40
                    repeat: true
                    running: view.isPlaying
                    onTriggered: {
                        specRow.simStep++;
                        const step = specRow.simStep;
                        const newL = [];
                        const newP = [];
                        for (let i = 0; i < 20; i++) {
                            const w1 = Math.sin(step * 0.16 + i * 0.60);
                            const w2 = Math.cos(step * 0.10 - i * 0.45);
                            const w3 = Math.sin(step * 0.30 + i * 1.20);
                            const energy = i < 5 ? 0.92 : (i < 13 ? 0.74 : 0.50);
                            const raw = (w1 * 0.42 + w2 * 0.35 + w3 * 0.23 + 1.0) * 0.5;
                            const jitter = (Math.random() * 0.14 - 0.07);
                            const barVal = Math.max(0.06, Math.min(0.96, raw * energy + jitter));
                            newL.push(barVal);

                            const prevPeak = specRow.peaks[i] || 0;
                            const nextPeak = Math.max(barVal, prevPeak - 0.035);
                            newP.push(nextPeak);
                        }
                        specRow.levels = newL;
                        specRow.peaks = newP;
                    }
                }

                Row {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        model: 20
                        Item {
                            required property int index
                            width: (parent.width - 19 * 3) / 20
                            height: parent.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(2, (specRow.levels[index] || 0.05) * parent.height)
                                radius: 0
                                color: index < 7 ? Theme.accent
                                     : (index < 14 ? Theme.laser : Theme.accent2)
                                opacity: 0.85
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Math.min(parent.height - 2, (specRow.peaks[index] || 0.05) * parent.height)
                                width: parent.width
                                height: 1.5
                                radius: 0
                                color: Theme.amber
                                opacity: 0.95
                            }
                        }
                    }
                }
            }

            // Scrubber Bar & Timestamps
            Item {
                width: parent.width
                height: 20

                Text {
                    id: elapTxt
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.formatTime(view.currentPos)
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Item {
                    id: scrubBar
                    anchors.left: elapTxt.right
                    anchors.right: durTxt.left
                    anchors.margins: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 5
                        radius: 0
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.7)
                        border.width: 1
                        border.color: Theme.glassBorder

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            radius: 0
                            width: view.trackLength > 0
                                   ? Math.max(0, Math.min(parent.width, (view.currentPos / view.trackLength) * parent.width))
                                   : 0
                            color: Theme.accent
                        }
                    }

                    // Playhead Cursor
                    Rectangle {
                        readonly property real posX: view.trackLength > 0
                            ? Math.max(0, Math.min(parent.width, (view.currentPos / view.trackLength) * parent.width))
                            : 0
                        x: posX - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 14
                        radius: 0
                        color: "#ffffff"
                        border.width: 1
                        border.color: Theme.accent
                        visible: view.hasPlayer
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            if (!view.player || view.trackLength <= 0) return;
                            view.isScrubbing = true;
                            const ratio = Math.max(0, Math.min(1, mouse.x / width));
                            view.currentPos = ratio * view.trackLength;
                        }
                        onPositionChanged: mouse => {
                            if (!view.isScrubbing || !view.player || view.trackLength <= 0) return;
                            const ratio = Math.max(0, Math.min(1, mouse.x / width));
                            view.currentPos = ratio * view.trackLength;
                        }
                        onReleased: {
                            if (view.isScrubbing && view.player && view.trackLength > 0) {
                                view.player.position = view.currentPos;
                                view.isScrubbing = false;
                            }
                        }
                    }
                }

                Text {
                    id: durTxt
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.formatTime(view.trackLength)
                    color: Theme.textSecondary
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }
            }

            // Control Buttons & Volume
            Row {
                width: parent.width
                height: 28
                spacing: 8

                Btn {
                    text: "◀◀"
                    implicitWidth: 38
                    implicitHeight: 28
                    onClicked: if (view.player) view.player.previous()
                }

                Btn {
                    text: view.isPlaying ? "❚❚" : "▶"
                    jp: view.isPlaying ? "停止" : "再生"
                    active: view.isPlaying
                    implicitWidth: 54
                    implicitHeight: 28
                    onClicked: if (view.player) view.player.togglePlaying()
                }

                Btn {
                    text: "▶▶"
                    implicitWidth: 38
                    implicitHeight: 28
                    onClicked: if (view.player) view.player.next()
                }

                Item { width: 6; height: 1 }

                Btn {
                    text: "SHUFFLE"
                    jp: "乱順"
                    active: view.player && view.player.shuffle
                    implicitHeight: 28
                    onClicked: if (view.player) view.player.shuffle = !view.player.shuffle
                }

                Btn {
                    text: view.player && view.player.loopStatus === LoopStatus.Track ? "LOOP 1"
                        : (view.player && view.player.loopStatus === LoopStatus.Playlist ? "LOOP ALL" : "LOOP OFF")
                    jp: "反復"
                    active: view.player && view.player.loopStatus !== LoopStatus.None
                    implicitHeight: 28
                    onClicked: view.cycleLoop()
                }

                Item { width: parent.width - 520; height: 1 }

                // Compact Volume Meter
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Btn {
                        text: (view.player && view.player.volume < 0.01) ? "MUTED" : "VOL"
                        jp: "音量"
                        active: view.player && view.player.volume < 0.01
                        tint: (view.player && view.player.volume < 0.01) ? Theme.alert : Theme.line
                        implicitHeight: 28
                        onClicked: view.toggleMute()
                    }

                    Meter {
                        anchors.verticalCenter: parent.verticalCenter
                        segs: 12
                        pct: view.player ? Math.round(view.player.volume * 100) : 0
                        barColor: (view.player && view.player.volume < 0.01) ? Theme.dim : Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        text: view.player ? Math.round(view.player.volume * 100) + "%" : "--"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
