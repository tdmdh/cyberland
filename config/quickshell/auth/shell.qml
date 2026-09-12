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

    function submit(): void {
        if (!root.flow || !root.flow.isResponseRequired) return;
        root.flow.submit(root.entry);
        root.entry = "";
    }

    function cancel(): void {
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
                                    action: root.flow ? root.flow.actionId : "" });
        }
    }

    PanelWindow {
        id: win
        visible: agent.isActive

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
                    label: "POLKIT"
                    jp: "権限"
                    value: agent.isRegistered ? "READY" : "UNREG"
                    subValue: "AUTHORITY"
                    tint: agent.isRegistered ? Theme.laser : Theme.alert
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
                    text: root.flow ? root.flow.message : ""
                    color: Theme.text
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szValue
                    font.letterSpacing: 0.4
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: root.flow ? root.flow.actionId : ""
                    color: Theme.dim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.szTail
                    elide: Text.ElideMiddle
                }

                // ---- the field ------------------------------------------
                // Apple-Cyberpunk sharp password chamber
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: 0
                    color: Theme.glassCard
                    border.width: 1
                    border.color: fail.on ? Theme.alert : Theme.glassBorder
                    visible: !!root.flow && root.flow.isResponseRequired

                    // Top specular catch
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.leftMargin: 1; anchors.rightMargin: 1
                        height: 1
                        color: Theme.specularDim
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
                        text: (root.flow && root.flow.inputPrompt
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
                        echoMode: (root.flow && root.flow.responseVisible)
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
                    readonly property bool on: !!root.flow && root.flow.supplementaryIsError
                    width: parent.width
                    visible: !!root.flow && root.flow.supplementaryMessage !== ""
                    text: root.flow ? root.flow.supplementaryMessage.toUpperCase() : ""
                    color: fail.on ? Theme.alert : Theme.dim
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.szBody
                    font.letterSpacing: 2
                    wrapMode: Text.WordWrap
                }

                Row {
                    spacing: 10
                    Btn {
                        text: "AUTHORIZE"; jp: "許可"
                        enabled: !!root.flow && root.flow.isResponseRequired
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
