import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "CONTAINERS"
    readonly property string panelJp: "容器"
    readonly property string panelHint: "EDGE = SHARED DOCKER NETWORK  •  PULSE = PER-CONTAINER NET I/O DELTA  •  ESC  CLOSE"
    readonly property bool fullBleed: true
    readonly property string placement: "center"

    signal closeRequested()

    property var containers: []      // [{name, image, networks[], state, health}]
    property var stats: ({})         // name -> {cpu, mem, netBytes, activity}
    property string dockerError: ""

    function onActivated(): void {
        view.poll();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            view.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            view.poll();
            event.accepted = true;
        }
    }

    function toBytes(s: string): real {
        const m = /^([\d.]+)\s*([A-Za-z]*)$/.exec(String(s).trim());
        if (!m) return 0;
        const mult = { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12,
                       kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 };
        return parseFloat(m[1]) * (mult[m[2].toLowerCase()] ?? 1);
    }

    function parsePs(text: string): void {
        let out = [];
        for (const line of text.split("\n")) {
            if (!line.trim()) continue;
            try {
                const o = JSON.parse(line);
                out.push({
                    name: o.Names,
                    image: o.Image,
                    state: o.State,
                    health: o.HealthStatus || "",
                    networks: String(o.Networks || "").split(",").map(n => n.trim()).filter(n => n)
                });
            } catch (e) { /* partial line ignore */ }
        }
        out.sort((a, b) => a.name.localeCompare(b.name));
        view.containers = out;
        view.dockerError = "";
    }

    function parseStats(text: string): void {
        let next = {};
        for (const line of text.split("\n")) {
            if (!line.trim()) continue;
            try {
                const o = JSON.parse(line);
                const parts = String(o.NetIO || "0B / 0B").split("/");
                const bytes = view.toBytes(parts[0]) + view.toBytes(parts[1] || "0B");

                const prev = view.stats[o.Name];
                const delta = prev ? Math.max(0, bytes - prev.netBytes) : 0;
                const activity = prev ? Math.min(1, delta / 48000) : 0;

                next[o.Name] = {
                    cpu: o.CPUPerc, mem: o.MemPerc, memUsage: o.MemUsage,
                    netIO: o.NetIO, netBytes: bytes, activity: activity
                };
            } catch (e) { /* ignore */ }
        }
        view.stats = next;
        edges.requestPaint();
    }

    Process {
        id: psProc
        command: ["docker", "ps", "--format", "{{json .}}"]
        stdout: StdioCollector { onStreamFinished: view.parsePs(text) }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) view.dockerError = text.trim().split("\n")[0]
        }
    }

    Process {
        id: statsProc
        command: ["docker", "stats", "--no-stream", "--format", "{{json .}}"]
        stdout: StdioCollector { onStreamFinished: view.parseStats(text) }
    }

    function poll(): void {
        if (!psProc.running) psProc.running = true;
        if (!statsProc.running) statsProc.running = true;
    }

    Timer {
        interval: 2000
        repeat: true
        running: view.visible
        triggeredOnStart: true
        onTriggered: view.poll()
    }

    // Layout
    function nodePos(i: int, n: int, w: real, h: real): var {
        if (n === 1) return { x: w / 2, y: h / 2 };
        const r = Math.min(w, h) * 0.32;
        const a = (i / n) * 2 * Math.PI - Math.PI / 2;
        return { x: w / 2 + r * Math.cos(a), y: h / 2 + r * Math.sin(a) };
    }

    function sharesNetwork(a, b): bool {
        return a.networks.some(n => b.networks.indexOf(n) !== -1);
    }

    function activityOf(name: string): real {
        const s = view.stats[name];
        return s ? s.activity : 0;
    }

    readonly property int networkCount: {
        let seen = {};
        for (const c of view.containers) for (const n of c.networks) seen[n] = true;
        return Object.keys(seen).length;
    }
    readonly property int unhealthy: view.containers.filter(
        c => c.health !== "" && c.health !== "healthy").length
    readonly property real totalActivity: view.containers.reduce(
        (n, c) => n + view.activityOf(c.name), 0)

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "NODES"
                jp: "節点"
                value: ("0" + view.containers.length).slice(-2)
                subValue: "CONTAINERS"
                tint: view.containers.length > 0 ? Theme.accent : Theme.dim
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "NETS"
                jp: "網"
                value: ("0" + view.networkCount).slice(-2)
                subValue: "NETWORKS"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "DEGRADED"
                jp: "不調"
                value: ("0" + view.unhealthy).slice(-2)
                subValue: view.unhealthy > 0 ? "ATTENTION" : "HEALTHY"
                alert: view.unhealthy > 0
                anchors.verticalCenter: parent.verticalCenter
            }
            Btn {
                text: "REFRESH"
                jp: "更新"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.poll()
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Item {
        anchors.fill: parent

        Text {
            anchors.centerIn: parent
            visible: view.containers.length === 0
            text: view.dockerError !== "" ? view.dockerError : "NO RUNNING CONTAINERS"
            color: Theme.dim
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.szBody
            font.letterSpacing: Theme.trkWide
        }

        Item {
            id: graph
            anchors.fill: parent
            anchors.margins: 40

            // Edges canvas
            Canvas {
                id: edges
                anchors.fill: parent
                property real dashOffset: 0

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const n = view.containers.length;
                    if (n < 2) return;

                    for (let i = 0; i < n; i++) {
                        for (let j = i + 1; j < n; j++) {
                            const a = view.containers[i], b = view.containers[j];
                            if (!view.sharesNetwork(a, b)) continue;

                            const pa = view.nodePos(i, n, width, height);
                            const pb = view.nodePos(j, n, width, height);
                            const act = Math.max(view.activityOf(a.name), view.activityOf(b.name));

                            ctx.beginPath();
                            ctx.setLineDash([10, 8]);
                            ctx.lineDashOffset = -edges.dashOffset;
                            ctx.lineWidth = 1 + act * 3;
                            ctx.strokeStyle = Theme.accent;
                            ctx.globalAlpha = 0.22 + act * 0.7;
                            ctx.moveTo(pa.x, pa.y);
                            ctx.lineTo(pb.x, pb.y);
                            ctx.stroke();
                        }
                    }
                }

                NumberAnimation on dashOffset {
                    from: 0; to: 18
                    duration: 900
                    loops: Animation.Infinite
                    running: view.visible
                }
                onDashOffsetChanged: requestPaint()
            }

            // Nodes
            Repeater {
                model: view.containers

                Item {
                    id: node
                    required property var modelData
                    required property int index

                    readonly property var pos: view.nodePos(index, view.containers.length,
                                                            graph.width, graph.height)
                    readonly property real act: view.activityOf(modelData.name)
                    readonly property var st: view.stats[modelData.name] ?? null

                    x: pos.x - width / 2
                    y: pos.y - height / 2
                    width: 230
                    height: 108

                    // Pulse ring
                    Rectangle {
                        anchors.centerIn: box
                        width: box.width + 16
                        height: box.height + 16
                        radius: 0
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.accent
                        opacity: node.act * 0.55
                        scale: 1 + node.act * 0.06
                        Behavior on opacity { NumberAnimation { duration: Theme.morphMs } }
                        Behavior on scale { NumberAnimation { duration: Theme.morphMs; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        id: box
                        anchors.fill: parent
                        radius: 0
                        color: Theme.card
                        border.width: 1
                        border.color: node.act > 0.02
                                      ? Theme.accent
                                      : Theme.edge
                        Behavior on border.color { ColorAnimation { duration: Theme.morphMs } }

                        // Top specular catch
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            anchors.leftMargin: 1; anchors.rightMargin: 1
                            height: 1
                            color: Theme.accentEdge
                        }

                        // Health strip
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            anchors.margins: 4
                            width: 3
                            radius: 0
                            color: node.modelData.health === "healthy"
                                   ? Theme.accent
                                   : Theme.dim
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5

                            Text {
                                width: parent.width
                                text: node.modelData.name
                                color: Theme.text
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szBody
                                font.letterSpacing: Theme.trkLabel
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: node.modelData.image
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szBody
                                opacity: 0.75
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: node.st
                                      ? "cpu " + node.st.cpu + "   mem " + node.st.mem
                                      : "—"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szBody
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: node.st ? "net " + node.st.netIO : ""
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szBody
                                opacity: 0.65
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
