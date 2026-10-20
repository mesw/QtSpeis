import QtQuick

Item {
    id: root

    // --- Public Properties ---
    property real zoom: 1.0             // 1.0 = equitemporal, > 1.0 = enlarged, < 1.0 = shrunk
    property real focusAngle: Math.PI / 2 // Angle in radians (0 = 12 o'clock Midnight, π = 6 o'clock Noon)
    property real minZoom: 0.15
    property real maxZoom: 24.0
    property bool interactive: true
    property bool showIcons: true
    property bool showLabels: true
    property bool showLensHighlight: true

    // Spiral Duration Parameters (3 = 72 Hours / 3-Day Mode, 7 = 168 Hours / 7-Day Mode)
    property int daysCount: 3
    readonly property bool is3DayMode: (daysCount === 3)
    property var dayNames: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    property var dayShortNames: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

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

    // Sample fallback events matching the wireframe icons
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

    // Interactive Hover & Time Readability Tracking
    property real hoveredTime: -1
    property int hoveredCoil: -1
    property int hoveredDay: -1
    property bool isHoveringSpiral: false
    property real hoveredX: 0
    property real hoveredY: 0

    onPlanModelChanged: {
        if (planModel && planModel.modelChanged) {
            planModel.modelChanged.connect(canvas.requestPaint);
        }
        canvas.requestPaint();
    }

    // Live System Time Tracking ("Follow Time")
    property bool followTime: false
    property int currentDayOfWeek: 0       // 0 = Monday, ..., 6 = Sunday
    property real currentTimeHours: 12.0  // Current hour of day [0..24]
    property bool showCurrentTimeHand: true

    function updateCurrentTime() {
        let now = new Date();
        let jsDay = now.getDay();
        let monDay = (jsDay + 6) % 7; // Monday-first: 0 = Mon, 6 = Sun
        root.currentDayOfWeek = monDay;

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
    onDaysCountChanged: canvas.requestPaint()
    onFollowTimeChanged: {
        if (followTime) {
            updateCurrentTime();
        }
    }

    implicitWidth: 540
    implicitHeight: 540

    // --- Mathematical Distortion Functions ---
    function normalizeAngle(a) {
        while (a > Math.PI) a -= 2 * Math.PI;
        while (a < -Math.PI) a += 2 * Math.PI;
        return a;
    }

    // Warp a 24-hour angle (in radians, 0 = 12 o'clock, clockwise)
    function warpAngle(theta) {
        if (Math.abs(root.zoom - 1.0) < 0.001) return theta;
        let delta = normalizeAngle(theta - root.focusAngle);
        if (Math.abs(Math.abs(delta) - Math.PI) < 1e-5) {
            return root.focusAngle + delta;
        }
        let warpedDelta = 2.0 * Math.atan(root.zoom * Math.tan(delta * 0.5));
        return root.focusAngle + warpedDelta;
    }

    // Convert time in hours [0..24] to visual angle in radians [0..2π] (0 at top, clockwise)
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

    function pointToAngle(px, py) {
        let cx = root.width / 2;
        let cy = root.height / 2;
        let dx = px - cx;
        let dy = py - cy;
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

    function formatClockTime(hours) {
        let h = Math.floor(hours) % 24;
        let m = Math.floor((hours % 1) * 60);
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    function isItemActiveAtTime(item, t) {
        if (!item) return false;
        let s = item.startTime;
        let e = item.endTime;
        if (s === undefined || e === undefined) return false;
        if (Math.abs(s - e) < 0.001) {
            return Math.abs(t - s) < 0.08;
        }
        if (e > s) {
            return (t >= s && t <= e);
        } else {
            return (t >= s || t <= e);
        }
    }

    function getActiveActivitiesAtTime(t, calendarDay) {
        let result = [];
        let hasPlan = (root.planModel && root.planModel.flatItems && root.planModel.flatItems.length > 0);
        if (!hasPlan) {
            for (let s = 0; s < root.sections.length; ++s) {
                let sec = root.sections[s];
                if (t >= sec.startH && t <= sec.endH) {
                    result.push({
                        title: sec.name,
                        startClock: sec.label.split(" - ")[0],
                        endClock: sec.label.split(" - ")[1],
                        startTime: sec.startH,
                        endTime: sec.endH,
                        level: 0,
                        color: sec.color
                    });
                }
            }
            return result;
        }

        let list = root.planModel.intervals || [];
        for (let i = 0; i < list.length; ++i) {
            let iv = list[i];
            let matches = false;
            if (iv.repeatDaily) {
                matches = true;
            } else if (iv.day !== undefined && iv.day >= 0) {
                matches = (iv.day === calendarDay);
            } else {
                matches = (calendarDay === root.currentDayOfWeek);
            }
            if (!matches) continue;

            if (root.isItemActiveAtTime(iv, t)) {
                result.push(iv);
            }
        }

        let pList = root.planModel.pointItems || [];
        for (let j = 0; j < pList.length; ++j) {
            let p = pList[j];
            let matches = false;
            if (p.repeatDaily) {
                matches = true;
            } else if (p.day !== undefined && p.day >= 0) {
                matches = (p.day === calendarDay);
            } else {
                matches = (calendarDay === root.currentDayOfWeek);
            }
            if (!matches) continue;

            let pTime = p.startTime !== undefined ? p.startTime : p.time;
            let diff = Math.abs(pTime - t) % 24.0;
            if (diff > 12.0) diff = 24.0 - diff;
            if (diff <= 0.20) {
                result.push(Object.assign({}, p, { isPoint: true }));
            }
        }
        result.sort((a, b) => (a.level || 0) - (b.level || 0));
        return result;
    }

    function drawRoundedRect(ctx, x, y, width, height, radius) {
        let r = Math.min(radius, Math.min(width * 0.5, height * 0.5));
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + width - r, y);
        ctx.arcTo(x + width, y, x + width, y + r, r);
        ctx.lineTo(x + width, y + height - r);
        ctx.arcTo(x + width, y + height, x + width - r, y + height, r);
        ctx.lineTo(x + r, y + height);
        ctx.arcTo(x, y + height, x, y + height - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
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

    // --- Spiral Geometry Helpers ---
    function getSpiralMetrics(radius) {
        let rInner = radius * 0.18;
        let rOuter = radius * 0.95;
        let pitch = (rOuter - rInner) / (root.daysCount + 0.85);
        let bandWidth = pitch * 0.85;
        let gap = pitch * 0.15;
        return {
            rInner: rInner,
            rOuter: rOuter,
            pitch: pitch,
            bandWidth: bandWidth,
            gap: gap
        };
    }

    // Radius at any continuous angle Theta (radians from 0 at Day 0 00:00 to 14π at Day 6 24:00)
    // Winds from OUTSIDE (Current Day / Day 0) to INSIDE (Farthest in the future / Day 6)
    function getSpiralCenterRadius(totalAngle, metrics) {
        let windingFrac = totalAngle / (2.0 * Math.PI);
        return metrics.rOuter - (metrics.bandWidth * 0.5) - windingFrac * metrics.pitch;
    }

    // Sub-track within the day's band: parent (level 0) inside, children outside
    function getSpiralSubTrack(level, maxLevel, metrics) {
        let N = Math.min(4, Math.max(1, maxLevel + 1));
        let trackH = metrics.bandWidth / N;
        let subGap = 1.0;

        let idx = Math.min(level, N - 1);
        let offsetIn = -metrics.bandWidth * 0.5 + idx * trackH + subGap;
        let offsetOut = -metrics.bandWidth * 0.5 + (idx + 1) * trackH;
        let offsetMid = (offsetIn + offsetOut) * 0.5;
        return {
            offsetIn: offsetIn,
            offsetOut: offsetOut,
            offsetMid: offsetMid,
            trackH: trackH
        };
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
                let factor = (t - s1.t) / (s2.t - s1.t);
                let r = Math.round(s1.r + factor * (s2.r - s1.r));
                let g = Math.round(s1.g + factor * (s2.g - s1.g));
                let b = Math.round(s1.b + factor * (s2.b - s1.b));
                return "rgb(" + r + "," + g + "," + b + ")";
            }
        }
        return "rgb(22,48,118)";
    }

    // Public method: is an item currently visible on the spiral?
    function isItemVisibleOnDial(item) {
        if (!item) return false;
        if (item.level === 0) return true;
        let maxL = (root.planModel && root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;
        let radius = Math.min(root.width, root.height) / 2 - 24;
        let metrics = root.getSpiralMetrics(radius);
        let subTrack = root.getSpiralSubTrack(item.level, maxL, metrics);
        let minPixels = (item.level === 0) ? 2.0 : 4.5;

        let a1 = root.timeToAngle(item.startTime);
        let a2 = root.timeToAngle(item.endTime);
        let span = root.normalizeAngle(a2 - a1);
        if (span <= 0) span += 2 * Math.PI;

        // Approximate arc pixels at middle radius of winding
        let rApprox = metrics.rOuter - (metrics.bandWidth * 0.5) - (root.daysCount * 0.5) * metrics.pitch;
        return (rApprox * span >= minPixels);
    }

    // --- Synchronized Gesture Zoom Handling ---
    function handleWheelZoom(px, py, angleDeltaY) {
        if (root.followTime) {
            applyWheelZoomDelta(angleDeltaY);
            return;
        }

        let targetAngle = pointToAngle(px, py);
        if (Math.abs(root.zoom - 1.0) < 0.02) {
            root.focusAngle = targetAngle;
            applyWheelZoomDelta(angleDeltaY);
            return;
        }

        let diff = normalizeAngle(targetAngle - root.focusAngle);
        let absDiff = Math.abs(diff);
        let tolerance = 0.045;

        if (absDiff > tolerance) {
            let maxStep = Math.abs(angleDeltaY) * 0.0036;
            let step = Math.min(absDiff, maxStep);
            let dir = diff > 0 ? 1 : -1;
            let newAngle = normalizeAngle(root.focusAngle + dir * step);
            if (newAngle < 0) newAngle += 2 * Math.PI;
            root.focusAngle = newAngle;

            if (maxStep > 0 && step === absDiff) {
                let leftoverFraction = (maxStep - absDiff) / maxStep;
                if (leftoverFraction > 0.1) {
                    applyWheelZoomDelta(angleDeltaY * leftoverFraction);
                }
            }
        } else {
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

    // --- Main Canvas Painting ---
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
            if (radius <= 20) return;

            let metrics = root.getSpiralMetrics(radius);
            let zoomFactor = Math.max(1.0, root.zoom);
            let focusH = (root.focusAngle / (2.0 * Math.PI)) * 24.0;
            let hasPlan = (root.planModel && root.planModel.flatItems && root.planModel.flatItems.length > 0);
            let maxL = (root.planModel && root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;

            // Helper to trace a spiral arc segment
            function traceSpiralRibbon(aStart, aEnd, rOffsetIn, rOffsetOut) {
                let span = aEnd - aStart;
                if (span <= 0) return;
                let steps = Math.max(2, Math.ceil(span / 0.08));
                let dAngle = span / steps;

                ctx.beginPath();
                // Outer boundary forward
                for (let i = 0; i <= steps; ++i) {
                    let a = aStart + i * dAngle;
                    let r = root.getSpiralCenterRadius(a, metrics) + rOffsetOut;
                    let x = cx + r * Math.sin(a);
                    let y = cy - r * Math.cos(a);
                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                // Inner boundary backwards
                for (let i = steps; i >= 0; --i) {
                    let a = aStart + i * dAngle;
                    let r = root.getSpiralCenterRadius(a, metrics) + rOffsetIn;
                    let x = cx + r * Math.sin(a);
                    let y = cy - r * Math.cos(a);
                    ctx.lineTo(x, y);
                }
                ctx.closePath();
            }

            // 1. Draw Spiral Background Ribbon (Circadian Blended Gradient per Winding)
            let halfW = metrics.bandWidth * 0.5;
            let wedgeCount = 96; // 15-minute segments per day
            let dt = 24.0 / wedgeCount;

            for (let day = 0; day < root.daysCount; ++day) {
                for (let i = 0; i < wedgeCount; ++i) {
                    let t1 = i * dt;
                    let t2 = (i + 1) * dt;
                    let tMid = (t1 + t2) * 0.5;

                    let ca1 = day * 2 * Math.PI + root.timeToAngle(t1);
                    let ca2 = day * 2 * Math.PI + root.timeToAngle(t2);

                    traceSpiralRibbon(ca1, ca2, -halfW, halfW);
                    ctx.fillStyle = root.getBlendedColor(tMid);
                    // In 3-day mode, subtly dim past hours of today so the upcoming 72h stand out
                    let isPastToday = (day === 0 && tMid < root.currentTimeHours);
                    ctx.globalAlpha = isPastToday ? 0.55 : 0.92;
                    ctx.fill();
                }
            }
            ctx.globalAlpha = 1.0;

            // 2. Continuous Spiral Border Edges (Inner & Outer Wireframe Lines)
            let totalSpiralAngle = root.daysCount * 2 * Math.PI;
            let spiralSteps = Math.ceil(totalSpiralAngle / 0.04);
            let dSpAngle = totalSpiralAngle / spiralSteps;

            // Outer edge of the spiral band
            ctx.beginPath();
            for (let i = 0; i <= spiralSteps; ++i) {
                let a = i * dSpAngle;
                let r = root.getSpiralCenterRadius(a, metrics) + halfW;
                let x = cx + r * Math.sin(a);
                let y = cy - r * Math.cos(a);
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.strokeStyle = "rgba(255, 255, 255, 0.45)";
            ctx.lineWidth = 1.4;
            ctx.stroke();

            // Inner edge of the spiral band
            ctx.beginPath();
            for (let i = 0; i <= spiralSteps; ++i) {
                let a = i * dSpAngle;
                let r = root.getSpiralCenterRadius(a, metrics) - halfW;
                let x = cx + r * Math.sin(a);
                let y = cy - r * Math.cos(a);
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.strokeStyle = "rgba(255, 255, 255, 0.35)";
            ctx.lineWidth = 1.2;
            ctx.stroke();

            // 3. Radial Hour & 15-Minute Separators across Windings
            // Solid lines every hour across each day's ribbon
            ctx.beginPath();
            for (let day = 0; day < root.daysCount; ++day) {
                for (let h = 0; h < 24; ++h) {
                    if (h % 3 === 0) continue;
                    let a = day * 2 * Math.PI + root.timeToAngle(h);
                    let rCenter = root.getSpiralCenterRadius(a, metrics);
                    let r1 = rCenter - halfW;
                    let r2 = rCenter + halfW;
                    let sinA = Math.sin(a);
                    let cosA = Math.cos(a);
                    ctx.moveTo(cx + r1 * sinA, cy - r1 * cosA);
                    ctx.lineTo(cx + r2 * sinA, cy - r2 * cosA);
                }
            }
            ctx.lineWidth = 1.0;
            ctx.strokeStyle = "rgba(255, 255, 255, 0.45)";
            ctx.stroke();

            // 3-Hour Major Section Radial Boundaries
            ctx.beginPath();
            for (let day = 0; day < root.daysCount; ++day) {
                for (let h = 0; h < 24; h += 3) {
                    let a = day * 2 * Math.PI + root.timeToAngle(h);
                    let rCenter = root.getSpiralCenterRadius(a, metrics);
                    let r1 = rCenter - halfW;
                    let r2 = rCenter + halfW;
                    let sinA = Math.sin(a);
                    let cosA = Math.cos(a);
                    ctx.moveTo(cx + r1 * sinA, cy - r1 * cosA);
                    ctx.lineTo(cx + r2 * sinA, cy - r2 * cosA);
                }
            }
            ctx.lineWidth = 1.8;
            ctx.strokeStyle = "#FFFFFF";
            ctx.stroke();

            // 4. Four Major Cross-Hair Guidelines (Midnight North, 06:00 East, 12:00 South, 18:00 West)
            ctx.setLineDash([4, 4]);
            ctx.lineWidth = 1.0;
            ctx.strokeStyle = "rgba(255, 255, 255, 0.20)";
            let majorAngles = [
                { a: root.timeToAngle(0),  label: "00:00 MIDNIGHT (N)" },
                { a: root.timeToAngle(6),  label: "06:00 MORNING (E)"  },
                { a: root.timeToAngle(12), label: "12:00 NOON (S)"     },
                { a: root.timeToAngle(18), label: "18:00 EVENING (W)"  }
            ];
            for (let m = 0; m < majorAngles.length; ++m) {
                let ma = majorAngles[m].a;
                let sinM = Math.sin(ma);
                let cosM = Math.cos(ma);
                ctx.beginPath();
                ctx.moveTo(cx + metrics.rInner * sinM, cy - metrics.rInner * cosM);
                ctx.lineTo(cx + (metrics.rOuter + 8) * sinM, cy - (metrics.rOuter + 8) * cosM);
                ctx.stroke();
            }
            ctx.setLineDash([]);

            // 5. Plan Model Intervals (Hierarchical Tracks with Parent Inside, Children Outside)
            if (hasPlan) {
                let hasLevels = (root.planModel.levels && root.planModel.levels.length > 0);
                let levelCount = hasLevels ? root.planModel.levels.length : 1;

                for (let lvl = 0; lvl < levelCount; ++lvl) {
                    let levelItems = hasLevels ? root.planModel.levels[lvl] : root.planModel.intervals;
                    if (!levelItems || levelItems.length === 0) continue;

                    let subTrack = root.getSpiralSubTrack(lvl, maxL, metrics);
                    let minPixels = (lvl === 0) ? 2.0 : 4.0;

                    // Level-level culling
                    let maxDurAtLevel = 24.0;
                    if (hasLevels && root.planModel.levelMaxDurations && root.planModel.levelMaxDurations[lvl] !== undefined) {
                        maxDurAtLevel = root.planModel.levelMaxDurations[lvl];
                    }
                    let avgRadius = metrics.rOuter - (metrics.bandWidth * 0.5) - (root.daysCount * 0.5) * metrics.pitch;
                    let maxPossiblePixelsAtLevel = avgRadius * (maxDurAtLevel / 24.0) * (2.0 * Math.PI) * zoomFactor;
                    if (maxPossiblePixelsAtLevel < minPixels) {
                        continue; // Cull entire level in O(1)
                    }

                    // Angular window culling around focus angle
                    let visibleWindowHours = 12.0;
                    let basePixelsAtLevel = avgRadius * (maxDurAtLevel / 24.0) * (2.0 * Math.PI);
                    let mReq = minPixels / Math.max(0.0001, basePixelsAtLevel);

                    if (mReq > 1.0 && root.zoom > 1.0) {
                        if (mReq > root.zoom) continue;
                        let sinVal = Math.max(0.0, Math.min(1.0, ((root.zoom / mReq) - 1.0) / (root.zoom * root.zoom - 1.0)));
                        let deltaMax = 2.0 * Math.asin(Math.sqrt(sinVal));
                        visibleWindowHours = (deltaMax / (2.0 * Math.PI)) * 24.0 + maxDurAtLevel + 0.25;
                    }

                    for (let k = 0; k < levelItems.length; ++k) {
                        let iv = levelItems[k];

                        // Skip items outside visible angular focus window
                        if (visibleWindowHours < 12.0) {
                            if (!root.isTimeRangeInVisibleWindow(iv.startTime, iv.endTime, focusH, visibleWindowHours)) {
                                continue;
                            }
                        }

                        // Determine which coil(s) this item belongs to within the current window
                        let startCoil, endCoil;
                        if (iv.repeatDaily) {
                            startCoil = 0;
                            endCoil = root.daysCount - 1;
                        } else if (iv.day !== undefined && iv.day >= 0) {
                            let targetCoil = (iv.day - root.currentDayOfWeek + 7) % 7;
                            if (targetCoil >= root.daysCount) continue; // Outside current window (e.g. beyond 72h)
                            startCoil = targetCoil;
                            endCoil = targetCoil;
                        } else {
                            startCoil = 0;
                            endCoil = 0;
                        }

                        for (let day = startCoil; day <= endCoil; ++day) {
                            let ca1 = day * 2 * Math.PI + root.timeToAngle(iv.startTime);
                            let ca2 = (iv.crossesMidnight ? (day + 1) : day) * 2 * Math.PI + root.timeToAngle(iv.endTime);
                            let span = ca2 - ca1;
                            if (span <= 0) span += 2 * Math.PI;

                            let rMidWinding = root.getSpiralCenterRadius((ca1 + ca2) * 0.5, metrics);
                            let arcPixels = rMidWinding * span;
                            if (arcPixels < minPixels) continue;

                            let actualDay = (root.currentDayOfWeek + day) % 7;
                            let isHovered = (root.hoveredItem && root.hoveredItem.title === iv.title && (root.hoveredItem.day === undefined || root.hoveredItem.day === actualDay) && root.hoveredItem.startTime === iv.startTime);
                            let isSelected = (root.selectedItem && root.selectedItem.title === iv.title);

                            let isTargetCoil = (root.isHoveringSpiral && root.hoveredCoil === day);
                            let isActiveAtHover = isTargetCoil && (root.hoveredTime >= 0) && root.isItemActiveAtTime(iv, root.hoveredTime);

                            traceSpiralRibbon(ca1, ca2, subTrack.offsetIn, subTrack.offsetOut);

                            // Translucent fill with hierarchical depth
                            ctx.fillStyle = iv.color ? iv.color : "rgba(255, 255, 255, 0.35)";
                            let baseAlpha = (iv.level === 0) ? 0.65 : (iv.level === 1 ? 0.55 : 0.45);
                            if (root.isHoveringSpiral) {
                                ctx.globalAlpha = isActiveAtHover ? 0.92 : (isSelected ? 0.65 : 0.20);
                            } else {
                                ctx.globalAlpha = isHovered ? 0.85 : (isSelected ? 0.75 : baseAlpha);
                            }
                            ctx.fill();

                            // Border stroke
                            let isHighlighted = isActiveAtHover || isHovered || isSelected;
                            ctx.strokeStyle = isHighlighted ? "#38BDF8" : (iv.color ? iv.color : "rgba(255, 255, 255, 0.85)");
                            ctx.lineWidth = isHighlighted ? 2.5 : 1.0;
                            if (root.isHoveringSpiral) {
                                ctx.globalAlpha = isHighlighted ? 1.0 : 0.20;
                            } else {
                                ctx.globalAlpha = isHighlighted ? 1.0 : 0.85;
                            }
                            ctx.stroke();

                            // Progressive Label Disclosure inside the slice based on available room
                            if (arcPixels >= 45) {
                                let aMid = (ca1 + ca2) * 0.5;
                                let rLabel = root.getSpiralCenterRadius(aMid, metrics) + subTrack.offsetMid;
                                let lx = cx + rLabel * Math.sin(aMid);
                                let ly = cy - rLabel * Math.cos(aMid);

                                ctx.font = (iv.level === 0) ? "bold 10px sans-serif" : "9px sans-serif";
                                ctx.fillStyle = "#FFFFFF";
                                ctx.globalAlpha = isActiveAtHover ? 1.0 : (root.isHoveringSpiral ? 0.25 : 1.0);
                                ctx.textAlign = "center";
                                ctx.textBaseline = "middle";
                                ctx.shadowColor = "rgba(0, 0, 0, 0.95)";
                                ctx.shadowBlur = 5;
                                ctx.fillText((iv.icon ? iv.icon + " " : "") + iv.title, lx, ly);
                                ctx.shadowColor = "transparent";
                                ctx.shadowBlur = 0;
                            } else if (arcPixels >= 16 && iv.icon) {
                                let aMid = (ca1 + ca2) * 0.5;
                                let rLabel = root.getSpiralCenterRadius(aMid, metrics) + subTrack.offsetMid;
                                let lx = cx + rLabel * Math.sin(aMid);
                                let ly = cy - rLabel * Math.cos(aMid);

                                ctx.font = "11px sans-serif";
                                ctx.fillStyle = "#FFFFFF";
                                ctx.globalAlpha = isActiveAtHover ? 1.0 : (root.isHoveringSpiral ? 0.25 : 1.0);
                                ctx.textAlign = "center";
                                ctx.textBaseline = "middle";
                                ctx.fillText(iv.icon, lx, ly);
                            }
                        }
                    }
                }
            }

            // 6. Point Items & Steps
            if (root.showIcons) {
                let pointList = hasPlan ? root.planModel.pointItems : root.events;

                for (let j = 0; j < pointList.length; ++j) {
                    let ev = pointList[j];
                    let evTime = hasPlan ? ev.startTime : ev.time;
                    let startCoil, endCoil;
                    if (ev.repeatDaily) {
                        startCoil = 0;
                        endCoil = root.daysCount - 1;
                    } else if (ev.day !== undefined && ev.day >= 0) {
                        let targetCoil = (ev.day - root.currentDayOfWeek + 7) % 7;
                        if (targetCoil >= root.daysCount) continue;
                        startCoil = targetCoil;
                        endCoil = targetCoil;
                    } else {
                        startCoil = 0;
                        endCoil = 0;
                    }

                    for (let day = startCoil; day <= endCoil; ++day) {
                        let a = day * 2 * Math.PI + root.timeToAngle(evTime);
                        let subTrack = root.getSpiralSubTrack(ev.level || 0, maxL, metrics);
                        let r = root.getSpiralCenterRadius(a, metrics) + subTrack.offsetMid;
                        let ex = cx + r * Math.sin(a);
                        let ey = cy - r * Math.cos(a);

                        let actualDay = (root.currentDayOfWeek + day) % 7;
                        let isPointActive = false;
                        if (root.isHoveringSpiral && root.hoveredCoil === day && root.hoveredTime >= 0) {
                            let diffH = Math.abs(evTime - root.hoveredTime) % 24.0;
                            if (diffH > 12.0) diffH = 24.0 - diffH;
                            isPointActive = (diffH <= 0.20);
                        }

                        let isHovered = isPointActive || (root.hoveredItem && root.hoveredItem.title === ev.title && (root.hoveredItem.day === undefined || root.hoveredItem.day === actualDay));
                        let isSelected = (root.selectedItem && root.selectedItem.title === ev.title);
                        let badgeRadius = (isHovered || isSelected) ? 14 : (root.daysCount === 3 ? 12 : 10);

                        ctx.save();
                        if (root.isHoveringSpiral && !isHovered) {
                            ctx.globalAlpha = 0.25;
                        }

                        ctx.beginPath();
                        ctx.arc(ex, ey, badgeRadius, 0, 2 * Math.PI, false);
                        ctx.fillStyle = ev.color ? ev.color : (ev.isUntimedStep ? "#FEF08A" : "#FFFFFF");
                        ctx.fill();
                        ctx.strokeStyle = (isHovered || isSelected) ? "#38BDF8" : "#1E293B";
                        ctx.lineWidth = (isHovered || isSelected) ? 2.2 : 1.2;
                        ctx.stroke();

                        ctx.font = (isHovered || isSelected) ? "13px sans-serif" : "10px sans-serif";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillStyle = "#1E293B";
                        ctx.fillText(ev.icon ? ev.icon : (ev.orderIndex ? ev.orderIndex : "📌"), ex, ey + 1);

                        if (isHovered && !root.isHoveringSpiral) {
                            let titleY = ey - 22;
                            let dayPrefix = (day === 0) ? "TODAY" : ((day === 1 && root.daysCount === 3) ? "TMRW" : root.dayShortNames[actualDay]);
                            let tipText = dayPrefix + " • " + (ev.icon ? ev.icon + " " : "") + ev.title;
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
                        ctx.restore();
                    }
                }
            }

            // 7. Day Pill Badges at 00:00 Midnight (North) for Each Spiral Coil
            for (let day = 0; day < root.daysCount; ++day) {
                let aStart = day * 2 * Math.PI + root.timeToAngle(0.0);
                let rStart = root.getSpiralCenterRadius(aStart, metrics);
                let bx = cx + rStart * Math.sin(aStart);
                let by = cy - rStart * Math.cos(aStart);

                let isToday = (day === 0);
                let actualDay = (root.currentDayOfWeek + day) % 7;
                let dayName = root.dayShortNames[actualDay];
                let badgeText = (day === 0) ? (root.daysCount === 3 ? "TODAY • " + dayName : "TODAY") :
                                (day === 1 && root.daysCount === 3 ? "TMRW • " + dayName :
                                (day === 2 && root.daysCount === 3 ? "+2D • " + dayName : dayName));

                let badgeH = Math.min(18, Math.max(12, metrics.bandWidth * 0.72));
                let badgeW = (root.daysCount === 3) ? 72 : Math.min(36, metrics.bandWidth * 1.65);

                let rx = bx - badgeW / 2;
                let ry = by - badgeH / 2;
                let rw = badgeW;
                let rh = badgeH;
                let rad = rh * 0.5;

                root.drawRoundedRect(ctx, rx, ry, rw, rh, rad);
                ctx.fillStyle = isToday ? "#F43F5E" : "rgba(15, 23, 42, 0.88)";
                ctx.fill();
                ctx.strokeStyle = isToday ? "#FDA4AF" : "rgba(255, 255, 255, 0.40)";
                ctx.lineWidth = 1.2;
                ctx.stroke();

                ctx.font = (root.daysCount === 3) ? "bold 9px sans-serif" : "bold 8px sans-serif";
                ctx.fillStyle = "#FFFFFF";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText(badgeText, bx, by);
            }

            // 8. Live System Time Needle & "NOW" Marker on the Spiral
            if (root.showCurrentTimeHand) {
                let nowDay = 0; // In rolling mode, Today is always coil 0 on the outer rim
                let nowH = root.currentTimeHours;
                let nowAngle = nowDay * 2 * Math.PI + root.timeToAngle(nowH);
                let rCenter = root.getSpiralCenterRadius(nowAngle, metrics);
                let r1 = rCenter - halfW - 2;
                let r2 = rCenter + halfW + 2;

                let sinNow = Math.sin(nowAngle);
                let cosNow = Math.cos(nowAngle);

                // Sleek needle across TODAY's winding band
                ctx.beginPath();
                ctx.moveTo(cx + r1 * sinNow, cy - r1 * cosNow);
                ctx.lineTo(cx + r2 * sinNow, cy - r2 * cosNow);
                ctx.strokeStyle = "#F43F5E";
                ctx.lineWidth = 2.8;
                ctx.shadowColor = "rgba(244, 63, 94, 0.75)";
                ctx.shadowBlur = 6;
                ctx.stroke();
                ctx.shadowColor = "transparent";
                ctx.shadowBlur = 0;

                // Circular "NOW" beacon on the outer edge of today's winding
                let nx = cx + (r2 + 7) * sinNow;
                let ny = cy - (r2 + 7) * cosNow;

                ctx.beginPath();
                ctx.arc(nx, ny, 7, 0, 2 * Math.PI, false);
                ctx.fillStyle = "#F43F5E";
                ctx.fill();
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1.6;
                ctx.stroke();

                ctx.font = "bold 7px sans-serif";
                ctx.fillStyle = "#FFFFFF";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText("NOW", nx, ny + 1);
            }

            // 9. Focus Lens Arc Highlight on Outer Rim
            if (root.showLensHighlight && Math.abs(root.zoom - 1.0) > 0.05) {
                let isZoomedIn = (root.zoom > 1.0);
                let a1 = root.warpAngle(root.focusAngle - Math.PI / 8) - Math.PI / 2;
                let a2 = root.warpAngle(root.focusAngle + Math.PI / 8) - Math.PI / 2;
                let fSpan = a2 - a1;
                while (fSpan <= 0) fSpan += 2 * Math.PI;
                while (fSpan > 2 * Math.PI) fSpan -= 2 * Math.PI;

                ctx.beginPath();
                ctx.arc(cx, cy, metrics.rOuter + 6, a1, a1 + fSpan, false);
                ctx.strokeStyle = isZoomedIn ? "#F59E0B" : "#F43F5E";
                ctx.lineWidth = isZoomedIn ? 5 : 4;
                ctx.stroke();
            }

            // 10. Center Hub
            ctx.beginPath();
            ctx.arc(cx, cy, metrics.rInner, 0, 2 * Math.PI, false);
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
                ctx.fillText(liveTimeStr, cx, cy - 8);
                ctx.fillStyle = "#FDA4AF";
                ctx.font = "bold 9px sans-serif";
                ctx.fillText(root.dayNames[root.currentDayOfWeek].toUpperCase(), cx, cy + 5);
                ctx.fillStyle = "#94A3B8";
                ctx.font = "8px sans-serif";
                ctx.fillText("LIVE (" + root.zoom.toFixed(1) + "x)", cx, cy + 16);
            } else if (root.zoom > 1.05) {
                ctx.fillStyle = "#38BDF8";
                ctx.font = "bold 13px sans-serif";
                ctx.fillText(root.zoom.toFixed(1) + "x", cx, cy - 7);
                ctx.fillStyle = "#94A3B8";
                ctx.font = "9px sans-serif";
                ctx.fillText(root.daysCount === 3 ? "3-DAY (72h)" : "7-DAY SPIRAL", cx, cy + 7);
            } else {
                ctx.fillStyle = "#F8FAFC";
                ctx.font = "bold 11px sans-serif";
                ctx.fillText(root.daysCount === 3 ? "3-DAY (72H)" : "7-DAY WEEK", cx, cy - 7);
                ctx.fillStyle = "#94A3B8";
                ctx.font = "9px sans-serif";
                ctx.fillText("SPIRAL (1.0x)", cx, cy + 7);
            }

            // 11. Top-Level High-Contrast Readability Pass (Active Activities Highlight)
            if (root.isHoveringSpiral && root.hoveredTime >= 0 && root.hoveredCoil >= 0) {
                let hTime = root.hoveredTime;
                let hCoil = root.hoveredCoil;
                let targetCalendarDay = (root.currentDayOfWeek + hCoil) % 7;
                let hAngle = root.timeToAngle(hTime);
                let aTotal = hCoil * 2 * Math.PI + hAngle;
                let rCenter = root.getSpiralCenterRadius(aTotal, metrics);

                let activeActs = root.getActiveActivitiesAtTime(hTime, targetCalendarDay);

                // A. Hairline Guideline across hovered coil's winding
                let r1 = rCenter - metrics.bandWidth * 0.5 - 2;
                let r2 = rCenter + metrics.bandWidth * 0.5 + 2;
                let sinH = Math.sin(hAngle);
                let cosH = Math.cos(hAngle);

                ctx.save();
                ctx.beginPath();
                ctx.moveTo(cx + r1 * sinH, cy - r1 * cosH);
                ctx.lineTo(cx + r2 * sinH, cy - r2 * cosH);
                ctx.strokeStyle = "#38BDF8";
                ctx.lineWidth = 2.0;
                ctx.setLineDash([3, 2]);
                ctx.shadowColor = "rgba(56, 189, 248, 0.8)";
                ctx.shadowBlur = 6;
                ctx.stroke();
                ctx.restore();

                // B. Floating Activity Callout Card (Zero-Overlap Layout)
                let cardWidth = 290;
                let rowH = 24;
                let headerH = 34;
                let cardHeight = headerH + Math.max(1, activeActs.length) * rowH + 10;

                // Adjust card width dynamically if title is wide
                ctx.font = "bold 11px sans-serif";
                for (let aIdx = 0; aIdx < activeActs.length; ++aIdx) {
                    let act = activeActs[aIdx];
                    let prefix = (act.level === 0) ? "🔷 " : (act.level === 1 ? "  ↳ " : "    ↳ ");
                    if (act.isPoint) prefix = "📌 ";
                    let titleStr = prefix + (act.icon ? act.icon + " " : "") + act.title;
                    let fullW = ctx.measureText(titleStr).width + 130;
                    if (fullW > cardWidth) cardWidth = Math.min(420, fullW);
                }

                // Position card with 24px clearance from cursor to prevent covering cursor and dial slices
                let cardX;
                if (root.hoveredX > cx) {
                    cardX = root.hoveredX + 24;
                    if (cardX + cardWidth > root.width - 12) {
                        cardX = root.hoveredX - cardWidth - 24;
                    }
                } else {
                    cardX = root.hoveredX - cardWidth - 24;
                    if (cardX < 12) {
                        cardX = root.hoveredX + 24;
                    }
                }
                if (cardX < 12) cardX = 12;
                if (cardX + cardWidth > root.width - 12) cardX = root.width - cardWidth - 12;

                let cardY = root.hoveredY - cardHeight * 0.5;
                if (cardY < 12) cardY = 12;
                if (cardY + cardHeight > root.height - 12) cardY = root.height - cardHeight - 12;

                // C. Leader line from cursor anchor to card
                let anchorCardX = (root.hoveredX < cardX) ? cardX : (cardX + cardWidth);
                let anchorCardY = Math.max(cardY + 12, Math.min(cardY + cardHeight - 12, root.hoveredY));

                ctx.save();
                ctx.strokeStyle = "rgba(56, 189, 248, 0.65)";
                ctx.lineWidth = 1.4;
                ctx.setLineDash([3, 2]);
                ctx.beginPath();
                ctx.moveTo(root.hoveredX, root.hoveredY);
                ctx.lineTo(anchorCardX, anchorCardY);
                ctx.stroke();
                ctx.setLineDash([]);

                // Target anchor pip at cursor point on track
                ctx.beginPath();
                ctx.arc(root.hoveredX, root.hoveredY, 4, 0, 2 * Math.PI, false);
                ctx.fillStyle = "#38BDF8";
                ctx.fill();
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1.5;
                ctx.stroke();

                // Draw Card Container
                ctx.shadowColor = "rgba(0, 0, 0, 0.85)";
                ctx.shadowBlur = 14;
                root.drawRoundedRect(ctx, cardX, cardY, cardWidth, cardHeight, 8);
                ctx.fillStyle = "rgba(15, 23, 42, 0.96)";
                ctx.fill();
                ctx.strokeStyle = "#38BDF8";
                ctx.lineWidth = 1.6;
                ctx.stroke();

                ctx.shadowColor = "transparent";
                ctx.shadowBlur = 0;

                // Header with Day + Time
                let dayLabel = (hCoil === 0) ? "TODAY" :
                               (hCoil === 1 && root.daysCount === 3 ? "TOMORROW" : root.dayNames[targetCalendarDay]);
                let headerTitle = "📅 " + dayLabel + " • " + root.formatClockTime(hTime);
                let countStr = activeActs.length === 0 ? "No active activities" : (activeActs.length === 1 ? "1 Active Activity" : activeActs.length + " Active Activities");

                ctx.font = "bold 12px sans-serif";
                ctx.fillStyle = "#38BDF8";
                ctx.textAlign = "left";
                ctx.textBaseline = "middle";
                ctx.fillText(headerTitle, cardX + 12, cardY + 18);

                ctx.font = "10px sans-serif";
                ctx.fillStyle = "#94A3B8";
                ctx.textAlign = "right";
                ctx.fillText(countStr, cardX + cardWidth - 12, cardY + 18);

                // Separator line
                ctx.beginPath();
                ctx.moveTo(cardX + 10, cardY + 30);
                ctx.lineTo(cardX + cardWidth - 10, cardY + 30);
                ctx.strokeStyle = "rgba(56, 189, 248, 0.30)";
                ctx.lineWidth = 1.0;
                ctx.stroke();

                // Non-overlapping rows for all active activities
                if (activeActs.length === 0) {
                    ctx.font = "italic 11px sans-serif";
                    ctx.fillStyle = "#94A3B8";
                    ctx.textAlign = "left";
                    ctx.fillText("No scheduled broadcasts or tasks", cardX + 14, cardY + 46);
                } else {
                    for (let aIdx = 0; aIdx < activeActs.length; ++aIdx) {
                        let act = activeActs[aIdx];
                        let curY = cardY + 44 + aIdx * rowH;

                        let prefix = (act.level === 0) ? "🔷 " : (act.level === 1 ? "  ↳ " : "    ↳ ");
                        if (act.isPoint) prefix = "📌 ";
                        let title = prefix + (act.icon ? act.icon + " " : "") + act.title;
                        let timeRange = act.startClock ? (act.startClock + " - " + act.endClock) : (root.formatClockTime(act.startTime) + " - " + root.formatClockTime(act.endTime));
                        if (act.isPoint) timeRange = act.startClock || root.formatClockTime(act.startTime || act.time);

                        ctx.font = (act.level === 0) ? "bold 11px sans-serif" : "11px sans-serif";
                        ctx.fillStyle = "#FFFFFF";
                        ctx.textAlign = "left";
                        ctx.textBaseline = "middle";

                        let maxTitleW = cardWidth - 110;
                        let dispTitle = title;
                        if (ctx.measureText(dispTitle).width > maxTitleW) {
                            while (dispTitle.length > 3 && ctx.measureText(dispTitle + "...").width > maxTitleW) {
                                dispTitle = dispTitle.substring(0, dispTitle.length - 1);
                            }
                            dispTitle += "...";
                        }
                        ctx.fillText(dispTitle, cardX + 12, curY);

                        ctx.font = "10px monospace";
                        ctx.fillStyle = "#38BDF8";
                        ctx.textAlign = "right";
                        ctx.fillText(timeRange, cardX + cardWidth - 12, curY);
                    }
                }
                ctx.restore();
            }
        }
    }

    // --- Interactive Gesture Handlers ---

    // 1. Pinch Gesture Handler (Trackpad / Touch)
    PinchHandler {
        id: pinchHandler
        enabled: root.interactive
        target: null
        property real lastScale: 1.0

        onActiveChanged: {
            if (active) lastScale = 1.0;
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

    // 2. Mouse Wheel Handler
    WheelHandler {
        id: wheelHandler
        enabled: root.interactive
        target: null
        onWheel: (event) => {
            root.handleWheelZoom(point.position.x, point.position.y, event.angleDelta.y);
        }
    }

    // 3. Drag Handler (Rotate focus angle)
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

    // 4. Tap Handler
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

    // 5. Hover Handler on Spiral (Constant Time O(1) Geometry Hit-Testing)
    HoverHandler {
        enabled: root.interactive
        onHoveredChanged: {
            if (!hovered) {
                root.isHoveringSpiral = false;
                root.hoveredCoil = -1;
                root.hoveredDay = -1;
                root.hoveredTime = -1;
                root.hoveredItem = null;
                canvas.requestPaint();
            }
        }
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
            let metrics = root.getSpiralMetrics(radius);

            // Compute spiral cursor position and coil
            let cursorClockAngle = Math.atan2(dx, -dy);
            if (cursorClockAngle < 0) cursorClockAngle += 2 * Math.PI;
            let cursorTime = root.angleToTime(cursorClockAngle);

            let dApprox = ((metrics.rOuter - metrics.bandWidth * 0.5) - dist) / metrics.pitch - (cursorClockAngle / (2 * Math.PI));
            let targetDay = Math.round(dApprox);

            if (targetDay >= 0 && targetDay < root.daysCount) {
                let aCenter = targetDay * 2 * Math.PI + cursorClockAngle;
                let rCenter = root.getSpiralCenterRadius(aCenter, metrics);
                let targetCalendarDay = (root.currentDayOfWeek + targetDay) % 7;

                if (Math.abs(dist - rCenter) <= metrics.bandWidth * 0.5 + 4) {
                    root.isHoveringSpiral = true;
                    root.hoveredCoil = targetDay;
                    root.hoveredDay = targetCalendarDay;
                    root.hoveredTime = cursorTime;
                    root.hoveredX = px;
                    root.hoveredY = py;
                } else {
                    root.isHoveringSpiral = false;
                    root.hoveredCoil = -1;
                    root.hoveredDay = -1;
                    root.hoveredTime = -1;
                }
            } else {
                root.isHoveringSpiral = false;
                root.hoveredCoil = -1;
                root.hoveredDay = -1;
                root.hoveredTime = -1;
            }

            // 1. Point items check first
            let closestItem = null;
            let minDistance = 18;
            let pointList = hasPlan ? root.planModel.pointItems : root.events;
            let maxL = (root.planModel && root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 1;

            for (let j = 0; j < pointList.length; ++j) {
                let ev = pointList[j];
                let evTime = hasPlan ? ev.startTime : ev.time;
                let startCoil, endCoil;
                if (ev.repeatDaily) {
                    startCoil = 0;
                    endCoil = root.daysCount - 1;
                } else if (ev.day !== undefined && ev.day >= 0) {
                    let targetCoil = (ev.day - root.currentDayOfWeek + 7) % 7;
                    if (targetCoil >= root.daysCount) continue;
                    startCoil = targetCoil;
                    endCoil = targetCoil;
                } else {
                    startCoil = 0;
                    endCoil = 0;
                }

                for (let coil = startCoil; coil <= endCoil; ++coil) {
                    let a = coil * 2 * Math.PI + root.timeToAngle(evTime);
                    let subTrack = root.getSpiralSubTrack(ev.level || 0, maxL, metrics);
                    let r = root.getSpiralCenterRadius(a, metrics) + subTrack.offsetMid;
                    let ex = cx + r * Math.sin(a);
                    let ey = cy - r * Math.cos(a);
                    let d = Math.hypot(px - ex, py - ey);
                    if (d < minDistance) {
                        minDistance = d;
                        let actualDay = (root.currentDayOfWeek + coil) % 7;
                        closestItem = Object.assign({}, ev, { day: actualDay, coil: coil });
                    }
                }
            }

            // 2. Spiral Interval hit-testing via O(1) inverse spiral equation
            if (!closestItem && hasPlan && root.isHoveringSpiral && root.hoveredCoil >= 0) {
                let aCenter = root.hoveredCoil * 2 * Math.PI + cursorClockAngle;
                let rCenter = root.getSpiralCenterRadius(aCenter, metrics);
                let targetCalendarDay = (root.currentDayOfWeek + root.hoveredCoil) % 7;
                let hasLevels = (root.planModel.levels && root.planModel.levels.length > 0);

                for (let targetLevel = maxL; targetLevel >= 0; --targetLevel) {
                    let subTrack = root.getSpiralSubTrack(targetLevel, maxL, metrics);
                    let rSubMid = rCenter + subTrack.offsetMid;
                    let subHalfH = subTrack.trackH * 0.5;

                    if (Math.abs(dist - rSubMid) <= subHalfH + 2) {
                        let levelItems = hasLevels ? root.planModel.levels[targetLevel] : root.planModel.intervals;
                        if (!levelItems) continue;

                        for (let k = 0; k < levelItems.length; ++k) {
                            let iv = levelItems[k];
                            let matches = false;
                            if (iv.repeatDaily) {
                                matches = true;
                            } else if (iv.day !== undefined && iv.day >= 0) {
                                let itemCoil = (iv.day - root.currentDayOfWeek + 7) % 7;
                                matches = (itemCoil === root.hoveredCoil);
                            } else {
                                matches = (root.hoveredCoil === 0);
                            }
                            if (!matches) continue;

                            let s = iv.startTime;
                            let e = iv.endTime;
                            let inside = (e >= s) ? (cursorTime >= s && cursorTime <= e) : (cursorTime >= s || cursorTime <= e);
                            if (inside) {
                                closestItem = Object.assign({}, iv, { day: targetCalendarDay, coil: root.hoveredCoil });
                                break;
                            }
                        }
                        if (closestItem) break;
                    }
                }

                // Fallback: if in collapsed outer region of this day's band, find parent item
                if (!closestItem) {
                    let levelItems = hasLevels ? root.planModel.levels[0] : root.planModel.intervals;
                    if (levelItems) {
                        for (let k = 0; k < levelItems.length; ++k) {
                            let iv = levelItems[k];
                            let matches = false;
                            if (iv.repeatDaily) {
                                matches = true;
                            } else if (iv.day !== undefined && iv.day >= 0) {
                                let itemCoil = (iv.day - root.currentDayOfWeek + 7) % 7;
                                matches = (itemCoil === root.hoveredCoil);
                            } else {
                                matches = (root.hoveredCoil === 0);
                            }
                            if (!matches) continue;

                            let s = iv.startTime;
                            let e = iv.endTime;
                            let inside = (e >= s) ? (cursorTime >= s && cursorTime <= e) : (cursorTime >= s || cursorTime <= e);
                            if (inside) {
                                closestItem = Object.assign({}, iv, { day: targetCalendarDay, coil: root.hoveredCoil });
                                break;
                            }
                        }
                    }
                }
            }

            if (root.hoveredItem !== closestItem || root.isHoveringSpiral) {
                root.hoveredItem = closestItem;
                canvas.requestPaint();
            }
        }
    }
}
