pragma Singleton

// System telemetry, read from one process for the whole desktop.
//
// hypr/bin/sysbus prints a JSON line every couple of seconds; this tails it.
// A singleton so that seven modules reading CPU do not become seven pollers,
// and so the parsing lives in one testable place (`sysbus 1` on a terminal
// shows exactly what arrives here).
//
// Every field defaults to -1 = "no reading yet", which the UI renders as
// "--". A sensor that vanishes must not silently read as zero.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int    cpu:      -1
    property int    mem:      -1
    property real   memgb:    -1
    property int    gpu:      -1
    property int    vram:     -1
    property int    cputemp:  -1
    property int    gputemp:  -1
    property int    nvmetemp: -1
    property int    disk:     -1
    property real   rx:       -1     // bytes/sec
    property real   tx:       -1
    property string host:     ""
    property string kernel:   ""
    property string up:       ""

    // The hottest thing in the box, whatever that currently is. One number
    // for the HUD; the individual sensors stay available for the panel.
    readonly property int temp: Math.max(root.cputemp, root.gputemp)

    function num(v, fallback) {
        return (typeof v === "number" && isFinite(v)) ? v : fallback;
    }

    // Human-readable throughput. Rates, not totals, so the unit changes a lot
    // and the string has to stay short enough not to reflow the cluster.
    function rate(bps) {
        if (bps < 0) return "--";
        if (bps < 1024) return Math.round(bps) + "B";
        if (bps < 1048576) return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + "K";
        return (bps / 1048576).toFixed(bps < 10485760 ? 1 : 0) + "M";
    }

    Process {
        running: true
        command: [Quickshell.env("HOME") + "/.config/hypr/bin/sysbus", "2"]
        stdout: SplitParser {
            onRead: line => {
                let e;
                try { e = JSON.parse(line); } catch (err) { return; }
                root.cpu      = root.num(e.cpu, root.cpu);
                root.mem      = root.num(e.mem, root.mem);
                root.memgb    = root.num(e.memgb, root.memgb);
                // Omitted rather than zeroed when the sensor is gone, so a
                // suspended GPU keeps its last reading instead of flashing 0.
                root.gpu      = root.num(e.gpu, -1);
                root.vram     = root.num(e.vram, -1);
                root.cputemp  = root.num(e.cputemp, -1);
                root.gputemp  = root.num(e.gputemp, -1);
                root.nvmetemp = root.num(e.nvmetemp, -1);
                root.disk     = root.num(e.disk, root.disk);
                root.rx       = root.num(e.rx, -1);
                root.tx       = root.num(e.tx, -1);
                root.host     = e.host || root.host;
                root.kernel   = e.kernel || root.kernel;
                root.up       = e.up || root.up;
            }
        }
    }
}
