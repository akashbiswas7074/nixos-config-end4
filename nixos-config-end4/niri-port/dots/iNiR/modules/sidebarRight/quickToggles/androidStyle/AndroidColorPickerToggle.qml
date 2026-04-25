import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Color picker")
    statusText: ""
    toggled: false
    buttonIcon: "colorize"

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start()
    }
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false 
        onTriggered: {
            if (CompositorService.isNiri) {
                Quickshell.execDetached([
                    "bash",
                    "-c",
                    Config.subprocessPathShExport()
                        + "NIRI_BIN=\"$HOME/.nix-profile/bin/niri\"; "
                        + "[ -x \"$NIRI_BIN\" ] || NIRI_BIN=\"niri\"; "
                        + "if \"$NIRI_BIN\" msg action pick-color >/dev/null 2>&1; then exit 0; fi; "
                        + "HYP_BIN=\"$HOME/.nix-profile/bin/hyprpicker\"; "
                        + "[ -x \"$HYP_BIN\" ] || HYP_BIN=\"hyprpicker\"; "
                        + "exec \"$HYP_BIN\" -a"
                ])
            } else {
                Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport() + "exec hyprpicker -a"])
            }
        }
    }

    StyledToolTip {
        text: Translation.tr("Color picker")
    }
}
