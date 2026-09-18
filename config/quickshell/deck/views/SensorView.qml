import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "SENSORS"
    readonly property string panelJp: "計装"
    readonly property string panelHint: "R  REFRESH TELEMETRY  •  ESC  CLOSE"
    readonly property int panelWidth: Theme.panelM
    readonly property int panelHeight: -1          // fit content; see deck targetH
    implicitHeight: contentCol.implicitHeight
    readonly property string placement: "center"

    signal closeRequested()

    property var telemetryData: ({})
    property bool busy: false

    function onActivated(): void {
        view.probe();
    }

    Component.onCompleted: {
        view.probe();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            view.probe();
            event.accepted = true;
        }
    }

    // ---- probe process ---------------------------------------------------
    Process {
        id: probeProc
        command: [Quickshell.env("HOME") + "/.config/hypr/bin/sensorprobe"]
        stdout: StdioCollector {
            onStreamFinished: {
                view.busy = false;
                try {
                    view.telemetryData = JSON.parse(text);
                } catch (e) {
                    console.warn("SENSORVIEW JSON parse error:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") console.warn("SENSORVIEW stderr:", text);
            }
        }
    }

    function probe(): void {
        if (!probeProc.running) {
            view.busy = true;
            probeProc.running = true;
        }
    }

    // Active polling timer while visible
    Timer {
        interval: 1500
        running: view.visible
        repeat: true
        onTriggered: view.probe()
    }

    function tempColor(t: int): color {
        if (t >= 80) return Theme.alert;
        if (t >= 65) return Theme.warn;
        return Theme.accent;
    }

    function coreFreq(idx: int): string {
        if (!view.telemetryData.cores || idx >= view.telemetryData.cores.length) return "--";
        const mhz = view.telemetryData.cores[idx].freq_mhz || 0;
        return (mhz / 1000).toFixed(2) + " GHz";
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "CPU"
                jp: "核心"
                value: (view.telemetryData.cpu_pkg_temp ? view.telemetryData.cpu_pkg_temp : "--") + "°"
                subValue: "PKG THERMAL"
                tint: view.tempColor(view.telemetryData.cpu_pkg_temp || 0)
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "GPU"
                jp: "画像"
                value: (view.telemetryData.gpu ? view.telemetryData.gpu.temp : "--") + "°"
                subValue: view.telemetryData.gpu ? Math.round(view.telemetryData.gpu.power) + "W" : "GPU CORE"
                tint: view.tempColor(view.telemetryData.gpu ? view.telemetryData.gpu.temp : 0)
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "VRAM"
                jp: "画像記憶"
                value: view.telemetryData.gpu ? Math.round(view.telemetryData.gpu.mem_used * 100 / view.telemetryData.gpu.mem_total) + "%" : "--"
                subValue: view.telemetryData.gpu ? (view.telemetryData.gpu.mem_used / 1024).toFixed(1) + "G USED" : "VRAM"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: view.busy ? "PROBING" : "REFRESH"
                jp: "更新"
                active: view.busy
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.probe()
            }
        }
    }

    // ---- Body ------------------------------------------------------------
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

            // ================= SECTION 1: GPU AVIONICS =================
            Row {
                spacing: 8
                Text {
                    text: "// GPU AVIONICS //"
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkLabel
                    font.weight: Font.Bold
                }
                Text {
                    text: (view.telemetryData.gpu ? view.telemetryData.gpu.name : "NVIDIA GPU").toUpperCase()
                    color: Theme.accent2
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkLabel
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                width: parent.width
                height: 104
                radius: 0
                color: Theme.card
                border.width: 1
                border.color: Theme.edge
                clip: true

                // Top specular catch
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

                Row {
                    anchors.centerIn: parent
                    spacing: 36

                    // Core load
                    Column {
                        spacing: 4
                        Tag { label: "CORE LOAD"; jp: "演算負荷" }
                        Row {
                            spacing: 10
                            Meter {
                                pct: view.telemetryData.gpu ? view.telemetryData.gpu.util : 0
                                segs: 16
                                segWidth: 6
                                segHeight: 12
                                barColor: Theme.accent
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (view.telemetryData.gpu ? view.telemetryData.gpu.util : 0) + "%"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szValue
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    // VRAM
                    Column {
                        spacing: 4
                        Tag { label: "VRAM ALLOC"; jp: "記憶割当" }
                        Row {
                            spacing: 10
                            Meter {
                                pct: view.telemetryData.gpu ? Math.round(view.telemetryData.gpu.mem_used * 100 / view.telemetryData.gpu.mem_total) : 0
                                segs: 16
                                segWidth: 6
                                segHeight: 12
                                barColor: Theme.accent2
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (view.telemetryData.gpu ? (view.telemetryData.gpu.mem_used / 1024).toFixed(1) : 0) + " / " + (view.telemetryData.gpu ? (view.telemetryData.gpu.mem_total / 1024).toFixed(0) : 0) + " GB"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szValue
                            }
                        }
                    }

                    // Clocks & Cooling
                    Column {
                        spacing: 6
                        Row {
                            spacing: 16
                            Cluster {
                                label: "CORE CLK"; jp: "周波数"
                                alwaysOn: true
                                value: view.telemetryData.gpu ? view.telemetryData.gpu.clock_core + " MHz" : "--"
                                valueColor: Theme.text
                            }
                            Cluster {
                                label: "MEM CLK"; jp: "記憶速度"
                                alwaysOn: true
                                value: view.telemetryData.gpu ? view.telemetryData.gpu.clock_mem + " MHz" : "--"
                                valueColor: Theme.dim
                            }
                            Cluster {
                                label: "FAN SPEED"; jp: "送風"
                                alwaysOn: true
                                value: view.telemetryData.gpu ? view.telemetryData.gpu.fan + "%" : "--"
                                valueColor: (view.telemetryData.gpu && view.telemetryData.gpu.fan > 60) ? Theme.warn : Theme.text
                            }
                        }
                    }
                }
            }

            // ================= SECTION 2: CPU CORE MATRIX =================
            Row {
                spacing: 8
                Text {
                    text: "// CPU CORE THERMAL MATRIX //"
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkLabel
                    font.weight: Font.Bold
                }
                Text {
                    text: "PACKAGE: " + (view.telemetryData.cpu_pkg_temp ? view.telemetryData.cpu_pkg_temp + "°C" : "--")
                    color: view.tempColor(view.telemetryData.cpu_pkg_temp || 0)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkLabel
                }
            }

            // Core Grid
            Grid {
                id: coreGrid
                width: parent.width
                // Fewest rows of at most 7, then spread evenly: 14 cores -> 7x2,
                // not 5+5+4.
                readonly property int n: (view.telemetryData.core_temps || []).length
                columns: n > 0 ? Math.ceil(n / Math.ceil(n / 7)) : 1
                spacing: 8

                Repeater {
                    model: view.telemetryData.core_temps || []

                    Rectangle {
                        required property var modelData
                        required property int index

                        width: (coreGrid.width - (coreGrid.columns - 1) * 8) / coreGrid.columns
                        height: 48
                        radius: 0
                        color: Theme.card
                        border.width: 1
                        border.color: Theme.edge

                        // Top specular catch
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            anchors.leftMargin: 1; anchors.rightMargin: 1
                            height: 1
                            color: Theme.accentWash
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Column {
                                spacing: 1
                                Text {
                                    text: modelData.label.toUpperCase()
                                    color: Theme.dim
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.szMicro
                                    font.letterSpacing: Theme.trkLabel
                                }
                                Text {
                                    text: view.coreFreq(index)
                                    color: Theme.dim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.szMicro
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.temp + "°C"
                                color: view.tempColor(modelData.temp)
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szValue
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            // ================= SECTION 3: STORAGE, RAM & BUS =================
            Row {
                spacing: 8
                Text {
                    text: "// STORAGE, RAM & BUS THERMALS //"
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkLabel
                    font.weight: Font.Bold
                }
            }

            Row {
                width: parent.width
                spacing: 12

                // NVMe Drives
                Rectangle {
                    width: (parent.width - 24) / 3
                    height: 72
                    radius: 0
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.edge

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        color: Theme.accentWash
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Tag { label: "NVME STORAGE"; jp: "高速記録" }
                        Row {
                            spacing: 14
                            Repeater {
                                model: view.telemetryData.nvme_temps || []
                                Row {
                                    required property var modelData
                                    required property int index
                                    spacing: 4
                                    Text {
                                        text: "NVME" + index + ":"
                                        color: Theme.dim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szBody
                                    }
                                    Text {
                                        text: modelData + "°C"
                                        color: view.tempColor(modelData)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szBody
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }

                // DDR5 SPD Sensors
                Rectangle {
                    width: (parent.width - 24) / 3
                    height: 72
                    radius: 0
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.edge

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        color: Theme.accentWash
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Tag { label: "DDR5 MEMORY SPD"; jp: "記憶素子" }
                        Row {
                            spacing: 14
                            Repeater {
                                model: view.telemetryData.spd_temps || []
                                Row {
                                    required property var modelData
                                    required property int index
                                    spacing: 4
                                    Text {
                                        text: "DIMM" + index + ":"
                                        color: Theme.dim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szBody
                                    }
                                    Text {
                                        text: modelData + "°C"
                                        color: view.tempColor(modelData)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szBody
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }

                // System RAM & Swap Bar
                Rectangle {
                    width: (parent.width - 24) / 3
                    height: 72
                    radius: 0
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.edge

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        color: Theme.accentWash
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Tag { label: "RAM & SWAP ALLOC"; jp: "主記憶" }
                        Row {
                            spacing: 10
                            Meter {
                                pct: view.telemetryData.memory ? view.telemetryData.memory.pct : 0
                                segs: 10
                                segWidth: 5
                                segHeight: 10
                                barColor: Theme.level(pct)
                            }
                            Text {
                                text: view.telemetryData.memory ? (view.telemetryData.memory.used_mb / 1024).toFixed(1) + " / " + (view.telemetryData.memory.total_mb / 1024).toFixed(0) + " GB" : "--"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szBody
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
}
