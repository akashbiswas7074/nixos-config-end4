pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root
    property int shiftMode: 0 // 0: off, 1: on, 2: lock
    property list<int> shiftKeys: [42, 54] // Keycodes for Shift keys (left and right)
    property list<int> altKeys: [56, 100] // Keycodes for Alt keys (left and right) 
    property list<int> ctrlKeys: [29, 97] // Keycodes for Ctrl keys (left and right)
    readonly property string ydotoolBin: `${Quickshell.env("HOME")}/.nix-profile/bin/ydotool`
    readonly property string ydotooldBin: `${Quickshell.env("HOME")}/.nix-profile/bin/ydotoold`

    function runYdotool(args) {
        const ydEsc = ydotoolBin.replace(/'/g, "'\\''");
        const yddEsc = ydotooldBin.replace(/'/g, "'\\''");
        Quickshell.execDetached([
            "bash",
            "-c",
            Config.subprocessPathShExport()
                + `YD='${ydEsc}'; YDD='${yddEsc}'; `
                + `[ -x "$YD" ] || YD=ydotool; `
                + `[ -x "$YDD" ] || YDD=ydotoold; `
                + `pidof ydotoold >/dev/null 2>&1 || nohup "$YDD" >/tmp/inir-ydotoold.log 2>&1 < /dev/null & `
                + `sleep 0.05; exec "$YD" key --key-delay 0 ${args}`
        ]);
    }

    function releaseAllKeys() {
        const keycodes = Array.from(Array(249).keys());
        runYdotool(keycodes.map(keycode => `${keycode}:0`).join(" "))
        root.shiftMode = 0; // Reset shift mode
    }

    function releaseShiftKeys() {
        runYdotool(root.shiftKeys.map(keycode => `${keycode}:0`).join(" "))
        root.shiftMode = 0; // Reset shift mode
    }

    function press(keycode) {
        runYdotool(`${keycode}:1`);
    }

    function release(keycode) {
        runYdotool(`${keycode}:0`);
    }
}
