import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root
    
    property bool auto: Config.options?.light?.night?.automatic ?? false

    name: Translation.tr("Night Light")
    statusText: (auto ? Translation.tr("Auto, ") : "") + (toggled ? Translation.tr("Active") : Translation.tr("Inactive"))

    toggled: Hyprsunset.active
    buttonIcon: auto ? "night_sight_auto" : "bedtime"
    
    mainAction: () => {
        if (CompositorService.isNiri) {
            const temp = Config.options?.light?.night?.colorTemperature ?? 5000
            Quickshell.execDetached([
                "bash",
                "-c",
                Config.subprocessPathShExport()
                    + "if pidof wlsunset >/dev/null 2>&1; then "
                    + "pkill -x wlsunset; "
                    + "else "
                    + "WLSUNSET_BIN=\"$HOME/.nix-profile/bin/wlsunset\"; [ -x \"$WLSUNSET_BIN\" ] || WLSUNSET_BIN=\"wlsunset\"; "
                    + "nohup \"$WLSUNSET_BIN\" -T 6500 -t " + temp + " -s 00:00 -S 23:59 >/tmp/inir-nightlight.log 2>&1 < /dev/null & "
                    + "fi"
            ])
            Hyprsunset.fetchState()
            return
        }
        Hyprsunset.toggle()
    }

    altAction: () => {
        root.openMenu()
    }

    Component.onCompleted: {
        Hyprsunset.fetchState()
    }
    
    StyledToolTip {
        text: Translation.tr("Night Light | Right-click to configure")
    }
}

