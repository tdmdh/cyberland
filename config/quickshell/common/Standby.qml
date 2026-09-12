// The idle readout, worn by both idle stages.
//
// Lives in common/ because the two stages are two processes: a layer-shell
// surface and a WlSessionLock cannot coexist in one Wayland client (measured:
// "wl_display: error 0: invalid object" and a fatal disconnect the moment the
// lock engages, regardless of focus mode or visibility). So `idle` draws the
// ambient stage and `lock` draws the locked one, and this is what keeps them
// identical.
import QtQuick
import Quickshell        // SystemClock
import Quickshell.Io
import "."

Item {
    id: ro

    property string state1: "STANDBY"
    property string jp1: "待機"
    // The locked stage shows strictly less: anyone standing at a locked
    // machine can read this, and which files an agent is touching is not
    // for them.
    property bool   showWork: true
    property bool   auth: false

    focus: ro.auth
    Keys.forwardTo: [field]

    // Auth wiring, bound by the lock module. Left inert on the ambient stage.
    property string entry: ""
    property string note: ""
    property bool   failed: false
    signal submitted()
    signal typed(string text)

    // ---- wallpaper detection ---------------------------------------------
    property string wallpaper: ""

    FileView {
        id: srcView
        path: Quickshell.env("HOME") + "/.cache/hypr/wallpaper-source"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text().trim();
            if (t) ro.wallpaper = t;
        }
    }

    Process {
        id: swwwQuery
        command: ["swww", "query"]
        stdout: SplitParser {
            onRead: line => {
                const m = /currently displaying: image: (.*)$/.exec(line.trim());
                if (m && m[1]) ro.wallpaper = m[1];
            }
        }
    }

    function refreshWallpaper() {
        if (!swwwQuery.running) swwwQuery.running = true;
    }

    Component.onCompleted: refreshWallpaper()

    // ---- wallpaper background layer --------------------------------------
    Item {
        anchors.fill: parent
        z: -1

        Image {
            id: bgWall
            anchors.fill: parent
            source: ro.wallpaper !== "" ? "file://" + ro.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: false
            visible: ro.wallpaper !== ""
        }

        // Tokyo dark scrim overlay: dims the wallpaper and binds it to the ground palette,
        // ensuring high-contrast legibility for clock, telemetry, and password input
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            opacity: 0.65
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.22
        }

        // Procedural CRT micro-scanlines
        Scanlines {}
    }

    Bracket { corner: "tl"; anchors.left: parent.left;   anchors.top: parent.top
              anchors.margins: 40; arm: 34 }
    Bracket { corner: "tr"; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 40; arm: 34 }
    Bracket { corner: "bl"; anchors.left: parent.left;   anchors.bottom: parent.bottom
              anchors.margins: 40; arm: 34 }
    Bracket { corner: "br"; anchors.right: parent.right; anchors.bottom: parent.bottom
              anchors.margins: 40; arm: 34 }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(ro.now, "HH:mm")
            color: Theme.text
            font.family: Theme.fontDisplay
            font.pixelSize: 154
            font.weight: Font.Light
            font.letterSpacing: -4.0
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            bottomPadding: 36
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(ro.now, "dddd dd MMMM").toUpperCase()
                color: Theme.dim
                font.family: Theme.fontDisplay
                font.pixelSize: 15
                font.letterSpacing: 4
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "日付"
                color: Theme.line
                font.family: Theme.fontJP
                font.pixelSize: 12
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            bottomPadding: 36

            DynamicPill {
                label: "HOST"
                jp: "宿主"
                value: Sys.host || "--"
                subValue: "SYSTEM"
                tint: Theme.laser
            }
            DynamicPill {
                label: "UPTIME"
                jp: "稼働"
                value: Sys.up || "--"
                subValue: "SESSION"
                tint: Theme.dim
            }
            DynamicPill {
                label: "CPU"
                jp: "演算"
                visible: ro.showWork
                value: Sys.cpu < 0 ? "--" : Sys.cpu + "%"
                subValue: "LOAD"
                tint: Sys.cpu >= 80 ? Theme.alert : (Sys.cpu >= 60 ? Theme.warn : Theme.laser)
            }
            DynamicPill {
                label: "MEM"
                jp: "記憶"
                visible: ro.showWork
                value: Sys.mem < 0 ? "--" : Sys.mem + "%"
                subValue: "RAM"
                tint: Sys.mem >= 80 ? Theme.alert : Theme.laser
            }
            DynamicPill {
                label: "TEMP"
                jp: "温度"
                visible: ro.showWork
                value: Sys.temp < 0 ? "--" : Sys.temp + "°"
                subValue: "THERMAL"
                tint: Sys.temp >= 75 ? Theme.alert : Theme.laser
            }
        }

        // ---- auth ----
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ro.auth
            width: 420
            height: 48
            radius: 0
            color: Theme.glassCard
            border.width: 1
            border.color: ro.failed ? Theme.alert : (field.activeFocus ? Theme.accent : Theme.glassBorder)

            // Top specular catch
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                anchors.leftMargin: 1; anchors.rightMargin: 1
                height: 1
                color: Theme.specularDim
            }

            // Dots, not a text cursor: the field reads as a lock and the
            // count is the only feedback that matters.
            Row {
                anchors.centerIn: parent
                spacing: 9
                visible: ro.entry.length > 0
                Repeater {
                    model: Math.min(ro.entry.length, 32)
                    Rectangle { width: 8; height: 8; radius: 0; color: Theme.accent }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: ro.entry.length === 0
                text: "PASSWORD  合言葉"
                color: Theme.dim
                font.family: Theme.fontDisplay
                font.pixelSize: 12
                font.letterSpacing: 3
            }

            // Invisible: the field above is drawn by hand, this only collects
            // keystrokes.
            TextInput {
                id: field
                anchors.fill: parent
                opacity: 0
                focus: ro.auth
                echoMode: TextInput.Password
                text: ro.entry
                onTextChanged: ro.typed(text)
                onAccepted: ro.submitted()
                Component.onCompleted: if (ro.auth) forceActiveFocus()
                onVisibleChanged: if (visible && ro.auth) forceActiveFocus()
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: if (ro.auth) field.forceActiveFocus()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ro.auth && ro.note !== ""
            topPadding: 14
            text: ro.note
            color: ro.failed ? Theme.alert : Theme.dim
            font.family: Theme.fontDisplay
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }

    // ---- state label ----
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64
        spacing: 9

        Rectangle {
            id: pip
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6
            color: ro.auth ? Theme.alert : Theme.accent
            // The same drawn pulse the frame uses for a working agent.
            SequentialAnimation on opacity {
                running: true; loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ro.state1
            color: Theme.dim
            font.family: Theme.fontDisplay
            font.pixelSize: 13
            font.letterSpacing: 6
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ro.jp1
            color: Theme.line
            font.family: Theme.fontJP
            font.pixelSize: 11
        }
    }

    // One clock per surface. SystemClock cannot live in a singleton shared
    // across processes, so each stage keeps its own.
    property date now: clk.date
    SystemClock { id: clk; precision: SystemClock.Minutes }
}
