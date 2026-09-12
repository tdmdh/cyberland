// Idle chain: standby readout, then lock, then display off.
//
// Replaces hypridle entirely -- IdleMonitor is ext-idle-notify, so the
// compositor owns the activity clock and there are no timers to drift out of
// step with it.
//
//     0:00   active
//     5:00   AMBIENT   standby readout, swallows input, any activity dismisses
//    10:00   LOCKED    handed to `lock` (a separate process, see below)
//    15:00   DPMS OFF  display sleeps
//
// respectInhibitors is on for every stage, so a fullscreen video holding an
// idle inhibitor suppresses the whole chain rather than just the lock.
//
// WHY THE LOCK IS NOT HERE -- a layer-shell surface and a WlSessionLock
// cannot share one Wayland client. Measured in a two-line probe: the moment
// the lock engages the compositor sends "wl_display: error 0: invalid object"
// and drops the connection, regardless of keyboard-focus mode or whether the
// layer window is hidden first. This module owns the layer surfaces; `lock`
// owns the session lock and has no windows at all.
//
//   run: qs -d -c idle     (needs qs -d -c lock running too)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._IdleNotify
import "./common"

ShellRoot {
    id: root

    // ---- timings ---------------------------------------------------------
    // The only numbers worth tuning. Seconds.
    readonly property int tAmbient: 300     //  5 min
    readonly property int tLock:    600     // 10 min
    readonly property int tDpms:    900     // 15 min

    IdleMonitor {
        id: mAmbient
        timeout: root.tAmbient
        respectInhibitors: true
    }
    IdleMonitor {
        id: mLock
        timeout: root.tLock
        respectInhibitors: true
        // Fire-and-forget into the lock process. If `lock` is not running the
        // desktop simply stays unlocked rather than this module dying, which
        // is the right failure for a screensaver to have.
        onIsIdleChanged: if (isIdle)
            Quickshell.execDetached(["qs", "-c", "lock", "ipc", "call", "lock", "engage"])
    }
    IdleMonitor {
        id: mDpms
        timeout: root.tDpms
        respectInhibitors: true
        // Waking is the compositor's job: misc.key_press_enables_dpms and
        // mouse_move_enables_dpms are set in conf/looknfeel.lua. Both default
        // to FALSE, and without them this blacks the screen with no way back.
        onIsIdleChanged: if (isIdle)
            Quickshell.execDetached(["hyprctl", "dispatch",
                                     'hl.dsp.dpms({ state = "off" })'])
    }

    Component.onCompleted: void Sys.cpu     // singletons build lazily

    IpcHandler {
        target: "idle"
        // Lets the chain be checked without waiting fifteen minutes for it.
        function status(): string {
            return JSON.stringify({
                ambient: mAmbient.isIdle, lockDue: mLock.isIdle,
                dpmsOff: mDpms.isIdle,
                timings: [root.tAmbient, root.tLock, root.tDpms] });
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:idle"
            WlrLayershell.layer: WlrLayer.Overlay
            // Exclusive focus so the first keystroke dismisses the screen
            // instead of landing in whatever terminal is underneath it.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }

            // Bound to the monitor rather than dismissed by hand: any input at
            // all clears isIdle, so there is no input handling to get wrong.
            visible: mAmbient.isIdle
            onVisibleChanged: if (visible && standby) standby.refreshWallpaper()

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                Standby {
                    id: standby
                    anchors.fill: parent
                    state1: "STANDBY"; jp1: "待機"
                    showWork: true
                    auth: false
                }
            }
        }
    }
}
