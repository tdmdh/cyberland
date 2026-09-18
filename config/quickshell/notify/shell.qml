// Notifications: the server, the popups, and the history panel.
//
// Replaces swaync. Not because swaync was broken -- it worked -- but because
// it was the last surface on this desktop drawn in someone else's design
// language: a rounded Material card with its own fonts and its own palette,
// sliding in over a machine built entirely out of hairlines and brackets.
// Quickshell ships Services.Notifications, so the server can just live here
// and the popups can wear Corners and Tag like everything else.
//
// ONE PROCESS OWNS org.freedesktop.Notifications. swaync must be masked, or
// whichever of the two wins the name race gets the notifications and the
// other silently gets none.
//
// The history is the SAME objects as the popups: `tracked` keeps a
// notification alive after its popup has timed out, so nothing is copied into
// a second list that could disagree with the first. Dismissing it anywhere
// removes it everywhere.
//
//   run:    qs -d -c notify
//   toggle: qs -c notify ipc call notify toggle       (SUPER+SHIFT+N)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "./common"

ShellRoot {
    id: root

    // ---- state -----------------------------------------------------------
    property bool isOpen: false
    property bool dnd: false

    // id -> { at, until }. `at` is ours because the spec carries no timestamp;
    // `until` is when the popup stops being drawn, NOT when the notification
    // dies -- it stays in the history until something dismisses it.
    property var meta: ({})
    property double tick: Date.now()

    readonly property int histMax: 60
    readonly property int defaultSecs: 6

    // Newest first. The history and the popups are two views of this one list.
    readonly property var all: {
        const v = server.trackedNotifications.values.slice();
        v.reverse();
        return v;
    }

    readonly property var popups: root.all.filter(n => {
        const m = root.meta[n.id];
        return m !== undefined && m.until > root.tick;
    })

    function ago(id): string {
        const m = root.meta[id];
        if (!m) return "";
        const s = Math.floor((root.tick - m.at) / 1000);
        if (s < 60)   return s + "s";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    function clearAll(): void {
        // Copy first: dismiss() mutates the model being iterated.
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        root.meta = ({});
    }

    // ---- server ----------------------------------------------------------
    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: false        // this desktop draws no icons anywhere
        persistenceSupported: true   // tells apps the history exists

        onNotification: n => {
            // Without this the notification is dropped the moment the handler
            // returns, and there is no history at all.
            n.tracked = true;

            const now = Date.now();
            // Spec: 0 means "never expire", -1 means "server decides".
            // Critical is never dismissed on a timer -- that is the whole
            // difference between critical and normal.
            const crit = n.urgency === NotificationUrgency.Critical;
            const t = n.expireTimeout;
            const secs = t === 0 ? 0 : (t > 0 ? t : (crit ? 0 : root.defaultSecs));
            const quiet = root.dnd && !crit;

            let m = {};
            // Rebuilt rather than appended to, which is also what prunes the
            // entries of notifications that have since been dismissed.
            for (const k of server.trackedNotifications.values)
                if (root.meta[k.id] !== undefined) m[k.id] = root.meta[k.id];
            m[n.id] = { at: now,
                        until: quiet ? 0 : (secs > 0 ? now + secs * 1000 : Infinity) };
            root.meta = m;
            root.tick = now;

            // Oldest first in .values, so the overflow is at the front.
            const over = server.trackedNotifications.values.length - root.histMax;
            for (let i = 0; i < over; i++)
                server.trackedNotifications.values[i].dismiss();
        }
    }

    // One timer for every relative time and every popup expiry on screen.
    // Idle when there is nothing on screen that moves.
    Timer {
        interval: 500
        repeat: true
        running: root.popups.length > 0 || root.isOpen
        onTriggered: root.tick = Date.now()
    }

    Process {
        id: deckProc
    }

    function forwardToDeck(action: string): void {
        deckProc.command = ["qs", "-c", "deck", "ipc", "call", "deck", action, "notify"];
        deckProc.running = true;
    }

    IpcHandler {
        target: "notify"
        function toggle(): void { root.forwardToDeck("toggle"); }
        function open(): void { root.forwardToDeck("open"); }
        function close(): void { root.forwardToDeck("close"); }
        function clear(): void { root.clearAll(); }
        function dnd(): string { root.dnd = !root.dnd; return root.dnd ? "on" : "off"; }
        function setDnd(val: string): void { root.dnd = (val === "true" || val === "1" || val === "on"); }
        // What the control panel reads. Kept small on purpose -- control
        // renders a summary, this module renders the list.
        function state(): string {
            return JSON.stringify({
                dnd: root.dnd,
                count: root.all.length,
                recent: root.all.slice(0, 3).map(n => ({
                    app: n.appName || "?",
                    summary: n.summary || "",
                    crit: n.urgency === NotificationUrgency.Critical }))
            });
        }
        function list(): string {
            return JSON.stringify({
                dnd: root.dnd,
                count: root.all.length,
                items: root.all.map(n => ({
                    id: n.id,
                    appName: n.appName || "UNKNOWN",
                    summary: n.summary || "",
                    body: n.body || "",
                    urgency: n.urgency,
                    crit: n.urgency === NotificationUrgency.Critical,
                    timeAgo: root.ago(n.id),
                    actions: n.actions ? n.actions.map(a => ({ id: a.id, text: a.text })) : []
                }))
            });
        }
        function dismiss(idStr: string): void {
            const id = parseInt(idStr);
            const item = server.trackedNotifications.values.find(n => n.id === id);
            if (item) item.dismiss();
        }
        function invoke(idStr: string, actionId: string): void {
            const id = parseInt(idStr);
            const item = server.trackedNotifications.values.find(n => n.id === id);
            if (item && item.actions) {
                const a = item.actions.find(act => act.id === actionId);
                if (a) a.invoke();
            }
        }
    }

    // ---- popups ----------------------------------------------------------
    // Top-right, below the frame's 44px top band so it never sits on the TR
    // system meters. Overlay layer: a notification is meant to cover a window.
    PanelWindow {
        id: pop
        visible: root.popups.length > 0 && !root.isOpen

        WlrLayershell.namespace: "quickshell:notify"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        exclusiveZone: 0

        anchors { top: true; right: true }
        margins { top: 52; right: 22 }

        implicitWidth: 400
        // Never 0: a layer surface with no size is a protocol error.
        implicitHeight: Math.max(1, stack.implicitHeight)

        // Only the cards take clicks; the gaps between them do not.
        mask: Region { item: stack }

        Column {
            id: stack
            width: parent.width
            spacing: 10

            Repeater {
                model: root.popups

                Item {
                    id: card
                    required property var modelData
                    width: stack.width
                    implicitHeight: cardBody.implicitHeight + 26
                    height: implicitHeight

                    readonly property bool crit:
                        modelData.urgency === NotificationUrgency.Critical
                    readonly property color edge:
                        card.crit ? Theme.alert
                      : modelData.urgency === NotificationUrgency.Low ? Theme.line2
                      : Theme.line

                    // Apple x Cyberpunk Floating Smoked Glass Card
                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        color: Theme.card
                        border.width: 1
                        border.color: card.crit ? Theme.alert : Theme.edge
                        clip: true

                        // Top specular hairline catch
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            anchors.leftMargin: 1; anchors.rightMargin: 1
                            height: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Theme.accentEdge }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Left glowing status strip
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            anchors.margins: 4
                            width: 3
                            radius: 0
                            color: card.crit ? Theme.alert : Theme.accent
                        }
                    }

                    Column {
                        id: cardBody
                        anchors { left: parent.left; right: parent.right
                                  verticalCenter: parent.verticalCenter
                                  leftMargin: 15; rightMargin: 15 }
                        spacing: 5

                        Item {
                            width: parent.width
                            height: appTag.height
                            Tag {
                                id: appTag
                                label: (card.modelData.appName || "UNKNOWN").toUpperCase()
                                jp: "通知"
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: appTag.verticalCenter
                                text: root.ago(card.modelData.id)
                                color: Theme.dim
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.szMicro
                            }
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.modelData.summary
                            color: card.crit ? Theme.alert : Theme.text
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szValue
                            font.letterSpacing: Theme.trkTight
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: card.modelData.body
                            color: Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.szBody
                            // Apps send pango markup whether or not you asked;
                            // declaring support and rendering it is the only
                            // way the tags do not show up as literal text.
                            textFormat: Text.StyledText
                            linkColor: Theme.accent
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 3
                        }

                        Row {
                            spacing: 8
                            topPadding: 3
                            visible: card.modelData.actions.length > 0
                            Repeater {
                                model: card.modelData.actions
                                Btn {
                                    required property var modelData
                                    text: modelData.text.toUpperCase()
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }

                    // Click anywhere else on the card to dismiss it. Actions
                    // are Btns and take their own clicks first.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: card.modelData.dismiss()
                        z: -1
                    }
                }
            }
        }
    }

    // ---- history ---------------------------------------------------------
    // Migrated to unified modal deck host (quickshell/deck/views/NotifyView.qml).
    // The NotificationServer and toast popups remain active here.
    PanelWindow {
        id: win
        visible: false

        WlrLayershell.namespace: "quickshell:notifypanel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.isOpen = false
            Keys.onPressed: e => {
                if (e.key === Qt.Key_D) { root.dnd = !root.dnd; e.accepted = true; }
                if (e.key === Qt.Key_C) { root.clearAll(); e.accepted = true; }
            }
        }

        Panel {
            title: "NOTIFICATIONS"
            jp: "通知"
            hint: "D  DO NOT DISTURB       C  CLEAR ALL       ESC  CLOSE"
            panelWidth: 800
            placement: "right"
            scrimMode: "dim"
            onDismissed: root.isOpen = false

            headerItems: [
                DynamicPill {
                    label: "HELD"
                    jp: "件数"
                    value: ("0" + root.all.length).slice(-2)
                    subValue: root.dnd ? "DND ACTIVE" : (root.all.length > 0 ? "NOTIFICATIONS" : "ALL CLEAR")
                    warn: root.dnd
                    anchors.verticalCenter: parent.verticalCenter
                },
                Btn {
                    text: "DND"
                    jp: "静音"
                    active: root.dnd
                    tint: Theme.warn
                    onClicked: root.dnd = !root.dnd
                },
                Btn {
                    text: "CLEAR"
                    jp: "消去"
                    tint: Theme.alert
                    enabled: root.all.length > 0
                    onClicked: root.clearAll()
                }
            ]

            Item {
                width: parent.width
                height: parent.height
                // Grows with the list, then stops and scrolls. A fixed floor
                // keeps the empty state from collapsing the panel to a slit.
                implicitHeight: Math.max(140, Math.min(list.contentHeight, 560))

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 1
                    model: root.all
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: row
                        required property var modelData
                        width: list.width
                        implicitHeight: rowBody.implicitHeight + 22
                        height: implicitHeight

                        readonly property bool crit:
                            modelData.urgency === NotificationUrgency.Critical

                        Rectangle {
                            anchors.fill: parent
                            color: hov.hovered ? Theme.layer1 : "transparent"
                        }
                        // The row separator, not a box: a list of boxes is a
                        // list of things, a ruled list is one instrument.
                        Rectangle {
                            anchors { left: parent.left; right: parent.right
                                      bottom: parent.bottom }
                            height: 1
                            color: Theme.line2
                        }
                        // Critical rows get a spine rather than a fill, so
                        // colour still only ever means "wrong".
                        Rectangle {
                            anchors { left: parent.left; top: parent.top
                                      bottom: parent.bottom; bottomMargin: 1 }
                            width: 2
                            visible: row.crit
                            color: Theme.alert
                        }

                        Column {
                            id: rowBody
                            anchors { left: parent.left; right: parent.right
                                      verticalCenter: parent.verticalCenter
                                      leftMargin: 14; rightMargin: 14 }
                            spacing: 4

                            Item {
                                width: parent.width
                                height: rowTag.height
                                Tag {
                                    id: rowTag
                                    label: (row.modelData.appName || "UNKNOWN").toUpperCase()
                                    jp: row.crit ? "重要" : ""
                                }
                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: rowTag.verticalCenter
                                    spacing: 12
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.ago(row.modelData.id)
                                        color: Theme.dim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szMicro
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "✕"
                                        color: hov.hovered ? Theme.alert : Theme.dim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.szMicro
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: row.modelData.dismiss()
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.summary
                                color: row.crit ? Theme.alert : Theme.text
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szBody + 2
                                font.letterSpacing: Theme.trkTight
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.body
                                color: Theme.dim
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.szBody
                                textFormat: Text.StyledText
                                linkColor: Theme.accent
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }
                            Row {
                                spacing: 8
                                topPadding: 2
                                visible: row.modelData.actions.length > 0
                                Repeater {
                                    model: row.modelData.actions
                                    Btn {
                                        required property var modelData
                                        text: modelData.text.toUpperCase()
                                        onClicked: modelData.invoke()
                                    }
                                }
                            }
                        }

                        HoverHandler { id: hov }
                    }
                }

                // The empty state says which of the two reasons it is empty
                // for: nothing arrived, or nothing is being let through.
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.all.length === 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dnd ? "DO NOT DISTURB" : "NOTHING HELD"
                        color: root.dnd ? Theme.warn : Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szBody
                        font.letterSpacing: Theme.trkWide
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dnd ? "静音" : "空"
                        color: Theme.dim
                        font.family: Theme.fontJP
                        font.pixelSize: Theme.szMicro
                    }
                }
            }
        }
    }
}
