import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Game mode")
    statusText: GameMode.active ? Translation.tr("Active") : ""
    toggled: GameMode.active
    buttonIcon: "gamepad"

    mainAction: () => {
        const inirEsc = `${Quickshell.env("HOME")}/.nix-profile/bin/inir`.replace(/'/g, "'\\''")
        Quickshell.execDetached([
            "bash",
            "-c",
            Config.subprocessPathShExport() + `exec '${inirEsc}' gamemode toggle`
        ])
    }

    StyledToolTip {
        text: GameMode.active 
            ? Translation.tr("Game mode") + " (" + (GameMode.manuallyActivated ? Translation.tr("manual") : Translation.tr("auto")) + ")"
            : Translation.tr("Game mode")
    }
}
