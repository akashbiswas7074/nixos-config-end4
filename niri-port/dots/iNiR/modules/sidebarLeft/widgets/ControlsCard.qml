pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitHeight: row.implicitHeight
    property bool nightLightLocalActive: Hyprsunset.active ?? false
    property string _settingsCommand: ""
    property string _lockCommand: ""
    property string _nightToggleCommand: ""

    function toggleDark(): void {
        const current = Config.options?.appearance?.customTheme?.darkmode ?? true
        Config.setNestedValue("appearance.customTheme.darkmode", !current)
    }

    function openSettings(): void {
        const inirEsc = StringUtils.shellSingleQuoteEscape(`${Quickshell.env("HOME")}/.nix-profile/bin/inir`)
        root._settingsCommand = Config.subprocessPathShExport()
            + `'${inirEsc}' settings >/tmp/inir-settings.log 2>&1; `
            + "echo SETTINGS:TRIGGERED"
        settingsProc.command = ["bash", "-c", root._settingsCommand]
        settingsProc.running = true
    }

    function toggleDnd(): void {
        const before = Notifications.silent ?? false
        Notifications.toggleSilent()
        const after = Notifications.silent ?? false
        console.log("[ControlsCard] DND toggle", before, "->", after)
    }

    function toggleGameMode(): void {
        const before = GameMode.active ?? false
        GameMode.toggle()
        const after = GameMode.active ?? false
        console.log("[ControlsCard] GameMode toggle", before, "->", after)
    }

    function toggleNightLight(): void {
        console.log("[ControlsCard] toggleNightLight() process-runner")
        if (CompositorService.isNiri) {
            const next = !root.nightLightLocalActive
            root.nightLightLocalActive = next
            const temp = (Config.options?.light?.night?.colorTemperature ?? 5000)
            if (next) {
                root._nightToggleCommand = Config.subprocessPathShExport()
                    + "pkill -x wlsunset >/dev/null 2>&1; "
                    + "WLSUNSET_BIN=\"$HOME/.nix-profile/bin/wlsunset\"; "
                    + "[ -x \"$WLSUNSET_BIN\" ] || WLSUNSET_BIN=\"wlsunset\"; "
                    + "nohup \"$WLSUNSET_BIN\" -T 6500 -t " + temp + " -s 00:00 -S 23:59 >/tmp/inir-nightlight.log 2>&1 < /dev/null & "
                    + "sleep 0.2; pidof wlsunset >/dev/null 2>&1 && echo NIGHT:ON || echo NIGHT:OFF"
            } else {
                root._nightToggleCommand = Config.subprocessPathShExport()
                    + "pkill -x wlsunset >/dev/null 2>&1; "
                    + "sleep 0.2; pidof wlsunset >/dev/null 2>&1 && echo NIGHT:ON || echo NIGHT:OFF"
            }
            nightToggleProc.command = ["bash", "-c", root._nightToggleCommand]
            nightToggleProc.running = true
            Hyprsunset.active = next
            return
        }
        Hyprsunset.toggle()
        root.nightLightLocalActive = Hyprsunset.active ?? false
    }

    Process {
        id: nightToggleProc
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                if (txt.length > 0)
                    console.log("[ControlsCard] nightToggle stdout:", txt)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                if (txt.length > 0)
                    console.warn("[ControlsCard] nightToggle stderr:", txt)
            }
        }
        onExited: (exitCode, exitStatus) => {
            console.log("[ControlsCard] nightToggle exit:", exitCode, exitStatus)
            Hyprsunset.fetchState()
        }
    }

    Process {
        id: lockProc
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                if (txt.length > 0)
                    console.log("[ControlsCard] lock stdout:", txt)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                if (txt.length > 0)
                    console.warn("[ControlsCard] lock stderr:", txt)
            }
        }
        onExited: (exitCode, exitStatus) => {
            console.log("[ControlsCard] lock exit:", exitCode, exitStatus)
        }
    }

    Process {
        id: settingsProc
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                if (txt.length > 0)
                    console.log("[ControlsCard] settings stdout:", txt)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const txt = text.trim()
                if (txt.length > 0)
                    console.warn("[ControlsCard] settings stderr:", txt)
            }
        }
        onExited: (exitCode, exitStatus) => {
            console.log("[ControlsCard] settings exit:", exitCode, exitStatus)
        }
    }

    function lockScreen(): void {
        const inirEsc = StringUtils.shellSingleQuoteEscape(`${Quickshell.env("HOME")}/.nix-profile/bin/inir`)
        root._lockCommand = Config.subprocessPathShExport()
            + `'${inirEsc}' lock activate >/tmp/inir-lock.log 2>&1; `
            + "echo LOCK:TRIGGERED"
        lockProc.command = ["bash", "-c", root._lockCommand]
        lockProc.running = true
    }

    Connections {
        target: Hyprsunset
        function onActiveChanged(): void {
            root.nightLightLocalActive = Hyprsunset.active ?? root.nightLightLocalActive
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        Item { Layout.fillWidth: true }

        // Toggles
        Toggle {
            btnIcon: "dark_mode"
            tip: Translation.tr("Dark mode")
            active: Appearance.m3colors?.darkmode ?? false
            runAction: () => root.toggleDark()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showDarkMode ?? true
        }
        Toggle {
            btnIcon: "do_not_disturb_on"
            tip: Translation.tr("Do not disturb")
            active: Notifications.silent ?? false
            runAction: () => root.toggleDnd()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showDnd ?? true
        }
        Toggle {
            btnIcon: "nightlight"
            tip: Translation.tr("Night light")
            active: CompositorService.isNiri ? root.nightLightLocalActive : (Hyprsunset.active ?? false)
            runAction: () => root.toggleNightLight()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showNightLight ?? true
        }
        Toggle {
            btnIcon: "sports_esports"
            tip: (GameMode.active ?? false) ? Translation.tr("Game mode (active)") : Translation.tr("Game mode")
            active: GameMode.active ?? false
            runAction: () => root.toggleGameMode()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showGameMode ?? true
        }

        Rectangle { 
            width: 1
            height: 24
            radius: 0.5
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                : Appearance.colors.colOutlineVariant
            opacity: 0.5
            Layout.leftMargin: 8
            Layout.rightMargin: 8
        }

        // Actions
        Action { btnIcon: "wifi"; tip: Translation.tr("Network"); runAction: function() { GlobalStates.sidebarLeftOpen = false; GlobalStates.requestWifiDialog = true }; visible: Config.options?.sidebar?.widgets?.controlsCard?.showNetwork ?? true }
        Action { btnIcon: "bluetooth"; tip: Translation.tr("Bluetooth"); runAction: function() { GlobalStates.sidebarLeftOpen = false; GlobalStates.requestBluetoothDialog = true }; visible: Config.options?.sidebar?.widgets?.controlsCard?.showBluetooth ?? true }
        Action { btnIcon: "settings"; tip: Translation.tr("Settings"); runAction: () => root.openSettings(); visible: Config.options?.sidebar?.widgets?.controlsCard?.showSettings ?? true }
        Action { btnIcon: "lock"; tip: Translation.tr("Lock"); runAction: () => root.lockScreen(); visible: Config.options?.sidebar?.widgets?.controlsCard?.showLock ?? true }

        Item { Layout.fillWidth: true }
    }

    component Toggle: RippleButton {
        property string btnIcon
        property string tip
        property bool active: false
        property var runAction

        implicitWidth: 40
        implicitHeight: 40
        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
            : Appearance.colors.colLayer1Hover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
            : Appearance.colors.colLayer1Active

        onClicked: {
            console.log("[ControlsCard] toggle clicked", btnIcon)
            if (runAction)
                runAction()
        }

        Behavior on colBackground {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                text: btnIcon
                iconSize: 22
                fill: active ? 1 : 0
                color: active
                    ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
                        : Appearance.colors.colPrimary)
                    : (Appearance.angelEverywhere ? Appearance.angel.colText
                        : Appearance.inirEverywhere ? Appearance.inir.colText
                        : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSurface
                        : Appearance.colors.colOnLayer0)
                Behavior on fill { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                Behavior on color { enabled: Appearance.animationsEnabled; animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            }
        }

        StyledToolTip { text: tip }
    }

    component Action: RippleButton {
        property string btnIcon
        property string tip
        property var runAction

        implicitWidth: 40
        implicitHeight: 40
        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover 
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active 
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active

        onClicked: {
            console.log("[ControlsCard] action clicked", btnIcon)
            if (runAction)
                runAction()
        }

        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                text: btnIcon
                iconSize: 20
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            }
        }

        StyledToolTip { text: tip }
    }
}
