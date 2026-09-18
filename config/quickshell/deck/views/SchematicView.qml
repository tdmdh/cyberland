import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "./common"

Item {
    id: view
    anchors.fill: parent

    readonly property string panelTitle: "SCHEMATIC"
    readonly property string panelJp: "設計図"
    readonly property string panelHint: "TAB (HOLD): 8-WAY WHEEL  •  1..9: LINK/SELECT  •  E: STYLE  •  L: LABEL  •  SPACE: ROTATE  •  DEL: REMOVE  •  ESC: CLOSE"
    readonly property bool fullBleed: true
    readonly property string placement: "center"

    signal closeRequested()

    property string activeFile: "pipeline.mmd"
    property string rawBuffer: ""
    property string themeMode: "cyberpunk"
    property real zoomLevel: 1.0
    property int renderCounter: 0
    property string renderError: ""
    property bool isRendering: false
    property var tabList: ["pipeline.mmd", "architecture.mmd", "auth_flow.mmd", "fsm_lifecycle.mmd"]
    property bool showCodeDrawer: false

    // ---- Graph State Model -----------------------------------------------
    property string layoutDir: "LR"
    property var nodes: []
    property var edges: []
    property int selectedNodeIndex: -1

    readonly property var badgeKeys: [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"
    ]

    readonly property string vaultDir: Quickshell.env("HOME") + "/.local/share/hypr/schematics"
    readonly property string previewSvg: Quickshell.env("XDG_RUNTIME_DIR") + "/schematic_preview.svg"

    function onActivated(): void {
        view.triggerRender();
        cursorTracker.forceActiveFocus();
    }

    // ---- File Loading & Persistence --------------------------------------
    FileView {
        id: fileStore
        path: view.vaultDir + "/" + view.activeFile
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            const content = text();
            if (content !== view.rawBuffer) {
                view.rawBuffer = content;
                view.parseMermaid(content);
                view.triggerRender();
            }
        }
        onLoadFailed: {
            view.nodes = [
                { id: "Gateway", label: "API Gateway", shape: "box", type: "gateway", badge: "1" },
                { id: "Service", label: "Worker Swarm", shape: "box", type: "service", badge: "2" },
                { id: "Database", label: "PostgreSQL", shape: "cylinder", type: "database", badge: "3" }
            ];
            view.edges = [
                { from: "Gateway", to: "Service", style: "-->", label: "HTTP 200" },
                { from: "Service", to: "Database", style: "-->", label: "SQL" }
            ];
            view.selectedNodeIndex = -1;
            view.serializeAndRender();
        }
    }

    Timer {
        id: debounceTimer
        interval: 160
        repeat: false
        onTriggered: {
            view.saveCurrent();
            view.triggerRender();
        }
    }

    function switchTab(filename) {
        view.saveCurrent();
        view.activeFile = filename;
        fileStore.path = view.vaultDir + "/" + view.activeFile;
        fileStore.reload();
        zoomLevel = 1.0;
        selectedNodeIndex = -1;
    }

    function prevTab() {
        if (view.tabList.length <= 1) return;
        const idx = view.tabList.indexOf(view.activeFile);
        const nextIdx = (idx - 1 + view.tabList.length) % view.tabList.length;
        view.switchTab(view.tabList[nextIdx]);
    }

    function nextTab() {
        if (view.tabList.length <= 1) return;
        const idx = view.tabList.indexOf(view.activeFile);
        const nextIdx = (idx + 1) % view.tabList.length;
        view.switchTab(view.tabList[nextIdx]);
    }

    function saveCurrent() {
        if (view.rawBuffer) {
            fileStore.setText(view.rawBuffer);
        }
    }

    function triggerRender() {
        view.isRendering = true;
        renderProc.running = true;
    }

    Process {
        id: renderProc
        command: [
            Quickshell.env("HOME") + "/.config/hypr/bin/schematic-render",
            view.vaultDir + "/" + view.activeFile,
            view.previewSvg,
            view.themeMode
        ]
        onExited: exitCode => {
            view.isRendering = false;
            if (exitCode === 0) {
                view.renderError = "";
                view.renderCounter++;
            } else {
                view.renderError = "Syntax Error // Check node connections or bracket tags";
            }
        }
    }

    function toggleTheme() {
        view.themeMode = view.themeMode === "cyberpunk" ? "whitepaper" : "cyberpunk";
        view.triggerRender();
    }

    function copySvg() {
        Quickshell.execDetached(["sh", "-c", "cat \"$1\" | wl-copy --type image/svg+xml && notify-send -a 'SCHEMATIC' 'SVG COPIED' 'Vector diagram copied to clipboard'", "sh", view.previewSvg]);
    }

    function copyPng() {
        Quickshell.execDetached(["sh", "-c", "rsvg-convert -d 300 -p 300 \"$1\" | wl-copy --type image/png && notify-send -a 'SCHEMATIC' 'PNG COPIED' 'High-res 300 DPI diagram copied to clipboard'", "sh", view.previewSvg]);
    }

    function createNewTab() {
        const name = "sketch_" + Date.now().toString().slice(-4) + ".mmd";
        const newPath = view.vaultDir + "/" + name;
        Quickshell.execDetached(["sh", "-c", "printf 'flowchart LR\\n    A[Client] --> B[Service]\\n' > \"$1\"", "sh", newPath]);
        view.tabList.push(name);
        view.switchTab(name);
    }

    // ---- Graph Serialization & Parser Engine -----------------------------
    function formatNodeToken(node) {
        const id = node.id;
        const label = node.label || id;
        if (node.shape === "cylinder") {
            return id + "[(" + label + ")]";
        } else if (node.shape === "diamond") {
            return id + "{" + label + "}";
        } else if (node.shape === "box3d") {
            return id + "[[" + label + "]]";
        } else if (node.shape === "oval") {
            return id + "([" + label + "])";
        } else {
            return id + "[" + label + "]";
        }
    }

    function serializeMermaid() {
        let out = "flowchart " + view.layoutDir + "\n";
        const referenced = {};
        const declared = {};

        for (const e of view.edges) {
            const srcNode = view.nodes.find(n => n.id === e.from) || { id: e.from, label: e.from, shape: "box" };
            const dstNode = view.nodes.find(n => n.id === e.to) || { id: e.to, label: e.to, shape: "box" };

            referenced[srcNode.id] = true;
            referenced[dstNode.id] = true;

            const srcFmt = declared[srcNode.id] ? srcNode.id : view.formatNodeToken(srcNode);
            declared[srcNode.id] = true;

            const dstFmt = declared[dstNode.id] ? dstNode.id : view.formatNodeToken(dstNode);
            declared[dstNode.id] = true;

            const lbl = e.label ? ("|" + e.label + "| ") : "";
            out += "    " + srcFmt + " " + (e.style || "-->") + lbl + dstFmt + "\n";
        }

        for (const n of view.nodes) {
            if (!referenced[n.id]) {
                out += "    " + view.formatNodeToken(n) + "\n";
            }
        }
        return out;
    }

    function serializeAndRender() {
        view.rawBuffer = view.serializeMermaid();
        debounceTimer.restart();
    }

    function parseMermaid(text) {
        const lines = text.split("\n");
        let dir = "LR";
        const foundNodes = {};
        const foundEdges = [];

        function extractNode(str) {
            str = str.trim();
            let m = str.match(/^([a-zA-Z0-9_\-]+)\s*\[\(([^\)]+)\)\]$/);
            if (m) return { id: m[1], label: m[2], shape: "cylinder", type: m[2].toLowerCase().includes("cache") ? "cache" : "database" };
            m = str.match(/^([a-zA-Z0-9_\-]+)\s*\(\[([^\]]+)\]\)$/);
            if (m) return { id: m[1], label: m[2], shape: "oval", type: "client" };
            m = str.match(/^([a-zA-Z0-9_\-]+)\s*\[\[([^\]]+)\]\]$/);
            if (m) return { id: m[1], label: m[2], shape: "box3d", type: "queue" };
            m = str.match(/^([a-zA-Z0-9_\-]+)\s*\{([^}]+)\}$/);
            if (m) return { id: m[1], label: m[2], shape: "diamond", type: "decision" };
            m = str.match(/^([a-zA-Z0-9_\-]+)\s*\[([^\]]+)\]$/);
            if (m) return { id: m[1], label: m[2], shape: "box", type: m[2].toLowerCase().includes("api") ? "gateway" : "service" };
            m = str.match(/^([a-zA-Z0-9_\-]+)$/);
            if (m) return { id: m[1], label: m[1], shape: "box", type: "service" };
            return null;
        }

        for (let l of lines) {
            l = l.trim();
            if (!l || l.startsWith("%%")) continue;
            if (l.startsWith("flowchart") || l.startsWith("graph")) {
                const parts = l.split(/\s+/);
                if (parts[1]) dir = parts[1].toUpperCase();
                continue;
            }

            const edgeMatch = l.match(/^(.*?)\s*(-->|-\.->|==>)\s*(?:\|([^|]+)\|\s*)?(.*)$/);
            if (edgeMatch) {
                const srcRaw = edgeMatch[1];
                const style = edgeMatch[2];
                const lbl = edgeMatch[3] || "";
                const dstRaw = edgeMatch[4];

                const srcNode = extractNode(srcRaw);
                const dstNode = extractNode(dstRaw);

                if (srcNode) {
                    if (!foundNodes[srcNode.id]) foundNodes[srcNode.id] = srcNode;
                    else if (srcNode.label !== srcNode.id) foundNodes[srcNode.id].label = srcNode.label;
                }
                if (dstNode) {
                    if (!foundNodes[dstNode.id]) foundNodes[dstNode.id] = dstNode;
                    else if (dstNode.label !== dstNode.id) foundNodes[dstNode.id].label = dstNode.label;
                }

                if (srcNode && dstNode) {
                    foundEdges.push({ from: srcNode.id, to: dstNode.id, style: style, label: lbl });
                }
            } else {
                const standalone = extractNode(l);
                if (standalone && !foundNodes[standalone.id]) {
                    foundNodes[standalone.id] = standalone;
                }
            }
        }

        view.layoutDir = dir;
        const nodeList = Object.values(foundNodes);
        for (let i = 0; i < nodeList.length; i++) {
            nodeList[i].badge = view.badgeKeys[i] || ("" + (i + 1));
        }
        view.nodes = nodeList;
        view.edges = foundEdges;
    }

    function selectOrLinkNode(idx) {
        if (idx < 0 || idx >= view.nodes.length) return;

        if (view.selectedNodeIndex === -1) {
            view.selectedNodeIndex = idx;
        } else if (view.selectedNodeIndex === idx) {
            view.selectedNodeIndex = -1;
        } else {
            const idA = view.nodes[view.selectedNodeIndex].id;
            const idB = view.nodes[idx].id;

            const existingIdx = view.edges.findIndex(e => (e.from === idA && e.to === idB));
            if (existingIdx !== -1) {
                view.edges.splice(existingIdx, 1);
            } else {
                const revIdx = view.edges.findIndex(e => (e.from === idB && e.to === idA));
                if (revIdx !== -1) {
                    view.edges.splice(revIdx, 1);
                } else {
                    view.edges.push({ from: idA, to: idB, style: "-->", label: "" });
                }
            }
            view.selectedNodeIndex = idx;
            view.serializeAndRender();
        }
    }

    function selectNodeByBadge(badgeChar) {
        const idx = view.nodes.findIndex(n => n.badge.toUpperCase() === badgeChar.toUpperCase());
        if (idx !== -1) {
            view.selectOrLinkNode(idx);
        }
    }

    function cycleEdgeStyle() {
        if (view.selectedNodeIndex < 0 || view.selectedNodeIndex >= view.nodes.length) return;
        const curId = view.nodes[view.selectedNodeIndex].id;
        for (let i = 0; i < view.edges.length; i++) {
            if (view.edges[i].from === curId || view.edges[i].to === curId) {
                const s = view.edges[i].style;
                if (s === "-->") view.edges[i].style = "-.->";
                else if (s === "-.->") view.edges[i].style = "==>";
                else view.edges[i].style = "-->";
                view.serializeAndRender();
                return;
            }
        }
    }

    function cycleEdgeLabel() {
        if (view.selectedNodeIndex < 0 || view.selectedNodeIndex >= view.nodes.length) return;
        const curId = view.nodes[view.selectedNodeIndex].id;
        const labels = ["", "HTTP", "gRPC", "Queue", "SQL", "Sync"];
        for (let i = 0; i < view.edges.length; i++) {
            if (view.edges[i].from === curId || view.edges[i].to === curId) {
                const cur = labels.indexOf(view.edges[i].label || "");
                const next = (cur + 1) % labels.length;
                view.edges[i].label = labels[next];
                view.serializeAndRender();
                return;
            }
        }
    }

    function rotateLayout() {
        view.layoutDir = view.layoutDir === "LR" ? "TD" : "LR";
        view.serializeAndRender();
    }

    function deleteSelectedNode() {
        if (view.selectedNodeIndex < 0 || view.selectedNodeIndex >= view.nodes.length) return;
        const doomedId = view.nodes[view.selectedNodeIndex].id;
        view.edges = view.edges.filter(e => e.from !== doomedId && e.to !== doomedId);
        view.nodes.splice(view.selectedNodeIndex, 1);
        for (let i = 0; i < view.nodes.length; i++) {
            view.nodes[i].badge = view.badgeKeys[i] || ("" + (i + 1));
        }
        view.selectedNodeIndex = -1;
        view.serializeAndRender();
    }

    function spawnComponentFromPreset(presetIndex) {
        const p = radialHUD.presets[presetIndex];
        if (!p) return;

        const count = view.nodes.filter(n => n.type === p.type).length + 1;
        const id = p.type.charAt(0).toUpperCase() + p.type.slice(1) + "_" + count;
        const label = p.label + (count > 1 ? (" #" + count) : "");
        const badge = view.badgeKeys[view.nodes.length] || ("" + (view.nodes.length + 1));

        const newNode = {
            id: id,
            label: label,
            shape: p.shape,
            type: p.type,
            badge: badge
        };

        view.nodes.push(newNode);

        if (view.selectedNodeIndex >= 0 && view.selectedNodeIndex < view.nodes.length - 1) {
            const srcId = view.nodes[view.selectedNodeIndex].id;
            view.edges.push({ from: srcId, to: id, style: "-->", label: "" });
        }

        view.selectedNodeIndex = view.nodes.length - 1;
        view.serializeAndRender();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Tab && !event.isAutoRepeat) {
            radialHUD.centerX = Math.max(160, Math.min(view.width - 160, cursorTracker.mouseX));
            radialHUD.centerY = Math.max(160, Math.min(view.height - 160, cursorTracker.mouseY));
            radialHUD.active = true;
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Escape) {
            if (radialHUD.active) {
                radialHUD.active = false;
            } else if (view.showCodeDrawer) {
                view.showCodeDrawer = false;
            } else {
                view.closeRequested();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_C && !(event.modifiers & Qt.ControlModifier)) {
            view.showCodeDrawer = !view.showCodeDrawer;
            event.accepted = true;
        } else if (event.key === Qt.Key_E && !(event.modifiers & Qt.ControlModifier)) {
            view.cycleEdgeStyle();
            event.accepted = true;
        } else if (event.key === Qt.Key_L && !(event.modifiers & Qt.ControlModifier)) {
            view.cycleEdgeLabel();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Space || event.key === Qt.Key_R) && !(event.modifiers & Qt.ControlModifier)) {
            view.rotateLayout();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            view.deleteSelectedNode();
            event.accepted = true;
        } else if (event.key === Qt.Key_BracketLeft) {
            view.prevTab();
            event.accepted = true;
        } else if (event.key === Qt.Key_BracketRight) {
            view.nextTab();
            event.accepted = true;
        } else if (event.key === Qt.Key_T && !(event.modifiers & Qt.ControlModifier)) {
            view.toggleTheme();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_C) {
            view.copyPng();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
            view.copySvg();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
            view.saveCurrent();
            view.triggerRender();
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_T) {
            view.createNewTab();
            event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            view.zoomLevel = Math.min(3.5, view.zoomLevel + 0.15);
            event.accepted = true;
        } else if (event.key === Qt.Key_Minus) {
            view.zoomLevel = Math.max(0.3, view.zoomLevel - 0.15);
            event.accepted = true;
        } else if (event.key === Qt.Key_0) {
            view.zoomLevel = 1.0;
            event.accepted = true;
        } else if (event.text && event.text.length === 1) {
            const ch = event.text.toUpperCase();
            if (view.badgeKeys.indexOf(ch) !== -1) {
                view.selectNodeByBadge(ch);
                event.accepted = true;
            }
        }
    }

    // ---- Header Component ------------------------------------------------
    property Component headerComponent: Component {
        Row {
            spacing: 8
            DynamicPill {
                label: "ACTIVE"
                jp: "図面"
                value: view.activeFile.replace(".mmd", "").toUpperCase()
                subValue: "SCHEMATIC"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            DynamicPill {
                label: "FLOW"
                jp: "方向"
                value: view.layoutDir === "LR" ? "LR ➔" : "TD 🠓"
                subValue: "TOPOLOGY"
                tint: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: view.tabList
                    Btn {
                        required property string modelData
                        text: modelData.replace(".mmd", "")
                        active: view.activeFile === modelData
                        tint: Theme.accent
                        implicitHeight: 22
                        onClicked: view.switchTab(modelData)
                    }
                }

                Btn {
                    text: "+ NEW"
                    jp: "作成"
                    tint: Theme.accent
                    implicitHeight: 22
                    onClicked: view.createNewTab()
                }
            }

            Btn {
                text: view.themeMode === "cyberpunk" ? "CYBERPUNK" : "WHITEPAPER"
                jp: "外観"
                active: view.themeMode === "cyberpunk"
                tint: Theme.accent
                implicitHeight: 22
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.toggleTheme()
            }
            Btn {
                text: "COPY SVG"
                jp: "複製"
                tint: Theme.accent
                implicitHeight: 22
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.copySvg()
            }
            Btn {
                text: "COPY PNG"
                jp: "高画質"
                tint: Theme.accent
                implicitHeight: 22
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.copyPng()
            }
            Btn {
                text: "[C] SYNTAX"
                jp: "文法"
                active: view.showCodeDrawer
                tint: Theme.accent2
                implicitHeight: 22
                anchors.verticalCenter: parent.verticalCenter
                onClicked: view.showCodeDrawer = !view.showCodeDrawer
            }
        }
    }

    // ---- Body ------------------------------------------------------------
    Item {
        anchors.fill: parent

        MouseArea {
            id: cursorTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: {
                if (radialHUD.active) {
                    radialHUD.updateFromMouse(mouseX, mouseY);
                }
            }
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Tab && radialHUD.active) {
                    radialHUD.commit();
                    event.accepted = true;
                }
            }
        }

        // Fullscreen Vector Stage
        ChamferBox {
            id: canvasStage
            anchors.fill: parent
            cut: 8
            strokeColor: view.renderError ? Theme.alert : Theme.line
            fillColor: view.themeMode === "cyberpunk" ? Theme.layer2 : "#ffffff"
            reticles: true
            notch: true
            notchColor: view.renderError ? Theme.alert : (view.isRendering ? Theme.warn : Theme.accent)

            Flickable {
                id: canvasFlick
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentWidth: Math.max(width, diagramImg.width * view.zoomLevel + 200)
                contentHeight: Math.max(height, diagramImg.height * view.zoomLevel + 200)

                MouseArea {
                    anchors.fill: parent
                    onClicked: view.selectedNodeIndex = -1
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) {
                            view.zoomLevel = Math.min(3.5, view.zoomLevel + 0.12);
                        } else {
                            view.zoomLevel = Math.max(0.3, view.zoomLevel - 0.12);
                        }
                    }
                }

                Item {
                    width: Math.max(canvasFlick.width, diagramImg.width * view.zoomLevel + 100)
                    height: Math.max(canvasFlick.height, diagramImg.height * view.zoomLevel + 100)

                    Image {
                        id: diagramImg
                        anchors.centerIn: parent
                        source: "file://" + view.previewSvg + "?" + view.renderCounter
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        scale: view.zoomLevel
                        transformOrigin: Item.Center

                        Behavior on scale {
                            NumberAnimation { duration: Theme.easeFastMs; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            // Canvas Top Status & Zoom Bar
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CANVAS ZOOM:"
                        color: Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szMicro
                        font.letterSpacing: Theme.trkLabel
                        font.weight: Font.Bold
                    }

                    Btn {
                        text: "−"
                        implicitWidth: 26; implicitHeight: 22
                        onClicked: view.zoomLevel = Math.max(0.3, view.zoomLevel - 0.15)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(view.zoomLevel * 100) + "%"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.szMicro
                        width: 38
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Btn {
                        text: "+"
                        implicitWidth: 26; implicitHeight: 22
                        onClicked: view.zoomLevel = Math.min(3.5, view.zoomLevel + 0.15)
                    }
                    Btn {
                        text: "⌖ 100%"
                        implicitHeight: 22
                        onClicked: { view.zoomLevel = 1.0; canvasFlick.contentX = 0; canvasFlick.contentY = 0; }
                    }
                }

                // Compiler Status Telemetry
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 6; height: 6; radius: 0
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.renderError ? Theme.alert : (view.isRendering ? Theme.warn : Theme.accent)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.renderError ? "SYNTAX FAULT" : (view.isRendering ? "COMPILING..." : "RENDER ONLINE")
                        color: view.renderError ? Theme.alert : (view.isRendering ? Theme.warn : Theme.accent)
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szMicro
                        font.letterSpacing: Theme.trkLabel
                        font.weight: Font.Bold
                    }
                }
            }

            // Render Error Notification Banner
            Rectangle {
                visible: view.renderError !== ""
                anchors.top: parent.top
                anchors.topMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(600, parent.width - 40)
                height: 28
                color: Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.25)
                border.color: Theme.alert

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "⚠ " + view.renderError
                        color: Theme.alert
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szMicro
                        font.letterSpacing: Theme.trkLabel
                        font.weight: Font.Bold
                    }
                }
            }

            // Holographic Hotkey Badges & Node Control Matrix Bar
            Item {
                id: nodeMatrixBar
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                height: 72

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.90)
                    border.width: 1
                    border.color: view.selectedNodeIndex >= 0 ? Theme.accent : Theme.line
                    opacity: 0.96

                    Behavior on border.color { ColorAnimation { duration: Theme.easeMs } }

                    Bracket { corner: "tl"; anchors.left: parent.left; anchors.top: parent.top; visible: view.selectedNodeIndex >= 0 }
                    Bracket { corner: "tr"; anchors.right: parent.right; anchors.top: parent.top; visible: view.selectedNodeIndex >= 0 }
                }

                Item {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    height: 14

                    Row {
                        anchors.left: parent.left
                        spacing: 10

                        Text {
                            text: "GRAPH TOPOLOGY: " + view.nodes.length + " NODES // " + view.edges.length + " EDGES"
                            color: Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                            font.letterSpacing: Theme.trkLabel
                        }

                        Text {
                            text: view.selectedNodeIndex >= 0
                                ? ("SOURCE: [" + view.nodes[view.selectedNodeIndex].badge + "] " + view.nodes[view.selectedNodeIndex].label + " ➔ SELECT TARGET (1..9 OR CLICK)")
                                : "HOLD TAB TO PLACE COMPONENT // PRESS 1..9 OR CLICK TO SELECT SOURCE"
                            color: view.selectedNodeIndex >= 0 ? Theme.accent : Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szMicro
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trkLabel
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 6
                        visible: view.selectedNodeIndex >= 0

                        Btn {
                            text: "STYLE [E]"
                            implicitHeight: 18
                            tint: Theme.accent2
                            onClicked: view.cycleEdgeStyle()
                        }
                        Btn {
                            text: "LABEL [L]"
                            implicitHeight: 18
                            tint: Theme.accent
                            onClicked: view.cycleEdgeLabel()
                        }
                        Btn {
                            text: "ROTATE [SPACE]"
                            implicitHeight: 18
                            tint: Theme.accent
                            onClicked: view.rotateLayout()
                        }
                        Btn {
                            text: "DEL [DEL]"
                            implicitHeight: 18
                            tint: Theme.alert
                            onClicked: view.deleteSelectedNode()
                        }
                    }
                }

                Flickable {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    height: 44
                    contentWidth: nodeRow.implicitWidth + 20
                    clip: true

                    Row {
                        id: nodeRow
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: view.nodes

                            Item {
                                id: chip
                                required property var modelData
                                required property int index

                                readonly property bool isSelected: view.selectedNodeIndex === chip.index

                                width: chipContent.implicitWidth + 24
                                height: 36

                                Rectangle {
                                    anchors.fill: parent
                                    color: chip.isSelected
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
                                        : Theme.layer1
                                    border.width: chip.isSelected ? 2 : 1
                                    border.color: chip.isSelected ? Theme.accent : Theme.line2

                                    Behavior on color { ColorAnimation { duration: Theme.easeFastMs } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.easeFastMs } }

                                    Row {
                                        id: chipContent
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            width: 18; height: 18
                                            radius: 0
                                            color: chip.isSelected ? Theme.accent : Theme.layer3
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: chip.modelData.badge
                                                color: chip.isSelected ? Theme.onAccent : Theme.accent
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.szMicro
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: chip.modelData.shape === "cylinder" ? "[(DB)]"
                                                : chip.modelData.shape === "diamond" ? "{DEC}"
                                                : chip.modelData.shape === "box3d" ? "[[Q]]"
                                                : chip.modelData.shape === "oval" ? "([APP])"
                                                : "[SVC]"
                                            color: Theme.dim
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.szMicro
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: chip.modelData.label
                                            color: chip.isSelected ? Theme.text : Theme.dim
                                            font.family: Theme.fontDisplay
                                            font.pixelSize: Theme.szBody
                                            font.weight: chip.isSelected ? Font.Bold : Font.Normal
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: view.selectOrLinkNode(chip.index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Radial HUD Wheel
        SchematicRadial {
            id: radialHUD
            onSectorSelected: sectorIdx => {
                view.spawnComponentFromPreset(sectorIdx);
                radialHUD.active = false;
                cursorTracker.forceActiveFocus();
            }
            onCanceled: {
                radialHUD.active = false;
                cursorTracker.forceActiveFocus();
            }
        }

        // Mermaid Syntax Peek Drawer
        Item {
            id: codeDrawer
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 440
            visible: x < parent.width

            x: view.showCodeDrawer ? (parent.width - width) : parent.width
            Behavior on x { NumberAnimation { duration: Theme.easeMs; easing.type: Easing.OutCubic } }

            ChamferBox {
                anchors.fill: parent
                cut: 8
                strokeColor: Theme.accent2
                fillColor: Qt.rgba(Theme.layer1.r, Theme.layer1.g, Theme.layer1.b, 0.98)
                reticles: true
                notch: true
                notchColor: Theme.accent2

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 26

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "// MERMAID SYNTAX //"
                                color: Theme.accent2
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szBody
                                font.letterSpacing: Theme.trkLabel
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "文法"
                                color: Theme.dim
                                font.pixelSize: Theme.szBody
                            }
                        }

                        Btn {
                            anchors.right: parent.right
                            text: "✕ CLOSE"
                            implicitHeight: 22
                            tint: Theme.alert
                            onClicked: view.showCodeDrawer = false
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 14

                        Text {
                            text: "LINES: " + view.rawBuffer.split("\n").length
                            color: Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                        }
                        Text {
                            text: "NODES: " + view.nodes.length
                            color: Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                        }
                        Text {
                            text: "EDGES: " + view.edges.length
                            color: Theme.dim
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szMicro
                        }
                    }

                    ChamferBox {
                        width: parent.width
                        height: parent.height - 96
                        cut: 6
                        strokeColor: Theme.line2
                        fillColor: Theme.bg

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 10
                            contentWidth: Math.max(width, codeEdit.implicitWidth)
                            contentHeight: Math.max(height, codeEdit.implicitHeight)
                            clip: true

                            TextEdit {
                                id: codeEdit
                                width: 380
                                text: view.rawBuffer
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szBody
                                font.letterSpacing: Theme.trkTight
                                selectByMouse: true
                                selectionColor: Theme.accent2
                                readOnly: true
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Btn {
                            text: "COPY CODE"
                            jp: "文面複製"
                            tint: Theme.accent2
                            onClicked: {
                                Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy && notify-send -a 'SCHEMATIC' 'CODE COPIED' 'Mermaid syntax copied to clipboard'", "sh", view.rawBuffer]);
                            }
                        }

                        Btn {
                            text: "FORCE RECOMPILE"
                            jp: "再描画"
                            tint: Theme.accent
                            onClicked: view.triggerRender()
                        }
                    }
                }
            }
        }
    }
}
