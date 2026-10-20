import QtQuick

Item {
    id: root

    // --- Public Properties ---
    property real zoom: 1.0             // 1.0 = equitemporal linear top-to-bottom, > 1.0 = expanded around focus
    property real focusAngle: Math.PI   // Radians [0..2π] -> 12:00 Noon by default
    property real minZoom: 0.20
    property real maxZoom: 16.0
    property bool interactive: true
    property bool showIcons: true
    property bool showLabels: true

    // Calendar Duration Parameters (1 = 24h, 3 = 3-Day, 7 = 7-Day Week)
    property int daysCount: 7
    property int dayOffset: 0          // Day offset (e.g. for navigating in 24h view)
    property var dayNames: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    property var dayShortNames: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    // 8 3-hour circadian time sections (00:00 to 24:00)
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

    // Plan Model integration
    property var planModel: null
    property var hoveredItem: null
    property var selectedItem: null
    signal itemClicked(var item)

    // Interactive Hover & Readability Tracking
    property real hoveredTime: -1
    property int hoveredCol: -1
    property int hoveredDay: -1
    property bool isHoveringTable: false
    property real hoveredX: 0
    property real hoveredY: 0

    // Geometry layout cache
    readonly property real gutterW: 64
    readonly property real headerH: 38
    readonly property real topMargin: 6
    readonly property real bottomMargin: 10
    readonly property real rightMargin: 8
    readonly property real gridX: gutterW
    readonly property real gridY: headerH + topMargin
    readonly property real gridW: Math.max(10, width - gridX - rightMargin)
    readonly property real gridH: Math.max(10, height - gridY - bottomMargin)

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
        interval: 250
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
        enabled: !root.followTime
        RotationAnimation {
            direction: RotationAnimation.Shortest
            duration: 130
            easing.type: Easing.OutQuad
        }
    }

    onZoomChanged: canvas.requestPaint()
    onFocusAngleChanged: canvas.requestPaint()
    onDaysCountChanged: canvas.requestPaint()
    onDayOffsetChanged: canvas.requestPaint()
    onFollowTimeChanged: {
        if (followTime) {
            updateCurrentTime();
        }
    }

    implicitWidth: 640
    implicitHeight: 540

    // Reset Zoom to Equitemporal (1.0x)
    function resetZoom() {
        root.zoom = 1.0;
        canvas.requestPaint();
    }

    // --- Mathematical Mapping for Straight Time Axis (Starts at Top, Ends at Bottom) ---
    // At hours = 0.0 -> gridY (Top)
    // At hours = 24.0 -> gridY + gridH (Bottom)
    // No vertical scrolling needed: the full 24h day spans height & width
    function timeToY(hours, gY, gH) {
        let clampedH = Math.max(0.0, Math.min(24.0, hours));
        if (Math.abs(root.zoom - 1.0) < 0.001) {
            return gY + (clampedH / 24.0) * gH;
        }
        let focusH = (root.focusAngle / (2.0 * Math.PI)) * 24.0;
        let k = 4.0;
        let gMin = Math.atan(root.zoom * (0.0 - focusH) / k);
        let gMax = Math.atan(root.zoom * (24.0 - focusH) / k);
        let gVal = Math.atan(root.zoom * (clampedH - focusH) / k);
        let frac = (gVal - gMin) / (gMax - gMin);
        return gY + Math.max(0.0, Math.min(1.0, frac)) * gH;
    }

    // Inverse mapping from Y coordinate to time in hours [0..24]
    function yToTime(y, gY, gH) {
        let frac = Math.max(0.0, Math.min(1.0, (y - gY) / gH));
        if (Math.abs(root.zoom - 1.0) < 0.001) {
            return frac * 24.0;
        }
        let focusH = (root.focusAngle / (2.0 * Math.PI)) * 24.0;
        let k = 4.0;
        let gMin = Math.atan(root.zoom * (0.0 - focusH) / k);
        let gMax = Math.atan(root.zoom * (24.0 - focusH) / k);
        let targetG = gMin + frac * (gMax - gMin);
        let h = focusH + (k / root.zoom) * Math.tan(targetG);
        return Math.max(0.0, Math.min(24.0, h));
    }

    function formatClockTime(hours) {
        let h = Math.floor(hours) % 24;
        let m = Math.floor((hours % 1) * 60);
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    // Diurnal / Circadian blended color function matching Circle & Spiral exactly:
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
        return "rgb(22, 48, 118)";
    }

    // Safe cross-platform rounded rectangle path without relying on ctx.roundRect
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

    function isItemActiveAtTime(item, t) {
        if (!item) return false;
        let s = item.startTime;
        let e = item.endTime;
        if (s === undefined || e === undefined) return false;
        if (Math.abs(s - e) < 0.001) {
            return Math.abs(t - s) < 0.10;
        }
        if (e > s) {
            return (t >= s && t <= e);
        } else {
            return (t >= s || t <= e);
        }
    }

    // Get column specifications based on mode (24h, 3-Day, 7-Day)
    function getColumnDays() {
        let cols = [];
        if (root.daysCount === 7) {
            // Standard weekly calendar: Monday (0) through Sunday (6)
            for (let i = 0; i < 7; ++i) {
                cols.push({
                    day: i,
                    name: root.dayNames[i],
                    shortName: root.dayShortNames[i],
                    isToday: (i === root.currentDayOfWeek)
                });
            }
        } else if (root.daysCount === 3) {
            // 3-Day rolling window starting today
            for (let i = 0; i < 3; ++i) {
                let d = (root.currentDayOfWeek + root.dayOffset + i) % 7;
                if (d < 0) d += 7;
                let isToday = (d === root.currentDayOfWeek);
                let label = (i === 0 && isToday) ? "Today" : ((i === 1 && (root.currentDayOfWeek + 1) % 7 === d) ? "Tomorrow" : root.dayShortNames[d]);
                cols.push({
                    day: d,
                    name: label + " • " + root.dayNames[d],
                    shortName: root.dayShortNames[d],
                    isToday: isToday
                });
            }
        } else {
            // 24h single day view (Today by default)
            let d = (root.currentDayOfWeek + root.dayOffset) % 7;
            if (d < 0) d += 7;
            let isToday = (d === root.currentDayOfWeek);
            cols.push({
                day: d,
                name: (isToday ? "Today • " : "") + root.dayNames[d],
                shortName: root.dayShortNames[d],
                isToday: isToday
            });
        }
        return cols;
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
            if (Math.abs(pTime - t) <= 0.20) {
                result.push(Object.assign({}, p, { isPoint: true }));
            }
        }
        result.sort((a, b) => (a.level || 0) - (b.level || 0));
        return result;
    }

    // Public method: is an item visible in the current tabular calendar view?
    function isItemVisibleOnDial(item) {
        if (!item) return false;
        let cols = root.getColumnDays();
        let matchesDay = false;
        for (let c = 0; c < cols.length; ++c) {
            let calDay = cols[c].day;
            if (item.repeatDaily || (item.day !== undefined && item.day === calDay) || (item.day === undefined && calDay === root.currentDayOfWeek)) {
                matchesDay = true;
                break;
            }
        }
        if (!matchesDay) return false;
        let y1 = root.timeToY(item.startTime, root.gridY, root.gridH);
        let y2 = root.timeToY(item.endTime, root.gridY, root.gridH);
        return Math.abs(y2 - y1) >= 2.0;
    }

    // Canvas Painting
    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            let ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, width, height);

            let gX = root.gridX;
            let gY = root.gridY;
            let gW = root.gridW;
            let gH = root.gridH;
            if (gW <= 20 || gH <= 20) return;

            let cols = root.getColumnDays();
            let colCount = cols.length;
            let colW = gW / colCount;
            let hasPlan = (root.planModel && root.planModel.flatItems && root.planModel.flatItems.length > 0);
            let maxL = (root.planModel && root.planModel.maxLevel !== undefined) ? root.planModel.maxLevel : 0;

            // 1. Column Headers
            ctx.save();
            for (let c = 0; c < colCount; ++c) {
                let col = cols[c];
                let colX = gX + c * colW;
                let boxX = colX + 2;
                let boxW = colW - 4;
                let boxH = root.headerH - 6;
                let boxY = 4;

                // Header pill background
                if (col.isToday) {
                    drawRoundedRect(ctx, boxX, boxY, boxW, boxH, 6);
                    ctx.fillStyle = "rgba(37, 99, 235, 0.35)";
                    ctx.fill();
                    ctx.strokeStyle = "#38BDF8";
                    ctx.lineWidth = 1.6;
                    ctx.stroke();
                } else {
                    drawRoundedRect(ctx, boxX, boxY, boxW, boxH, 6);
                    ctx.fillStyle = "rgba(30, 41, 59, 0.70)";
                    ctx.fill();
                    ctx.strokeStyle = "rgba(51, 65, 85, 0.85)";
                    ctx.lineWidth = 1.0;
                    ctx.stroke();
                }

                // Header text
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                let textY = boxY + boxH * 0.5;

                if (col.isToday) {
                    if (boxW >= 110) {
                        ctx.font = "bold 11px sans-serif";
                        ctx.fillStyle = "#38BDF8";
                        ctx.fillText("TODAY • " + (boxW >= 150 ? col.name : col.shortName), boxX + boxW * 0.5, textY);
                    } else {
                        ctx.font = "bold 10px sans-serif";
                        ctx.fillStyle = "#38BDF8";
                        ctx.fillText(col.shortName + " (TODAY)", boxX + boxW * 0.5, textY);
                    }
                } else {
                    ctx.font = (boxW >= 100) ? "bold 11px sans-serif" : "bold 10px sans-serif";
                    ctx.fillStyle = "#E2E8F0";
                    let titleStr = (boxW >= 120) ? col.name : col.shortName;
                    ctx.fillText(titleStr, boxX + boxW * 0.5, textY);
                }
            }
            ctx.restore();

            // 2. Circadian Column Background Gradients (00:00 top to 24:00 bottom)
            ctx.save();
            let baseGrad = ctx.createLinearGradient(0, gY, 0, gY + gH);
            baseGrad.addColorStop(0.0 / 24.0, "rgb(22, 48, 118)");   // 00:00 Midnight blue
            baseGrad.addColorStop(3.5 / 24.0, "rgb(28, 56, 130)");   // 03:30 Deep calm night
            baseGrad.addColorStop(5.5 / 24.0, "rgb(65, 75, 130)");   // 05:30 Dawn twilight
            baseGrad.addColorStop(7.0 / 24.0, "rgb(220, 118, 50)");  // 07:00 Sunrise amber
            baseGrad.addColorStop(9.5 / 24.0, "rgb(248, 168, 30)");  // 09:30 Morning gold
            baseGrad.addColorStop(12.0 / 24.0, "rgb(255, 195, 18)"); // 12:00 Bright midday yellow
            baseGrad.addColorStop(14.5 / 24.0, "rgb(248, 160, 28)"); // 14:30 Afternoon sun
            baseGrad.addColorStop(17.0 / 24.0, "rgb(232, 110, 45)"); // 17:00 Golden hour
            baseGrad.addColorStop(19.5 / 24.0, "rgb(175, 68, 85)");  // 19:30 Sunset dusky rose
            baseGrad.addColorStop(21.5 / 24.0, "rgb(58, 48, 112)");  // 21:30 Evening indigo
            baseGrad.addColorStop(24.0 / 24.0, "rgb(22, 48, 118)");  // 24:00 Midnight blue

            for (let c = 0; c < colCount; ++c) {
                let col = cols[c];
                let colX = gX + c * colW;

                // Subtle circadian backdrop
                ctx.fillStyle = baseGrad;
                ctx.globalAlpha = 0.28;
                ctx.fillRect(colX + 2, gY, colW - 4, gH);

                // Highlight today column
                if (col.isToday) {
                    ctx.fillStyle = "rgba(56, 189, 248, 0.08)";
                    ctx.globalAlpha = 1.0;
                    ctx.fillRect(colX + 2, gY, colW - 4, gH);
                }

                // Column vertical border
                ctx.beginPath();
                ctx.moveTo(colX, gY);
                ctx.lineTo(colX, gY + gH);
                ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
                ctx.lineWidth = 1.0;
                ctx.globalAlpha = 1.0;
                ctx.stroke();
            }

            // Right closing grid border
            ctx.beginPath();
            ctx.moveTo(gX + gW, gY);
            ctx.lineTo(gX + gW, gY + gH);
            ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
            ctx.lineWidth = 1.0;
            ctx.stroke();
            ctx.restore();

            // 3. Horizontal Grid Lines & Ticks Across Straight Time Axis
            ctx.save();
            for (let h = 0; h <= 24; ++h) {
                let y = root.timeToY(h, gY, gH);
                let isMajor = (h % 3 === 0);

                ctx.beginPath();
                ctx.moveTo(gX, y);
                ctx.lineTo(gX + gW, y);
                ctx.strokeStyle = isMajor ? "rgba(255, 255, 255, 0.22)" : "rgba(255, 255, 255, 0.08)";
                ctx.lineWidth = isMajor ? 1.0 : 0.7;
                ctx.stroke();

                // Half-hour dashed line if height allows
                if (h < 24 && gH / 24.0 >= 32) {
                    let yHalf = root.timeToY(h + 0.5, gY, gH);
                    ctx.beginPath();
                    ctx.setLineDash([3, 4]);
                    ctx.moveTo(gX, yHalf);
                    ctx.lineTo(gX + gW, yHalf);
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.05)";
                    ctx.lineWidth = 0.6;
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
            }
            ctx.restore();

            // 4. Time Gutter Labels & Colored Section Indicators
            ctx.save();
            // Section color stripes on the left gutter
            for (let s = 0; s < root.sections.length; ++s) {
                let sec = root.sections[s];
                let sY1 = root.timeToY(sec.startH, gY, gH);
                let sY2 = root.timeToY(sec.endH, gY, gH);
                let barH = Math.max(2, sY2 - sY1 - 2);

                ctx.fillStyle = sec.color;
                drawRoundedRect(ctx, gX - 7, sY1 + 1, 4, barH, 2);
                ctx.fill();
            }

            // Time labels in gutter
            ctx.textAlign = "right";
            ctx.textBaseline = "middle";
            for (let h = 0; h <= 24; ++h) {
                let y = root.timeToY(h, gY, gH);
                let isMajor = (h % 3 === 0);

                if (isMajor) {
                    let timeStr = (h < 10 ? "0" : "") + h + ":00";
                    ctx.font = "bold 11px sans-serif";
                    ctx.fillStyle = "rgba(255, 255, 255, 0.88)";
                    ctx.fillText(timeStr, gX - 12, y);
                } else if (gH / 24.0 >= 28) {
                    let timeStr = (h < 10 ? "0" : "") + h + ":00";
                    ctx.font = "9px sans-serif";
                    ctx.fillStyle = "rgba(255, 255, 255, 0.40)";
                    ctx.fillText(timeStr, gX - 12, y);
                }
            }
            ctx.restore();

            // 5. Activity Intervals (Tabular Cards)
            if (hasPlan) {
                let intervals = root.planModel.intervals || [];
                let subTrackCount = Math.min(3, Math.max(1, maxL + 1));

                for (let c = 0; c < colCount; ++c) {
                    let col = cols[c];
                    let colX = gX + c * colW;

                    for (let i = 0; i < intervals.length; ++i) {
                        let iv = intervals[i];
                        let matches = false;
                        if (iv.repeatDaily) {
                            matches = true;
                        } else if (iv.day !== undefined && iv.day >= 0) {
                            matches = (iv.day === col.day);
                        } else {
                            matches = (col.day === root.currentDayOfWeek);
                        }
                        if (!matches) continue;

                        let sTime = iv.startTime;
                        let eTime = iv.crossesMidnight ? 24.0 : iv.endTime;
                        let y1 = root.timeToY(sTime, gY, gH);
                        let y2 = root.timeToY(eTime, gY, gH);
                        let cardH = Math.max(16, y2 - y1);

                        // Horizontal track position for multi-level items
                        let trackW = (colW - 8) / (subTrackCount > 1 ? subTrackCount : 1);
                        let trackIdx = Math.min(iv.level || 0, subTrackCount - 1);
                        let cardX = colX + 4 + (subTrackCount > 1 ? trackIdx * trackW : 0);
                        let cardW = (subTrackCount > 1 ? trackW - 2 : colW - 8);

                        // Hover & Selection state
                        let isHoveredCol = (root.isHoveringTable && root.hoveredCol === c);
                        let isActiveAtHover = isHoveredCol && (root.hoveredTime >= 0) && root.isItemActiveAtTime(iv, root.hoveredTime);
                        let isHovered = (root.hoveredItem && root.hoveredItem.title === iv.title && root.hoveredItem.startTime === iv.startTime);
                        let isSelected = (root.selectedItem && root.selectedItem.title === iv.title);
                        let isHighlighted = isActiveAtHover || isHovered || isSelected;

                        // Card Fill
                        ctx.save();
                        ctx.fillStyle = iv.color ? iv.color : "rgba(255, 255, 255, 0.35)";
                        let baseAlpha = (iv.level === 0) ? 0.65 : (iv.level === 1 ? 0.55 : 0.45);
                        if (root.isHoveringTable) {
                            ctx.globalAlpha = isActiveAtHover ? 0.95 : (isSelected ? 0.75 : 0.22);
                        } else {
                            ctx.globalAlpha = isHovered ? 0.85 : (isSelected ? 0.75 : baseAlpha);
                        }
                        drawRoundedRect(ctx, cardX, y1, cardW, cardH, Math.min(6, cardH * 0.25));
                        ctx.fill();

                        // Card Border Stroke
                        ctx.strokeStyle = isHighlighted ? "#38BDF8" : (iv.color ? iv.color : "rgba(255, 255, 255, 0.85)");
                        ctx.lineWidth = isHighlighted ? 2.5 : 1.0;
                        if (root.isHoveringTable) {
                            ctx.globalAlpha = isHighlighted ? 1.0 : 0.22;
                        } else {
                            ctx.globalAlpha = isHighlighted ? 1.0 : 0.85;
                        }
                        ctx.stroke();

                        // Card Text Content (Clips strictly to rounded card)
                        ctx.save();
                        ctx.beginPath();
                        drawRoundedRect(ctx, cardX, y1, cardW, cardH, Math.min(6, cardH * 0.25));
                        ctx.clip();

                        ctx.fillStyle = "#FFFFFF";
                        ctx.globalAlpha = isActiveAtHover ? 1.0 : (root.isHoveringTable ? 0.25 : 1.0);
                        ctx.textAlign = "left";
                        ctx.textBaseline = "top";
                        ctx.shadowColor = "rgba(0, 0, 0, 0.95)";
                        ctx.shadowBlur = 4;

                        let paddingX = 5;
                        let textX = cardX + paddingX;
                        let textY = y1 + 4;

                        if (cardH >= 34 && cardW >= 60) {
                            ctx.font = (iv.level === 0) ? "bold 11px sans-serif" : "bold 10px sans-serif";
                            let titleStr = (iv.icon ? iv.icon + " " : "") + iv.title;
                            ctx.fillText(titleStr, textX, textY);

                            ctx.font = "9px sans-serif";
                            ctx.fillStyle = "rgba(255, 255, 255, 0.85)";
                            let timeStr = iv.startClock + " - " + iv.endClock;
                            ctx.fillText(timeStr, textX, textY + 14);
                        } else if (cardH >= 16 && cardW >= 36) {
                            ctx.font = (cardW >= 65) ? "bold 10px sans-serif" : "9px sans-serif";
                            let titleStr = (iv.icon ? iv.icon + " " : "") + iv.title;
                            ctx.fillText(titleStr, textX, y1 + (cardH - 12) * 0.5);
                        } else if (iv.icon) {
                            ctx.font = "11px sans-serif";
                            ctx.textAlign = "center";
                            ctx.fillText(iv.icon, cardX + cardW * 0.5, y1 + (cardH - 11) * 0.5);
                        }
                        ctx.restore();
                        ctx.restore();

                        // Continuation for midnight-crossing items on next column
                        if (iv.crossesMidnight && c + 1 < colCount) {
                            let nextCol = cols[c + 1];
                            let nextColX = gX + (c + 1) * colW;
                            let yNext1 = root.timeToY(0.0, gY, gH);
                            let yNext2 = root.timeToY(iv.endTime, gY, gH);
                            let nextH = Math.max(16, yNext2 - yNext1);
                            let nextCardX = nextColX + 4 + (subTrackCount > 1 ? trackIdx * trackW : 0);

                            ctx.save();
                            ctx.fillStyle = iv.color ? iv.color : "rgba(255, 255, 255, 0.35)";
                            ctx.globalAlpha = root.isHoveringTable ? 0.22 : 0.55;
                            drawRoundedRect(ctx, nextCardX, yNext1, cardW, nextH, Math.min(6, nextH * 0.25));
                            ctx.fill();
                            ctx.strokeStyle = iv.color ? iv.color : "rgba(255, 255, 255, 0.85)";
                            ctx.lineWidth = 1.0;
                            ctx.stroke();

                            ctx.save();
                            ctx.beginPath();
                            drawRoundedRect(ctx, nextCardX, yNext1, cardW, nextH, 4);
                            ctx.clip();
                            ctx.fillStyle = "#FFFFFF";
                            ctx.font = "9px sans-serif";
                            ctx.fillText((iv.icon ? iv.icon + " " : "") + iv.title + " (cont.)", nextCardX + 5, yNext1 + 4);
                            ctx.restore();
                            ctx.restore();
                        }
                    }
                }
            }

            // 6. Point Items & Steps
            if (hasPlan) {
                let points = root.planModel.pointItems || [];
                for (let c = 0; c < colCount; ++c) {
                    let col = cols[c];
                    let colX = gX + c * colW;

                    for (let j = 0; j < points.length; ++j) {
                        let pt = points[j];
                        let matches = false;
                        if (pt.repeatDaily) {
                            matches = true;
                        } else if (pt.day !== undefined && pt.day >= 0) {
                            matches = (pt.day === col.day);
                        } else {
                            matches = (col.day === root.currentDayOfWeek);
                        }
                        if (!matches) continue;

                        let pTime = pt.startTime !== undefined ? pt.startTime : pt.time;
                        let pY = root.timeToY(pTime, gY, gH);

                        ctx.save();
                        // Point marker pill
                        let pillW = Math.min(colW - 12, 130);
                        let pillH = 18;
                        let pillX = colX + 6;
                        let pillY = pY - pillH * 0.5;

                        ctx.fillStyle = pt.color ? pt.color : "#38BDF8";
                        ctx.globalAlpha = 0.90;
                        drawRoundedRect(ctx, pillX, pillY, pillW, pillH, 9);
                        ctx.fill();
                        ctx.strokeStyle = "#FFFFFF";
                        ctx.lineWidth = 1.2;
                        ctx.stroke();

                        ctx.fillStyle = "#FFFFFF";
                        ctx.font = "bold 9px sans-serif";
                        ctx.textAlign = "left";
                        ctx.textBaseline = "middle";
                        let ptText = (pt.icon ? pt.icon + " " : "📌 ") + pt.title;
                        ctx.fillText(ptText, pillX + 6, pY);
                        ctx.restore();
                    }
                }
            }

            // 7. Live System Time Needle & "NOW" Indicator
            if (root.showCurrentTimeHand) {
                let nowH = root.currentTimeHours;
                let yNow = root.timeToY(nowH, gY, gH);

                // Check which column is Today
                let todayColIdx = -1;
                for (let c = 0; c < colCount; ++c) {
                    if (cols[c].isToday) {
                        todayColIdx = c;
                        break;
                    }
                }

                // Gutter current time badge
                ctx.save();
                let nowHoursInt = Math.floor(nowH);
                let nowMinsInt = Math.floor((nowH % 1) * 60);
                let liveStr = (nowHoursInt < 10 ? "0" : "") + nowHoursInt + ":" + (nowMinsInt < 10 ? "0" : "") + nowMinsInt;

                drawRoundedRect(ctx, gX - 58, yNow - 8, 48, 16, 4);
                ctx.fillStyle = "#F43F5E";
                ctx.fill();
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1.0;
                ctx.stroke();

                ctx.font = "bold 9px sans-serif";
                ctx.fillStyle = "#FFFFFF";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText(liveStr, gX - 34, yNow);

                // Horizontal red needle
                if (todayColIdx >= 0) {
                    let colX = gX + todayColIdx * colW;
                    // Across today's column with glowing red stroke
                    ctx.beginPath();
                    ctx.moveTo(colX, yNow);
                    ctx.lineTo(colX + colW, yNow);
                    ctx.strokeStyle = "#F43F5E";
                    ctx.lineWidth = 2.6;
                    ctx.shadowColor = "rgba(244, 63, 94, 0.85)";
                    ctx.shadowBlur = 6;
                    ctx.stroke();
                    ctx.shadowColor = "transparent";
                    ctx.shadowBlur = 0;

                    // Pulsing beacon on the left of today's column
                    ctx.beginPath();
                    ctx.arc(colX + 6, yNow, 4.5, 0, 2 * Math.PI, false);
                    ctx.fillStyle = "#F43F5E";
                    ctx.fill();
                    ctx.strokeStyle = "#FFFFFF";
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                } else {
                    // Dotted line across all columns if today isn't directly highlighted
                    ctx.beginPath();
                    ctx.setLineDash([4, 4]);
                    ctx.moveTo(gX, yNow);
                    ctx.lineTo(gX + gW, yNow);
                    ctx.strokeStyle = "rgba(244, 63, 94, 0.75)";
                    ctx.lineWidth = 1.8;
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
                ctx.restore();
            }

            // 8. Hover Guideline & Interactive Floating Callout Card
            if (root.isHoveringTable && root.hoveredCol >= 0 && root.hoveredTime >= 0) {
                let hCol = root.hoveredCol;
                let hDay = root.hoveredDay;
                let hTime = root.hoveredTime;
                let colX = gX + hCol * colW;
                let hY = root.timeToY(hTime, gY, gH);

                // A. Dashed Cyan Guideline across the hovered column
                ctx.save();
                ctx.beginPath();
                ctx.moveTo(colX, hY);
                ctx.lineTo(colX + colW, hY);
                ctx.strokeStyle = "#38BDF8";
                ctx.lineWidth = 2.0;
                ctx.setLineDash([3, 2]);
                ctx.shadowColor = "rgba(56, 189, 248, 0.8)";
                ctx.shadowBlur = 6;
                ctx.stroke();
                ctx.restore();

                // Target anchor pip at cursor point
                ctx.save();
                ctx.beginPath();
                ctx.arc(root.hoveredX, root.hoveredY, 4, 0, 2 * Math.PI, false);
                ctx.fillStyle = "#38BDF8";
                ctx.fill();
                ctx.strokeStyle = "#FFFFFF";
                ctx.lineWidth = 1.5;
                ctx.stroke();
                ctx.restore();

                // B. Floating Activity Callout Card (Zero-Overlap Layout)
                let activeActs = root.getActiveActivitiesAtTime(hTime, hDay);
                let cardWidth = 290;
                let rowH = 24;
                let headerCardH = 34;
                let cardHeight = headerCardH + Math.max(1, activeActs.length) * rowH + 10;

                ctx.save();
                ctx.font = "bold 11px sans-serif";
                for (let aIdx = 0; aIdx < activeActs.length; ++aIdx) {
                    let act = activeActs[aIdx];
                    let prefix = (act.level === 0) ? "🔷 " : (act.level === 1 ? "  ↳ " : "    ↳ ");
                    if (act.isPoint) prefix = "📌 ";
                    let titleStr = prefix + (act.icon ? act.icon + " " : "") + act.title;
                    let fullW = ctx.measureText(titleStr).width + 130;
                    if (fullW > cardWidth) cardWidth = Math.min(420, fullW);
                }

                // Position card safely within screen boundaries
                let cardX = root.hoveredX + 20;
                if (cardX + cardWidth > root.width - 12) {
                    cardX = root.hoveredX - cardWidth - 20;
                }
                if (cardX < 12) cardX = 12;

                let cardY = root.hoveredY - cardHeight * 0.5;
                if (cardY < 12) cardY = 12;
                if (cardY + cardHeight > root.height - 12) cardY = root.height - cardHeight - 12;

                // Leader line from cursor to card
                let anchorCardX = (root.hoveredX < cardX) ? cardX : (cardX + cardWidth);
                let anchorCardY = Math.max(cardY + 12, Math.min(cardY + cardHeight - 12, root.hoveredY));

                ctx.strokeStyle = "rgba(56, 189, 248, 0.65)";
                ctx.lineWidth = 1.4;
                ctx.setLineDash([3, 2]);
                ctx.beginPath();
                ctx.moveTo(root.hoveredX, root.hoveredY);
                ctx.lineTo(anchorCardX, anchorCardY);
                ctx.stroke();
                ctx.setLineDash([]);

                // Draw Callout Box
                ctx.shadowColor = "rgba(0, 0, 0, 0.85)";
                ctx.shadowBlur = 12;
                drawRoundedRect(ctx, cardX, cardY, cardWidth, cardHeight, 8);
                ctx.fillStyle = "#0F172A";
                ctx.fill();
                ctx.shadowColor = "transparent";
                ctx.shadowBlur = 0;

                ctx.strokeStyle = "#38BDF8";
                ctx.lineWidth = 1.6;
                ctx.stroke();

                // Callout Header
                let hStr = root.formatClockTime(hTime);
                let dayNameStr = root.dayNames[hDay] || "";
                ctx.textAlign = "left";
                ctx.textBaseline = "middle";
                ctx.font = "bold 12px sans-serif";
                ctx.fillStyle = "#38BDF8";
                ctx.fillText("🕒 " + hStr + "  •  " + dayNameStr, cardX + 12, cardY + 18);

                ctx.beginPath();
                ctx.moveTo(cardX + 12, cardY + 30);
                ctx.lineTo(cardX + cardWidth - 12, cardY + 30);
                ctx.strokeStyle = "#334155";
                ctx.lineWidth = 1.0;
                ctx.stroke();

                // Active Activities List
                let startRowY = cardY + headerCardH + 12;
                if (activeActs.length === 0) {
                    ctx.font = "italic 11px sans-serif";
                    ctx.fillStyle = "#94A3B8";
                    ctx.fillText("No scheduled activity at this time", cardX + 12, startRowY);
                } else {
                    for (let aIdx = 0; aIdx < activeActs.length; ++aIdx) {
                        let act = activeActs[aIdx];
                        let curRowY = startRowY + aIdx * rowH;

                        // Level indicator bullet
                        let bulletColor = act.color ? act.color : "#38BDF8";
                        ctx.beginPath();
                        ctx.arc(cardX + 16 + (act.level || 0) * 8, curRowY, 3.5, 0, 2 * Math.PI, false);
                        ctx.fillStyle = bulletColor;
                        ctx.fill();

                        // Title with high contrast
                        ctx.font = (act.level === 0) ? "bold 11px sans-serif" : "11px sans-serif";
                        ctx.fillStyle = "#FFFFFF";
                        let titleX = cardX + 26 + (act.level || 0) * 8;
                        let titleText = (act.icon ? act.icon + " " : "") + act.title;
                        ctx.fillText(titleText, titleX, curRowY);

                        // Time span right-aligned
                        ctx.font = "10px sans-serif";
                        ctx.fillStyle = "#94A3B8";
                        ctx.textAlign = "right";
                        let timeRangeStr = (act.isInterval && act.startClock && act.endClock) ?
                                    (act.startClock + " - " + act.endClock) :
                                    (act.startClock ? act.startClock : "");
                        ctx.fillText(timeRangeStr, cardX + cardWidth - 12, curRowY);
                        ctx.textAlign = "left";
                    }
                }
                ctx.restore();
            }
        }
    }

    // --- Interactive Hover & Click Handling ---
    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: {
            if (!hovered) {
                root.isHoveringTable = false;
                root.hoveredCol = -1;
                root.hoveredDay = -1;
                root.hoveredTime = -1;
                root.hoveredItem = null;
                canvas.requestPaint();
            }
        }
        onPointChanged: {
            let px = point.position.x;
            let py = point.position.y;
            let gX = root.gridX;
            let gY = root.gridY;
            let gW = root.gridW;
            let gH = root.gridH;

            if (px >= gX && px <= gX + gW && py >= gY && py <= gY + gH) {
                let cols = root.getColumnDays();
                let colW = gW / cols.length;
                let c = Math.floor((px - gX) / colW);
                c = Math.max(0, Math.min(cols.length - 1, c));

                root.isHoveringTable = true;
                root.hoveredCol = c;
                root.hoveredDay = cols[c].day;
                root.hoveredTime = root.yToTime(py, gY, gH);
                root.hoveredX = px;
                root.hoveredY = py;

                // Find closest matching item
                let activeActs = root.getActiveActivitiesAtTime(root.hoveredTime, root.hoveredDay);
                root.hoveredItem = activeActs.length > 0 ? activeActs[0] : null;
            } else {
                root.isHoveringTable = false;
                root.hoveredCol = -1;
                root.hoveredDay = -1;
                root.hoveredTime = -1;
                root.hoveredItem = null;
            }
            canvas.requestPaint();
        }
    }

    TapHandler {
        id: tapHandler
        enabled: root.interactive
        onTapped: (eventPoint) => {
            let px = eventPoint.position.x;
            let py = eventPoint.position.y;
            let gX = root.gridX;
            let gY = root.gridY;
            let gW = root.gridW;
            let gH = root.gridH;

            if (px >= gX && px <= gX + gW && py >= gY && py <= gY + gH) {
                let cols = root.getColumnDays();
                let colW = gW / cols.length;
                let c = Math.floor((px - gX) / colW);
                c = Math.max(0, Math.min(cols.length - 1, c));

                let clickTime = root.yToTime(py, gY, gH);
                let activeActs = root.getActiveActivitiesAtTime(clickTime, cols[c].day);
                if (activeActs.length > 0) {
                    root.selectedItem = activeActs[0];
                    root.itemClicked(activeActs[0]);
                }
            }
        }
    }

    WheelHandler {
        enabled: root.interactive
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y !== 0) {
                let py = event.position.y;
                let t = root.yToTime(py, root.gridY, root.gridH);
                root.focusAngle = (t / 24.0) * 2.0 * Math.PI;

                let factor = event.angleDelta.y > 0 ? 1.15 : 0.87;
                let targetZoom = root.zoom * factor;
                root.zoom = Math.max(root.minZoom, Math.min(root.maxZoom, targetZoom));
            }
        }
    }

    PinchHandler {
        id: pinchHandler
        enabled: root.interactive
        onScaleChanged: (delta) => {
            let newZoom = root.zoom * delta;
            root.zoom = Math.max(root.minZoom, Math.min(root.maxZoom, newZoom));
        }
    }
}
