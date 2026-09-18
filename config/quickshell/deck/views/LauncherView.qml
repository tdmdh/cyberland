import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick.Effects
import "./common"
import "rank.js" as Rank

// Spotlight: one bar a fifth of the way down the screen that grows into
// grouped results and a preview once you type.
//
// Everything ranks here in QML -- ~100 apps, a dozen windows and ~30 system
// entries take microseconds. Two helpers run outside: qalc, kept running so
// a sum answers in ~0.5ms instead of the 40ms a fresh spawn costs, and
// hypr/bin/fileindex, a resident Go indexer (source in hypr/src/fileindex).
// Ranking lives in rank.js, checked by deck/selftest.sh.
//
// Ctrl+1-4 narrow to Apps, Files, Actions or Clipboard; with nothing typed
// each shows a browse list. Clipboard history appears only there, never
// mixed into ordinary results. ">" runs a shell command.
Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "SPOTLIGHT"
    readonly property string panelJp: "検索"
    readonly property string panelHint: ""
    readonly property int panelWidth: Theme.panelS
    readonly property int panelHeight: -1          // fit content; see deck targetH
    readonly property string placement: "spotlight"
    readonly property bool bare: true
    readonly property bool scrim: false
    property Component headerComponent: null

    // Two heights only, the bar or the bar plus a fixed results area.
    // Sizing to the result count would re-animate the chassis on every key.
    readonly property int barH: 60
    readonly property int resultsH: 420
    implicitHeight: view.barH + (view.results.length > 0 ? 1 + view.resultsH : 0)

    readonly property string searchUrl: "https://duckduckgo.com/?q="

    signal closeRequested()

    property string query: ""
    readonly property string q: view.query.trim().toLowerCase()
    readonly property bool shell: view.query.trim().startsWith(">")
    property var results: []        // flat: section headers and entries
    property int sel: -1
    property string armed: ""       // key of a confirm-twice entry awaiting its second Enter

    // 0 everything, 1 apps, 2 files, 3 actions, 4 clipboard.
    property int scope: 0
    readonly property var scopes: [
        null,
        { label: "APPS",      jp: "応用", short: "Apps",    place: "Search applications" },
        { label: "FILES",     jp: "書類", short: "Files",   place: "Search files" },
        { label: "ACTIONS",   jp: "操作", short: "Actions", place: "Search actions" },
        { label: "CLIPBOARD", jp: "履歴", short: "Clip",    place: "Search clipboard history" }
    ]

    function onActivated(): void {
        if (!qalc.running) qalc.running = true;
        if (!fidx.running) fidx.running = true;
        else fidx.write('{"rescan":true}\n');   // relists only if over a minute old
        view.quietHover(600);       // outlasts the open animation
        view.scope = 0;
        input.text = "";
        view.armed = "";
        input.forceActiveFocus();
    }

    function handleKey(event): void {
        input.forceActiveFocus();
    }

    // Recomputed on a new query, scope or helper answer, never as a live
    // binding: a terminal retitling itself several times a second would
    // otherwise rebuild the list, and reset the selection, while you read it.
    onQueryChanged: {
        view.armed = "";
        if (view.scope === 0 && !view.shell && Rank.looksLikeMath(view.query) && qalc.running)
            qalc.write(view.query.trim() + "\n");
        if ((view.scope === 0 || view.scope === 2) && fidx.running) view.askFiles();
        view.refresh();
    }

    onScopeChanged: {
        view.armed = "";
        if (view.scope === 2 && fidx.running) view.askFiles();
        if (view.scope === 4) view.loadClip();
        view.refresh();
    }

    function setScope(n: int): void {
        view.scope = view.scope === n ? 0 : n;
    }

    onSelChanged: if (view.sel >= 0) list.positionViewAtIndex(view.sel, ListView.Contain)

    // Hover selects only when the pointer really moves. Qt also sends hover
    // moves when rows appear or scroll under a resting pointer, and while the
    // deck's open animation slides and scales them the mapped position drifts
    // a few pixels -- together that picked row 10 of every browse list for a
    // mouse left mid-screen. So: ignore hover until the animation is over,
    // and count only real movement.
    property point pointer: Qt.point(-1, -1)
    property bool pointerSeen: false
    property double hoverQuietUntil: 0

    function quietHover(ms: int): void {
        view.pointerSeen = false;
        view.hoverQuietUntil = Date.now() + ms;
    }

    function hovered(area, mouse, index: int): void {
        const g = area.mapToGlobal(mouse.x, mouse.y);
        const moved = view.pointerSeen
                   && Math.abs(g.x - view.pointer.x) + Math.abs(g.y - view.pointer.y) > 2;
        view.pointer = g;
        view.pointerSeen = true;
        if (!moved || Date.now() < view.hoverQuietUntil) return;
        if (view.sel !== index) {
            view.sel = index;
            view.armed = "";
        }
    }

    // ---- launch history ---------------------------------------------------
    readonly property string histPath: Quickshell.env("HOME") + "/.local/share/hypr/launcher-history.json"
    property var hist: ({})

    FileView {
        id: histFile
        path: view.histPath
        atomicWrites: true
        onLoaded: {
            let v;
            try { v = JSON.parse(text()); } catch (e) { v = {}; }
            view.hist = (v && typeof v === "object") ? v : {};
        }
        onLoadFailed: view.hist = {}
    }

    Component.onCompleted: Quickshell.execDetached(["sh", "-c",
        'mkdir -p "$(dirname "$1")"; [ -f "$1" ] || printf "{}\\n" > "$1"', "sh", view.histPath])

    // ponytail: keys are never pruned. Only launched things get one, so it
    // stays at a few hundred; add pruning if the file ever passes ~100KB.
    function record(key: string): void {
        const h = Object.assign({}, view.hist);
        const e = h[key] || [0, 0];
        h[key] = [e[0] + 1, Date.now()];
        view.hist = h;
        histFile.setText(JSON.stringify(h) + "\n");
    }

    function boost(key: string): real {
        return Rank.boost(view.hist[key], Date.now());
    }

    // ---- calculator ---------------------------------------------------------
    // stdbuf: without line buffering qalc holds each answer until the next
    // line arrives. It echoes "> expr", then the result indented.
    property string calcExpr: ""
    property string calcResult: ""

    Process {
        id: qalc
        command: ["stdbuf", "-oL", "qalc", "-t", "-s", "color 0", "-s", "unicode 0"]
        stdinEnabled: true
        property string echo: ""
        // A query typed before qalc was up would otherwise never be sent.
        onRunningChanged: if (running && Rank.looksLikeMath(view.query)) write(view.query.trim() + "\n")
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("> ")) {
                    qalc.echo = line.slice(2).trim();
                } else if (line.startsWith("  ") && line.trim() !== "") {
                    view.calcExpr = qalc.echo;
                    view.calcResult = line.trim();
                    view.refresh();
                }
            }
        }
    }

    // ---- files --------------------------------------------------------------
    // Replies echo the query, so an answer to an older keystroke is dropped
    // rather than shown under a newer one.
    property string filesQ: ""
    property var filesHits: []

    function askFiles(): void {
        const raw = view.query.trim();
        if (raw.startsWith(">")) return;
        if (raw === "") {
            if (view.scope === 2) fidx.write('{"recent":true,"limit":40}\n');
            return;
        }
        fidx.write(JSON.stringify({ q: raw, limit: view.scope === 2 ? 40 : 8 }) + "\n");
    }

    Process {
        id: fidx
        command: [Quickshell.env("HOME") + "/.config/hypr/bin/fileindex"]
        stdinEnabled: true
        onRunningChanged: if (running) view.askFiles()
        stdout: SplitParser {
            onRead: line => {
                let r;
                try { r = JSON.parse(line); } catch (e) { return; }
                if (r.q !== view.query.trim()) return;
                view.filesQ = r.q;
                view.filesHits = r.hits || [];
                view.refresh();
            }
        }
    }

    // First bytes of the selected text file, for the preview.
    property string headPath: ""
    property string headText: ""

    Process {
        id: headProc
        stdout: StdioCollector { onStreamFinished: view.headText = text }
    }

    function fileUrl(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // ---- clipboard ------------------------------------------------------------
    // cliphist, the same store the Clipboard panel reads. Loaded when the
    // Clipboard scope opens, never searched otherwise.
    property var clipItems: []      // { id, text, low, raw }

    function loadClip(): void {
        clipProc.running = false;
        clipProc.running = true;
    }

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const items = [];
                for (const raw of text.split("\n")) {
                    const tab = raw.indexOf("\t");
                    if (tab < 0) continue;
                    const t = raw.slice(tab + 1);
                    items.push({ id: raw.slice(0, tab), text: t, low: t.toLowerCase(), raw: raw });
                    if (items.length === 300) break;
                }
                view.clipItems = items;
                view.refresh();
            }
        }
    }

    Process {
        id: clipDel
        onExited: view.loadClip()
    }

    function clipDelete(c): void {
        clipDel.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", c.raw];
        clipDel.running = true;
    }

    // Copied images preview by decoding the selected entry to one scratch
    // file; the revision counter defeats Image's cache between entries.
    readonly property string clipImgPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-launcher-clip.img"
    property string clipImgId: ""
    property string clipImage: ""
    property int clipRev: 0

    Process {
        id: clipImg
        onExited: {
            view.clipRev++;
            view.clipImage = "file://" + view.clipImgPath + "?" + view.clipRev;
        }
    }

    onCurrentChanged: {
        const e = view.current;
        if (!e) return;
        if (e.kind === "file" && e.text && e.path !== view.headPath) {
            view.headPath = e.path;
            view.headText = "";
            headProc.running = false;
            headProc.command = ["head", "-c", "1200", "--", e.path];
            headProc.running = true;
        } else if (e.kind === "clip" && e.isImage && e.clipId !== view.clipImgId) {
            view.clipImgId = e.clipId;
            view.clipImage = "";
            clipImg.running = false;
            clipImg.command = ["sh", "-c", 'cliphist decode "$1" > "$2"', "sh", e.clipId, view.clipImgPath];
            clipImg.running = true;
        }
    }

    // ---- sources --------------------------------------------------------------
    // An empty q means browsing: every item, ordered by use.
    function appEntries(q: string): var {
        const out = [];
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            let s = 1;
            if (q !== "") {
                s = Math.max(Rank.match(a.name, q), 0.6 * Rank.match(a.genericName, q));
                for (const k of (a.keywords || [])) s = Math.max(s, 0.5 * Rank.match(k, q));
                if (s <= 0) continue;
            }
            const acts = a.actions || [];
            out.push({
                kind: "app", key: "app:" + a.id, score: s + view.boost("app:" + a.id),
                title: a.name, sub: a.genericName || "", desc: a.comment || "",
                icon: Quickshell.iconPath(a.icon, "application-x-executable"),
                runLabel: "Open", run: () => a.execute(),
                altLabel: acts.length > 0 ? acts[0].name : "",
                alt: acts.length > 0 ? () => acts[0].execute() : null,
                more: acts.slice(1).map(x => x.name)
            });
        }
        return q === "" ? out.sort((x, y) => x.title.localeCompare(y.title)) : out;
    }

    function winEntries(q: string): var {
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const cls = (t.lastIpcObject && t.lastIpcObject.class) || "";
            const de = cls ? DesktopEntries.heuristicLookup(cls) : null;
            const app = de ? de.name : cls;
            const s = Math.max(Rank.match(t.title, q), Rank.match(app, q));
            if (s <= 0) continue;
            const ws = t.workspace ? t.workspace.id : 0;
            const addr = String(t.address).startsWith("0x") ? String(t.address) : "0x" + t.address;
            out.push({
                kind: "window", key: "win:" + cls, score: s + 0.5 * view.boost("win:" + cls),
                title: t.title || app, sub: ws > 0 ? "Workspace " + ("0" + ws).slice(-2) : "Scratchpad",
                desc: app,
                icon: Quickshell.iconPath(de ? de.icon : cls, "application-x-executable"),
                runLabel: "Switch to",
                run: () => Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })'),
                altLabel: "Close window",
                alt: () => Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + addr + '" })')
            });
        }
        return out;
    }

    function fileEntries(): var {
        if (view.filesQ !== view.query.trim()) return [];
        return view.filesHits.map(h => ({
            // -5: at the same tier an app beats a file named like it, as in Spotlight.
            kind: "file", key: "file:" + h.path, score: h.score - 5 + view.boost("file:" + h.path),
            title: h.name, sub: h.dir,
            desc: (h.isDir ? "Folder" : Rank.fileSize(h.size))
                  + (h.mtime > 0 ? "  ·  " + Qt.formatDateTime(new Date(h.mtime * 1000), "d MMM yyyy") : ""),
            icon: Quickshell.iconPath(h.icon, h.generic),
            path: h.path, mime: h.mime, isDir: h.isDir, text: h.text,
            image: !h.isDir && h.mime.startsWith("image/"),
            runLabel: h.isDir ? "Open folder" : "Open",
            run: () => Quickshell.execDetached(h.isDir ? ["nautilus", h.path] : ["xdg-open", h.path]),
            altLabel: "Show in Files",
            alt: () => Quickshell.execDetached(["nautilus", "--select", h.path])
        }));
    }

    // Deck panels open by morphing the deck, so they keep it open.
    readonly property var panels: [
        ["control",   "Control Center",     "preferences-system",               "settings volume wifi bluetooth session"],
        ["music",     "Music",              "audio-x-generic",                  "player mpris now playing"],
        ["spectrum",  "Audio Mixer",        "audio-volume-high",                "spectrum volume sound output device"],
        ["keys",      "Keybinds",           "input-keyboard",                   "shortcuts cheatsheet hotkeys"],
        ["sensor",    "Sensors",            "cpu",                              "temperature hardware gpu fans"],
        ["radar",     "Ports",              "network-server",                   "radar sockets listening"],
        ["palette",   "Wallpaper & Theme",  "preferences-desktop-wallpaper",    "palette colors background effects"],
        ["todo",      "Todo",               "view-task",                        "tasks list"],
        ["clip",      "Clipboard History",  "edit-paste",                       "clip copy paste"],
        ["notify",    "Notifications",      "preferences-desktop-notification", "history alerts"],
        ["agent",     "Agents",             "utilities-terminal",               "claude activity sessions"],
        ["expose",    "Exposé",             "window",                           "workspaces overview"],
        ["nodemap",   "Containers",         "network-workgroup",                "docker nodemap"],
        ["schematic", "Schematic",          "applications-graphics",            "diagram mermaid"],
        ["cyberpad",  "Scratchpad",         "accessories-text-editor",          "cyberpad notes"],
        ["dev",       "Projects",           "folder-development",               "dev ignition code repos"]
    ]

    function sysEntries(q: string): var {
        const wifi = Networking.wifiEnabled;
        const bt = Bluetooth.defaultAdapter;
        const defs = [
            { id: "lock", title: "Lock Screen", icon: "system-lock-screen", kw: "lock",
              run: () => Quickshell.execDetached(["qs", "-c", "lock", "ipc", "call", "lock", "engage"]) },
            { id: "suspend", title: "Suspend", icon: "system-suspend", kw: "sleep", confirm: true,
              run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
            { id: "logout", title: "Log Out", icon: "system-log-out", kw: "exit session", confirm: true,
              run: () => Quickshell.execDetached(["uwsm", "stop"]) },
            { id: "reboot", title: "Restart", icon: "system-reboot", kw: "reboot", confirm: true,
              run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
            { id: "poweroff", title: "Shut Down", icon: "system-shutdown", kw: "power off", confirm: true,
              run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
            { id: "dnd", title: "Do Not Disturb", icon: "notifications-disabled", kw: "dnd quiet focus",
              run: () => Quickshell.execDetached(["qs", "-c", "notify", "ipc", "call", "notify", "dnd"]) },
            { id: "wifi", title: wifi ? "Turn Wi-Fi Off" : "Turn Wi-Fi On", icon: "network-wireless",
              kw: "wifi wireless network", run: () => { Networking.wifiEnabled = !wifi; } },
            { id: "bt", title: bt && bt.enabled ? "Turn Bluetooth Off" : "Turn Bluetooth On",
              icon: "network-bluetooth", kw: "bluetooth", run: () => { if (bt) bt.enabled = !bt.enabled; } }
        ];
        for (const p of view.panels)
            defs.push({ id: p[0], title: p[1], icon: p[2], kw: p[3], panel: true,
                        run: () => Quickshell.execDetached(["qs", "-c", "deck", "ipc", "call", "deck", "open", p[0]]) });

        const out = [];
        for (const d of defs) {
            let s = 1;
            if (q !== "") {
                s = Rank.match(d.title, q);
                for (const k of d.kw.split(" ")) s = Math.max(s, 0.6 * Rank.match(k, q));
                if (s <= 0) continue;
            }
            out.push({
                kind: "system", key: "sys:" + d.id, score: s + view.boost("sys:" + d.id),
                title: d.title, sub: d.panel ? "Panel" : "System",
                desc: d.confirm ? "Asks for a second Enter first." : "",
                icon: Quickshell.iconPath(d.icon, "application-x-executable"),
                runLabel: d.panel ? "Open" : "Run", run: d.run, alt: null, altLabel: "",
                confirm: !!d.confirm, panel: !!d.panel
            });
        }
        return out;
    }

    // Desktop-file actions as results of their own: "private" finds
    // Firefox's New Private Window. Typed queries only -- listed in full
    // they would bury the system actions in a dozen "New Window"s.
    function appActionEntries(q: string): var {
        const out = [];
        if (q === "") return out;
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            for (const act of (a.actions || [])) {
                const s = Math.max(Rank.match(act.name, q), 0.9 * Rank.match(a.name + " " + act.name, q));
                if (s <= 0) continue;
                const key = "act:" + a.id + ":" + act.name;
                out.push({
                    kind: "action", key: key, score: s + view.boost(key),
                    title: act.name, sub: a.name, desc: "An action of " + a.name + ".",
                    icon: Quickshell.iconPath(act.icon || a.icon, "system-run"),
                    runLabel: "Run", run: () => act.execute(), alt: null, altLabel: ""
                });
            }
        }
        return out;
    }

    function actionEntries(q: string): var {
        return view.sysEntries(q).concat(view.appActionEntries(q));
    }

    function clipEntries(q: string): var {
        const out = [];
        for (const c of view.clipItems) {
            if (q !== "" && !c.low.includes(q)) continue;
            // cliphist lists images as "[[ binary data 106 KiB png 462x409 ]]".
            const bin = /^\[\[ binary data (.*) \]\]$/.exec(c.text);
            const img = bin !== null;
            out.push({
                kind: "clip", key: "clip:" + c.id, noRecord: true, score: 0,
                title: img ? "Image  ·  " + bin[1] : c.text.replace(/\s+/g, " ").slice(0, 200),
                sub: img ? "Image" : "", desc: "",
                icon: Quickshell.iconPath(img ? "image-x-generic" : "edit-paste", "edit-paste"),
                clipId: c.id, isImage: img, full: c.text,
                runLabel: "Copy",
                run: () => Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", c.id]),
                altLabel: "Delete", altStays: true, alt: () => view.clipDelete(c)
            });
            if (out.length === 60) break;
        }
        return out;
    }

    function calcEntry(): var {
        const expr = view.query.trim();
        if (!Rank.looksLikeMath(expr) || view.calcExpr !== expr || view.calcResult === "") return null;
        const r = view.calcResult;
        return {
            kind: "calc", key: "calc", noRecord: true, score: 1000, title: "= " + r, sub: expr, desc: "",
            icon: Quickshell.iconPath("accessories-calculator", "application-x-executable"),
            runLabel: "Copy result", run: () => Quickshell.execDetached(["wl-copy", "--", r]),
            alt: null, altLabel: "", result: r
        };
    }

    function webEntry(raw: string): var {
        return {
            kind: "web", key: "web", noRecord: true, score: 0,
            title: "Search the web for “" + raw + "”", sub: "DuckDuckGo", desc: "",
            icon: Quickshell.iconPath("internet-web-browser", "application-x-executable"),
            runLabel: "Search",
            run: () => Quickshell.execDetached(["xdg-open", view.searchUrl + encodeURIComponent(raw)]),
            alt: null, altLabel: ""
        };
    }

    function shellEntry(cmd: string): var {
        return {
            kind: "shell", key: "shell", noRecord: true, score: 0,
            title: cmd, sub: "Command", desc: "Runs in a kitty window that stays open.",
            icon: Quickshell.iconPath("utilities-terminal", "system-run"),
            runLabel: "Run in terminal",
            run: () => Quickshell.execDetached(["kitty", "--hold", "sh", "-c", cmd]),
            altLabel: "Run in background",
            alt: () => Quickshell.execDetached(["sh", "-c", cmd])
        };
    }

    // ---- results ----------------------------------------------------------------
    function refresh(): void {
        // From query, not view.q: this runs inside onQueryChanged, before the
        // q binding is guaranteed to have caught up.
        const raw = view.query.trim();
        const q = raw.toLowerCase();
        const flat = [];
        const section = (label, jp, items) => {
            if (items.length === 0) return;
            flat.push({ header: true, label: label, jp: jp });
            for (const it of items) flat.push(it);
        };
        // V4's sort is not stable, so ties keep their source order explicitly.
        const ranked = (list, n) => {
            list.forEach((e, i) => e.order = i);
            return list.sort((a, b) => (b.score - a.score) || (a.order - b.order)).slice(0, n);
        };

        if (raw.startsWith(">")) {
            const cmd = raw.slice(1).trim();
            if (cmd !== "") section("COMMAND", "命令", [view.shellEntry(cmd)]);
        } else if (view.scope === 4) {
            section("CLIPBOARD", "履歴", view.clipEntries(q));
        } else if (view.scope > 0) {
            const items = view.scope === 1 ? view.appEntries(q)
                        : view.scope === 2 ? view.fileEntries()
                        : view.actionEntries(q);
            const s = view.scopes[view.scope];
            // Browsing files keeps the indexer's newest-first order.
            section(s.label, s.jp, q === "" && view.scope === 2 ? items.slice(0, 40) : ranked(items, 40));
        } else if (q !== "") {
            const secs = [
                { label: "APPLICATIONS", jp: "応用", items: ranked(view.appEntries(q), 5) },
                { label: "WINDOWS",      jp: "窓",   items: ranked(view.winEntries(q), 5) },
                { label: "FILES",        jp: "書類", items: ranked(view.fileEntries(), 5) },
                { label: "ACTIONS",      jp: "操作", items: ranked(view.actionEntries(q), 5) }
            ];
            const calc = view.calcEntry();
            let top = calc;
            if (!top)
                for (const s of secs)
                    for (const it of s.items)
                        if (!top || it.score > top.score) top = it;
            const web = view.webEntry(raw);
            if (!top) {
                // Nothing matched: searching the web is the best answer left.
                section("TOP HIT", "最適", [web]);
            } else {
                section(calc ? "CALCULATOR" : "TOP HIT", calc ? "計算" : "最適", [top]);
                // Once something matches well, hide the scraps: "fir" should not
                // list Advanced Network Configuration for having f, i, r in order.
                const floor = Math.min(45, top.score / 2);
                for (const s of secs)
                    section(s.label, s.jp, s.items.filter(it => it !== top && it.score >= floor));
                section("WEB", "網", [web]);
            }
        }
        view.results = flat;
        view.quietHover(450);       // outlasts the chassis resize (Theme.morphMs)
        view.sel = flat.length > 1 ? 1 : -1;
        list.positionViewAtBeginning();
    }

    readonly property var current: view.sel >= 0 && view.sel < view.results.length ? view.results[view.sel] : null
    readonly property var topHit: view.results.length > 1 ? view.results[1] : null

    // Spotlight's inline completion: the rest of the top hit's name, drawn
    // dim after what you typed. Tab accepts it.
    readonly property string ghost: {
        const t = view.topHit, typed = view.query;
        if (!t || t.kind === "calc" || typed === "" || view.sel !== 1) return "";
        return t.title.toLowerCase().startsWith(typed.toLowerCase()) ? t.title.slice(typed.length) : "";
    }

    function move(dir: int): void {
        let i = view.sel;
        do { i += dir; } while (i >= 0 && i < view.results.length && view.results[i].header);
        if (i >= 0 && i < view.results.length) {
            view.sel = i;
            view.armed = "";
        }
    }

    // Ctrl+Up/Down: first entry of the previous / next section.
    function jump(dir: int): void {
        const r = view.results;
        let h = view.sel;
        while (h >= 0 && !r[h].header) h--;     // this section's header
        let n = h + dir;
        while (n >= 0 && n < r.length && !r[n].header) n += dir;
        if (n >= 0 && n + 1 < r.length && r[n].header) {
            view.sel = n + 1;
            view.armed = "";
        }
    }

    function activate(alt: bool): void {
        const e = view.current;
        if (!e || e.header) return;
        const fn = alt ? e.alt : e.run;
        if (!fn) return;
        if (e.confirm && !alt && view.armed !== e.key) {
            view.armed = e.key;
            return;
        }
        if (!e.noRecord) view.record(e.key);
        fn();
        if (!(e.panel || (alt && e.altStays))) view.closeRequested();
    }

    function key(e): void {
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        if (ctrl && e.key >= Qt.Key_1 && e.key <= Qt.Key_4) { view.setScope(e.key - Qt.Key_0); e.accepted = true; }
        else if (e.key === Qt.Key_Down) { ctrl ? view.jump(1) : view.move(1); e.accepted = true; }
        else if (e.key === Qt.Key_Up) { ctrl ? view.jump(-1) : view.move(-1); e.accepted = true; }
        else if (e.key === Qt.Key_Tab) {
            if (view.ghost !== "") {
                input.text = view.topHit.title;
                input.cursorPosition = input.text.length;
            }
            e.accepted = true;
        }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { view.activate(ctrl); e.accepted = true; }
        else if (e.key === Qt.Key_Escape) {
            // Esc peels one layer at a time: the text, then the scope, then the bar.
            if (input.text !== "") input.text = "";
            else if (view.scope !== 0) view.scope = 0;
            else view.closeRequested();
            e.accepted = true;
        }
    }

    function esc(s: string): string {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // The title with the matched run in the accent, when the match is a run.
    function marked(name: string): string {
        const i = view.q === "" || view.shell ? -1 : name.toLowerCase().indexOf(view.q);
        if (i < 0) return view.esc(name);
        return view.esc(name.slice(0, i))
             + '<font color="' + Theme.accent + '">' + view.esc(name.slice(i, i + view.q.length)) + "</font>"
             + view.esc(name.slice(i + view.q.length));
    }

    // Greyscale icons: colour here only ever reports a problem.
    component MonoIcon: IconImage {
        layer.enabled: true
        layer.effect: MultiEffect { saturation: -1.0 }
    }

    component Hint: Row {
        property string keys
        property string label
        spacing: 12
        Text {
            width: 28
            text: parent.keys
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.szBody
        }
        Text {
            text: parent.label
            color: Theme.text
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.szBody
        }
    }

    // ---- bar --------------------------------------------------------------------
    Item {
        id: bar
        width: parent.width
        height: view.barH

        Text {
            id: glyph
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            text: ""      // magnifier, Nerd Font
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.szLead
        }

        // The active scope, as a chip between the magnifier and the text.
        Rectangle {
            id: chip
            visible: view.scope > 0
            anchors.left: glyph.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: chipTag.implicitWidth + 18
            height: 24
            color: Theme.cardActive
            border.width: 1
            border.color: Theme.accent
            Tag {
                id: chipTag
                anchors.centerIn: parent
                label: view.scope > 0 ? view.scopes[view.scope].label : ""
                jp: view.scope > 0 ? view.scopes[view.scope].jp : ""
            }
        }

        // Scope keys, always on show: nobody finds Ctrl+1-4 otherwise.
        Row {
            id: scopeKeys
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Repeater {
                model: [1, 2, 3, 4]
                Text {
                    required property int modelData
                    text: "^" + modelData + " " + view.scopes[modelData].short
                    color: view.scope === modelData ? Theme.accent : Theme.dim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szMicro
                }
            }
        }

        TextInput {
            id: input
            anchors { left: chip.visible ? chip.right : glyph.right; leftMargin: chip.visible ? 12 : 16
                      right: scopeKeys.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
            focus: true
            clip: true
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: view.shell ? Theme.fontMono : Theme.fontDisplay
            font.pixelSize: Theme.szLead
            onTextChanged: view.query = text
            Keys.onPressed: e => view.key(e)
        }

        Text {
            anchors.left: input.left
            anchors.right: input.right
            anchors.verticalCenter: input.verticalCenter
            visible: input.text === ""
            elide: Text.ElideRight
            text: view.scope > 0 ? view.scopes[view.scope].place
                                 : "Search apps, files, windows and actions — or type 12*19"
            color: Theme.dim
            font: input.font
        }

        Text {
            x: input.x + input.contentWidth
            width: Math.max(0, input.width - input.contentWidth)
            anchors.verticalCenter: input.verticalCenter
            visible: view.ghost !== ""
            elide: Text.ElideRight
            text: view.ghost
            color: Theme.dim
            font: input.font
        }
    }

    Rectangle {
        y: view.barH
        width: parent.width
        height: 1
        color: Theme.line2
        visible: view.results.length > 0
    }

    // ---- results ----------------------------------------------------------------
    Item {
        y: view.barH + 1
        width: parent.width
        height: view.resultsH
        visible: view.results.length > 0

        ListView {
            id: list
            width: parent.width - preview.width - 1
            height: parent.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            topMargin: 6
            bottomMargin: 6
            model: view.results

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: row.index === view.sel

                width: list.width
                height: row.modelData.header ? 28 : 36

                Tag {
                    visible: !!row.modelData.header
                    x: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    label: row.modelData.header ? row.modelData.label : ""
                    jp: row.modelData.header ? row.modelData.jp : ""
                }

                Item {
                    anchors.fill: parent
                    visible: !row.modelData.header

                    // The selected-row treatment used across the deck: a raised
                    // layer and a 2px accent bar.
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        color: row.on ? Theme.layer2 : "transparent"
                    }
                    Rectangle {
                        x: 8
                        width: 2
                        height: parent.height
                        color: row.on ? Theme.accent : "transparent"
                    }

                    MonoIcon {
                        id: rowIcon
                        x: 22
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 20
                        source: row.modelData.header ? "" : row.modelData.icon
                        opacity: row.on ? 1.0 : 0.7
                    }

                    Text {
                        id: rowTitle
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, row.width - x - 150)
                        textFormat: Text.StyledText
                        text: row.modelData.header ? "" : view.marked(row.modelData.title)
                        color: Theme.text
                        font.family: row.modelData.kind === "calc" || row.modelData.kind === "shell"
                                     ? Theme.fontMono : Theme.fontDisplay
                        font.pixelSize: Theme.szValue
                        font.weight: row.on ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: rowTitle.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: row.modelData.header ? ""
                            : (view.armed === row.modelData.key ? "Press ↵ again" : row.modelData.sub)
                        color: view.armed === row.modelData.key ? Theme.warn : Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szBody
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => view.hovered(this, mouse, row.index)
                        onClicked: { view.sel = row.index; view.activate(false); }
                    }
                }
            }
        }

        Rectangle {
            x: list.width
            width: 1
            height: parent.height
            color: Theme.line2
        }

        // ---- preview ------------------------------------------------------------
        Item {
            id: preview
            x: list.width + 1
            width: 300
            height: parent.height
            readonly property var e: view.current

            Column {
                visible: !!preview.e
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: 24; rightMargin: 24; topMargin: 36 }
                spacing: 10

                readonly property bool isClip: !!preview.e && preview.e.kind === "clip"
                readonly property string imageSource:
                    !preview.e ? ""
                    : preview.e.image ? view.fileUrl(preview.e.path)
                    : (isClip && preview.e.isImage) ? view.clipImage : ""
                readonly property string bodyText:
                    !preview.e ? ""
                    : (preview.e.kind === "file" && preview.e.text && view.headPath === preview.e.path) ? view.headText
                    : (isClip && !preview.e.isImage) ? preview.e.full : ""

                MonoIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: parent.imageSource === "" && parent.bodyText === ""
                    implicitSize: 64
                    source: preview.e ? preview.e.icon : ""
                }

                // Pictures keep their colour: here the colour is the content.
                Image {
                    visible: parent.imageSource !== ""
                    width: parent.width
                    height: 150
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    sourceSize.width: 2 * width
                    source: parent.imageSource
                }

                Rectangle {
                    visible: parent.bodyText !== ""
                    width: parent.width
                    height: parent.isClip ? 220 : 150
                    color: Theme.layer1
                    border.width: 1
                    border.color: Theme.line2
                    clip: true
                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: parent.parent.bodyText
                        textFormat: Text.PlainText
                        color: parent.parent.isClip ? Theme.text : Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szMicro
                        wrapMode: parent.parent.isClip ? Text.WrapAnywhere : Text.NoWrap
                        elide: Text.ElideRight
                    }
                }

                Text {
                    width: parent.width
                    visible: !parent.isClip
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: !preview.e ? "" : (preview.e.kind === "calc" ? preview.e.result : preview.e.title)
                    color: Theme.text
                    font.family: preview.e && (preview.e.kind === "calc" || preview.e.kind === "shell")
                                 ? Theme.fontMono : Theme.fontDisplay
                    font.pixelSize: Theme.szLead
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    text: preview.e ? preview.e.sub : ""
                    color: Theme.dim
                    font.family: preview.e && preview.e.kind === "calc" ? Theme.fontMono : Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    text: preview.e ? preview.e.desc : ""
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                }

                Item { width: 1; height: 6 }
                Rectangle { width: parent.width; height: 1; color: Theme.line2 }
                Item { width: 1; height: 2 }

                Hint {
                    keys: preview.e && preview.e.confirm ? "↵↵" : "↵"
                    label: preview.e ? preview.e.runLabel : ""
                }
                Hint {
                    visible: !!preview.e && preview.e.altLabel !== ""
                    keys: "^↵"
                    label: preview.e ? preview.e.altLabel : ""
                }
                Hint {
                    visible: view.ghost !== ""
                    keys: "⇥"
                    label: "Complete"
                }

                Text {
                    width: parent.width
                    visible: !!preview.e && !!preview.e.more && preview.e.more.length > 0
                    wrapMode: Text.Wrap
                    text: preview.e && preview.e.more ? "Also: " + preview.e.more.join(" · ") : ""
                    color: Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szMicro
                }
            }
        }
    }
}
