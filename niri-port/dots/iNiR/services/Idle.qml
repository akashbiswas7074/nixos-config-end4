pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property bool inhibit: false
    readonly property int screenOffTimeout: Config.options?.idle?.screenOffTimeout ?? 300
    readonly property int lockTimeout: Config.options?.idle?.lockTimeout ?? 600
    readonly property int suspendTimeout: Config.options?.idle?.suspendTimeout ?? 0
    readonly property string launcherPath: Quickshell.shellPath("scripts/inir")

    onScreenOffTimeoutChanged: _restartSwayidle()
    onLockTimeoutChanged: _restartSwayidle()
    onSuspendTimeoutChanged: _restartSwayidle()
    onInhibitChanged: _restartSwayidle()

    function toggleInhibit(active = null): void {
        if (active !== null) {
            inhibit = active;
        } else {
            inhibit = !inhibit;
        }
        Persistent.states.idle.inhibit = inhibit;
    }

    function _restartSwayidle() {
        _stopSwayidle()
        if (!inhibit) _startSwayidleDelayed.start()
    }

    function _stopSwayidle() {
        Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport() + "exec pkill -x swayidle"])
    }

    function _startSwayidle() {
        if (inhibit) return

        const cmd = ["swayidle", "-w"]
        const lockBeforeSleep = Config.options?.idle?.lockBeforeSleep !== false

        if (screenOffTimeout > 0) {
            cmd.push("timeout", screenOffTimeout.toString(), "niri msg action power-off-monitors", "resume", "niri msg action power-on-monitors")
        }

        // Determine effective lock timeout
        // If suspend is configured and lockBeforeSleep is enabled, ensure lock happens before suspend
        let effectiveLockTimeout = lockTimeout
        if (suspendTimeout > 0 && lockBeforeSleep) {
            // Lock should happen before suspend - use 5 seconds before suspend if lockTimeout is 0 or > suspendTimeout
            const lockBeforeSuspendTime = Math.max(1, suspendTimeout - 5)
            if (lockTimeout <= 0 || lockTimeout > lockBeforeSuspendTime) {
                effectiveLockTimeout = lockBeforeSuspendTime
            }
        }

        const lockBeforeIdle = Config.subprocessPathShExport()
            + "export XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\"; "
            + "export DBUS_SESSION_BUS_ADDRESS=\"${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}\"; "
            + "export WAYLAND_DISPLAY=\"${WAYLAND_DISPLAY:-wayland-1}\"; "
            + "if command -v inir >/dev/null 2>&1; then exec inir lock activate; fi; "
            + "if [ -x /run/current-system/sw/bin/swaylock ]; then exec /run/current-system/sw/bin/swaylock -f; fi; "
            + "exec swaylock -f"
        if (effectiveLockTimeout > 0) {
            cmd.push("timeout", effectiveLockTimeout.toString(), lockBeforeIdle)
        }

        if (suspendTimeout > 0) {
            const cool = Config.options?.idle?.suspendCooldownSec ?? 120
            const suspendAfterIdle = Config.subprocessPathShExport()
                + "export XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\"; "
                + "f=\"$XDG_RUNTIME_DIR/inir-idle-suspend-cooldown\"; "
                + "now=$(date +%s); cool=" + String(cool) + "; "
                + "if [ -f \"$f\" ]; then last=$(cat \"$f\" 2>/dev/null || echo 0); "
                + "if [ \"$((now - last))\" -lt \"$cool\" ]; then exit 0; fi; fi; "
                + "printf '%s\\n' \"$now\" > \"$f\"; "
                + "exec systemctl suspend-then-hibernate -i"
            cmd.push("timeout", suspendTimeout.toString(), suspendAfterIdle)
        }

        if (lockBeforeSleep) {
            cmd.push("before-sleep", lockBeforeIdle)
        }

        console.log("[Idle] Starting swayidle")
        const cmdEsc = cmd.map(c => `'${String(c).replace(/'/g, "'\\''")}'`).join(" ")
        Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport() + `exec ${cmdEsc}`])
    }

    Timer {
        id: _startSwayidleDelayed
        interval: 200
        onTriggered: root._startSwayidle()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root._restartSwayidle()
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready && Persistent.states?.idle?.inhibit)
                root.inhibit = true
        }
    }

    Component.onDestruction: _stopSwayidle()
}
