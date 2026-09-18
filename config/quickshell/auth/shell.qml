// Polkit authentication agent.
//
// Nothing was answering polkit before this: polkitd runs, but no agent was
// registered (hyprpolkitagent installed and never started, and the KDE agent
// in /etc/xdg/autostart is OnlyShowIn=KDE). Anything needing a privileged
// action -- mounting a disk through the portal, a GUI touching systemd --
// simply hung with no prompt.
//
// This replaces hyprpolkitagent rather than starting it: that agent draws a
// GTK/Qt dialog with none of this desktop's chrome, and Quickshell ships
// Services.Polkit, so the prompt can wear the same brackets and dot-field as
// the lock screen instead.
//
// The dialog is deliberately small and modal: it holds exclusive keyboard
// focus while it is up, because the alternative is a password landing in
// whatever terminal is underneath.
//
// It is also sudo's password card. Dev-session terminals open on silent
// workspaces, so a tty prompt there waits where nobody is looking;
// hypr/bin/sudo-shim puts `sudo -A` in front of them and hypr/bin/qs-askpass
// queues the prompt here instead. See the askpass block below.
//
//   run: qs -d -c auth
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "./common"

ShellRoot {
    id: root

    property string entry: ""

    readonly property var flow: agent.flow

    // ---- sudo askpass: the second door into this card --------------------
    // hypr/bin/qs-askpass is sudo's SUDO_ASKPASS helper. It registers a
    // request here over IPC, then blocks reading a FIFO until this card
    // writes the answer into it.
    //
    // A queue, not a slot: a dev session opens several terminals at once and
    // sudo caches credentials per tty, so each of them asks on its own.
    property var asks: []
    readonly property var pending: root.asks.length > 0 ? root.asks[0] : null
    // polkit first. polkitd owns that flow and times it out on its own clock;
    // a sudo request just waits its turn.
    readonly property bool askMode: !agent.isActive && root.pending !== null
    // sudo retries a rejected password by running the helper again from the
    // same sudo process. Same pid as the last answer = the last answer was wrong.
    property int lastAnsweredPid: -1

    // One writer per answer, handed the secret on stdin -- never argv, which
    // any process can read from /proc. `[ -p ]` so a request whose helper has
    // already gone (FIFO dir removed) fails to open rather than creating a
    // regular file with the password in it; timeout so a writer can never sit
    // blocked on a pipe nobody reads. Empty secret = cancel: close, write nothing.
    Component {
        id: writer
        Process {
            required property string fifo
            property string secret: ""
            command: ["timeout", "5", "sh", "-c", '[ -p "$1" ] && exec cat > "$1"', "sh", fifo]
            stdinEnabled: true
            onStarted: {
                if (secret.length > 0) write(secret + "\n");
                secret = "";
                stdinEnabled = false;
            }
            onExited: destroy()
            Component.onCompleted: running = true
        }
    }

    function answerAsk(secret: string): void {
        const a = root.pending;
        if (!a) return;
        writer.createObject(root, { fifo: a.fifo, secret: secret });
        root.lastAnsweredPid = secret.length > 0 ? a.pid : -1;
        root.asks = root.asks.slice(1);
    }

    function submit(): void {
        if (root.askMode) {
            // An empty Enter is a slip, not an answer: sudo would take it as
            // "no password" and give up on the command.
            if (root.entry.length === 0) return;
            root.answerAsk(root.entry);
            root.entry = "";
            return;
        }
        if (!root.flow || !root.flow.isResponseRequired) return;
        root.flow.submit(root.entry);
        root.entry = "";
    }

    function cancel(): void {
        if (root.askMode) { root.answerAsk(""); root.entry = ""; return; }
        if (root.flow) root.flow.cancelAuthenticationRequest();
        root.entry = "";
    }

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: {
            root.entry = "";
            // polkit hands over a list of identities that may authorize the
            // action; on a single-user box that is one entry and Quickshell
            // preselects it. Pick the first only if it did not, rather than
            // overriding a choice that was already made.
            const f = agent.flow;
            if (f && !f.selectedIdentity && f.identities.length > 0)
                f.selectedIdentity = f.identities[0];
        }
    }

    IpcHandler {
        target: "auth"
        // Registration is silent when it works and silent when it does not,
        // so there has to be a way to ask.
        function status(): string {
            return JSON.stringify({ registered: agent.isRegistered,
                                    active: agent.isActive,
                                    action: root.flow ? root.flow.actionId : "",
                                    asks: root.asks.length });
        }

        // Called by hypr/bin/qs-askpass, once per sudo prompt. Nothing secret
        // crosses here -- only what to display, and where to write the answer.
        function ask(prompt: string, command: string, terminal: string, pid: int, fifo: string): void {
            root.asks = root.asks.concat([{ prompt: prompt, command: command,
                                            terminal: terminal, pid: pid, fifo: fifo,
                                            retry: pid === root.lastAnsweredPid }]);
        }

        // The helper gave up (timeout, Ctrl-C in its terminal): stop showing it.
        function drop(fifo: string): void {
            root.asks = root.asks.filter(a => a.fifo !== fifo);
        }
    }

    PanelWindow {
        id: win
        visible: agent.isActive || root.pending !== null

        WlrLayershell.namespace: "quickshell:auth"
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive: a password must not leak into the window underneath.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: if (visible) field.forceActiveFocus()

        Panel {
            title: "AUTHORIZE"
            jp: "認証"
            hint: "ENTER  SUBMIT       ESC  CANCEL"
            panelWidth: 620
            pad: 20
            onDismissed: root.cancel()

            headerItems: [
                DynamicPill {
                    label: root.askMode ? "SUDO" : "POLKIT"
                    jp: "権限"
                    value: root.askMode
                           ? (root.asks.length > 1 ? root.asks.length + " QUEUED" : "ASKPASS")
                           : (agent.isRegistered ? "READY" : "UNREG")
                    subValue: root.askMode ? "TERMINAL" : "AUTHORITY"
                    tint: (root.askMode || agent.isRegistered) ? Theme.accent : Theme.alert
                    anchors.verticalCenter: parent.verticalCenter
                }
            ]

            Column {
                width: parent.width
                spacing: Theme.pad

                // What is actually being authorized. polkit writes this
                // sentence, so it is shown verbatim -- paraphrasing the thing
                // you are about to grant is how people click through prompts.
                Text {
                    width: parent.width
                    text: root.askMode
                          ? root.pending.terminal + " is asking for your sudo password"
                          : (root.flow ? root.flow.message : "")
                    color: Theme.text
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szValue
                    font.letterSpacing: Theme.trkTight
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    // sudo's own argv, verbatim, for the same reason polkit's
                    // sentence is: this line is what you are about to allow.
                    text: root.askMode ? root.pending.command
                                       : (root.flow ? root.flow.actionId : "")
                    color: Theme.dim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szMicro
                    elide: Text.ElideMiddle
                }

                // ---- the field ------------------------------------------
                // Apple-Cyberpunk sharp password chamber
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: 0
                    color: Theme.card
                    border.width: 1
                    border.color: fail.on ? Theme.alert : Theme.edge
                    visible: root.askMode || (!!root.flow && root.flow.isResponseRequired)

                    // Top specular catch
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        color: Theme.accentWash
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.entry.length > 0
                        Repeater {
                            model: Math.min(root.entry.length, 32)
                            Rectangle { width: 7; height: 7; radius: 0; color: Theme.accent }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.entry.length === 0
                        text: (root.askMode
                               ? root.pending.prompt.replace(/^\[sudo\]\s*/, "").replace(/:\s*$/, "").toUpperCase()
                               : root.flow && root.flow.inputPrompt
                               ? root.flow.inputPrompt.replace(/:\s*$/, "").toUpperCase()
                               : "PASSWORD") + "  合言葉"
                        color: Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.szBody
                        font.letterSpacing: Theme.trkWide - 1
                    }

                    // Drawn by hand above; this only collects keystrokes.
                    // echoMode follows polkit: some stacks (a fingerprint or
                    // OTP step) ask a question whose answer is not secret.
                    TextInput {
                        id: field
                        anchors.fill: parent
                        opacity: 0
                        focus: true
                        echoMode: (!root.askMode && root.flow && root.flow.responseVisible)
                                  ? TextInput.Normal : TextInput.Password
                        text: root.entry
                        onTextChanged: root.entry = text
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancel()
                    }
                }

                // PAM's own words -- "Authentication failure", a retry count,
                // a fingerprint instruction. Colour only when it is an error,
                // because colour in this design only ever means "wrong".
                Text {
                    id: fail
                    // In sudo mode the one thing to report is a rejection. sudo
                    // prints "Sorry, try again" into the terminal, which is
                    // exactly where nobody is looking.
                    readonly property bool retry: root.askMode && root.pending.retry
                    readonly property bool on: retry || (!root.askMode && !!root.flow && root.flow.supplementaryIsError)
                    width: parent.width
                    visible: retry || (!root.askMode && !!root.flow && root.flow.supplementaryMessage !== "")
                    text: retry ? "SUDO DID NOT ACCEPT THAT PASSWORD. TRY AGAIN."
                                : (root.flow ? root.flow.supplementaryMessage.toUpperCase() : "")
                    color: fail.on ? Theme.alert : Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: Theme.trkLabel
                    wrapMode: Text.WordWrap
                }

                Row {
                    spacing: 10
                    Btn {
                        text: "AUTHORIZE"; jp: "許可"
                        enabled: root.askMode || (!!root.flow && root.flow.isResponseRequired)
                        onClicked: root.submit()
                    }
                    Btn {
                        text: "CANCEL"; jp: "取消"
                        tint: Theme.alert
                        onClicked: root.cancel()
                    }
                }
            }
        }
    }
}
