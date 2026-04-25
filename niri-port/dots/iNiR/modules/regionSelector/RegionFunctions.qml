pragma Singleton
import Quickshell

Singleton {
    id: root

    function _near(a, b, tol) {
        return Math.abs(a - b) <= tol;
    }

    /// Niri `logical` rect vs Quickshell `ShellScreen` (may differ when Qt uses buffer pixels vs logical size).
    function niriLogicalMatchesScreen(screen, L) {
        if (!L || !screen) {
            return false;
        }
        const lx = L.x;
        const ly = L.y;
        const lw = L.width;
        const lh = L.height;
        const sx = screen.x;
        const sy = screen.y;
        const sw = screen.width;
        const sh = screen.height;
        if (lx !== sx || ly !== sy) {
            return false;
        }
        if (lw === sw && lh === sh) {
            return true;
        }
        const sc = typeof L.scale === "number" && L.scale > 0 ? L.scale : 1;
        const pw = Math.round(lw * sc);
        const ph = Math.round(lh * sc);
        if (_near(pw, sw, 2) && _near(ph, sh, 2)) {
            return true;
        }
        if (lw === Math.round(sw / sc) && lh === Math.round(sh / sc)) {
            return true;
        }
        return false;
    }

    /// Resolves a head name for `grim -o` on Niri: must match `niri msg -j outputs` keys / wlr output names.
    function niriGrimOutputName(screen, outputs) {
        if (!screen) {
            return "";
        }
        if (!outputs || typeof outputs !== "object") {
            // Avoid guessing with Qt's screen name before Niri outputs arrive.
            // Passing an unknown value to `grim -o` fails the capture.
            return "";
        }
        const preferred = screen.name || "";
        if (preferred.length > 0 && outputs[preferred] !== undefined) {
            return preferred;
        }
        const keys = Object.keys(outputs);
        for (let i = 0; i < keys.length; ++i) {
            const k = keys[i];
            const L = outputs[k].logical;
            if (!L) {
                continue;
            }
            if (root.niriLogicalMatchesScreen(screen, L)) {
                return k;
            }
        }
        if (keys.length === 1) {
            return keys[0];
        }
        if (keys.length === 0) {
            return preferred;
        }
        // Several heads but no geometry / name match — do not guess (caller avoids `grim` without `-o`).
        return "";
    }

    function intersectionOverUnion(regionA, regionB) {
        // region: { at: [x, y], size: [w, h] }
        if (!regionA || !regionB
            || !regionA.at || !regionB.at
            || !regionA.size || !regionB.size
            || regionA.at.length < 2 || regionB.at.length < 2
            || regionA.size.length < 2 || regionB.size.length < 2) {
            return 0;
        }

        const ax1 = regionA.at[0], ay1 = regionA.at[1];
        const ax2 = ax1 + regionA.size[0], ay2 = ay1 + regionA.size[1];
        const bx1 = regionB.at[0], by1 = regionB.at[1];
        const bx2 = bx1 + regionB.size[0], by2 = by1 + regionB.size[1];

        const interX1 = Math.max(ax1, bx1);
        const interY1 = Math.max(ay1, by1);
        const interX2 = Math.min(ax2, bx2);
        const interY2 = Math.min(ay2, by2);

        const interArea = Math.max(0, interX2 - interX1) * Math.max(0, interY2 - interY1);
        const areaA = (ax2 - ax1) * (ay2 - ay1);
        const areaB = (bx2 - bx1) * (by2 - by1);
        const unionArea = areaA + areaB - interArea;

        return unionArea > 0 ? interArea / unionArea : 0;
    }

    function filterOverlappingImageRegions(regions) {
        let keep = [];
        let removed = new Set();
        for (let i = 0; i < regions.length; ++i) {
            if (removed.has(i)) continue;
            let regionA = regions[i];
            for (let j = i + 1; j < regions.length; ++j) {
                if (removed.has(j)) continue;
                let regionB = regions[j];
                if (intersectionOverUnion(regionA, regionB) > 0) {
                    // Compare areas
                    let areaA = regionA.size[0] * regionA.size[1];
                    let areaB = regionB.size[0] * regionB.size[1];
                    if (areaA <= areaB) {
                        removed.add(j);
                    } else {
                        removed.add(i);
                    }
                }
            }
        }
        for (let i = 0; i < regions.length; ++i) {
            if (!removed.has(i)) keep.push(regions[i]);
        }
        return keep;
    }

    function filterWindowRegionsByLayers(windowRegions, layerRegions) {
        return windowRegions.filter(windowRegion => {
            for (let i = 0; i < layerRegions.length; ++i) {
                if (intersectionOverUnion(windowRegion, layerRegions[i]) > 0)
                    return false;
            }
            return true;
        });
    }

    function filterImageRegions(regions, windowRegions, threshold = 0.1) {
        // Remove image regions that overlap too much with any window region
        let filtered = regions.filter(region => {
            for (let i = 0; i < windowRegions.length; ++i) {
                if (intersectionOverUnion(region, windowRegions[i]) > threshold)
                    return false;
            }
            return true;
        });
        // Remove overlapping image regions, keep only the smaller one
        return filterOverlappingImageRegions(filtered);
    }
}
