// Session lock + PAM. Nothing else lives in this process.
//
// Split from `idle` for a hard technical reason, not tidiness: a layer-shell
// surface and a WlSessionLock cannot share one Wayland client. Measured, in a
// two-line probe -- the moment the lock engages the compositor sends
// "wl_display: error 0: invalid object" and drops the connection, regardless
// of keyboard-focus mode or whether the layer window is hidden first. So this
// module has no PanelWindow at all, and `idle` owns every layer surface.
//
// SECURITY -- ext-session-lock is compositor-enforced: while `secure` is true
// the desktop is genuinely not composited. Screencopy is refused too, which
// is why `grim` blocks against a locked session rather than capturing it.
//
// What happens if this process DIES while locked is compositor-dependent and
// is NOT verified here. The protocol says the session should stay locked;
// twice during development this client died mid-lock and the desktop came
// back unlocked. Do not treat "it crashed" as "it stayed secure". If it does
// stay locked, recovery is a VT switch (Ctrl+Alt+F2).
//
// There is deliberately no `unlock` IPC. A lock you can release from a shell
// is not a lock.
//
//   run:    qs -d -c lock
//   engage: qs -c lock ipc call lock engage        (SUPER+L, and the idle chain)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "./common"

ShellRoot {
    id: root

    property string entry: ""
    property string note: ""
    property bool   failed: false

    function engage(): void {
        if (lock.locked) return;
        root.entry = ""; root.note = ""; root.failed = false;
        if (typeof standby !== "undefined" && standby) standby.refreshWallpaper();
        lock.locked = true;
        pam.start();
    }

    function submit(): void {
        if (!pam.active || !pam.responseRequired) return;
        pam.respond(root.entry);
        root.entry = "";
    }

    IpcHandler {
        target: "lock"
        function engage(): void { root.engage(); }
        function status(): string {
            return JSON.stringify({
                locked: lock.locked,
                secure: lock.secure,
                wallpaper: (typeof standby !== "undefined" && standby) ? standby.wallpaper : ""
            });
        }
    }

    PamContext {
        id: pam
        // /etc/pam.d/hyprlock is `auth include login` -- exactly the stack a
        // locker wants, and already installed. No new pam.d file needed.
        config: "hyprlock"

        onPamMessage: {
            // A failure notice is NOT cleared here. PAM is restarted right
            // after a wrong password, and the fresh "Password:" prompt used to
            // wipe "AUTHENTICATION FAILED" ~600ms after it appeared, so the
            // failure was real but invisible. Typing clears it instead.
            if (pam.message.trim() !== "Password:") {
                root.note = pam.message;
                root.failed = pam.messageIsError;
            }
        }
        onCompleted: res => {
            if (res === PamResult.Success) {
                root.note = ""; root.failed = false;
                lock.locked = false;
                return;
            }
            root.failed = true;
            root.note = "AUTHENTICATION FAILED";
            root.entry = "";
            // PAM is single-shot: a finished conversation must be restarted or
            // the field silently stops accepting anything.
            restart.restart();
        }
        onError: e => {
            root.failed = true;
            root.note = "PAM ERROR " + e;
            restart.restart();
        }
    }
    Timer { id: restart; interval: 600; onTriggered: if (lock.locked) pam.start() }

    WlSessionLock {
        id: lock
        surface: WlSessionLockSurface {
            color: Theme.bg
            Standby {
                id: standby
                anchors.fill: parent
                state1: "LOCKED"; jp1: "施錠"
                showWork: false
                auth: true
                entry: root.entry
                note: root.note
                failed: root.failed
                onSubmitted: root.submit()
                onTyped: t => {
                    root.entry = t;
                    // Typing again dismisses the last failure -- the only
                    // thing that should clear it.
                    if (t.length > 0 && root.failed) { root.failed = false; root.note = ""; }
                }
            }
        }
    }
}
