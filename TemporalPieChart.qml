import QtQuick

Item {
    id: root

    // --- Public Properties ---
    property real zoom: 1.0             // 1.0 = equitemporal, > 1.0 = enlarged, < 1.0 = shrunk
    property real focusAngle: Math.PI / 2 // Angle in radians (0 = 12 o'clock, π/2 = 3 o'clock, clockwise)
    property real minZoom: 0.15
    property real maxZoom: 24.0
    property bool interactive: true
    property bool showIcons: true
    property bool showLabels: true
    property bool showLensHighlight: true

    // 8 3-hour time sections for the 24h day (00:00 to 24:00)
    property var sections: [
        { label: "00:00 - 03:00", name: "Night",       color: "#3B4252", startH: 0,  endH: 3  },
        { label: "03:00 - 06:00", name: "Early Morn",  color: "#434C5E", startH: 3,  endH: 6  },
        { label: "06:00 - 09:00", name: "Morning",     color: "#2E5B88", startH: 6,  endH: 9  },
        { label: "09:00 - 12:00", name: "Late Morn",   color: "#2B7A78", startH: 9,  endH: 12 },
        { label: "12:00 - 15:00", name: "Afternoon",   color: "#C05621", startH: 12, endH: 15 },
        { label: "15:00 - 18:00", name: "Late Aft",    color: "#DD6B20", startH: 15, endH: 18 },
        { label: "18:00 - 21:00", name: "Evening",     color: "#805AD5", startH: 18, endH: 21 },
        { label: "21:00 - 24:00", name: "Late Night",  color: "#553C9A", startH: 21, endH: 24 }
    ]

    // Sample events matching the wireframe icons
    property var events: [
        { time: 1.5,  icon: "😴", title: "Sleep",       color: "#E2E8F0" },
        { time: 4.2,  icon: "💊", title: "Medication",  color: "#FEB2B2" },
        { time: 6.8,  icon: "🥛", title: "Water",       color: "#BEE3F8" },
        { time: 7.6,  icon: "🏃", title: "Morning Run", color: "#FEEBC8" },
        { time: 8.5,  icon: "🚗", title: "Commute",     color: "#FED7D7" },
        { time: 10.5, icon: "💻", title: "Deep Work",   color: "#E9D8FD" },
        { time: 12.8, icon: "🍽️", title: "Lunch",       color: "#C6F6D5" },
        { time: 14.8, icon: "💊", title: "Medication",  color: "#FEB2B2" },
        { time: 16.5, icon: "🏃", title: "Workout",     color: "#FEEBC8" },
        { time: 18.8, icon: "🚗", title: "Drive Home",  color: "#FED7D7" },
        { time: 19.8, icon: "🍽️", title: "Dinner",      color: "#C6F6D5" },
        { time: 21.0, icon: "📺", title: "Relax / TV",  color: "#E2E8F0" },
        { time: 23.0, icon: "😴", title: "Bedtime",     color: "#E2E8F0" }
    ]

    // Plan Model integration
    property var planModel: null
    property var hoveredItem: null
    property var selectedItem: null
    signal itemClicked(var item)

    onPlanModelChanged: {
        if (planModel && planModel.modelChanged) {
            planModel.modelChanged.connect(canvas.requestPaint)
        }
        canvas.requestPaint();
    }

    // Hovered event tracking
    property int hoveredEventIndex: -1

    // Live System Time Tracking ("Follow Time")
    property bool followTime: false
    property real currentTimeHours: 12.0
    property bool showCurrentTimeHand: true

    function updateCurrentTime() {
        let now = new Date();
        let h = now.getHours() + now.getMinutes() / 60.0 + now.getSeconds() / 3600.0 + now.getMilliseconds() / 3600000.0;
        root.currentTimeHours = h;
        if (root.followTime) {
            root.focusAngle = (h / 24.0) * 2.0 * Math.PI;
        }
        canvas.requestPaint();
    }

    Timer {
        id: liveClockTimer
        interval: 200
        running: true
        repeat: true
        onTriggered: root.updateCurrentTime()
    }

    Component.onCompleted: root.updateCurrentTime()

    // Smooth animation on zoom and focus angle changes (disabled during active gesture or live tracking)
    Behavior on zoom {
        enabled: !pinchHandler.active
        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
    }

    Behavior on focusAngle {
        enabled: !dragHandler.active && !root.followTime
        RotationAnimation {
            direction: RotationAnimation.Shortest
            duration: 130
            easing.type: Easing.OutQuad
        }
    }

    onZoomChanged: canvas.requestPaint()
    onFocusAngleChanged: canvas.requestPaint()
    onHoveredEventIndexChanged: canvas.requestPaint()
    onFollowTimeChanged: {
        if (followTime) {
            updateCurrentTime();
        }
    }

    implicitWidth: 420
    implicitHeight: 420

    // --- Mathematical Distortion Functions ---
    function normalizeAngle(a) {
        while (a > Math.PI) a -= 2 * Math.PI;
        while (a < -Math.PI) a += 2 * Math.PI;
        return a;
    }

    // Warp an angle (in radians, 0 = 12 o'clock, clockwise)
    function warpAngle(theta) {
        if (Math.abs(root.zoom - 1.0) < 0.001) return theta;
        let delta = normalizeAngle(theta - root.focusAngle);
        if (Math.abs(Math.abs(delta) - Math.PI) < 1e-5) {
            return root.focusAngle + delta;
        }
        let warpedDelta = 2.0 * Math.atan(root.zoom * Math.tan(delta * 0.5));
        return root.focusAngle + warpedDelta;
    }

    // Convert time in hours [0..24] to visual angle in radians (0 at top, clockwise)
    function timeToAngle(hours) {
        let baseAngle = (hours / 24.0) * 2.0 * Math.PI;
        return warpAngle(baseAngle);
    }

    // Unwarp a visual angle back to equitemporal angle (exact inverse of warpAngle)
    function unwarpAngle(warpedAngle) {
        if (Math.abs(root.zoom - 1.0) < 0.001) return warpedAngle;
        let warpedDelta = normalizeAngle(warpedAngle - root.focusAngle);
        if (Math.abs(Math.abs(warpedDelta) - Math.PI) < 1e-5) {
            return root.focusAngle + warpedDelta;
        }
        let delta = 2.0 * Math.atan(Math.tan(warpedDelta * 0.5) / root.zoom);
        return root.focusAngle + delta;
    }

    // Convert visual angle [0..2π] to equitemporal clock time in hours [0..24]
    function angleToTime(angle) {
        let unwarped = unwarpAngle(angle);
        let norm = normalizeAngle(unwarped);
        if (norm < 0) norm += 2 * Math.PI;
        return (norm / (2 * Math.PI)) * 24.0;
    }

    // Fast check: Does an item's time span intersect the visible focus window?
    function isTimeRangeInVisibleWindow(sTime, eTime, focusH, windowH) {
        if (windowH >= 12.0) return true;
        let dur = (eTime >= sTime) ? (eTime - sTime) : (24.0 - sTime + eTime);
        let mid = (sTime + dur * 0.5) % 24.0;
        let diff = Math.abs(mid - focusH) % 24.0;
        if (diff > 12.0) diff = 24.0 - diff;
        return diff <= (windowH + dur * 0.5 + 0.15);
    }

    // Public method: is an item currently visible and rendered on the dial?
    function isItemVisibleOnDial(item) {
        if (!item) return false;
        if (item.level === 0) return true;
        let maxL = (root.planModel && root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;
        let radius = Math.min(root.width, root.height) / 2 - 24;
        let track = root.getTrackRadii(item.level, maxL, radius);
        let minPixels = (item.level === 0) ? 2.0 : 4.5;

        let zoomFactor = Math.max(1.0, root.zoom);
        let maxPixels = track.rMid * (item.duration / 24.0) * (2.0 * Math.PI) * zoomFactor;
        if (maxPixels < minPixels) return false;

        let ca1 = root.timeToAngle(item.startTime) - Math.PI / 2;
        let ca2 = root.timeToAngle(item.endTime) - Math.PI / 2;
        let span = ca2 - ca1;
        while (span <= 0) span += 2 * Math.PI;
        while (span > 2 * Math.PI) span -= 2 * Math.PI;
        return (track.rMid * span >= minPixels);
    }

    function pointToAngle(px, py) {
        let cx = root.width / 2;
        let cy = root.height / 2;
        let dx = px - cx;
        let dy = py - cy;
        // 0 angle at top (12 o'clock), clockwise
        let angle = Math.atan2(dx, -dy);
        if (angle < 0) angle += 2 * Math.PI;
        return angle;
    }

    function setFocusFromPoint(px, py) {
        if (root.followTime) root.followTime = false;
        root.focusAngle = pointToAngle(px, py);
    }

    function resetZoom() {
        root.zoom = 1.0;
    }

    function getTrackRadii(level, maxLevel, radius) {
        let N = Math.min(4, Math.max(1, maxLevel + 1));
        let rOuter = radius * 0.94;
        let rInner = (N === 1) ? radius * 0.58 :
                     (N === 2) ? radius * 0.52 :
                     (N === 3) ? radius * 0.46 : radius * 0.40;
        let totalSpan = rOuter - rInner;
        let trackH = totalSpan / N;
        let gap = 2.0;

        // Parent (level 0) on the inside, children expand outwards to rOuter
        let idx = Math.min(level, N - 1);
        let rIn = rInner + idx * trackH + gap;
        let rOut = rInner + (idx + 1) * trackH;
        return { rIn: rIn, rOut: rOut, rMid: (rIn + rOut) * 0.5, height: trackH };
    }

    // Synchronized smooth gesture handling:
    // Moves the zoom origin towards the gesture location first before altering zoom.
    function handleWheelZoom(px, py, angleDeltaY) {
        if (root.followTime) {
            applyWheelZoomDelta(angleDeltaY);
            return;
        }

        let targetAngle = pointToAngle(px, py);

        // When equitemporal (1.0x), no distortion exists, so locking focusAngle causes zero visual jump.
        if (Math.abs(root.zoom - 1.0) < 0.02) {
            root.focusAngle = targetAngle;
            applyWheelZoomDelta(angleDeltaY);
            return;
        }

        let diff = normalizeAngle(targetAngle - root.focusAngle);
        let absDiff = Math.abs(diff);
        let tolerance = 0.045; // ~2.5 degrees

        if (absDiff > tolerance) {
            // Origin moves towards target angle first!
            // ~0.0036 rad per notch unit (~25 degrees per 120-unit wheel detent)
            let maxStep = Math.abs(angleDeltaY) * 0.0036;
            let step = Math.min(absDiff, maxStep);
            let dir = diff > 0 ? 1 : -1;
            let newAngle = normalizeAngle(root.focusAngle + dir * step);
            if (newAngle < 0) newAngle += 2 * Math.PI;
            root.focusAngle = newAngle;

            // If this step reached the target, apply leftover delta to scale zoom
            if (maxStep > 0 && step === absDiff) {
                let leftoverFraction = (maxStep - absDiff) / maxStep;
                if (leftoverFraction > 0.1) {
                    applyWheelZoomDelta(angleDeltaY * leftoverFraction);
                }
            }
        } else {
            // Already at the target, directly zoom
            root.focusAngle = targetAngle;
            applyWheelZoomDelta(angleDeltaY);
        }
    }

    function applyWheelZoomDelta(deltaY) {
        let factor = deltaY > 0 ? 1.15 : 0.87;
        let targetZoom = root.zoom * factor;
        root.zoom = Math.max(root.minZoom, Math.min(root.maxZoom, targetZoom));
    }

    function applyPinchScaleDelta(scaleDelta) {
        let newZoom = root.zoom * (1.0 + scaleDelta);
        root.zoom = Math.max(root.minZoom, Math.min(root.maxZoom, newZoom));
    }

    // Diurnal / Circadian blended color function:
    // Calm blue at midnight (00:00) -> Sunrise gold -> Bright orangy yellow at noon (12:00) -> Sunset coral -> Midnight blue
    function getBlendedColor(timeHours) {
        let t = timeHours % 24.0;
        if (t < 0) t += 24.0;

        let stops = [
            { t: 0.0,  r: 22,  g: 48,  b: 118 }, // 00:00 Calm midnight blue
            { t: 3.5,  r: 28,  g: 56,  b: 130 }, // 03:30 Deep calm night
            { t: 5.5,  r: 65,  g: 75,  b: 130 }, // 05:30 Dawn twilight
            { t: 7.0,  r: 220, g: 118, b: 50  }, // 07:00 Sunrise amber
            { t: 9.5,  r: 248, g: 168, b: 30  }, // 09:30 Morning gold
            { t: 12.0, r: 255, g: 195, b: 18  }, // 12:00 Bright orangy yellow (radiant midday)
            { t: 14.5, r: 248, g: 160, b: 28  }, // 14:30 Warm afternoon sun
            { t: 17.0, r: 232, g: 110, b: 45  }, // 17:00 Golden hour
            { t: 19.5, r: 175, g: 68,  b: 85  }, // 19:30 Sunset dusky rose
            { t: 21.5, r: 58,  g: 48,  b: 112 }, // 21:30 Evening indigo
            { t: 24.0, r: 22,  g: 48,  b: 118 }  // 24:00 Calm midnight blue
        ];

        for (let i = 0; i < stops.length - 1; ++i) {
            let s1 = stops[i];
            let s2 = stops[i + 1];
            if (t >= s1.t && t <= s2.t) {
                let frac = (t - s1.t) / (s2.t - s1.t);
                // Cosine easing for smooth organic blending across transitions
                let smoothFrac = 0.5 - 0.5 * Math.cos(frac * Math.PI);
                let r = Math.round(s1.r + (s2.r - s1.r) * smoothFrac);
                let g = Math.round(s1.g + (s2.g - s1.g) * smoothFrac);
                let b = Math.round(s1.b + (s2.b - s1.b) * smoothFrac);
                return "rgb(" + r + "," + g + "," + b + ")";
            }
        }
        return "rgb(22,48,118)";
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            let ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, width, height);

            let cx = width / 2;
            let cy = height / 2;
            let radius = Math.min(cx, cy) - 24;
            if (radius <= 10) return;

            let innerRadius = radius * 0.22;
            let iconRadius = radius * 0.72;

            // 1. Draw Continuous Circadian Blended Background (96 15-minute segments)
            let wedgeCount = 96;
            let dt = 24.0 / wedgeCount;
            let overlap = 0.003;

            for (let i = 0; i < wedgeCount; ++i) {
                let t1 = i * dt;
                let t2 = (i + 1) * dt;
                let tMid = (t1 + t2) * 0.5;

                let ca1 = root.timeToAngle(t1) - Math.PI / 2;
                let ca2 = root.timeToAngle(t2) - Math.PI / 2;

                let span = ca2 - ca1;
                while (span <= 0) span += 2 * Math.PI;
                while (span > 2 * Math.PI) span -= 2 * Math.PI;

                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, radius, ca1, ca1 + span + overlap, false);
                ctx.closePath();

                ctx.fillStyle = root.getBlendedColor(tMid);
                ctx.globalAlpha = 0.95;
                ctx.fill();
            }
            ctx.globalAlpha = 1.0;

            // 2. Dashed Line Separators Every 15 Minutes (:15, :30, :45) - batched & culled
            let quarterLines = [];
            let halfLines = [];
            let minSep = 2.5 / radius; // ~2.5px arc minimum separation

            for (let h = 0; h < 24; ++h) {
                for (let q = 1; q <= 3; ++q) {
                    let t = h + q * 0.25;
                    let a = root.timeToAngle(t);
                    let aPrev = root.timeToAngle(t - 0.25);
                    let sep = root.normalizeAngle(a - aPrev);
                    if (sep < 0) sep += 2 * Math.PI;
                    if (sep < minSep) continue; // Culled in squished region

                    if (q === 2) halfLines.push(a);
                    else quarterLines.push(a);
                }
            }

            if (quarterLines.length > 0) {
                ctx.lineWidth = 1.0;
                ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
                ctx.setLineDash([3, 4]);
                ctx.beginPath();
                for (let i = 0; i < quarterLines.length; ++i) {
                    let a = quarterLines[i];
                    let sinA = Math.sin(a);
                    let cosA = Math.cos(a);
                    ctx.moveTo(cx + (innerRadius + 2) * sinA, cy - (innerRadius + 2) * cosA);
                    ctx.lineTo(cx + (radius - 1) * sinA, cy - (radius - 1) * cosA);
                }
                ctx.stroke();
            }

            if (halfLines.length > 0) {
                ctx.lineWidth = 1.0;
                ctx.strokeStyle = "rgba(255, 255, 255, 0.38)";
                ctx.setLineDash([4, 3]);
                ctx.beginPath();
                for (let i = 0; i < halfLines.length; ++i) {
                    let a = halfLines[i];
                    let sinA = Math.sin(a);
                    let cosA = Math.cos(a);
                    ctx.moveTo(cx + (innerRadius + 2) * sinA, cy - (innerRadius + 2) * cosA);
                    ctx.lineTo(cx + (radius - 1) * sinA, cy - (radius - 1) * cosA);
                }
                ctx.stroke();
            }
            ctx.setLineDash([]);

            // 3. Solid Line Separators At Every Hour (0, 1, 2, ..., 23) - batched
            ctx.beginPath();
            for (let h = 0; h < 24; ++h) {
                if (h % 3 === 0) continue;
                let a = root.timeToAngle(h);
                let sinA = Math.sin(a);
                let cosA = Math.cos(a);
                ctx.moveTo(cx + (innerRadius + 1) * sinA, cy - (innerRadius + 1) * cosA);
                ctx.lineTo(cx + (radius - 1) * sinA, cy - (radius - 1) * cosA);
            }
            ctx.lineWidth = 1.3;
            ctx.strokeStyle = "rgba(255, 255, 255, 0.65)";
            ctx.stroke();

            ctx.beginPath();
            for (let h = 0; h < 24; h += 3) {
                let a = root.timeToAngle(h);
                let sinA = Math.sin(a);
                let cosA = Math.cos(a);
                ctx.moveTo(cx + (innerRadius + 1) * sinA, cy - (innerRadius + 1) * cosA);
                ctx.lineTo(cx + (radius - 1) * sinA, cy - (radius - 1) * cosA);
            }
            ctx.lineWidth = 2.0;
            ctx.strokeStyle = "#FFFFFF";
            ctx.stroke();

            // Outer circumference rim border
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, 2 * Math.PI, false);
            ctx.strokeStyle = "#FFFFFF";
            ctx.lineWidth = 2.0;
            ctx.stroke();

            // 4. Concentric Track Guideline for Events
            ctx.beginPath();
            ctx.arc(cx, cy, iconRadius, 0, 2 * Math.PI, false);
            ctx.strokeStyle = "rgba(255, 255, 255, 0.35)";
            ctx.lineWidth = 1.2;
            ctx.setLineDash([4, 4]);
            ctx.stroke();
            ctx.setLineDash([]);

            let hasPlan = (root.planModel && root.planModel.flatItems && root.planModel.flatItems.length > 0);

            // 5. Section and Hourly Labels
            if (root.showLabels) {
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.shadowColor = "rgba(0, 0, 0, 0.70)";
                ctx.shadowBlur = 4;
                ctx.shadowOffsetX = 0;
                ctx.shadowOffsetY = 1;

                // 3-Hour Section Names in slice bodies (in inner collar if plan is active)
                for (let i = 0; i < root.sections.length; ++i) {
                    let sec = root.sections[i];
                    let midHour = (sec.startH + sec.endH) / 2.0;
                    let aMid = root.timeToAngle(midHour);
                    let aStart = root.timeToAngle(sec.startH);
                    let aEnd = root.timeToAngle(sec.endH);

                    let angularSpan = root.normalizeAngle(aEnd - aStart);
                    if (angularSpan < 0) angularSpan += 2 * Math.PI;

                    if (angularSpan > 0.28) {
                        let textR = hasPlan ? (innerRadius + radius * 0.38) * 0.5 : (radius * 0.44);
                        let tx = cx + textR * Math.sin(aMid);
                        let ty = cy - textR * Math.cos(aMid);

                        ctx.fillStyle = "#FFFFFF";
                        ctx.font = hasPlan ? "bold 10px sans-serif" : "bold 11px sans-serif";
                        ctx.fillText(sec.startH + ":00", tx, ty - 6);

                        ctx.fillStyle = "rgba(255, 255, 255, 0.90)";
                        ctx.font = "9px sans-serif";
                        ctx.fillText(sec.name, tx, ty + 7);
                    }
                }

                // Hourly Markers near rim for hours that have enough space
                for (let h = 0; h < 24; ++h) {
                    // Only for intermediate hours (since 3h slices already have central labels)
                    if (h % 3 !== 0) {
                        let aPrev = root.timeToAngle(h - 0.5);
                        let aNext = root.timeToAngle(h + 0.5);
                        let span = root.normalizeAngle(aNext - aPrev);
                        if (span < 0) span += 2 * Math.PI;

                        // Only show if expanded enough to be legible
                        if (span > 0.16) {
                            let aH = root.timeToAngle(h);
                            let textR = hasPlan ? (radius * 0.97) : (radius * 0.90);
                            let tx = cx + textR * Math.sin(aH);
                            let ty = cy - textR * Math.cos(aH);

                            ctx.font = "bold 9px sans-serif";
                            ctx.fillStyle = "rgba(255, 255, 255, 0.85)";
                            ctx.fillText(h + "h", tx, ty);
                        }
                    }
                }
                ctx.shadowColor = "transparent";
                ctx.shadowBlur = 0;
            }

            // 4. Plan Model Intervals (Concentric Multi-Track Bands with Culling & Semantic LOD)
            if (hasPlan) {
                let maxL = (root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;
                let zoomFactor = Math.max(1.0, root.zoom);
                let focusH = (root.focusAngle / (2.0 * Math.PI)) * 24.0;

                // Precompute track geometry for each level
                let tracks = [];
                for (let l = 0; l <= maxL; ++l) {
                    tracks.push(root.getTrackRadii(l, maxL, radius));
                }

                let hasLevels = (root.planModel.levels && root.planModel.levels.length > 0);
                let levelCount = hasLevels ? root.planModel.levels.length : 1;

                for (let lvl = 0; lvl < levelCount; ++lvl) {
                    let levelItems = hasLevels ? root.planModel.levels[lvl] : root.planModel.intervals;
                    if (!levelItems || levelItems.length === 0) continue;

                    let targetTrack = tracks[Math.min(lvl, tracks.length - 1)];
                    let minPixels = (lvl === 0) ? 2.0 : 4.5;

                    // Level-level culling: check if max possible duration at this level could EVER reach minPixels
                    let maxDurAtLevel = 24.0;
                    if (hasLevels && root.planModel.levelMaxDurations && root.planModel.levelMaxDurations[lvl] !== undefined) {
                        maxDurAtLevel = root.planModel.levelMaxDurations[lvl];
                    }
                    let maxPossiblePixelsAtLevel = targetTrack.rMid * (maxDurAtLevel / 24.0) * (2.0 * Math.PI) * zoomFactor;
                    if (maxPossiblePixelsAtLevel < minPixels) {
                        // Entire level is smaller than visible pixel threshold: cull in O(1)!
                        continue;
                    }

                    // Angular window culling around focus angle
                    let visibleWindowHours = 12.0; // full circle by default
                    let basePixelsAtLevel = targetTrack.rMid * (maxDurAtLevel / 24.0) * (2.0 * Math.PI);
                    let mReq = minPixels / Math.max(0.0001, basePixelsAtLevel);

                    if (mReq > 1.0 && root.zoom > 1.0) {
                        if (mReq > root.zoom) {
                            continue; // Even maximum magnification cannot reach minPixels anywhere
                        }
                        let sinVal = Math.max(0.0, Math.min(1.0, ((root.zoom / mReq) - 1.0) / (root.zoom * root.zoom - 1.0)));
                        let deltaMax = 2.0 * Math.asin(Math.sqrt(sinVal));
                        visibleWindowHours = (deltaMax / (2.0 * Math.PI)) * 24.0 + maxDurAtLevel + 0.25;
                    }

                    for (let k = 0; k < levelItems.length; ++k) {
                        let iv = levelItems[k];
                        let track = tracks[Math.min(iv.level, tracks.length - 1)];

                        // Fast item culling: skip items outside visible angular focus window
                        if (visibleWindowHours < 12.0) {
                            if (!root.isTimeRangeInVisibleWindow(iv.startTime, iv.endTime, focusH, visibleWindowHours)) {
                                continue;
                            }
                        }

                        let ca1 = root.timeToAngle(iv.startTime) - Math.PI / 2;
                        let ca2 = root.timeToAngle(iv.endTime) - Math.PI / 2;

                        let span = ca2 - ca1;
                        while (span <= 0) span += 2 * Math.PI;
                        while (span > 2 * Math.PI) span -= 2 * Math.PI;

                        let arcPixels = track.rMid * span;
                        if (arcPixels < minPixels) {
                            continue;
                        }

                        let isHovered = (root.hoveredItem && root.hoveredItem.title === iv.title && root.hoveredItem.startTime === iv.startTime);
                        let isSelected = (root.selectedItem && root.selectedItem.title === iv.title && root.selectedItem.startTime === iv.startTime);

                        ctx.beginPath();
                        ctx.arc(cx, cy, track.rOut, ca1, ca1 + span, false);
                        ctx.arc(cx, cy, track.rIn, ca1 + span, ca1, true);
                        ctx.closePath();

                        // Translucent fill with hierarchical layer depth
                        ctx.fillStyle = iv.color ? iv.color : "rgba(255, 255, 255, 0.35)";
                        let baseAlpha = (iv.level === 0) ? 0.50 : (iv.level === 1 ? 0.44 : (iv.level === 2 ? 0.38 : 0.60));
                        ctx.globalAlpha = isHovered ? 0.80 : (isSelected ? 0.70 : baseAlpha);
                        ctx.fill();

                        // Border
                        ctx.strokeStyle = (isHovered || isSelected) ? "#38BDF8" : (iv.color ? iv.color : "rgba(255, 255, 255, 0.85)");
                        ctx.lineWidth = (isHovered || isSelected) ? 2.5 : ((iv.level >= 2 && arcPixels < 12) ? 0.6 : 1.2);
                        ctx.globalAlpha = (isHovered || isSelected) ? 1.0 : 0.85;
                        ctx.stroke();

                        // Progressive Label Disclosure based on available room
                        if (arcPixels >= 55) {
                            let aMid = ca1 + span * 0.5 + Math.PI / 2;
                            let lx = cx + track.rMid * Math.sin(aMid);
                            let ly = cy - track.rMid * Math.cos(aMid);

                            ctx.font = (iv.level === 0) ? "bold 11px sans-serif" : (iv.level === 1 ? "bold 10px sans-serif" : "9px sans-serif");
                            ctx.fillStyle = "#FFFFFF";
                            ctx.textAlign = "center";
                            ctx.textBaseline = "middle";
                            ctx.shadowColor = "rgba(0, 0, 0, 0.85)";
                            ctx.shadowBlur = 4;
                            ctx.fillText((iv.icon ? iv.icon + " " : "") + iv.title, lx, ly);
                            ctx.shadowColor = "transparent";
                            ctx.shadowBlur = 0;
                        } else if (arcPixels >= 18 && iv.icon) {
                            let aMid = ca1 + span * 0.5 + Math.PI / 2;
                            let lx = cx + track.rMid * Math.sin(aMid);
                            let ly = cy - track.rMid * Math.cos(aMid);

                            ctx.font = (track.height > 24) ? "13px sans-serif" : "11px sans-serif";
                            ctx.fillStyle = "#FFFFFF";
                            ctx.textAlign = "center";
                            ctx.textBaseline = "middle";
                            ctx.fillText(iv.icon, lx, ly);
                        }
                    }
                }
            }

            // 5. Point Items & Ordered Steps
            if (root.showIcons) {
                let pointList = hasPlan ? root.planModel.pointItems : root.events;

                for (let j = 0; j < pointList.length; ++j) {
                    let ev = pointList[j];
                    let evTime = hasPlan ? ev.startTime : ev.time;
                    let maxL = (root.planModel && root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;
                    let pTrack = hasPlan ? root.getTrackRadii(ev.level || 0, maxL, radius) : null;
                    let rTrack = pTrack ? pTrack.rMid : (radius * 0.84);

                    let a = root.timeToAngle(evTime);
                    let ex = cx + rTrack * Math.sin(a);
                    let ey = cy - rTrack * Math.cos(a);

                    let isHovered = (root.hoveredItem && root.hoveredItem.title === ev.title && (hasPlan ? (root.hoveredItem.startTime === ev.startTime) : (root.hoveredItem.time === ev.time)));
                    let isSelected = (root.selectedItem && root.selectedItem.title === ev.title);
                    let badgeRadius = (isHovered || isSelected) ? 16 : 13;

                    // Badge background
                    ctx.beginPath();
                    ctx.arc(ex, ey, badgeRadius, 0, 2 * Math.PI, false);
                    ctx.fillStyle = ev.color ? ev.color : (ev.isUntimedStep ? "#FEF08A" : "#FFFFFF");
                    ctx.fill();
                    ctx.strokeStyle = (isHovered || isSelected) ? "#38BDF8" : "#1E293B";
                    ctx.lineWidth = (isHovered || isSelected) ? 2.5 : 1.5;
                    ctx.stroke();

                    // Emoji or order step tag
                    ctx.font = (isHovered || isSelected) ? "15px sans-serif" : "12px sans-serif";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillStyle = "#1E293B";
                    ctx.fillText(ev.icon ? ev.icon : (ev.orderIndex ? ev.orderIndex : "📌"), ex, ey + 1);

                    // Hovered Tooltip Card
                    if (isHovered) {
                        let titleY = ey - 26;
                        let tipText = (ev.icon ? ev.icon + " " : "") + ev.title;
                        if (ev.isUntimedStep) {
                            tipText += " (Step " + ev.orderIndex + " in " + ev.parentTitle + ")";
                        } else if (hasPlan) {
                            tipText += " (" + ev.startClock + (ev.parentTitle ? " in " + ev.parentTitle : "") + ")";
                        } else {
                            let hourStr = Math.floor(ev.time) + ":" + (Math.floor((ev.time % 1) * 60) < 10 ? "0" : "") + Math.floor((ev.time % 1) * 60);
                            tipText += " (" + hourStr + ")";
                        }

                        ctx.font = "bold 11px sans-serif";
                        let textWidth = ctx.measureText(tipText).width;

                        ctx.fillStyle = "rgba(15, 23, 42, 0.95)";
                        ctx.fillRect(ex - textWidth / 2 - 8, titleY - 10, textWidth + 16, 20);
                        ctx.strokeStyle = "#38BDF8";
                        ctx.lineWidth = 1;
                        ctx.strokeRect(ex - textWidth / 2 - 8, titleY - 10, textWidth + 16, 20);

                        ctx.fillStyle = "#F8FAFC";
                        ctx.fillText(tipText, ex, titleY);
                    }
                }
            }

            // 5. Center Hub
            ctx.beginPath();
            ctx.arc(cx, cy, innerRadius, 0, 2 * Math.PI, false);
            ctx.fillStyle = "#0F172A";
            ctx.fill();
            ctx.strokeStyle = root.followTime ? "#F43F5E" : "#38BDF8";
            ctx.lineWidth = root.followTime ? 3.0 : 2.5;
            ctx.stroke();

            // Center Info
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            let nowH = Math.floor(root.currentTimeHours);
            let nowM = Math.floor((root.currentTimeHours % 1) * 60);
            let nowS = Math.floor(((root.currentTimeHours * 60) % 1) * 60);
            let liveTimeStr = (nowH < 10 ? "0" : "") + nowH + ":" + (nowM < 10 ? "0" : "") + nowM + ":" + (nowS < 10 ? "0" : "") + nowS;

            if (root.followTime) {
                ctx.fillStyle = "#F43F5E";
                ctx.font = "bold 13px sans-serif";
                ctx.fillText(liveTimeStr, cx, cy - 7);
                ctx.fillStyle = "#FDA4AF";
                ctx.font = "bold 9px sans-serif";
                ctx.fillText("FOLLOWING (" + root.zoom.toFixed(1) + "x)", cx, cy + 8);
            } else if (root.zoom > 1.05) {
                ctx.fillStyle = "#38BDF8";
                ctx.font = "bold 14px sans-serif";
                ctx.fillText(root.zoom.toFixed(1) + "x", cx, cy - 6);
                ctx.fillStyle = "#94A3B8";
                ctx.font = "9px sans-serif";
                ctx.fillText("ENLARGED", cx, cy + 8);
            } else if (root.zoom < 0.95) {
                ctx.fillStyle = "#F43F5E";
                ctx.font = "bold 14px sans-serif";
                ctx.fillText(root.zoom.toFixed(2) + "x", cx, cy - 6);
                ctx.fillStyle = "#FDA4AF";
                ctx.font = "9px sans-serif";
                ctx.fillText("SHRUNK", cx, cy + 8);
            } else {
                ctx.fillStyle = "#F8FAFC";
                ctx.font = "bold 13px sans-serif";
                ctx.fillText("24 HOURS", cx, cy - 6);
                ctx.fillStyle = "#94A3B8";
                ctx.font = "9px sans-serif";
                ctx.fillText("EQUAL (1.0x)", cx, cy + 8);
            }

            // 6. Current System Time Needle & "NOW" Marker
            if (root.showCurrentTimeHand) {
                let nowAngle = root.timeToAngle(root.currentTimeHours);
                let nx1 = cx + (innerRadius + 1) * Math.sin(nowAngle);
                let ny1 = cy - (innerRadius + 1) * Math.cos(nowAngle);
                let nx2 = cx + (radius + 2) * Math.sin(nowAngle);
                let ny2 = cy - (radius + 2) * Math.cos(nowAngle);

                // Sleek glowing indicator needle
                ctx.beginPath();
                ctx.moveTo(nx1, ny1);
                ctx.lineTo(nx2, ny2);
                ctx.strokeStyle = root.followTime ? "#F43F5E" : "rgba(244, 63, 94, 0.75)";
                ctx.lineWidth = root.followTime ? 2.2 : 1.6;
                ctx.shadowColor = root.followTime ? "rgba(244, 63, 94, 0.7)" : "rgba(251, 113, 133, 0.4)";
                ctx.shadowBlur = 6;
                ctx.stroke();
                ctx.shadowColor = "transparent";
                ctx.shadowBlur = 0;

                // "NOW" Badge on outer rim
                let bx = cx + (radius + 14) * Math.sin(nowAngle);
                let by = cy - (radius + 14) * Math.cos(nowAngle);

                ctx.beginPath();
                ctx.arc(bx, by, 8, 0, 2 * Math.PI, false);
                ctx.fillStyle = root.followTime ? "#F43F5E" : "#E11D48";
                ctx.fill();
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1.6;
                ctx.stroke();

                ctx.font = "bold 8px sans-serif";
                ctx.fillStyle = "#FFFFFF";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText("NOW", bx, by + 1);
            }

            // 6. Focus Lens Indicator on Outer Rim
            if (root.showLensHighlight && Math.abs(root.zoom - 1.0) > 0.05) {
                let isZoomedIn = (root.zoom > 1.0);
                // Calculate physical visual span of the focused ±1.5h section (±π/8)
                let a1 = root.warpAngle(root.focusAngle - Math.PI / 8) - Math.PI / 2;
                let a2 = root.warpAngle(root.focusAngle + Math.PI / 8) - Math.PI / 2;
                let fSpan = a2 - a1;
                while (fSpan <= 0) fSpan += 2 * Math.PI;
                while (fSpan > 2 * Math.PI) fSpan -= 2 * Math.PI;

                ctx.beginPath();
                ctx.arc(cx, cy, radius + 4, a1, a1 + fSpan, false);
                ctx.strokeStyle = isZoomedIn ? "#F59E0B" : "#F43F5E";
                ctx.lineWidth = isZoomedIn ? 5 : 4;
                ctx.stroke();

                // Lens focus dot
                let fx = cx + (radius + 4) * Math.sin(root.focusAngle);
                let fy = cy - (radius + 4) * Math.cos(root.focusAngle);
                ctx.beginPath();
                ctx.arc(fx, fy, isZoomedIn ? 5 : 4, 0, 2 * Math.PI, false);
                ctx.fillStyle = isZoomedIn ? "#FBBF24" : "#FB7185";
                ctx.fill();
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1.8;
                ctx.stroke();
            }

            // 7. Active Pinch Touch Points Feedback (if pinching)
            if (pinchHandler.active) {
                let p1 = pinchHandler.point1.position;
                let p2 = pinchHandler.point2.position;

                ctx.strokeStyle = "#F59E0B";
                ctx.lineWidth = 2;
                ctx.setLineDash([3, 3]);

                ctx.beginPath();
                ctx.arc(p1.x, p1.y, 16, 0, 2 * Math.PI, false);
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(p2.x, p2.y, 16, 0, 2 * Math.PI, false);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(p1.x, p1.y);
                ctx.lineTo(p2.x, p2.y);
                ctx.stroke();
                ctx.setLineDash([]);
            }
        }
    }

    // 1. Pinch Handler (Touch screen zoom & angle tracking)
    PinchHandler {
        id: pinchHandler
        enabled: root.interactive
        target: null
        property real lastScale: 1.0

        onActiveChanged: {
            if (active) {
                lastScale = 1.0;
            }
            canvas.requestPaint();
        }

        onScaleChanged: {
            if (active) {
                let scaleDelta = scale - lastScale;
                lastScale = scale;

                if (root.followTime) {
                    root.applyPinchScaleDelta(scaleDelta);
                    return;
                }

                let px = centroid.position.x;
                let py = centroid.position.y;
                let targetAngle = root.pointToAngle(px, py);

                if (Math.abs(root.zoom - 1.0) < 0.02) {
                    root.focusAngle = targetAngle;
                    root.applyPinchScaleDelta(scaleDelta);
                    return;
                }

                let diff = root.normalizeAngle(targetAngle - root.focusAngle);
                let absDiff = Math.abs(diff);
                let tolerance = 0.045;

                if (absDiff > tolerance) {
                    // Pinch movement steps the origin towards targetAngle first
                    let maxStep = Math.abs(scaleDelta) * 4.5;
                    let step = Math.min(absDiff, maxStep);
                    let dir = diff > 0 ? 1 : -1;
                    let newAngle = root.normalizeAngle(root.focusAngle + dir * step);
                    if (newAngle < 0) newAngle += 2 * Math.PI;
                    root.focusAngle = newAngle;

                    if (maxStep > 0 && step === absDiff) {
                        let leftoverFraction = (maxStep - absDiff) / maxStep;
                        if (leftoverFraction > 0.1) {
                            root.applyPinchScaleDelta(scaleDelta * leftoverFraction);
                        }
                    }
                } else {
                    root.focusAngle = targetAngle;
                    root.applyPinchScaleDelta(scaleDelta);
                }
            }
        }
    }

    // 2. Mouse Wheel Handler (Desktop & WebAssembly)
    WheelHandler {
        id: wheelHandler
        enabled: root.interactive
        target: null
        onWheel: (event) => {
            root.handleWheelZoom(point.position.x, point.position.y, event.angleDelta.y);
        }
    }

    // 3. Drag Handler (Rotate / pan focus angle when zoomed without abrupt jumping)
    DragHandler {
        id: dragHandler
        enabled: root.interactive && Math.abs(root.zoom - 1.0) > 0.05
        target: null
        property real startFocusAngle: 0.0
        property real startTouchAngle: 0.0

        onActiveChanged: {
            if (active) {
                if (root.followTime) root.followTime = false;
                startFocusAngle = root.focusAngle;
                startTouchAngle = root.pointToAngle(centroid.position.x, centroid.position.y);
            }
        }
        onTranslationChanged: {
            if (active) {
                let currentTouchAngle = root.pointToAngle(centroid.position.x, centroid.position.y);
                let touchDelta = root.normalizeAngle(currentTouchAngle - startTouchAngle);
                let newAngle = root.normalizeAngle(startFocusAngle + touchDelta);
                if (newAngle < 0) newAngle += 2 * Math.PI;
                root.focusAngle = newAngle;
            }
        }
    }

    // 4. Tap Handler (Double tap to reset, single tap to focus/select)
    TapHandler {
        enabled: root.interactive
        onDoubleTapped: root.resetZoom()
        onSingleTapped: (event) => {
            if (root.hoveredItem) {
                root.selectedItem = root.hoveredItem;
                root.itemClicked(root.hoveredItem);
            } else {
                root.setFocusFromPoint(event.position.x, event.position.y);
            }
        }
    }

    // 5. Hover Handler (Highlight nearest item or interval)
    HoverHandler {
        enabled: root.interactive
        onPointChanged: {
            let cx = root.width / 2;
            let cy = root.height / 2;
            let radius = Math.min(cx, cy) - 24;
            let px = point.position.x;
            let py = point.position.y;
            let dx = px - cx;
            let dy = py - cy;
            let dist = Math.hypot(dx, dy);

            let hasPlan = (root.planModel && root.planModel.flatItems && root.planModel.flatItems.length > 0);
            let pointList = hasPlan ? root.planModel.pointItems : root.events;

            // 1. Check point items first
            let closestItem = null;
            let minDistance = 22;

            let maxL = (root.planModel && root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;

            for (let j = 0; j < pointList.length; ++j) {
                let ev = pointList[j];
                let evTime = hasPlan ? ev.startTime : ev.time;
                let pTrack = hasPlan ? root.getTrackRadii(ev.level || 0, maxL, radius) : null;
                let rTrack = pTrack ? pTrack.rMid : (radius * 0.84);

                let a = root.timeToAngle(evTime);
                let ex = cx + rTrack * Math.sin(a);
                let ey = cy - rTrack * Math.cos(a);
                let d = Math.hypot(px - ex, py - ey);
                if (d < minDistance) {
                    minDistance = d;
                    closestItem = ev;
                }
            }

            // 2. If not hovering a point, check intervals (from deepest visible level outwards)
            if (!closestItem && hasPlan) {
                let cursorClockAngle = Math.atan2(dx, -dy);
                if (cursorClockAngle < 0) cursorClockAngle += 2 * Math.PI;
                let cursorTime = root.angleToTime(cursorClockAngle);

                let maxL = (root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;
                let hasLevels = (root.planModel.levels && root.planModel.levels.length > 0);
                let zoomFactor = Math.max(1.0, root.zoom);

                // Check from deepest level to macro level
                for (let targetLevel = maxL; targetLevel >= 0; --targetLevel) {
                    let track = root.getTrackRadii(targetLevel, maxL, radius);
                    let minPixels = (targetLevel === 0) ? 2.0 : 4.5;

                    // Only consider if cursor is in or near this track radius
                    if (dist < track.rIn - 4 || dist > track.rOut + 4) {
                        continue;
                    }

                    // Level culling: if max duration at this level cannot reach minPixels, track is collapsed
                    let maxDurAtLevel = 24.0;
                    if (hasLevels && root.planModel.levelMaxDurations && root.planModel.levelMaxDurations[targetLevel] !== undefined) {
                        maxDurAtLevel = root.planModel.levelMaxDurations[targetLevel];
                    }
                    if (track.rMid * (maxDurAtLevel / 24.0) * (2.0 * Math.PI) * zoomFactor < minPixels) {
                        continue;
                    }

                    let levelItems = hasLevels ? root.planModel.levels[targetLevel] : root.planModel.intervals;
                    if (!levelItems) continue;

                    for (let k = 0; k < levelItems.length; ++k) {
                        let iv = levelItems[k];
                        if (!hasLevels && iv.level !== targetLevel) continue;

                        let s = iv.startTime;
                        let e = iv.endTime;
                        let inside = (e >= s) ? (cursorTime >= s && cursorTime <= e) : (cursorTime >= s || cursorTime <= e);
                        if (!inside) continue;

                        // Verify it's actually visible (arcPixels >= minPixels)
                        let ca1 = root.timeToAngle(s);
                        let ca2 = root.timeToAngle(e);
                        let span = root.normalizeAngle(ca2 - ca1);
                        if (span <= 0) span += 2 * Math.PI;

                        if (track.rMid * span >= minPixels) {
                            closestItem = iv;
                            break;
                        }
                    }
                    if (closestItem) break;
                }

                // Fallback: If cursor is within inner area where child items disappeared,
                // find the parent item that covers this cursorTime!
                if (!closestItem && dist >= radius * 0.40 && dist <= radius * 0.95) {
                    for (let targetLevel = maxL - 1; targetLevel >= 0; --targetLevel) {
                        let track = root.getTrackRadii(targetLevel, maxL, radius);
                        let minPixels = (targetLevel === 0) ? 2.0 : 4.5;
                        let levelItems = hasLevels ? root.planModel.levels[targetLevel] : root.planModel.intervals;
                        if (!levelItems) continue;

                        for (let k = 0; k < levelItems.length; ++k) {
                            let iv = levelItems[k];
                            if (!hasLevels && iv.level !== targetLevel) continue;

                            let s = iv.startTime;
                            let e = iv.endTime;
                            let inside = (e >= s) ? (cursorTime >= s && cursorTime <= e) : (cursorTime >= s || cursorTime <= e);
                            if (!inside) continue;

                            let ca1 = root.timeToAngle(s);
                            let ca2 = root.timeToAngle(e);
                            let span = root.normalizeAngle(ca2 - ca1);
                            if (span <= 0) span += 2 * Math.PI;

                            if (track.rMid * span >= minPixels) {
                                closestItem = iv;
                                break;
                            }
                        }
                        if (closestItem) break;
                    }
                }
            }

            if (root.hoveredItem !== closestItem) {
                root.hoveredItem = closestItem;
                canvas.requestPaint();
            }
        }
    }
}
