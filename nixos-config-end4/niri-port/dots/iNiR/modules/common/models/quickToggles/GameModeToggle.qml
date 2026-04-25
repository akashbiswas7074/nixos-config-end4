import QtQuick
import qs.services
import qs.modules.common

QuickToggleModel {
    name: Translation.tr("Game mode")
    toggled: GameMode.active
    icon: "gamepad"
    mainAction: () => Config.execInirDetached(["gamemode", "toggle"])
    tooltipText: Translation.tr("Game mode")
}
