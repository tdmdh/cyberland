// Unified Modal Deck Host: Apple x Cyberpunk Floating Neural-Glass Morphism Deck.
//
// Consolidates floating modal panels into a single, high-performance Quickshell daemon
// with a persistent glass chassis that physically glides and morphs across the display
// with physical Apple spring dynamics (Easing.OutBack).
//
// Supported panels:
//   - "control"   (center, 1080x560)  Volume, Media, Wifi, Bluetooth, Power
//   - "music"     (center, 920x330)   Cyberdeck Audio Player, MPRIS, Spectrum Analyzer
//   - "cyberpad"  (top, 960x420)      Quick-drop scratchpad console & hex editor
//   - "keys"      (bottom, 1280x460)  Keybind cheatsheet grid & search
//   - "agent"     (center, 1080x580)  Agent activity & token telemetry
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
    readonly property int targetH: root.activeView ? (targetFullBleed ? winH - 96 : root.activeView.panelHeight) : 560
    readonly property string targetPlacement: root.activeView ? (root.activeView.placement || "center") : "center"

    readonly property real targetX: {
        if (targetPlacement === "right") return winW - targetW - 14;
        if (targetPlacement === "left") return 14;
        return (winW - targetW) / 2;
    }

    readonly property real targetY: {
        if (targetPlacement === "top") return 48;
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
            color: Theme.obsidianBase
            opacity: 0.0

            Behavior on opacity {
                NumberAnimation { duration: 240; easing.type: Easing.OutQuad }
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
                    duration: 360
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.14
                }
            }
            Behavior on y {
                enabled: root.isOpen && !openAnim.running
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.14
                }
            }
            Behavior on width {
                enabled: root.isOpen && !openAnim.running
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.12
                }
            }
            Behavior on height {
                enabled: root.isOpen && !openAnim.running
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.12
                }
            }

            // Chassis Glass Body
            Rectangle {
                anchors.fill: parent
                radius: 0
                color: Theme.glassCard
                border.width: 1
                border.color: Theme.glassBorder

                // Top specular laser light catch
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    anchors.margins: 1
                    height: 1
                    radius: 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.15; color: Theme.specularDim }
                        GradientStop { position: 0.50; color: Theme.laser }
                        GradientStop { position: 0.85; color: Theme.specularDim }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Bottom subtle shadow rim
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: Theme.shadowRim
                }

                // Swallows clicks inside chassis and restores active focus
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.restoreFocus()
                }
            }

            // Precision Corner Vernier Brackets
            Bracket { corner: "tl"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.left: parent.left; anchors.top: parent.top }
            Bracket { corner: "tr"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.right: parent.right; anchors.top: parent.top }
            Bracket { corner: "bl"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.left: parent.left; anchors.bottom: parent.bottom }
            Bracket { corner: "br"; arm: 14; thickness: 1; stroke: Theme.specularCatch; anchors.right: parent.right; anchors.bottom: parent.bottom }

            // ---- Header --------------------------------------------------
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Glowing Micro-Indicator Pip
                    Rectangle {
                        width: 6; height: 6; radius: 0
                        color: Theme.laser
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
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
                        color: Theme.textPrimary
                        jpColor: Theme.laser
                        pixelSize: 17
                        letterSpacing: 2.2
                        weight: Font.DemiBold
                    }

                    // System Mode Tag Capsule
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        width: sysTagText.implicitWidth + 12
                        radius: 0
                        color: Qt.rgba(Theme.laser.r, Theme.laser.g, Theme.laser.b, 0.12)
                        border.width: 1
                        border.color: Theme.specularDim

                        Text {
                            id: sysTagText
                            anchors.centerIn: parent
                            text: "SYS // NOMINAL"
                            color: Theme.laser
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.szNano
                            font.letterSpacing: 1.0
                        }
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

                Rectangle { anchors.fill: parent; color: Theme.glassBorder }
                Rectangle {
                    width: 30; height: 1
                    color: Theme.laser
                    anchors.centerIn: parent
                    opacity: 0.7
                }
            }

            // ---- Body Content Slot ---------------------------------------
            Item {
                id: bodySlot
                anchors {
                    top: ruleTop.bottom
                    bottom: ruleBottom.top
                    left: parent.left
                    right: parent.right
                    topMargin: 14
                    bottomMargin: 14
                    leftMargin: 22
                    rightMargin: 22
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
            }

            // Bottom Division Rule
            Item {
                id: ruleBottom
                anchors { bottom: footer.top; bottomMargin: 12; left: parent.left; right: parent.right; leftMargin: 22; rightMargin: 22 }
                height: 1

                Rectangle { anchors.fill: parent; color: Theme.glassBorder }
                Rectangle {
                    width: 30; height: 1
                    color: Theme.specularCatch
                    anchors.centerIn: parent
                    opacity: 0.5
                }
            }

            // ---- Footer --------------------------------------------------
            Item {
                id: footer
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 22 }
                height: 20

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
                        color: Theme.textSecondary
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szTail
                        font.letterSpacing: 1.4
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NEURAL DECK // OPTICAL GLASS"
                    color: Theme.textTertiary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szNano
                    font.letterSpacing: 1.2
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
            duration: 220
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: headerSlot
            property: "opacity"
            from: 0.20
            to: 1.0
            duration: 220
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
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
        NumberAnimation {
            target: chassis
            property: "scale"
            from: 0.965
            to: 1.0
            duration: 300
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: chassis
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 200
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: scrimRect
            property: "opacity"
            from: 0.0
            to: 0.60
            duration: 240
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
            duration: 180
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: chassis
            property: "opacity"
            to: 0.0
            duration: 160
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: scrimRect
            property: "opacity"
            to: 0.0
            duration: 200
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
