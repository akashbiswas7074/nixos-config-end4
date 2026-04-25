import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Screen snip")
    statusText: ""
    toggled: false
    buttonIcon: "screenshot_region"

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start()
    }
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false
        onTriggered: {
            const inirEsc = `${Quickshell.env("HOME")}/.nix-profile/bin/inir`.replace(/'/g, "'\\''")
            Quickshell.execDetached([
                "bash",
                "-c",
                Config.subprocessPathShExport() + `exec '${inirEsc}' region screenshot`
            ])
        }
    }

    StyledToolTip {
        text: Translation.tr("Screen snip")
    }
}
