//@ pragma IconTheme breeze-dark
// Unified Modal Deck Host: Apple x Cyberpunk Floating Neural-Glass Morphism Deck.
//
// Consolidates floating modal panels into a single, high-performance Quickshell daemon
// with a persistent glass chassis that glides and resizes between views
// (Easing.OutCubic; bounce is reserved for the island).
//
// Panels are the views/ files; bin/qs-panel lists the ids. Each is Theme.panelS,
// Theme.panelM or fullBleed wide, centred (notify sits right), and either a
// fixed panelHeight or -1 to fit its content.
//
// IPC Interface:
//   qs -c deck ipc call deck toggle <panelName>
//   qs -c deck ipc call deck open <panelName>
//   qs -c deck ipc call deck close

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./common"
import "./views"

ShellRoot {
    id: root

    // ---- State & Navigation ----------------------------------------------
    property string activePanelId: ""
    property string previousPanelId: ""
    property bool isOpen: false
    property var activeView: null

    // Cache of instantiated view items for instant <1ms zero-latency morphing
    property var viewCache: ({})

    function getView(id: string): Item {
        if (root.viewCache[id]) return root.viewCache[id];
        return null;
    }

    function restoreFocus(): void {
        keyCatch.forceActiveFocus();
        const item = root.getView(root.activePanelId);
        if (item && typeof item.onActivated === "function") {
            item.onActivated();
        }
    }

    function openDeck(id: string): void {
        const targetId = id || "control";
        root.previousPanelId = "";
        root.activePanelId = targetId;

        // Ensure target loader is active
        root.ensureLoader(targetId);

        // Calculate initial launch coordinates
        const item = root.getView(targetId);
        root.activeView = item;

        let sx = 0;
        let sy = 24;
        const place = item ? item.placement : "center";
        if (place === "top") sy = -40;
        else if (place === "bottom") sy = 40;
        else if (place === "spotlight") sy = -12;

        chassis.scale = 0.965;
        chassis.opacity = 0.0;
        scrimRect.opacity = 0.0;

        win.visible = true;
        root.isOpen = true;

        openAnim.fromY = root.targetY + sy;
        openAnim.toY = root.targetY;
        openAnim.restart();

        if (titleGlitch) titleGlitch.trigger();
        root.restoreFocus();
        Qt.callLater(root.restoreFocus);
    }

    function morphTo(id: string): void {
        if (root.activePanelId === id) return;

        root.previousPanelId = root.activePanelId;
        root.activePanelId = id;

        root.ensureLoader(id);
        const item = root.getView(id);
        root.activeView = item;
        scrimRect.opacity = root.targetScrim;

        // Crossfade content smoothly
        crossfadeAnim.restart();

        if (titleGlitch) titleGlitch.trigger();
        root.restoreFocus();
        Qt.callLater(root.restoreFocus);
    }

    function closeDeck(): void {
        if (!root.isOpen) return;
        closeAnim.restart();
    }

    function ensureLoader(id: string): void {
        if (id === "control") loaderControl.active = true;
        else if (id === "music") loaderMusic.active = true;
        else if (id === "cyberpad") loaderCyberpad.active = true;
        else if (id === "keys") loaderKeys.active = true;
        else if (id === "agent") loaderAgent.active = true;
        else if (id === "clip") loaderClip.active = true;
        else if (id === "todo") loaderTodo.active = true;
        else if (id === "sensor") loaderSensor.active = true;
        else if (id === "radar") loaderRadar.active = true;
        else if (id === "dev") loaderDev.active = true;
        else if (id === "nodemap") loaderNodemap.active = true;
        else if (id === "expose") loaderExpose.active = true;
        else if (id === "palette") loaderPalette.active = true;
        else if (id === "schematic") loaderSchematic.active = true;
        else if (id === "launcher") loaderLauncher.active = true;
        else if (id === "notify") loaderNotify.active = true;
        else if (id === "spectrum") loaderSpectrum.active = true;
    }

    // ---- IPC Handler -----------------------------------------------------
    IpcHandler {
        target: "deck"

        function toggle(id: string): void {
            const targetId = id && id !== "" ? id : "control";
            if (!root.isOpen) {
                root.openDeck(targetId);
            } else if (root.activePanelId === targetId) {
                root.closeDeck();
            } else {
                root.morphTo(targetId);
            }
        }

        function open(id: string): void {
            const targetId = id && id !== "" ? id : "control";
            if (!root.isOpen) root.openDeck(targetId);
            else root.morphTo(targetId);
        }

        function close(): void {
            root.closeDeck();
        }

        function current(): string {
            return root.isOpen ? root.activePanelId : "closed";
        }

        function notifChanged(): void {
            if (root.activePanelId === "notify") {
                const item = root.getView("notify");
                if (item && typeof item.refresh === "function") {
                    item.refresh();
                }
            }
        }
    }

    // ---- Geometry Target Bindings ----------------------------------------
    readonly property int winW: win.width > 0 ? win.width : 2560
    readonly property int winH: win.height > 0 ? win.height : 1440

    readonly property bool targetFullBleed: root.activeView ? !!root.activeView.fullBleed : false
    readonly property int targetW: root.activeView ? (targetFullBleed ? winW - 96 : root.activeView.panelWidth) : 1080
    // A view may opt out of the deck's framing:
    //   bare: true    no title, rules or footer; the view fills the chassis
    //   scrim: false  leave the desktop undimmed (clicks outside still close)
    readonly property bool targetBare: root.activeView ? !!root.activeView.bare : false
    readonly property real targetScrim: root.activeView && root.activeView.scrim === false ? 0.0 : 0.60

    // panelHeight -1 = fit the view's implicitHeight, as Panel.qml's -1 does.
    // chrome is everything around bodySlot: 22+28+12+1+14 above, 14+1+12+20+22 below.
    readonly property int chrome: root.targetBare ? 0 : 146
    readonly property int targetH: {
        if (!root.activeView) return 560;
        if (targetFullBleed) return winH - 96;
        const h = root.activeView.panelHeight;
        return h > 0 ? h : Math.min(root.activeView.implicitHeight + root.chrome, winH - 96);
    }
    readonly property string targetPlacement: root.activeView ? (root.activeView.placement || "center") : "center"

    readonly property real targetX: {
        if (targetPlacement === "right") return winW - targetW - 14;
        if (targetPlacement === "left") return 14;
        return (winW - targetW) / 2;
    }

    readonly property real targetY: {
        if (targetPlacement === "top") return 48;
        // Fixed top edge, so a view that grows (the launcher as results
        // arrive) grows downward instead of re-centring.
        if (targetPlacement === "spotlight") return Math.round(winH * 0.22);
        if (targetPlacement === "bottom") return winH - targetH - 48;
        return (winH - targetH) / 2;
    }

    // ---- Window Surface --------------------------------------------------
    PanelWindow {
        id: win
        visible: false
        WlrLayershell.namespace: "quickshell:deck"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: {
            if (visible) root.restoreFocus();
        }

        // Global Backdrop Scrim
        Rectangle {
            id: scrimRect
            anchors.fill: parent
            color: Theme.bg
            opacity: 0.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.easeMs; easing.type: Easing.OutQuad }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeDeck()
            }
        }

        // Global Key Interceptor
        Item {
            id: keyCatch
            anchors.fill: parent
            focus: true

            Keys.priority: Keys.BeforeItem
            Keys.onEscapePressed: event => {
                root.closeDeck();
                event.accepted = true;
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.closeDeck();
                    event.accepted = true;
                    return;
                }
                if (root.activeView && typeof root.activeView.handleKey === "function") {
                    root.activeView.handleKey(event);
                }
            }

            // =================================================================
            // ---- MORPHING GLASS CHASSIS -------------------------------------
            // =================================================================
            Item {
                id: chassis
            x: root.targetX
            y: root.targetY
            width: root.targetW
            height: root.targetH

            // Physical Apple Spring Morph Behaviors
            Behavior on x {
                enabled: root.isOpen && !openAnim.running
                NumberAnimation {
                    duration: Theme.morphMs
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: root.isOpen && !openAnim.running
                NumberAnimation {
                    duration: Theme.morphMs
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                enabled: root.isOpen && !openAnim.running
                NumberAnimation {
                    duration: Theme.morphMs
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: root.isOpen && !openAnim.running
                NumberAnimation {
                    duration: Theme.morphMs
                    easing.type: Easing.OutCubic
                }
            }

            // Chassis Glass Body
            Rectangle {
                anchors.fill: parent
                radius: 0
                color: Theme.card
                border.width: 1
                border.color: Theme.edge

                // Top specular laser light catch
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    anchors.margins: 1
                    height: 1
                    radius: 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.15; color: Theme.accentWash }
                        GradientStop { position: 0.50; color: Theme.accent }
                        GradientStop { position: 0.85; color: Theme.accentWash }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Bottom subtle shadow rim
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: Theme.shadow
                }

                // Swallows clicks inside chassis and restores active focus
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.restoreFocus()
                }
            }

            // Precision Corner Vernier Brackets
            Bracket { corner: "tl"; arm: 14; thickness: 1; stroke: Theme.accentEdge; anchors.left: parent.left; anchors.top: parent.top }
            Bracket { corner: "tr"; arm: 14; thickness: 1; stroke: Theme.accentEdge; anchors.right: parent.right; anchors.top: parent.top }
            Bracket { corner: "bl"; arm: 14; thickness: 1; stroke: Theme.accentEdge; anchors.left: parent.left; anchors.bottom: parent.bottom }
            Bracket { corner: "br"; arm: 14; thickness: 1; stroke: Theme.accentEdge; anchors.right: parent.right; anchors.bottom: parent.bottom }

            // ---- Header --------------------------------------------------
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                height: 28
                visible: !root.targetBare

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Glowing Micro-Indicator Pip
                    Rectangle {
                        width: 6; height: 6; radius: 0
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        // Gated: ungated it ticked whenever the deck process
                        // lived, open or not, and under a hidden header.
                        SequentialAnimation on opacity {
                            running: win.visible && header.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Morphing Cryptographic Glitch Title
                    GlitchText {
                        id: titleGlitch
                        text: root.activeView ? root.activeView.panelTitle : "DECK"
                        jp: root.activeView ? root.activeView.panelJp : "卓"
                        color: Theme.text
                        jpColor: Theme.accent
                        pixelSize: Theme.szValue
                        letterSpacing: Theme.trkWide
                        weight: Font.DemiBold
                    }
                }

                // Dynamic Header Component Loader
                Loader {
                    id: headerSlot
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    sourceComponent: root.activeView ? root.activeView.headerComponent : null
                }
            }

            // Top Division Rule
            Item {
                id: ruleTop
                anchors { top: header.bottom; topMargin: 12; left: parent.left; right: parent.right; leftMargin: 22; rightMargin: 22 }
                height: 1
                visible: !root.targetBare

                Rectangle { anchors.fill: parent; color: Theme.edge }
                Rectangle {
                    width: 30; height: 1
                    color: Theme.accent
                    anchors.centerIn: parent
                    opacity: 0.7
                }
            }

            // ---- Body Content Slot ---------------------------------------
            Item {
                id: bodySlot
                anchors {
                    top: root.targetBare ? parent.top : ruleTop.bottom
                    bottom: root.targetBare ? parent.bottom : ruleBottom.top
                    left: parent.left
                    right: parent.right
                    topMargin: root.targetBare ? 0 : 14
                    bottomMargin: root.targetBare ? 0 : 14
                    leftMargin: root.targetBare ? 0 : 22
                    rightMargin: root.targetBare ? 0 : 22
                }
                clip: true

                // View Close Signal Interceptor
                Connections {
                    target: root.activeView
                    ignoreUnknownSignals: true
                    function onCloseRequested() { root.closeDeck(); }
                }

                // Lazy View Loaders with Caching
                Loader {
                    id: loaderControl
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: ControlView {}
                    opacity: root.activePanelId === "control" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["control"] = item;
                        if (root.activePanelId === "control") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderMusic
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: MusicView {}
                    opacity: root.activePanelId === "music" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["music"] = item;
                        if (root.activePanelId === "music") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderCyberpad
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: CyberpadView {}
                    opacity: root.activePanelId === "cyberpad" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["cyberpad"] = item;
                        if (root.activePanelId === "cyberpad") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderKeys
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: KeysView {}
                    opacity: root.activePanelId === "keys" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["keys"] = item;
                        if (root.activePanelId === "keys") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderAgent
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: AgentView {}
                    opacity: root.activePanelId === "agent" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["agent"] = item;
                        if (root.activePanelId === "agent") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderClip
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: ClipView {}
                    opacity: root.activePanelId === "clip" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["clip"] = item;
                        if (root.activePanelId === "clip") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderTodo
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: TodoView {}
                    opacity: root.activePanelId === "todo" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["todo"] = item;
                        if (root.activePanelId === "todo") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderSensor
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: SensorView {}
                    opacity: root.activePanelId === "sensor" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["sensor"] = item;
                        if (root.activePanelId === "sensor") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderRadar
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: RadarView {}
                    opacity: root.activePanelId === "radar" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["radar"] = item;
                        if (root.activePanelId === "radar") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderDev
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: DevView {}
                    opacity: root.activePanelId === "dev" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["dev"] = item;
                        if (root.activePanelId === "dev") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderNodemap
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: NodemapView {}
                    opacity: root.activePanelId === "nodemap" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["nodemap"] = item;
                        if (root.activePanelId === "nodemap") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderExpose
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: ExposeView {}
                    opacity: root.activePanelId === "expose" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["expose"] = item;
                        if (root.activePanelId === "expose") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderPalette
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: PaletteView {}
                    opacity: root.activePanelId === "palette" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["palette"] = item;
                        if (root.activePanelId === "palette") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderSchematic
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: SchematicView {}
                    opacity: root.activePanelId === "schematic" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["schematic"] = item;
                        if (root.activePanelId === "schematic") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderLauncher
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: LauncherView {}
                    opacity: root.activePanelId === "launcher" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["launcher"] = item;
                        if (root.activePanelId === "launcher") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderNotify
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: NotifyView {}
                    opacity: root.activePanelId === "notify" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["notify"] = item;
                        if (root.activePanelId === "notify") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }

                Loader {
                    id: loaderSpectrum
                    anchors.fill: parent
                    active: false
                    asynchronous: false
                    sourceComponent: SpectrumView {}
                    opacity: root.activePanelId === "spectrum" ? 1.0 : 0.0
                    visible: opacity > 0.01
                    onLoaded: {
                        root.viewCache["spectrum"] = item;
                        if (root.activePanelId === "spectrum") {
                            root.activeView = item;
                            root.restoreFocus();
                        }
                    }
                }
            }

            // Bottom Division Rule
            Item {
                id: ruleBottom
                anchors { bottom: footer.top; bottomMargin: 12; left: parent.left; right: parent.right; leftMargin: 22; rightMargin: 22 }
                height: 1
                visible: !root.targetBare

                Rectangle { anchors.fill: parent; color: Theme.edge }
                Rectangle {
                    width: 30; height: 1
                    color: Theme.accentEdge
                    anchors.centerIn: parent
                    opacity: 0.5
                }
            }

            // ---- Footer --------------------------------------------------
            Item {
                id: footer
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 22 }
                height: 20
                visible: !root.targetBare

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 4; height: 4; radius: 0
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "READY // 待機  •  " + (root.activeView ? root.activeView.panelHint : "ESC CLOSE")
                        color: Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szMicro
                        font.letterSpacing: Theme.trkLabel
                    }
                }
            }
        }
        }
    }

    // ---- Animations ------------------------------------------------------
    // Smooth Content Crossfade
    ParallelAnimation {
        id: crossfadeAnim

        NumberAnimation {
            target: bodySlot
            property: "opacity"
            from: 0.35
            to: 1.0
            duration: Theme.easeMs
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: headerSlot
            property: "opacity"
            from: 0.20
            to: 1.0
            duration: Theme.easeMs
            easing.type: Easing.OutQuad
        }
    }

    // Opening Spring Entrance
    ParallelAnimation {
        id: openAnim
        property real fromY: 0
        property real toY: 0

        NumberAnimation {
            target: chassis
            property: "y"
            from: openAnim.fromY
            to: openAnim.toY
            duration: Theme.morphMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: chassis
            property: "scale"
            from: 0.965
            to: 1.0
            duration: Theme.morphMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: chassis
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: Theme.easeMs
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: scrimRect
            property: "opacity"
            from: 0.0
            to: root.targetScrim
            duration: Theme.easeMs
            easing.type: Easing.OutQuad
        }
    }

    // Dismissal Exit
    ParallelAnimation {
        id: closeAnim

        NumberAnimation {
            target: chassis
            property: "scale"
            to: 0.965
            duration: Theme.easeMs
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: chassis
            property: "opacity"
            to: 0.0
            duration: Theme.easeMs
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: scrimRect
            property: "opacity"
            to: 0.0
            duration: Theme.easeMs
            easing.type: Easing.InQuad
        }

        onFinished: {
            win.visible = false;
            root.isOpen = false;
            root.activePanelId = "";
            root.activeView = null;
        }
    }
}
