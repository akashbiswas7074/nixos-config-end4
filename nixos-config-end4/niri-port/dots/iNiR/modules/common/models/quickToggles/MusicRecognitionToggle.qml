import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    toggled: SongRec.running
    property bool sourceIsMonitor: SongRec.monitorSource === SongRec.MonitorSource.Monitor

    name: Translation.tr("Identify Music")
    statusText: !SongRec.songrecAvailable
        ? Translation.tr("Install songrec")
        : (toggled ? Translation.tr("Listening...") : sourceIsMonitor ? Translation.tr("System sound") : Translation.tr("Microphone"))
    icon: toggled ? "music_cast" : (sourceIsMonitor ? "music_note" : "frame_person_mic")

    tooltipText: !SongRec.songrecAvailable
        ? Translation.tr("Install songrec to use music recognition")
        : Translation.tr("Recognize music | Right-click to toggle source")

    mainAction: () => {
        if (!SongRec.songrecAvailable) {
            return
        }
        SongRec.toggleRunning()
    }
    altAction: () => {
        SongRec.toggleMonitorSource()
    }
}
