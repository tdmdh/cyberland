import QtQuick
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "AGENTS"
    readonly property string panelJp: "代理"
    readonly property string panelHint: "ESC CLOSE"
    readonly property int panelWidth: 1080
    readonly property int panelHeight: 580
    readonly property string placement: "center"

    signal closeRequested()

    property double now: Date.now()
    Timer { interval: 500; running: true; repeat: true; onTriggered: view.now = Date.now() }

    property var sessions: []
    readonly property var fileTools: ["Read", "Edit", "Write", "MultiEdit", "NotebookEdit", "apply_patch"]
    readonly property var active: view.sessions.filter(s => s.state !== "IDLE" || view.now - s.last < 2500)

    function tok(n) {
        if (n <= 0) return "--";
        return n >= 1000 ? (n / 1000).toFixed(n < 10000 ? 1 : 0) + "K" : n + "";
    }
    function fmtNum(n) {
        return n >= 1000 ? (n / 1000).toFixed(1) + "k" : "" + n;
    }
    function fmtMs(ms) {
        if (ms <= 0) return "";
        return ms < 1000 ? ms + "ms" : ms < 60000 ? (ms / 1000).toFixed(1) + "s" : Math.round(ms / 60000) + "m";
    }
    function stateColor(s) {
        return s.state === "WAITING" ? Theme.accent2
             : s.state === "RUN"     ? Theme.accent
             : s.state === "THINKING"? Theme.text
             : Theme.dim;
    }

    function ingest(e) {
        const key = e.cli + ":" + e.sess;
        const list = view.sessions.slice();
        let s = list.find(x => x.key === key);

        if (!s) {
            s = { key: key, cli: e.cli, sess: e.sess, cwd: "", proj: "",
                  state: "IDLE", tool: "", arg: "", msg: "", last: 0,
                  started: 0, ctx: 0, out: 0, errs: 0, events: [], files: ({}) };
            list.push(s);
        }

        s.last = e.t || Date.now();
        if (e.cwd) {
            s.cwd = e.cwd;
            s.proj = e.cwd.slice(e.cwd.lastIndexOf("/") + 1);
        }

        switch (e.ev) {
        case "SessionStart":     s.state = "IDLE"; break;
        case "UserPromptSubmit": s.state = "THINKING"; s.msg = ""; break;
        case "PreToolUse":
            s.state = "RUN";
            s.tool = e.tool;
            s.arg = e.arg;
            s.started = s.last;
            break;
        case "PostToolUse":
            s.state = "THINKING";
            if (e.err) s.errs += 1;
            s.events = s.events.concat([{
                tool: e.tool, arg: e.arg, err: !!e.err,
                ms: s.started ? (s.last - s.started) : 0
            }]).slice(-24);
            if (e.arg && view.fileTools.indexOf(e.tool) >= 0) {
                const f = Object.assign({}, s.files);
                f[e.arg] = (f[e.arg] || 0) + 1;
                s.files = f;
            }
            break;
        case "Notification": s.state = "WAITING"; s.msg = e.msg || ""; break;
        case "Stop":       s.state = "IDLE"; s.tool = ""; s.arg = ""; break;
        case "SessionEnd": view.sessions = list.filter(x => x.key !== key); return;
        case "tokens":     s.ctx = e.ctx || 0; s.out = e.out || 0; break;
        }

        view.sessions = list;
    }

    Process {
        running: true
        command: ["tail", "-F", "-n", "0",
                  Quickshell.env("XDG_RUNTIME_DIR") + "/agentbus.jsonl"]
        stdout: SplitParser {
            onRead: line => {
                try { view.ingest(JSON.parse(line)); } catch (err) { }
            }
        }
    }

    // Dynamic Header Component
    property Component headerComponent: Component {
        Row {
            spacing: 16
            DynamicPill {
                label: "ACTIVE"
                jp: "稼働"
                value: view.active.length + "/" + view.sessions.length
                subValue: view.active.length > 0 ? "INFERENCE" : "IDLE"
                tint: view.active.length > 0 ? Theme.accent : Theme.dim
            }
            DynamicPill {
                label: "CONTEXT"
                jp: "文脈"
                value: view.tok(Math.max(0, ...view.sessions.map(x => x.ctx || 0)))
                subValue: "TOKEN WINDOW"
                tint: Theme.laser
            }
            DynamicPill {
                label: "ERRORS"
                jp: "異常"
                value: ("0" + view.sessions.reduce((n, x) => n + (x.errs || 0), 0)).slice(-2)
                subValue: view.sessions.some(x => x.errs > 0) ? "ALERT" : "NOMINAL"
                alert: view.sessions.some(x => x.errs > 0)
            }
        }
    }

    function handleKey(event): void {
        // Agent panel is predominantly read-only observability
    }

    // ---- Content Body ----------------------------------------------------
    Column {
        anchors.fill: parent
        spacing: 20

        Text {
            visible: view.sessions.length === 0
            width: parent.width
            text: "NOTHING ON THE BUS  ·  START AN AGENT SESSION, OR PIPE ANOTHER CLI THROUGH AGENTBUS-PIPE"
            color: Theme.dim
            font.family: Theme.fontDisplay
            font.pixelSize: 11
            font.letterSpacing: 1.6
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: view.sessions.slice(-3)

            Column {
                id: lane
                required property var modelData
                width: parent.width
                spacing: 10

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.line2; opacity: 0.35
                }

                Row {
                    width: parent.width
                    spacing: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 22
                        color: view.stateColor(lane.modelData)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.cli.toUpperCase()
                        color: Theme.text
                        font.family: Theme.fontDisplay
                        font.pixelSize: 13
                        font.letterSpacing: 3
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.proj ? "· " + lane.modelData.proj : ""
                        color: Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                    }
                    Item { height: 1; width: Math.max(10, parent.width - 470) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.errs > 0 ? lane.modelData.errs + " ERR" : ""
                        color: Theme.accent2
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.ctx > 0 ? view.fmtNum(lane.modelData.ctx) + " ctx" : ""
                        color: Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lane.modelData.state
                        color: view.stateColor(lane.modelData)
                        font.family: Theme.fontDisplay
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: {
                        const s = lane.modelData;
                        if (s.state === "WAITING") return "▸ " + (s.msg || "needs attention");
                        if (s.state === "RUN")     return "▸ " + s.tool + "  " + s.arg;
                        return "";
                    }
                    color: view.stateColor(lane.modelData)
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: lane.modelData.events.slice(-5).reverse()

                        Row {
                            required property var modelData
                            width: parent.width
                            spacing: 12

                            Text {
                                width: 96
                                text: modelData.tool
                                color: modelData.err ? Theme.accent2 : Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width - 96 - 72 - 36
                                text: modelData.arg || ""
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                width: 60
                                text: view.fmtMs(modelData.ms)
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }
        }
    }
}
