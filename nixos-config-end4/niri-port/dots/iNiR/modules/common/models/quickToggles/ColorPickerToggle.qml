import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Color picker")
    hasStatusText: false
    toggled: false
    icon: "colorize"

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start();
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
                ]);
            } else {
                Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport() + "exec hyprpicker -a"]);
            }
        }
    }

    tooltipText: Translation.tr("Color picker")
}
