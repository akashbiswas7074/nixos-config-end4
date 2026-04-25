pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/**
 * Handles EasyEffects active state and presets.
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false
    property bool nativeInstalled: false

    function fetchAvailability() {
        if (whichProc.running || flatpakInfoProc.running) return
        whichProc.running = true
    }

    function fetchActiveState() {
        if (!root.available) {
            root.active = false
            return
        }
        if (root.nativeInstalled) {
            if (nativeStatusProc.running) return
            nativeStatusProc.running = true
            return
        }
        if (flatpakPsProc.running) return
        flatpakPsProc.running = true
    }

    function disable() {
        root.active = false
        if (pkillProc.running || flatpakKillProc.running) return
        pkillProc.running = true
    }

    function enable() {
        root.active = true
        Quickshell.execDetached([
            "bash",
            "-c",
            Config.subprocessPathShExport()
                + "EE_BIN=\"$HOME/.nix-profile/bin/easyeffects\"; "
                + "[ -x \"$EE_BIN\" ] || EE_BIN=easyeffects; "
                + "if command -v \"$EE_BIN\" >/dev/null 2>&1; then "
                + "nohup \"$EE_BIN\" --service-mode >/tmp/inir-easyeffects.log 2>&1 < /dev/null & "
                + "exit 0; "
                + "fi; "
                + "exec flatpak run com.github.wwmm.easyeffects --service-mode"
        ])
        refreshStateTimer.restart()
    }

    function toggle() {
        root.fetchAvailability()
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Timer {
        id: initTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.fetchAvailability()
            root.fetchActiveState()
        }
    }

    Timer {
        id: refreshStateTimer
        interval: 900
        repeat: false
        onTriggered: root.fetchActiveState()
    }

    Timer {
        id: statePollTimer
        interval: 5000
        repeat: true
        running: Config.ready && root.available
        onTriggered: root.fetchActiveState()
    }

    Component.onCompleted: {
        if (Config.ready) {
            initTimer.start()
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                initTimer.start()
            }
        }
    }

    Process {
        id: whichProc
        running: false
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["which", "easyeffects"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.nativeInstalled = true
                root.available = true
            } else {
                root.nativeInstalled = false
                flatpakInfoProc.running = true
            }
        }
    }

    Process {
        id: flatpakInfoProc
        running: false
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["sh", "-c", "flatpak info com.github.wwmm.easyeffects"]
        onExited: (exitCode, exitStatus) => {
            root.nativeInstalled = false
            root.available = (exitCode === 0)
        }
    }

    Process {
        id: nativeStatusProc
        running: false
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["bash", "-lc", "pgrep -af '(^|/)easyeffects($| )' | grep -v ' -b ' | grep -v ' -q' >/dev/null"]
        onExited: (exitCode, _exitStatus) => {
            root.active = (exitCode === 0)
        }
    }

    Process {
        id: flatpakPsProc
        running: false
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["sh", "-c", "flatpak ps --columns=application"]
        stdout: StdioCollector {
            id: flatpakPsCollector
            onStreamFinished: {
                const t = (flatpakPsCollector.text ?? "")
                root.active = t.split("\n").some(l => l.trim().includes("com.github.wwmm.easyeffects"))
            }
        }
    }

    Process {
        id: pkillProc
        running: false
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["pkill", "easyeffects"]
        onExited: (_exitCode, _exitStatus) => {
            flatpakKillProc.running = true
            refreshStateTimer.restart()
        }
    }

    Process {
        id: flatpakKillProc
        running: false
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["sh", "-c", "flatpak kill com.github.wwmm.easyeffects"]
        onExited: (_exitCode, _exitStatus) => refreshStateTimer.restart()
    }
}
