pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import qs.modules.common
import qs.modules.common.functions
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root
    signal brightnessChanged()

    property var ddcMonitors: []
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
        screen
    }))

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function increaseBrightness(): void {
        const monitor = _monitorForBrightnessControl();
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const monitor = _monitorForBrightnessControl();
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.05);
    }

    /// Same screen selection as BrightnessOSD: Niri output name can disagree with `m.screen.name`
    /// or be empty briefly; fall back to primary / first screen so keys and IPC still work.
    function _monitorForBrightnessControl(): var {
        if (CompositorService.isNiri) {
            const screen = Quickshell.screens.find(s => s.name === NiriService.currentOutput)
                ?? GlobalStates.primaryScreen
                ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
            return screen ? getMonitorForScreen(screen) : undefined;
        }
        if (CompositorService.isHyprland) {
            const name = Hyprland.focusedMonitor?.name;
            const screen = (name ? Quickshell.screens.find(s => s.name === name) : null)
                ?? GlobalStates.primaryScreen
                ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
            return screen ? getMonitorForScreen(screen) : undefined;
        }
        return undefined;
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    Process {
        id: ddcProc

        command: ["bash", "-c", Config.subprocessPathShExport() + "exec ddcutil detect --brief"]
        environment: ({
            "PATH": Config.subprocessPath()
        })
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (data.startsWith("Display ")) {
                    const lines = data.split("\n").map(l => l.trim());
                    root.ddcMonitors.push({
                        model: lines.find(l => l.startsWith("Monitor:")).split(":")[2],
                        busNum: lines.find(l => l.startsWith("I2C bus:")).split("/dev/i2c-")[1]
                    });
                }
            }
        }
        onExited: root.ddcMonitorsChanged()
    }

    Process {
        id: setProc
        environment: ({
            "PATH": Config.subprocessPath()
        })
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property bool isDdc: {
            const match = root.ddcMonitors.find(m => screen.model?.includes(m.model) && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return !!match;
        }
        readonly property string busNum: {
            const match = root.ddcMonitors.find(m => screen.model?.includes(m.model) && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return match?.busNum ?? "";
        }
        property int rawMaxBrightness: 100
        property real brightness
        property real brightnessMultiplier: 1.0
        property real multipliedBrightness: Math.max(0, Math.min(1, brightness * ((Config.options?.light?.antiFlashbang?.enable ?? false) ? brightnessMultiplier : 1)))
        property bool ready: false
        property bool animateChanges: !monitor.isDdc

        onBrightnessChanged: {
            if (!monitor.ready) return;
            root.brightnessChanged();
        }

        Behavior on multipliedBrightness {
            enabled: monitor.animateChanges
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }
        onMultipliedBrightnessChanged: {
            if (monitor.animateChanges) syncBrightness();
            else setTimer.restart();
        }

        function initialize() {
            monitor.ready = false;
            initProc.command = isDdc
                ? ["bash", "-c", Config.subprocessPathShExport() + `exec ddcutil -b '${busNum}' getvcp 10 --brief`]
                : ["bash", "-c", Config.subprocessPathShExport()
                    + `USER_NAME="$(id -un)"; `
                    + `HOME_DIR="\${HOME:-$(getent passwd "$USER_NAME" | cut -d: -f6)}"; `
                    + `BR_BIN="$(command -v brightnessctl 2>/dev/null || true)"; `
                    + `[ -n "$BR_BIN" ] || BR_BIN="$HOME_DIR/.nix-profile/bin/brightnessctl"; `
                    + `[ -x "$BR_BIN" ] || BR_BIN="/etc/profiles/per-user/$USER_NAME/bin/brightnessctl"; `
                    + `[ -x "$BR_BIN" ] || BR_BIN="/run/current-system/sw/bin/brightnessctl"; `
                    + `[ -x "$BR_BIN" ] || BR_BIN="/run/wrappers/bin/brightnessctl"; `
                    + `if [ ! -x "$BR_BIN" ]; then echo "a b c"; echo "[Brightness] brightnessctl not found in service PATH=$PATH" >&2; `
                    + `else CUR="$("$BR_BIN" g 2>&1)"; MAX="$("$BR_BIN" m 2>&1)"; `
                    + `if [[ "$CUR" =~ ^[0-9]+$ && "$MAX" =~ ^[0-9]+$ ]]; then echo "a b c $CUR $MAX"; `
                    + `else echo "a b c"; echo "[Brightness] brightnessctl read failed bin=$BR_BIN current='$CUR' max='$MAX'" >&2; fi; fi`];
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            environment: ({
                "PATH": Config.subprocessPath()
            })
            stdout: SplitParser {
                onRead: data => {
                    const parts = data.trim().split(/\s+/);
                    const current = parseInt(parts[3], 10);
                    const max = parseInt(parts[4], 10);
                    if (!Number.isFinite(current) || !Number.isFinite(max) || max <= 0) {
                        console.warn("[Brightness] backlight init failed (no brightnessctl device or permission?). screen=", monitor.screen?.name, "line=", data);
                        monitor.rawMaxBrightness = 1;
                        monitor.brightness = 0;
                        monitor.ready = false;
                        return;
                    }
                    monitor.rawMaxBrightness = max;
                    monitor.brightness = current / max;
                    monitor.ready = true;
                }
            }
        }

        // We need a delay for DDC monitors because they can be quite slow and might act weird with rapid changes
        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 300 : 0
            onTriggered: {
                syncBrightness();
            }
        }

        function syncBrightness() {
            if (!monitor.ready || !Number.isFinite(monitor.rawMaxBrightness) || monitor.rawMaxBrightness <= 0)
                return;
            const brightnessValue = Math.max(monitor.multipliedBrightness, 0)
            const rawValueRounded = Math.max(Math.floor(brightnessValue * monitor.rawMaxBrightness), 1);
            setProc.command = isDdc
                ? ["bash", "-c", Config.subprocessPathShExport() + `exec ddcutil -b '${busNum}' setvcp 10 '${rawValueRounded}'`]
                : ["bash", "-c", Config.subprocessPathShExport()
                    + `USER_NAME="$(id -un)"; `
                    + `HOME_DIR="\${HOME:-$(getent passwd "$USER_NAME" | cut -d: -f6)}"; `
                    + `BR_BIN="$(command -v brightnessctl 2>/dev/null || true)"; `
                    + `[ -n "$BR_BIN" ] || BR_BIN="$HOME_DIR/.nix-profile/bin/brightnessctl"; `
                    + `[ -x "$BR_BIN" ] || BR_BIN="/etc/profiles/per-user/$USER_NAME/bin/brightnessctl"; `
                    + `[ -x "$BR_BIN" ] || BR_BIN="/run/current-system/sw/bin/brightnessctl"; `
                    + `[ -x "$BR_BIN" ] || BR_BIN="/run/wrappers/bin/brightnessctl"; `
                    + `if [ -x "$BR_BIN" ]; then exec "$BR_BIN" --class backlight s '${rawValueRounded}' --quiet; `
                    + `else echo "[Brightness] brightnessctl not found for set PATH=$PATH" >&2; exit 1; fi`];
            setProc.startDetached();
        }

        function setBrightness(value: real): void {
            value = Math.max(0, Math.min(1, value));
            monitor.brightness = value;
        }

        function setBrightnessMultiplier(value: real): void {
            monitor.brightnessMultiplier = value;
        }

        Component.onCompleted: {
            initialize();
        }

        onBusNumChanged: {
            initialize();
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    // Anti-flashbang
    property int workspaceAnimationDelay: 500
    property int contentSwitchDelay: 30
    property string screenshotDir: "/tmp/quickshell/brightness/antiflashbang"
    function brightnessMultiplierForLightness(x: real): real {
        // I hand picked some values and fitted an exponential curve for this
        // 6.600135 + 216.360356 * e^(-0.0811129189x)
        // Division by 100 is to normalize to [0, 1]
        return (6.600135 + 216.360356 * Math.pow(Math.E, -0.0811129189 * x)) / 100.0;
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property var modelData
            property string screenName: modelData.name
            property string screenshotPath: `${root.screenshotDir}/screenshot-${screenName}.png`
            Connections {
                enabled: (Config.options?.light?.antiFlashbang?.enable ?? false) && Appearance.m3colors.darkmode && CompositorService.isHyprland
                target: CompositorService.isHyprland ? Hyprland : null
                function onRawEvent(event) {
                    if (["activewindowv2", "windowtitlev2"].includes(event.name)) {
                        screenshotTimer.interval = root.contentSwitchDelay;
                        screenshotTimer.restart();
                    } else if (["workspacev2"].includes(event.name)) {
                        screenshotTimer.interval = root.workspaceAnimationDelay;
                        screenshotTimer.restart();
                    }
                }
            }

            // Niri support for anti-flashbang
            Connections {
                enabled: (Config.options?.light?.antiFlashbang?.enable ?? false) && Appearance.m3colors.darkmode && CompositorService.isNiri
                target: CompositorService.isNiri ? NiriService : null
                function onActiveWindowChanged() {
                    screenshotTimer.interval = root.contentSwitchDelay;
                    screenshotTimer.restart();
                }
                function onFocusedWorkspaceIdChanged() {
                    screenshotTimer.interval = root.workspaceAnimationDelay;
                    screenshotTimer.restart();
                }
            }

            Timer {
                id: screenshotTimer
                interval: 700 // This is what I have for a Hyprland ws anim
                onTriggered: {
                    screenshotProc.running = false;
                    screenshotProc.running = true;
                }
            }

            Process {
                id: screenshotProc
                command: ["bash", "-c", 
                    `mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}'`
                    + ` && grim -o '${StringUtils.shellSingleQuoteEscape(screenScope.screenName)}' -`
                    + ` | magick png:- -colorspace Gray -format "%[fx:mean*100]" info:`
                ]
                environment: ({
                    "PATH": Config.subprocessPath()
                })
                stdout: StdioCollector {
                    id: lightnessCollector
                    onStreamFinished: {
                        // No cleanup needed - we pipe directly to magick without saving file
                        const lightness = lightnessCollector.text
                        const newMultiplier = root.brightnessMultiplierForLightness(parseFloat(lightness))
                        Brightness.getMonitorForScreen(screenScope.modelData).setBrightnessMultiplier(newMultiplier)
                    }
                }
            }
        }
    }

    // External trigger points

    IpcHandler {
        target: "brightness"

        function increment(): void {
            root.increaseBrightness();
        }

        function decrement(): void {
            root.decreaseBrightness();
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "brightnessIncrease"
                description: "Increase brightness"
                onPressed: root.increaseBrightness()
            }

            GlobalShortcut {
                name: "brightnessDecrease"
                description: "Decrease brightness"
                onPressed: root.decreaseBrightness()
            }
        }
    }
}
