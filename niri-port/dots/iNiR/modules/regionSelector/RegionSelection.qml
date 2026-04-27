pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.regionSelector as WaffleRegion
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: true
    color: "transparent"
    WlrLayershell.namespace: "quickshell:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    enum SnipAction { Copy, Edit, Search, CharRecognition, Record, RecordWithSound } 
    enum SelectionMode { RectCorners, Circle }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    signal dismiss()
    
    readonly property bool useNiri: CompositorService.isNiri

    property string screenshotDir: Directories.screenshotTemp
    property string imageSearchEngineBaseUrl: Config.options?.search?.imageSearch?.imageSearchEngineBaseUrl ?? "https://lens.google.com/uploadbyurl?url="
    property string fileUploadApiEndpoint: Config.options?.search?.imageSearch?.fileUploadApiEndpoint ?? "https://0x0.st"
    property string fileUploadApiFallback: Config.options?.search?.imageSearch?.fileUploadApiFallback ?? "https://litterbox.catbox.moe/resources/internals/api.php"
    property string fileUploadApiFallback2: Config.options?.search?.imageSearch?.fileUploadApiFallback2 ?? "https://catbox.moe/user/api.php"
    readonly property string effectiveImageSearchEngineBaseUrl: {
        const configured = imageSearchEngineBaseUrl ?? ""
        return configured === "" ? "https://lens.google.com/uploadbyurl?url=" : configured
    }

    // Tri-style color support
    property color overlayColor: Appearance.angelEverywhere ? "#55000000"
        : Appearance.inirEverywhere ? "#88000000"
        : Appearance.auroraEverywhere ? "#66000000" : "#88111111"
    property color brightText: Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
        : (Appearance.m3colors.darkmode ? Appearance.colors.colOnLayer0 : Appearance.colors.colLayer0)
    property color brightSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.auroraEverywhere ? Appearance.aurora.colTextSecondary
        : (Appearance.m3colors.darkmode ? Appearance.colors.colSecondary : Appearance.colors.colOnSecondary)
    property color brightTertiary: Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
        : (Appearance.m3colors.darkmode ? Appearance.colors.colTertiary : Qt.lighter(Appearance.colors.colPrimary))
    property color selectionBorderColor: Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : ColorUtils.mix(brightText, brightSecondary, 0.5)
    property color selectionFillColor: Appearance.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colPrimary, 0.8)
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
        : "#33ffffff"
    property color windowBorderColor: brightSecondary
    property color windowFillColor: ColorUtils.transparentize(windowBorderColor, 0.85)
    property color imageBorderColor: brightTertiary
    property color imageFillColor: ColorUtils.transparentize(imageBorderColor, 0.85)
    property color onBorderColor: Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0 : "#ff000000"
    readonly property var windows: useNiri
        ? (NiriService.windows || [])
        : [...HyprlandData.windowList].sort((a, b) => {
            // Sort floating=true windows before others
            if (a.floating === b.floating) return 0;
            return a.floating ? -1 : 1;
        })
    readonly property var layers: useNiri ? ({}) : HyprlandData.layers
    readonly property real falsePositivePreventionRatio: 0.5

    readonly property var hyprlandMonitor: CompositorService.isHyprland ? null : null // Disabled for Niri
    readonly property real monitorScale: root.useNiri
        ? ((NiriService.displayScales && NiriService.displayScales[screen.name] !== undefined)
            ? NiriService.displayScales[screen.name]
            : 1)
        : (hyprlandMonitor ? hyprlandMonitor.scale : 1)
    readonly property real monitorOffsetX: root.useNiri ? 0 : (hyprlandMonitor ? hyprlandMonitor.x : 0)
    readonly property real monitorOffsetY: root.useNiri ? 0 : (hyprlandMonitor ? hyprlandMonitor.y : 0)
    property int activeWorkspaceId: root.useNiri 
        ? (NiriService.focusedWorkspaceIndex ?? 0)
        : (hyprlandMonitor && hyprlandMonitor.activeWorkspace ? hyprlandMonitor.activeWorkspace.id : 0)
    property string screenshotPath: `${root.screenshotDir}/image-${screen.name}`
    property bool screenshotReady: false
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property real dragDiffX: 0
    property real dragDiffY: 0
    property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)
    property bool dragging: false
    property list<point> points: []
    property var mouseButton: null
    property var imageRegions: []
    readonly property list<var> windowRegions: {
        if (root.useNiri) {
            const wins = NiriService.windows || []
            const regions = []
            for (let i = 0; i < wins.length; ++i) {
                const w = wins[i]
                const layout = w.layout
                if (!layout || !layout.tile_pos_in_workspace_view || !layout.tile_size)
                    continue

                const pos = layout.tile_pos_in_workspace_view
                const size = layout.tile_size

                regions.push({
                    at: [pos[0], pos[1]],
                    size: [size[0], size[1]],
                    class: w.app_id || w.appId || "",
                    title: w.title || "",
                })
            }
            return regions
        }

        return RegionFunctions.filterWindowRegionsByLayers(
            root.windows.filter(w => w.workspace.id === root.activeWorkspaceId),
            root.layerRegions
        ).map(window => {
            return {
                at: [window.at[0] - root.monitorOffsetX, window.at[1] - root.monitorOffsetY],
                size: [window.size[0], window.size[1]],
                class: window.class,
                title: window.title,
            }
        })
    }
    readonly property list<var> layerRegions: {
        if (root.useNiri)
            return [];

        const layersOfThisMonitor = root.layers[root.hyprlandMonitor.name]
        const topLayers = layersOfThisMonitor?.levels["2"]
        if (!topLayers) return [];
        const nonBarTopLayers = topLayers
            .filter(layer => !(layer.namespace.includes(":bar") || layer.namespace.includes(":verticalBar") || layer.namespace.includes(":dock")))
            .map(layer => {
            return {
                at: [layer.x, layer.y],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }
        })
        const offsetAdjustedLayers = nonBarTopLayers.map(layer => {
            return {
                at: [layer.at[0] - root.monitorOffsetX, layer.at[1] - root.monitorOffsetY],
                size: layer.size,
                namespace: layer.namespace,
            }
        });
        return offsetAdjustedLayers;
    }

    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    property bool enableWindowRegions: (Config.options?.regionSelector?.targetRegions?.windows ?? true) && !isCircleSelection
    property bool enableLayerRegions: (Config.options?.regionSelector?.targetRegions?.layers ?? true) && !isCircleSelection
    property bool enableContentRegions: Config.options?.regionSelector?.targetRegions?.content ?? true
    property real targetRegionOpacity: Config.options?.regionSelector?.targetRegions?.opacity ?? 0.5
    property real contentRegionOpacity: Config.options?.regionSelector?.targetRegions?.contentRegionOpacity ?? 0.3

    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0
    function targetedRegionValid() {
        return (root.targetedRegionX >= 0 && root.targetedRegionY >= 0)
    }
    function setRegionToTargeted() {
        const padding = Config.options?.regionSelector?.targetRegions?.selectionPadding ?? 2; // Make borders not cut off n stuff
        root.regionX = root.targetedRegionX - padding;
        root.regionY = root.targetedRegionY - padding;
        root.regionWidth = root.targetedRegionWidth + padding * 2;
        root.regionHeight = root.targetedRegionHeight + padding * 2;
    }

    function updateTargetedRegion(x, y) {
        function regionContainsPoint(region) {
            if (!region || !region.at || !region.size)
                return false;
            if (region.at.length < 2 || region.size.length < 2)
                return false;

            const rx = region.at[0];
            const ry = region.at[1];
            const rw = region.size[0];
            const rh = region.size[1];
            return rx <= x && x <= rx + rw && ry <= y && y <= ry + rh;
        }

        // Image regions
        const clickedRegion = root.imageRegions.find(region => regionContainsPoint(region));
        if (clickedRegion) {
            root.targetedRegionX = clickedRegion.at[0];
            root.targetedRegionY = clickedRegion.at[1];
            root.targetedRegionWidth = clickedRegion.size[0];
            root.targetedRegionHeight = clickedRegion.size[1];
            return;
        }

        // Layer regions
        const clickedLayer = root.layerRegions.find(region => regionContainsPoint(region));
        if (clickedLayer) {
            root.targetedRegionX = clickedLayer.at[0];
            root.targetedRegionY = clickedLayer.at[1];
            root.targetedRegionWidth = clickedLayer.size[0];
            root.targetedRegionHeight = clickedLayer.size[1];
            return;
        }

        // Window regions
        const clickedWindow = root.windowRegions.find(region => regionContainsPoint(region));
        if (clickedWindow) {
            root.targetedRegionX = clickedWindow.at[0];
            root.targetedRegionY = clickedWindow.at[1];
            root.targetedRegionWidth = clickedWindow.size[0];
            root.targetedRegionHeight = clickedWindow.size[1];
            return;
        }

        root.targetedRegionX = -1;
        root.targetedRegionY = -1;
        root.targetedRegionWidth = 0;
        root.targetedRegionHeight = 0;
    }

    function regionMatchesTarget(region) {
        if (!region || !region.at || !region.size)
            return false;
        if (region.at.length < 2 || region.size.length < 2)
            return false;

        return root.targetedRegionX === region.at[0]
            && root.targetedRegionY === region.at[1]
            && root.targetedRegionWidth === region.size[0]
            && root.targetedRegionHeight === region.size[1];
    }

    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)
    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)

    /// Wayland / grim output (Niri: match `niri msg -j outputs` when possible).
    readonly property string grimOutputName: root.useNiri
        ? RegionFunctions.niriGrimOutputName(root.screen, NiriService.outputs)
        : (root.screen.name || "")
    readonly property int _niriOutputCount: {
        const o = NiriService.outputs;
        return (o && typeof o === "object") ? Object.keys(o).length : 0;
    }
    readonly property string _homePathNoProto: FileUtils.trimFileProtocol(Directories.home)
    readonly property string _grimToFileBash: {
        const pathPre = Config.subprocessPathShExport();
        const d = StringUtils.shellSingleQuoteEscape(root.screenshotDir);
        const f = StringUtils.shellSingleQuoteEscape(root.screenshotPath);
        const o = root.grimOutputName;
        if (root.useNiri && root._niriOutputCount > 1 && (!o || o.length === 0)) {
            const body = StringUtils.shellSingleQuoteEscape(
                "Could not match this monitor to a Niri output for grim (multi-monitor). Try: niri msg -j outputs");
            return pathPre + `notify-send 'Region selector' ${body} -a 'Region Selector' -t 6000; exit 3`;
        }
        const oArg = (o && o.length > 0) ? ` -o '${StringUtils.shellSingleQuoteEscape(o)}'` : "";
        const grimCandidates = [
            `${Config.nixosSystemProfileBin}/grim`,
            `${root._homePathNoProto}/.nix-profile/bin/grim`,
            `/etc/profiles/per-user/akashbiswas/bin/grim`,
            "grim"
        ].map(StringUtils.shellSingleQuoteEscape).join(" ");
        return pathPre + `mkdir -p '${d}' && ` +
            `g=''; for c in ${grimCandidates}; do if [[ "$c" == grim ]] || [[ -x "$c" ]]; then g="$c"; [[ "$c" != grim ]] && break; fi; done; ` +
            `if [[ -z "$g" ]]; then notify-send 'Region search failed' 'grim binary not found' -a 'Region Selector' -t 5000; exit 127; fi; ` +
            `if "$g"${oArg} '${f}' 2>/tmp/inir-grim.err; then exit 0; fi; ` +
            `if "$g" '${f}' 2>>/tmp/inir-grim.err; then exit 0; fi; ` +
            `err="$(${Config.nixosSystemProfileBin}/tail -n 1 /tmp/inir-grim.err 2>/dev/null)"; ` +
            `if [[ -n "$err" ]]; then notify-send 'Region search failed' "$err" -a 'Region Selector' -t 5000; fi; ` +
            `exit 1`;
    }
    property bool _retriedNiriScreencap: false

    /// If `niri msg -j outputs` was not ready on first grim run, try again when JSON arrives.
    Connections {
        target: NiriService
        function onOutputsChanged() {
            if (!root.useNiri || root.screenshotReady) {
                return;
            }
            if (screenshotProc.running) {
                return;
            }
            const o = NiriService.outputs
            if (!o || Object.keys(o).length === 0) {
                return;
            }
            if (root._retriedNiriScreencap) {
                return;
            }
            root._retriedNiriScreencap = true
            Qt.callLater(() => { screenshotProc.running = true });
        }
    }

    Component.onCompleted: {
        root.screenshotReady = false
        screenshotProc.running = true
    }

    Process {
        id: screenshotProc
        running: false
        command: ["bash", "-c", root._grimToFileBash]
        onExited: (exitCode, exitStatus) => {
            const o = NiriService.outputs
            const haveOutputs = o && Object.keys(o).length > 0
            const willRetryNiriScreencap = exitCode !== 0 && root.useNiri && !root._retriedNiriScreencap
                && haveOutputs
            if (exitCode !== 0) {
                root.screenshotReady = false
                if (exitCode === 3) {
                    // Bash already notified (ambiguous multi-monitor or similar)
                } else if (willRetryNiriScreencap) {
                    root._retriedNiriScreencap = true
                    // Outputs may have loaded after the command was first bound; recapture with resolved name
                    Qt.callLater(() => { screenshotProc.running = true });
                } else if (root.useNiri && !haveOutputs) {
                    // Wait for NiriService.onOutputsChanged (or next failure) instead of a false "grim failed" toast
                } else {
                    Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport()
                        + `exec notify-send 'Region search failed' 'grim failed to capture the screen' -a 'Region Selector' -t 4000`])
                }
            } else {
                root.screenshotReady = true
            }
            if (root.enableContentRegions && (exitCode === 0 || !willRetryNiriScreencap)) {
                imageDetectionProcess.running = true;
            }
            root.preparationDone = !checkRecordingProc.running;
        }
    }
    property bool isRecording: root.action === RegionSelection.SnipAction.Record || root.action === RegionSelection.SnipAction.RecordWithSound
    property bool recordingShouldStop: false
    Process {
        id: checkRecordingProc
        running: isRecording
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["pidof", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            root.preparationDone = !screenshotProc.running
            root.recordingShouldStop = (exitCode === 0);
        }
    }
    property bool preparationDone: false
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        if (root.isRecording && root.recordingShouldStop) {
            Quickshell.execDetached(["bash", "-c", Config.subprocessPathShExport()
                + `exec bash '${StringUtils.shellSingleQuoteEscape(FileUtils.trimFileProtocol(Directories.recordScriptPath))}'`]);
            root.dismiss();
            return;
        }
        Qt.callLater(() => { root.visible = true; });
    }

    Process {
        id: imageDetectionProcess
        environment: ({
            "PATH": Config.subprocessPath()
        })
        command: ["bash", "-c", `${Directories.scriptsPath}/images/find-regions-venv.sh ` 
            + `--image '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' ` 
            + `--max-width ${Math.round(root.screen.width * root.falsePositivePreventionRatio)} ` 
            + `--max-height ${Math.round(root.screen.height * root.falsePositivePreventionRatio)} `]
        stdout: StdioCollector {
            id: imageDimensionCollector
            onStreamFinished: {
                try {
                    const text = imageDimensionCollector.text.trim()
                    if (text) {
                        imageRegions = RegionFunctions.filterImageRegions(
                            JSON.parse(text),
                            root.windowRegions
                        );
                    }
                } catch (e) {
                    imageRegions = []
                }
            }
        }
    }

    function snip() {
        if (root.regionWidth <= 0 || root.regionHeight <= 0) {
            root.dismiss();
            return;
        }

        root.regionX = Math.max(0, Math.min(root.regionX, root.screen.width - root.regionWidth));
        root.regionY = Math.max(0, Math.min(root.regionY, root.screen.height - root.regionHeight));
        root.regionWidth = Math.max(0, Math.min(root.regionWidth, root.screen.width - root.regionX));
        root.regionHeight = Math.max(0, Math.min(root.regionHeight, root.screen.height - root.regionY));

        if (root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Edit) {
            root.action = root.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }

        const rx = Math.round(root.regionX * root.monitorScale);
        const ry = Math.round(root.regionY * root.monitorScale);
        const rw = Math.round(root.regionWidth * root.monitorScale);
        const rh = Math.round(root.regionHeight * root.monitorScale);
        const cropBase = `magick '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' `
            + `-crop ${rw}x${rh}+${rx}+${ry}`
        const cropToStdout = `${cropBase} -`
        const cropInPlace = `${cropBase} '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}'`
        const cleanup = `rm '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}'`
        const slurpRegion = `${rx},${ry} ${rw}x${rh}`
        const screenshotSaveDir = StringUtils.shellSingleQuoteEscape(Directories.screenshotsPath)
        const uploadAndGetUrl = (filePath) => {
            const escaped = StringUtils.shellSingleQuoteEscape(filePath)
            const primary = `"$CURL_BIN" -sf --max-time 10 -F file=@'${escaped}' ${root.fileUploadApiEndpoint}`
            const fallback1 = `"$CURL_BIN" -s --max-time 15 -F reqtype=fileupload -F time=1h -F "fileToUpload=@'${escaped}'" ${root.fileUploadApiFallback}`
            const fallback2 = `"$CURL_BIN" -s --max-time 15 -F reqtype=fileupload -F "fileToUpload=@'${escaped}'" ${root.fileUploadApiFallback2}`
            // Try primary, then fallback1, then fallback2 and extract first URL via bash regex.
            return `resp="$(${primary} 2>/dev/null || true)"; url=""; `
                + `if [[ "$resp" =~ (https?://[^[:space:]\"]+) ]]; then url="\${BASH_REMATCH[1]}"; fi; `
                + `if [[ -z "$url" ]]; then resp="$(${fallback1} || true)"; if [[ "$resp" =~ (https?://[^[:space:]\"]+) ]]; then url="\${BASH_REMATCH[1]}"; fi; fi; `
                + `if [[ -z "$url" ]]; then resp="$(${fallback2} || true)"; if [[ "$resp" =~ (https?://[^[:space:]\"]+) ]]; then url="\${BASH_REMATCH[1]}"; fi; fi; `
                + `echo "$url"`
        }
        const annotationCommand = `${(Config.options?.regionSelector?.annotation?.useSatty ?? false) ? "satty" : "swappy"} -f -`;
        const pathPre = Config.subprocessPathShExport();
        switch (root.action) {
            case RegionSelection.SnipAction.Copy:
                snipProc.command = ["bash", "-c", pathPre + `_dir='${screenshotSaveDir}' && mkdir -p "$_dir" && _ss="$_dir/ss-$(date +%Y%m%d-%H%M%S).png" && ${cropToStdout} | tee "$_ss" | wl-copy && echo -n "$_ss" | wl-copy --primary && ${cleanup} && notify-send "Screenshot copied" "${rw}x${rh} saved to $_ss" -a "Screenshot" -i camera-photo -t 3000`]
                break;
            case RegionSelection.SnipAction.Edit:
                snipProc.command = ["bash", "-c", pathPre + `${cropToStdout} | ${annotationCommand} && ${cleanup}`]
                break;
            case RegionSelection.SnipAction.Search:
                snipProc.command = ["bash", "-c", pathPre
                    + `CURL_BIN="$HOME/.nix-profile/bin/curl"; [ -x "$CURL_BIN" ] || CURL_BIN="/run/current-system/sw/bin/curl"; [ -x "$CURL_BIN" ] || CURL_BIN="curl"; `
                    + `XDG_OPEN_BIN="$HOME/.nix-profile/bin/xdg-open"; [ -x "$XDG_OPEN_BIN" ] || XDG_OPEN_BIN="/run/current-system/sw/bin/xdg-open"; [ -x "$XDG_OPEN_BIN" ] || XDG_OPEN_BIN="xdg-open"; `
                    + `GIO_BIN="$HOME/.nix-profile/bin/gio"; [ -x "$GIO_BIN" ] || GIO_BIN="/run/current-system/sw/bin/gio"; [ -x "$GIO_BIN" ] || GIO_BIN="gio"; `
                    + `GRIM_BIN="$HOME/.nix-profile/bin/grim"; [ -x "$GRIM_BIN" ] || GRIM_BIN="/run/current-system/sw/bin/grim"; [ -x "$GRIM_BIN" ] || GRIM_BIN="grim"; `
                    + `if [[ ! -s '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' ]]; then "$GRIM_BIN" -g '${slurpRegion}' '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' >/dev/null 2>&1 || true; fi; `
                    + `if command -v magick >/dev/null 2>&1; then ${cropInPlace} || true; fi; `
                    + `uploaded_url="$(${uploadAndGetUrl(root.screenshotPath)})"; `
                    + `engine="${root.effectiveImageSearchEngineBaseUrl}"; if [[ -z "$engine" || "$engine" == "https://yandex.com/images/search?rpt=imageview&url=" ]]; then engine="https://lens.google.com/uploadbyurl?url="; fi; `
                    + `printf 'uploaded_url=%s\nengine=%s\nfile=%s\n' "$uploaded_url" "$engine" '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' > /tmp/inir-image-search.log; `
                    + `if [[ -n "$uploaded_url" && "$uploaded_url" == http* ]]; then `
                    + `target_url="\${engine}\${uploaded_url}"; `
                    + `"$XDG_OPEN_BIN" "$target_url" >/dev/null 2>&1 || "$GIO_BIN" open "$target_url" >/dev/null 2>&1 || { printf '%s' "$target_url" | wl-copy; notify-send "Image search link copied" "$target_url" -a "Image Search" -i image; }; `
                    + `else notify-send "Image search failed" "Could not upload the image for reverse search" -a "Image Search" -i image; `
                    + `fi; ${cleanup}`]
                break;
            case RegionSelection.SnipAction.CharRecognition:
                snipProc.command = ["bash", "-c", pathPre
                    + `${cropInPlace} && `
                    + `TESS_BIN="$HOME/.nix-profile/bin/tesseract"; [ -x "$TESS_BIN" ] || TESS_BIN="/run/current-system/sw/bin/tesseract"; [ -x "$TESS_BIN" ] || TESS_BIN="tesseract"; `
                    + `WLCOPY_BIN="$HOME/.nix-profile/bin/wl-copy"; [ -x "$WLCOPY_BIN" ] || WLCOPY_BIN="/run/current-system/sw/bin/wl-copy"; [ -x "$WLCOPY_BIN" ] || WLCOPY_BIN="wl-copy"; `
                    + `if ! command -v "$TESS_BIN" >/dev/null 2>&1; then notify-send "OCR failed" "tesseract not found" -a "OCR" -i edit-find -t 3000; ${cleanup}; exit 127; fi; `
                    + `if ! command -v "$WLCOPY_BIN" >/dev/null 2>&1; then notify-send "OCR failed" "wl-copy not found" -a "OCR" -i edit-find -t 3000; ${cleanup}; exit 127; fi; `
                    + `LANGS="$("$TESS_BIN" --list-langs 2>/dev/null | awk 'NR>1{print $1}' | paste -sd+ -)"; `
                    + `if [[ -n "$LANGS" ]]; then OCR_TEXT="$("$TESS_BIN" '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' stdout -l "$LANGS" 2>/dev/null || true)"; `
                    + `else OCR_TEXT="$("$TESS_BIN" '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' stdout 2>/dev/null || true)"; fi; `
                    + `OCR_TEXT="$(printf '%s' "$OCR_TEXT" | sed '/^[[:space:]]*$/d')"; `
                    + `if [[ -z "$OCR_TEXT" ]]; then notify-send "OCR finished" "No text detected in selection" -a "OCR" -i edit-find -t 3000; `
                    + `else printf '%s' "$OCR_TEXT" | "$WLCOPY_BIN"; printf '%s' "$OCR_TEXT" | "$WLCOPY_BIN" --primary; notify-send "Text recognized" "OCR text copied to clipboard" -a "OCR" -i edit-find -t 3000; fi; `
                    + `${cleanup}`]
                break;
            case RegionSelection.SnipAction.Record:
                snipProc.command = ["bash", "-c", pathPre + `${Directories.recordScriptPath} --region '${slurpRegion}'`]
                break;
            case RegionSelection.SnipAction.RecordWithSound:
                snipProc.command = ["bash", "-c", pathPre + `${Directories.recordScriptPath} --region '${slurpRegion}' --sound`]
                break;
            default:
                root.dismiss();
                return;
        }

        // Image post-processing
        snipProc.startDetached();
        root.dismiss();
    }

    Process {
        id: snipProc
        environment: ({
            "PATH": Config.subprocessPath()
        })
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Image {
            anchors.fill: parent
            source: root.visible && root.screenshotReady ? `file://${root.screenshotPath}` : ""
            fillMode: Image.PreserveAspectFit
            cache: false
        }

        focus: root.visible
        Keys.onPressed: (event) => { // Esc to close
            if (event.key === Qt.Key_Escape) {
                root.dismiss();
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            // Controls
            onPressed: (mouse) => {
                root.dragStartX = mouse.x;
                root.dragStartY = mouse.y;
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
                root.dragging = true;
                root.mouseButton = mouse.button;
            }
            onReleased: (mouse) => {
                // Detect if it was a click -> Try to select targeted region
                if (root.draggingX === root.dragStartX && root.draggingY === root.dragStartY) {
                    if (root.targetedRegionValid()) {
                        root.setRegionToTargeted();
                    }
                }
                // Circle dragging?
                else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                    const padding = (Config.options?.regionSelector?.circle?.padding ?? 10) + (Config.options?.regionSelector?.circle?.strokeWidth ?? 2) / 2;
                    const dragPoints = (root.points.length > 0) ? root.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                    const maxX = Math.max(...dragPoints.map(p => p.x));
                    const minX = Math.min(...dragPoints.map(p => p.x));
                    const maxY = Math.max(...dragPoints.map(p => p.y));
                    const minY = Math.min(...dragPoints.map(p => p.y));
                    root.regionX = minX - padding;
                    root.regionY = minY - padding;
                    root.regionWidth = maxX - minX + padding * 2;
                    root.regionHeight = maxY - minY + padding * 2;
                }
                root.snip();
            }
            onPositionChanged: (mouse) => {
                root.updateTargetedRegion(mouse.x, mouse.y);
                if (!root.dragging) return;
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
                root.dragDiffX = mouse.x - root.dragStartX;
                root.dragDiffY = mouse.y - root.dragStartY;
                root.points.push({ x: mouse.x, y: mouse.y });
            }
            
            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.RectCorners
                sourceComponent: RectCornersSelectionDetails {
                    regionX: root.regionX
                    regionY: root.regionY
                    regionWidth: root.regionWidth
                    regionHeight: root.regionHeight
                    mouseX: mouseArea.mouseX
                    mouseY: mouseArea.mouseY
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                }
            }

            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.Circle
                sourceComponent: CircleSelectionDetails {
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                    points: root.points
                }
            }

            // Window regions
            Repeater {
                model: ScriptModel {
                    values: root.enableWindowRegions ? root.windowRegions : []
                }
                delegate: TargetRegion {
                    z: 2
                    required property var modelData
                    clientDimensions: modelData
                    showIcon: true
                    targeted: !root.draggedAway && root.regionMatchesTarget(modelData)

                    opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                    borderColor: root.windowBorderColor
                    fillColor: targeted ? root.windowFillColor : "transparent"
                    text: `${modelData.class}`
                    radius: Appearance.rounding.windowRounding
                }
            }

            // Layer regions
            Repeater {
                model: ScriptModel {
                    values: root.enableLayerRegions ? root.layerRegions : []
                }
                delegate: TargetRegion {
                    z: 3
                    required property var modelData
                    clientDimensions: modelData
                    targeted: !root.draggedAway && root.regionMatchesTarget(modelData)

                    opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                    borderColor: root.windowBorderColor
                    fillColor: targeted ? root.windowFillColor : "transparent"
                    text: `${modelData.namespace}`
                    radius: Appearance.rounding.windowRounding
                }
            }

            // Content regions
            Repeater {
                model: ScriptModel {
                    values: root.enableContentRegions ? root.imageRegions : []
                }
                delegate: TargetRegion {
                    z: 4
                    required property var modelData
                    clientDimensions: modelData
                    targeted: !root.draggedAway && root.regionMatchesTarget(modelData)

                    opacity: root.draggedAway ? 0 : root.contentRegionOpacity
                    borderColor: root.imageBorderColor
                    fillColor: targeted ? root.imageFillColor : "transparent"
                    text: Translation.tr("Content region")
                }
            }

            // Controls
            Item {
                id: regionSelectionControls
                z: 9999
                implicitWidth: controlsLoader.implicitWidth
                implicitHeight: controlsLoader.implicitHeight
                opacity: 0
                
                readonly property bool useWaffle: Config.options?.panelFamily === "waffle"
                
                // Position: waffle = top center, material = bottom center
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: useWaffle ? parent.top : undefined
                    bottom: useWaffle ? undefined : parent.bottom
                    topMargin: useWaffle ? -height : 0
                    bottomMargin: useWaffle ? 0 : -height
                }
                
                Connections {
                    target: root
                    function onVisibleChanged() {
                        if (!visible) return;
                        if (regionSelectionControls.useWaffle) {
                            regionSelectionControls.anchors.topMargin = 16;
                        } else {
                            regionSelectionControls.anchors.bottomMargin = 8;
                        }
                        regionSelectionControls.opacity = 1;
                    }
                }
                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on anchors.topMargin {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on anchors.bottomMargin {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }

                Loader {
                    id: controlsLoader
                    sourceComponent: regionSelectionControls.useWaffle ? waffleControls : materialControls
                }

                // Material ii controls
                Component {
                    id: materialControls
                    Row {
                        spacing: 6

                        OptionsToolbar {
                            action: root.action
                            selectionMode: root.selectionMode
                            onActionChanged: root.action = action
                            onSelectionModeChanged: root.selectionMode = selectionMode
                            onDismiss: root.dismiss();
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: closeFab.implicitWidth
                            implicitHeight: closeFab.implicitHeight
                            StyledRectangularShadow {
                                target: closeFab
                                radius: closeFab.buttonRadius
                            }
                            FloatingActionButton {
                                id: closeFab
                                baseSize: 48
                                iconText: "close"
                                onClicked: root.dismiss();
                                StyledToolTip {
                                    text: Translation.tr("Close")
                                }
                                colBackground: Appearance.colors.colTertiaryContainer
                                colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                                colRipple: Appearance.colors.colTertiaryContainerActive
                                colOnBackground: Appearance.colors.colOnTertiaryContainer
                            }
                        }
                    }
                }

                // Waffle (Windows 11) controls
                Component {
                    id: waffleControls
                    WaffleRegion.WOptionsToolbar {
                        action: root.action
                        selectionMode: root.selectionMode
                        onActionChanged: root.action = action
                        onSelectionModeChanged: root.selectionMode = selectionMode
                        onDismiss: root.dismiss()
                    }
                }
            }
            
        }
    }
}
