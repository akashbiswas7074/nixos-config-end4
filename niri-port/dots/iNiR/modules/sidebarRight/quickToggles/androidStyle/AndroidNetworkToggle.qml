import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root
    
    name: Translation.tr("Internet")
    statusText: Network.networkName

    toggled: Network.wifiStatus !== "disabled"
    buttonIcon: Network.materialSymbol
    mainAction: () => {
        Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport()
            + `NMCLI_BIN="$(command -v nmcli 2>/dev/null || true)"; `
            + `[ -n "$NMCLI_BIN" ] || NMCLI_BIN="$HOME/.nix-profile/bin/nmcli"; `
            + `[ -x "$NMCLI_BIN" ] || NMCLI_BIN="/etc/profiles/per-user/$(id -un)/bin/nmcli"; `
            + `[ -x "$NMCLI_BIN" ] || NMCLI_BIN="/run/current-system/sw/bin/nmcli"; `
            + `[ -x "$NMCLI_BIN" ] || NMCLI_BIN="nmcli"; `
            + `if ! command -v "$NMCLI_BIN" >/dev/null 2>&1 && [ ! -x "$NMCLI_BIN" ]; then `
            + `notify-send 'Wi-Fi toggle failed' 'nmcli not found' -a 'Network' -t 3000; exit 127; fi; `
            + `state="$("$NMCLI_BIN" radio wifi 2>/dev/null | tr '[:upper:]' '[:lower:]')"; `
            + `if [ "$state" = "enabled" ]; then "$NMCLI_BIN" radio wifi off; else "$NMCLI_BIN" radio wifi on; fi`]);
        Qt.callLater(Network.update);
    }
    altAction: () => root.openMenu()
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to configure").arg(Network.networkName)
    }
}

