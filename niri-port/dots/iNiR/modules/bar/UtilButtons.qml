import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    // NixOS: execDetached / niri / hyprpicker need resolvable paths (see Quickshell INITIAL_ENVIRONMENT)
    readonly property string _bash: Config.nixosSystemProfileBin + "/bash"
    readonly property string _fish: `${root._homeNoProto}/.nix-profile/bin/fish`
    readonly property string _niri: Config.nixosSystemProfileBin + "/niri"
    readonly property string _hyprpicker: Config.nixosSystemProfileBin + "/hyprpicker"
    readonly property string _homeNoProto: FileUtils.trimFileProtocol(Directories.home)
    property bool _recordingActive: false
    property bool borderless: Config.options?.bar?.borderless ?? false
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: rowLayout.implicitHeight

    function refreshRecordingState() {
        if (!recordStatusProc.running)
            recordStatusProc.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshRecordingState()
    }

    Process {
        id: recordStatusProc
        command: [Config.nixosSystemProfileBin + "/pgrep", "-x", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            root._recordingActive = (exitCode === 0)
        }
    }

    Component.onCompleted: Qt.callLater(root.refreshRecordingState)

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.centerIn: parent

        Loader {
            active: Config.options?.bar?.utilButtons?.showScreenSnip ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    const grimProfile = `${root._homeNoProto}/.nix-profile/bin/grim`
                    const grimPerUser = "/etc/profiles/per-user/akashbiswas/bin/grim"
                    const wlcopySystem = `${Config.nixosSystemProfileBin}/wl-copy`
                    const wlcopyProfile = `${root._homeNoProto}/.nix-profile/bin/wl-copy`
                    const wlcopyPerUser = "/etc/profiles/per-user/akashbiswas/bin/wl-copy"
                    Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport()
                        + `g=''; for c in '${Config.nixosSystemProfileBin}/grim' '${StringUtils.shellSingleQuoteEscape(grimProfile)}' '${StringUtils.shellSingleQuoteEscape(grimPerUser)}' grim; do if [[ "$c" == grim ]] || [[ -x "$c" ]]; then g="$c"; break; fi; done; `
                        + `w=''; for c in '${StringUtils.shellSingleQuoteEscape(wlcopySystem)}' '${StringUtils.shellSingleQuoteEscape(wlcopyProfile)}' '${StringUtils.shellSingleQuoteEscape(wlcopyPerUser)}' wl-copy; do if [[ "$c" == wl-copy ]] || [[ -x "$c" ]]; then w="$c"; break; fi; done; `
                        + `if [[ -z "$g" || -z "$w" ]]; then notify-send 'Screenshot failed' 'grim or wl-copy not found' -a 'Util Buttons' -t 4000; exit 127; fi; `
                        + `if "$g" - | "$w"; then notify-send 'Screenshot copied' 'Full screen copied to clipboard' -a 'Screenshot' -i camera-photo -t 2500; `
                        + `else notify-send 'Screenshot failed' 'Could not capture full screen' -a 'Util Buttons' -t 4000; fi`])
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showScreenRecord ?? false
            visible: active
            sourceComponent: Item {
                id: recordButtonWrapper
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: screenRecordButton.implicitWidth
                implicitHeight: screenRecordButton.implicitHeight

                property bool isRecording: root._recordingActive

                CircleUtilButton {
                    id: screenRecordButton
                    anchors.fill: parent

                    onClicked: {
                        const rec = StringUtils.shellSingleQuoteEscape(FileUtils.trimFileProtocol(Directories.recordScriptPath))
                        Quickshell.execDetached([root._fish, "-c", `'${rec}' --fullscreen --sound`])
                        Qt.callLater(root.refreshRecordingState)
                    }

                    Item {
                        anchors.fill: parent

                        MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Qt.AlignHCenter
                            fill: 1
                            text: "videocam"
                            iconSize: Appearance.font.pixelSize.large
                            color: recordButtonWrapper.isRecording
                                ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                                : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
                        }

                        // Pulsating indicator dot when recording
                        Rectangle {
                            visible: recordButtonWrapper.isRecording
                            width: 6
                            height: 6
                            radius: 3
                            color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                            anchors {
                                top: parent.top
                                right: parent.right
                            }

                            SequentialAnimation on opacity {
                                running: recordButtonWrapper.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showColorPicker ?? false
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    if (CompositorService.isNiri) {
                        const niriProfile = `${root._homeNoProto}/.nix-profile/bin/niri`
                        const niriPerUser = "/etc/profiles/per-user/akashbiswas/bin/niri"
                        const hyprProfile = `${root._homeNoProto}/.nix-profile/bin/hyprpicker`
                        const hyprPerUser = "/etc/profiles/per-user/akashbiswas/bin/hyprpicker"
                        Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport()
                            + `picked=0; `
                            + `for n in '${StringUtils.shellSingleQuoteEscape(root._niri)}' '${StringUtils.shellSingleQuoteEscape(niriProfile)}' '${StringUtils.shellSingleQuoteEscape(niriPerUser)}' niri; do `
                            + `if [[ "$n" == niri ]] || [[ -x "$n" ]]; then "$n" msg action pick-color >/dev/null 2>&1 && picked=1 && break; fi; `
                            + `done; `
                            + `if [[ "$picked" -eq 1 ]]; then exit 0; fi; `
                            + `for h in '${StringUtils.shellSingleQuoteEscape(root._hyprpicker)}' '${StringUtils.shellSingleQuoteEscape(hyprProfile)}' '${StringUtils.shellSingleQuoteEscape(hyprPerUser)}' hyprpicker; do `
                            + `if [[ "$h" == hyprpicker ]] || [[ -x "$h" ]]; then exec "$h" -a; fi; `
                            + `done; `
                            + `notify-send 'Color picker failed' 'No supported picker backend found' -a 'Util Buttons' -t 4000`])
                    } else {
                        const hyprProfile = `${root._homeNoProto}/.nix-profile/bin/hyprpicker`
                        const hyprPerUser = "/etc/profiles/per-user/akashbiswas/bin/hyprpicker"
                        Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport()
                            + `if [[ -x '${StringUtils.shellSingleQuoteEscape(root._hyprpicker)}' ]]; then exec '${StringUtils.shellSingleQuoteEscape(root._hyprpicker)}' -a; `
                            + `elif [[ -x '${StringUtils.shellSingleQuoteEscape(hyprProfile)}' ]]; then exec '${StringUtils.shellSingleQuoteEscape(hyprProfile)}' -a; `
                            + `elif [[ -x '${StringUtils.shellSingleQuoteEscape(hyprPerUser)}' ]]; then exec '${StringUtils.shellSingleQuoteEscape(hyprPerUser)}' -a; `
                            + `elif command -v hyprpicker >/dev/null 2>&1; then exec hyprpicker -a; `
                            + `else notify-send 'Color picker failed' 'hyprpicker binary not found' -a 'Util Buttons' -t 4000; fi`])
                    }
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "colorize"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showNotepad ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    GlobalStates.sidebarRightOpen = true
                    // Ensure bottom widget group is expanded and focused on Notepad tab (index 2)
                    Persistent.states.sidebar.bottomGroup.collapsed = false
                    Persistent.states.sidebar.bottomGroup.tab = 2
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "edit_note"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showKeyboardToggle ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "keyboard"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        // Keyboard layout switch (Niri only)
        Loader {
            active: (Config.options?.bar?.utilButtons?.showKeyboardLayoutSwitch ?? false)
                    && CompositorService.isNiri
                    && NiriService.keyboardLayoutNames.length > 1
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: NiriService.switchLayout()
                Item {
                    anchors.fill: parent
                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: "language"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        Loader {
            readonly property bool micInUse: Privacy.micActive || (Audio?.micBeingAccessed ?? false)
            active: (Config.options?.bar?.utilButtons?.showMicToggle ?? false) || micInUse
            visible: active
            sourceComponent: CircleUtilButton {
                id: micButton
                Layout.alignment: Qt.AlignVCenter

                readonly property bool isMuted: Audio.micMuted
                readonly property bool isInUse: (Privacy.micActive || (Audio?.micBeingAccessed ?? false))

                onClicked: Audio.toggleMicMute()

                Item {
                    anchors.fill: parent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: micButton.isInUse ? 1 : 0
                        text: micButton.isMuted ? "mic_off" : "mic"
                        iconSize: Appearance.font.pixelSize.large
                        color: micButton.isInUse && !micButton.isMuted
                            ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                            : (Appearance.angelEverywhere ? Appearance.angel.colText
                             : Appearance.inirEverywhere ? Appearance.inir.colOnLayer2
                             : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSurface
                             : Appearance.colors.colOnLayer2)
                    }

                    Rectangle {
                        visible: micButton.isInUse && !micButton.isMuted
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                        anchors { top: parent.top; right: parent.right }

                        SequentialAnimation on opacity {
                            running: micButton.isInUse && !micButton.isMuted
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                }
            }
        }

        // Screen casting toggle (PR #29 by levpr1c)
        // Toggles Niri dynamic casting to configured output
        Loader {
            active: (Config.options?.bar?.utilButtons?.showScreenCast ?? false)
                    && CompositorService.isNiri
            visible: active
            sourceComponent: CircleUtilButton {
                id: screenCastButton
                Layout.alignment: Qt.AlignVCenter

                readonly property bool isCasting: Persistent.states.screenCast.active

                onClicked: {
                    const output = Config.options?.bar?.utilButtons?.screenCastOutput ?? "HDMI-A-1"

                    if (isCasting) {
                        Quickshell.execDetached([root._niri, "msg", "action", "clear-dynamic-cast-target"])
                        Persistent.states.screenCast.active = false
                    } else {
                        Quickshell.execDetached([root._niri, "msg", "action", "set-dynamic-cast-monitor", output])
                        Persistent.states.screenCast.active = true
                    }
                }

                Item {
                    anchors.fill: parent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: screenCastButton.isCasting ? 1 : 0
                        text: "visibility"
                        iconSize: Appearance.font.pixelSize.large
                        color: screenCastButton.isCasting
                            ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                            : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
                    }

                    Rectangle {
                        visible: screenCastButton.isCasting
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                        anchors {
                            top: parent.top
                            right: parent.right
                        }

                        SequentialAnimation on opacity {
                            running: screenCastButton.isCasting
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showDarkModeToggle ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    MaterialThemeLoader.setDarkMode(!Appearance.m3colors.darkmode)
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showPerformanceProfileToggle ?? false
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                            break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                            break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                            break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: switch(PowerProfiles.profile) {
                        case PowerProfile.PowerSaver: return "energy_savings_leaf"
                        case PowerProfile.Balanced: return "settings_slow_motion"
                        case PowerProfile.Performance: return "local_fire_department"
                    }
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
