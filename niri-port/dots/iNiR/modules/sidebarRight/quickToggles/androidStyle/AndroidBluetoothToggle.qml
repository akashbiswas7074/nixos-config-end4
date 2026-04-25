import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Bluetooth

AndroidQuickToggleButton {
    id: root
    
    name: Translation.tr("Bluetooth")
    statusText: BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("No device")

    toggled: BluetoothStatus.enabled
    buttonIcon: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
    mainAction: () => {
        Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport()
            + `BTCTL_BIN="$(command -v bluetoothctl 2>/dev/null || true)"; `
            + `[ -n "$BTCTL_BIN" ] || BTCTL_BIN="$HOME/.nix-profile/bin/bluetoothctl"; `
            + `[ -x "$BTCTL_BIN" ] || BTCTL_BIN="/etc/profiles/per-user/$(id -un)/bin/bluetoothctl"; `
            + `[ -x "$BTCTL_BIN" ] || BTCTL_BIN="/run/current-system/sw/bin/bluetoothctl"; `
            + `[ -x "$BTCTL_BIN" ] || BTCTL_BIN="bluetoothctl"; `
            + `if ! command -v "$BTCTL_BIN" >/dev/null 2>&1 && [ ! -x "$BTCTL_BIN" ]; then `
            + `notify-send 'Bluetooth toggle failed' 'bluetoothctl not found' -a 'Bluetooth' -t 3000; exit 127; fi; `
            + `if "$BTCTL_BIN" show 2>/dev/null | grep -Eqi 'Powered:[[:space:]]*yes'; then "$BTCTL_BIN" power off; else "$BTCTL_BIN" power on; fi`]);
    }
    altAction: () => {
        root.openMenu()
    }
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to configure").arg(
            (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Bluetooth"))
            + (BluetoothStatus.activeDeviceCount > 1 ? ` +${BluetoothStatus.activeDeviceCount - 1}` : "")
        )
    }
}

