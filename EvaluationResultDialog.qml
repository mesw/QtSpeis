import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(660, (parent ? parent.width : 660) - 16)
    height: Math.min(760, (parent ? parent.height : 760) - 20)
    padding: 0

    property var resultData: null
    property var gameLevelManager: null
    property var mealPlanManager: null
    property var langManager: null

    property string activeChronoNutrient: ""
    readonly property var activeChronoData: {
        if (!root.resultData || !gameLevelManager) return null;
        if (activeChronoNutrient === "" || (root.resultData.chronoData && activeChronoNutrient === root.resultData.chronoData.nutrientKey)) {
            return root.resultData.chronoData;
        }
        if (mealPlanManager) {
            return gameLevelManager.getChronoNutrientData(mealPlanManager, root.resultData.levelId, activeChronoNutrient);
        }
        return root.resultData.chronoData;
    }

    onAboutToShow: {
        activeChronoNutrient = "";
    }
    signal retryRequested()
    signal nextLevelRequested()
    signal levelSelectRequested()

    background: Rectangle {
        color: "#FFFDF9"
        radius: 18
        border.color: "#E2D9C8"
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 6
            color: (root.resultData && root.resultData.stars >= 2) ? "#16A34A" : ((root.resultData && root.resultData.stars === 1) ? "#D97706" : "#DC2626")
            radius: 3
        }
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.width < 500 ? 12 : 20
        spacing: root.width < 500 ? 10 : 14

        // Celebratory Stars Banner
        Rectangle {
            Layout.fillWidth: true
            height: 110
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: (root.resultData && root.resultData.stars >= 2) ? "#FEF3C7" : "#F5F5F4" }
                GradientStop { position: 1.0; color: "#FFFFFF" }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                // Star glyphs (0 to 3)
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: 3
                        delegate: Label {
                            property int starCount: root.resultData ? root.resultData.stars : 0
                            text: index < starCount ? "★" : "☆"
                            font.pixelSize: 38
                            color: index < starCount ? "#F59E0B" : "#D6D3D1"
                        }
                    }
                }

                // Title
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.resultData
                          ? String(root.resultData.starTitle || "").replace(/^[★☆]+\s*/, "")
                          : (langManager ? langManager.t("evaluating") : "Evaluating...")
                    font.bold: true
                    font.pixelSize: 18
                    color: "#292524"
                }
            }
        }

        // Summary Accuracy Scorecards
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Calorie Accuracy Card
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 10
                color: "#FFFFFF"
                border.color: "#E7E5E4"
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label { text: langManager ? langManager.t("calorie_accuracy") : "Calorie Accuracy"; font.pixelSize: 11; color: "#78716C" }
                    Label {
                        text: root.resultData ? (root.resultData.calorieAccuracy + "%") : "-"
                        font.bold: true; font.pixelSize: 18; color: "#D97706"
                    }
                    Label {
                        property real diff: root.resultData ? root.resultData.calorieDiff : 0
                        text: langManager ? langManager.t("diff_kcal", [(diff >= 0 ? "+" : "") + Math.round(diff)]) : ((diff >= 0 ? "+" : "") + Math.round(diff) + " kcal diff")
                        font.pixelSize: 10; color: "#78716C"
                    }
                }
            }

            // Macro Accuracy Card
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 10
                color: "#FFFFFF"
                border.color: "#E7E5E4"
                border.width: 1
                visible: root.resultData ? root.resultData.hasMacroTarget : false

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label { text: langManager ? langManager.t("macro_accuracy") : "Macro Balance Accuracy"; font.pixelSize: 11; color: "#78716C" }
                    Label {
                        text: root.resultData ? (root.resultData.macroAccuracy + "%") : "-"
                        font.bold: true; font.pixelSize: 18; color: "#16A34A"
                    }
                    Label {
                        text: root.resultData
                              ? (Math.round(root.resultData.actualCarbs || 0) + "% C • " +
                                 Math.round(root.resultData.actualProtein || 0) + "% P • " +
                                 Math.round(root.resultData.actualFat || 0) + "% F (" +
                                 Math.round(root.resultData.targetCarbs || 55) + "/" +
                                 Math.round(root.resultData.targetProtein || 15) + "/" +
                                 Math.round(root.resultData.targetFat || 30) + "%)")
                              : "55% C • 15% P • 30% F"
                        font.pixelSize: 10; color: "#78716C"
                    }
                }
            }
        }

        // Constraints Checklist
        Label {
            text: (root.resultData && root.resultData.levelId && root.resultData.levelId !== 24)
                  ? ("Level " + root.resultData.levelId + " Constraint:")
                  : (langManager ? langManager.t("constraints_breakdown") : "Constraints Breakdown:")
            font.bold: true
            font.pixelSize: 12
            color: "#44403C"
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.resultData ? root.resultData.constraints : []

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(44, constraintCol.implicitHeight + 14)
                        radius: 8
                        color: modelData.met ? "#F0FDF4" : "#FEF2F2"
                        border.color: modelData.met ? "#BBF7D0" : "#FECACA"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Label {
                                text: modelData.met ? "✔" : "✘"
                                font.bold: true
                                font.pixelSize: 16
                                color: modelData.met ? "#16A34A" : "#DC2626"
                            }

                            ColumnLayout {
                                id: constraintCol
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: modelData.name
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: "#1C1917"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Label {
                                    visible: modelData.target ? true : false
                                    text: "Target: " + modelData.target
                                    font.pixelSize: 10
                                    color: "#78716C"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            ColumnLayout {
                                spacing: 1
                                Label {
                                    text: modelData.actual
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: modelData.met ? "#15803D" : "#B91C1C"
                                    Layout.alignment: Qt.AlignRight
                                }
                                Label {
                                    visible: modelData.grade ? true : false
                                    text: modelData.grade
                                    font.pixelSize: 9
                                    color: modelData.met ? "#16A34A" : "#DC2626"
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }

                // Hero Constraints Breakdown (if active)
                Repeater {
                    model: root.resultData ? root.resultData.heroConstraints : []

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 8
                        color: modelData.met ? "#F0FDF4" : "#FEF2F2"
                        border.color: modelData.met ? "#BBF7D0" : "#FECACA"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Label {
                                text: modelData.met ? "🛡️ ✔" : "⚔️ ✘"
                                font.bold: true
                                font.pixelSize: 13
                                color: modelData.met ? "#16A34A" : "#DC2626"
                            }

                            Label {
                                text: "Hero Challenge " + modelData.heroId
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1C1917"
                            }

                            Label {
                                text: modelData.reason
                                font.pixelSize: 11
                                color: modelData.met ? "#15803D" : "#B91C1C"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Educational Coaching Tip Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 10
                    color: "#FEF9C3"
                    border.color: "#FEF08A"
                    border.width: 1
                    implicitHeight: tipCol.implicitHeight + 16

                    ColumnLayout {
                        id: tipCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            spacing: 6
                            Label { text: "💡"; font.pixelSize: 14 }
                            Label {
                                text: langManager ? langManager.t("coach_feedback") : "Nutrition Coach's Feedback:"
                                font.bold: true
                                font.pixelSize: 11
                                color: "#854D0E"
                            }
                        }

                        Label {
                            text: root.resultData ? root.resultData.coachingTip : ""
                            font.pixelSize: 11
                            color: "#713F12"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // ── Chrono-Nutrient Bar & Cumulative Line Chart ─────────────────
                Rectangle {
                    id: chronoChartCard
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    border.width: 1
                    implicitHeight: chartCol.implicitHeight + 20
                    visible: Boolean(root.activeChronoData && root.activeChronoData.meals && root.activeChronoData.meals.length > 0)

                    ColumnLayout {
                        id: chartCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Section Header & Nutrient Switcher
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Label {
                                text: "📈 " + (langManager ? langManager.t("chrono_timing_chart_title") : "Nutrient Timing & Cumulative Intake")
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1C1917"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Quick Nutrient Chips
                            Flickable {
                                Layout.preferredWidth: Math.min(320, parent.width * 0.55)
                                Layout.preferredHeight: 26
                                contentWidth: nutrientChipRow.implicitWidth
                                clip: true

                                Row {
                                    id: nutrientChipRow
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            { key: "", label: (root.resultData && root.resultData.chronoData) ? ("🎯 " + root.resultData.chronoData.nutrientName) : "🎯 Goal" },
                                            { key: "calories", label: "⚡ " + (langManager ? langManager.t("daily_calories") : "Calories") },
                                            { key: "protein", label: "🍗 " + (langManager ? langManager.t("protein") : "Protein") },
                                            { key: "carbs", label: "🌾 " + (langManager ? langManager.t("carbs") : "Carbs") },
                                            { key: "fat", label: "🥑 " + (langManager ? langManager.t("fat") : "Fat") },
                                            { key: "fiber", label: "🥦 " + (langManager ? langManager.t("fiber") : "Fiber") },
                                            { key: "magnesium", label: "✨ Mg" },
                                            { key: "calcium", label: "🥛 Ca" },
                                            { key: "omega3", label: "🐟 Ω-3" },
                                            { key: "potassium", label: "⚡ K" }
                                        ]

                                        delegate: Rectangle {
                                            id: nChip
                                            height: 24
                                            radius: 12
                                            property bool isSelected: (root.activeChronoNutrient === modelData.key) ||
                                                                      (root.activeChronoNutrient === "" && modelData.key === "")
                                            color: isSelected ? "#D97706" : (chipArea.containsMouse ? "#FEF3C7" : "#F5F5F4")
                                            border.color: isSelected ? "#B45309" : "#E7E5E4"
                                            implicitWidth: chipLbl.implicitWidth + 14

                                            Label {
                                                id: chipLbl
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                font.pixelSize: 9
                                                font.bold: nChip.isSelected
                                                color: nChip.isSelected ? "#FFFFFF" : "#57534E"
                                            }

                                            MouseArea {
                                                id: chipArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.activeChronoNutrient = modelData.key;
                                                    chronoCanvas.requestPaint();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Timing / Window Subtitle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: {
                                    var c = root.activeChronoData;
                                    if (!c) return "";
                                    var unit = c.nutrientUnit || "";
                                    var tot = Math.round(c.totalAmount * 10) / 10;
                                    var tgt = Math.round(c.targetDaily * 10) / 10;
                                    var s = c.nutrientName + ": " + tot + " " + unit;
                                    if (tgt > 0) s += " (Target: " + tgt + " " + unit + ")";
                                    if (c.windowType === "after" && c.windowStartMin >= 0) {
                                        var wTot = Math.round(c.windowAmount * 10) / 10;
                                        var pct = Math.round(c.windowActualPct * 10) / 10;
                                        s += " • Evening Window (≥ 18:00): " + wTot + " " + unit + " (" + pct + "% / Target: ≥ " + c.windowTargetPct + "%)";
                                    } else if (c.windowType === "before" && c.windowEndMin >= 0) {
                                        var wTot = Math.round(c.windowAmount * 10) / 10;
                                        var pct = Math.round(c.windowActualPct * 10) / 10;
                                        s += " • Morning Gate (< 13:00): " + wTot + " " + unit + " (" + pct + "% / Target: ≥ " + c.windowTargetPct + "%)";
                                    }
                                    return s;
                                }
                                font.pixelSize: 10
                                font.bold: true
                                color: "#78716C"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // Dual Plot Canvas
                        Rectangle {
                            Layout.fillWidth: true
                            height: 190
                            radius: 8
                            color: "#FAF8F5"
                            border.color: "#E7E5E4"
                            clip: true

                            Canvas {
                                id: chronoCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image

                                Connections {
                                    target: root
                                    function onActiveChronoDataChanged() { chronoCanvas.requestPaint(); }
                                    function onResultDataChanged() { chronoCanvas.requestPaint(); }
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    var c = root.activeChronoData;
                                    if (!c || !c.meals || c.meals.length === 0) return;

                                    var meals = c.meals;
                                    var unit = c.nutrientUnit || "";
                                    var tot = c.totalAmount || 0;
                                    var targetDaily = c.targetDaily || 0;

                                    var marginLeft = 48;
                                    var marginRight = 24;
                                    var marginTop = 26;
                                    var marginBottom = 38;
                                    var plotW = width - marginLeft - marginRight;
                                    var plotH = height - marginTop - marginBottom;
                                    if (plotW <= 0 || plotH <= 0) return;

                                    function timeToX(m) {
                                        return marginLeft + (Math.max(0, Math.min(1440, m)) / 1440.0) * plotW;
                                    }

                                    var maxVal = Math.max(tot * 1.15, targetDaily * 1.15, 1.0);
                                    for (var i = 0; i < meals.length; ++i) {
                                        if (meals[i].amount * 1.35 > maxVal) maxVal = meals[i].amount * 1.35;
                                    }

                                    function valToY(v) {
                                        return marginTop + plotH - (Math.max(0, v) / maxVal) * plotH;
                                    }

                                    // 1. Shaded Window Zone (e.g. L14 Evening, L13 Morning)
                                    if (c.windowType === "after" && c.windowStartMin >= 0) {
                                        var wx1 = timeToX(c.windowStartMin);
                                        var wx2 = timeToX(1440);
                                        ctx.fillStyle = "rgba(245, 158, 11, 0.12)";
                                        ctx.fillRect(wx1, marginTop, wx2 - wx1, plotH);

                                        ctx.strokeStyle = "rgba(245, 158, 11, 0.4)";
                                        ctx.setLineDash([3, 3]);
                                        ctx.beginPath();
                                        ctx.moveTo(wx1, marginTop);
                                        ctx.lineTo(wx1, marginTop + plotH);
                                        ctx.stroke();
                                        ctx.setLineDash([]);

                                        ctx.fillStyle = "#B45309";
                                        ctx.font = "bold 9px sans-serif";
                                        ctx.textAlign = "left";
                                        ctx.fillText("🌙 Window ≥ 18:00", wx1 + 6, marginTop + 14);
                                    } else if (c.windowType === "before" && c.windowEndMin >= 0) {
                                        var wx1 = timeToX(0);
                                        var wx2 = timeToX(c.windowEndMin);
                                        ctx.fillStyle = "rgba(59, 130, 246, 0.10)";
                                        ctx.fillRect(wx1, marginTop, wx2 - wx1, plotH);

                                        ctx.strokeStyle = "rgba(59, 130, 246, 0.4)";
                                        ctx.setLineDash([3, 3]);
                                        ctx.beginPath();
                                        ctx.moveTo(wx2, marginTop);
                                        ctx.lineTo(wx2, marginTop + plotH);
                                        ctx.stroke();
                                        ctx.setLineDash([]);

                                        ctx.fillStyle = "#1D4ED8";
                                        ctx.font = "bold 9px sans-serif";
                                        ctx.textAlign = "right";
                                        ctx.fillText("☀️ Gate < 13:00", wx2 - 6, marginTop + 14);
                                    }

                                    // 2. Horizontal Gridlines & Y-Axis labels
                                    ctx.strokeStyle = "#E7E5E4";
                                    ctx.lineWidth = 1;
                                    ctx.fillStyle = "#A8A29E";
                                    ctx.font = "9px sans-serif";
                                    ctx.textAlign = "right";

                                    var ySteps = 3;
                                    for (var s = 0; s <= ySteps; ++s) {
                                        var yVal = (maxVal / ySteps) * s;
                                        var gy = valToY(yVal);
                                        ctx.beginPath();
                                        ctx.moveTo(marginLeft, gy);
                                        ctx.lineTo(marginLeft + plotW, gy);
                                        ctx.stroke();

                                        var labelStr = (yVal >= 100) ? Math.round(yVal) : yVal.toFixed(yVal < 10 ? 1 : 0);
                                        ctx.fillText(labelStr + " " + unit, marginLeft - 6, gy + 3);
                                    }

                                    // 3. Time Ticks along X-Axis (00h, 04h, 08h, 12h, 16h, 20h, 24h)
                                    ctx.textAlign = "center";
                                    for (var h = 0; h <= 24; h += 4) {
                                        var tx = timeToX(h * 60);
                                        ctx.strokeStyle = "#E7E5E4";
                                        ctx.beginPath();
                                        ctx.moveTo(tx, marginTop + plotH);
                                        ctx.lineTo(tx, marginTop + plotH + 5);
                                        ctx.stroke();

                                        var hLabel = (h < 10 ? "0" : "") + h + ":00";
                                        ctx.fillStyle = "#78716C";
                                        ctx.fillText(hLabel, tx, marginTop + plotH + 16);
                                    }

                                    // 4. Target Daily Reference Line (Dashed)
                                    if (targetDaily > 0 && targetDaily <= maxVal) {
                                        var ty = valToY(targetDaily);
                                        ctx.strokeStyle = "#DC2626";
                                        ctx.lineWidth = 1.5;
                                        ctx.setLineDash([4, 4]);
                                        ctx.beginPath();
                                        ctx.moveTo(marginLeft, ty);
                                        ctx.lineTo(marginLeft + plotW, ty);
                                        ctx.stroke();
                                        ctx.setLineDash([]);

                                        ctx.fillStyle = "#DC2626";
                                        ctx.font = "bold 9px sans-serif";
                                        ctx.textAlign = "right";
                                        ctx.fillText("🎯 Target: " + Math.round(targetDaily) + " " + unit, marginLeft + plotW - 4, ty - 4);
                                    }

                                    // 5. Vertical Bars for Each Meal's Intake
                                    var barWidth = Math.max(16, Math.min(28, plotW / (meals.length * 2.5)));
                                    for (var i = 0; i < meals.length; ++i) {
                                        var m = meals[i];
                                        if (m.amount <= 0 && m.isWorkout) continue;

                                        var bx = timeToX(m.minutes) - barWidth / 2;
                                        var by = valToY(m.amount);
                                        var bh = (marginTop + plotH) - by;

                                        var barGrad = ctx.createLinearGradient(0, by, 0, marginTop + plotH);
                                        if (m.inWindow) {
                                            barGrad.addColorStop(0, "#F59E0B");
                                            barGrad.addColorStop(1, "#FDE68A");
                                        } else {
                                            barGrad.addColorStop(0, "#3B82F6");
                                            barGrad.addColorStop(1, "#BFDBFE");
                                        }
                                        ctx.fillStyle = barGrad;
                                        ctx.beginPath();
                                        var r = 4;
                                        ctx.moveTo(bx + r, by);
                                        ctx.lineTo(bx + barWidth - r, by);
                                        ctx.quadraticCurveTo(bx + barWidth, by, bx + barWidth, by + r);
                                        ctx.lineTo(bx + barWidth, marginTop + plotH);
                                        ctx.lineTo(bx, marginTop + plotH);
                                        ctx.lineTo(bx, by + r);
                                        ctx.quadraticCurveTo(bx, by, bx + r, by);
                                        ctx.closePath();
                                        ctx.fill();

                                        ctx.strokeStyle = m.inWindow ? "#D97706" : "#2563EB";
                                        ctx.lineWidth = 1;
                                        ctx.stroke();

                                        if (m.amount > 0) {
                                            ctx.fillStyle = m.inWindow ? "#B45309" : "#1D4ED8";
                                            ctx.font = "bold 9px sans-serif";
                                            ctx.textAlign = "center";
                                            var amtStr = (m.amount < 10 && m.amount > 0) ? m.amount.toFixed(1) : Math.round(m.amount);
                                            ctx.fillText(amtStr + unit, bx + barWidth / 2, by - 4);
                                        }

                                        ctx.fillStyle = "#44403C";
                                        ctx.font = "10px sans-serif";
                                        ctx.textAlign = "center";
                                        var icon = m.icon ? String(m.icon).replace(/\uFE0F/g, "") : "🍽";
                                        ctx.fillText(icon, bx + barWidth / 2, marginTop + plotH + 28);
                                    }

                                    // 6. Superimposed Cumulative Line Plot
                                    ctx.beginPath();
                                    ctx.moveTo(timeToX(0), valToY(0));
                                    for (var i = 0; i < meals.length; ++i) {
                                        var mx = timeToX(meals[i].minutes);
                                        var my = valToY(meals[i].cumulative);
                                        ctx.lineTo(mx, my);
                                    }
                                    ctx.lineTo(timeToX(1440), valToY(tot));
                                    ctx.lineTo(timeToX(1440), marginTop + plotH);
                                    ctx.lineTo(timeToX(0), marginTop + plotH);
                                    ctx.closePath();

                                    var areaGrad = ctx.createLinearGradient(0, marginTop, 0, marginTop + plotH);
                                    areaGrad.addColorStop(0, "rgba(22, 163, 74, 0.22)");
                                    areaGrad.addColorStop(1, "rgba(22, 163, 74, 0.02)");
                                    ctx.fillStyle = areaGrad;
                                    ctx.fill();

                                    ctx.beginPath();
                                    ctx.moveTo(timeToX(0), valToY(0));
                                    for (var i = 0; i < meals.length; ++i) {
                                        var mx = timeToX(meals[i].minutes);
                                        var my = valToY(meals[i].cumulative);
                                        ctx.lineTo(mx, my);
                                    }
                                    ctx.lineTo(timeToX(1440), valToY(tot));
                                    ctx.strokeStyle = "#16A34A";
                                    ctx.lineWidth = 2.5;
                                    ctx.stroke();

                                    for (var i = 0; i < meals.length; ++i) {
                                        var mx = timeToX(meals[i].minutes);
                                        var my = valToY(meals[i].cumulative);

                                        ctx.beginPath();
                                        ctx.arc(mx, my, 4, 0, 2 * Math.PI);
                                        ctx.fillStyle = "#FFFFFF";
                                        ctx.fill();
                                        ctx.strokeStyle = "#15803D";
                                        ctx.lineWidth = 2;
                                        ctx.stroke();
                                    }
                                }
                            }
                        }

                        // Chart Legend Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Row {
                                spacing: 4
                                Rectangle { width: 10; height: 10; radius: 2; color: "#3B82F6"; anchors.verticalCenter: parent.verticalCenter }
                                Label { text: langManager ? langManager.t("chrono_bar_legend") : "Meal Intake (Bar)"; font.pixelSize: 10; color: "#57534E" }
                            }

                            Row {
                                spacing: 4
                                Rectangle { width: 12; height: 3; radius: 1; color: "#16A34A"; anchors.verticalCenter: parent.verticalCenter }
                                Label { text: langManager ? langManager.t("chrono_line_legend") : "Cumulative Intake (Line)"; font.pixelSize: 10; color: "#57534E" }
                            }

                            Row {
                                spacing: 4
                                Rectangle { width: 12; height: 2; radius: 1; color: "#DC2626"; anchors.verticalCenter: parent.verticalCenter }
                                Label { text: langManager ? langManager.t("chrono_target_legend") : "Target / Gate"; font.pixelSize: 10; color: "#57534E" }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }

        // Gate Warning Notice when 1 star (constraint failed)
        Rectangle {
            Layout.fillWidth: true
            visible: Boolean(root.resultData && root.resultData.stars === 1 && !root.resultData.primaryConstraintMet && root.resultData.levelId < 24)
            radius: 8
            color: "#FEF2F2"
            border.color: "#FECACA"
            implicitHeight: gateCol.implicitHeight + 12

            ColumnLayout {
                id: gateCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2
                Label {
                    text: langManager ? langManager.t("next_level_locked_msg") : "⚠️ Level constraint unmet. Earn at least 2 stars (satisfy the biochemical rule) to unlock the next level!"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#B91C1C"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: langManager ? langManager.t("keep_editing") : "✏️ Keep Editing"
                Layout.preferredHeight: 38
                flat: true
                font.pixelSize: 12
                palette.buttonText: "#78716C"
                onClicked: root.close()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: langManager ? langManager.t("levels_menu") : "🏆 Levels Menu"
                Layout.preferredHeight: 38
                font.pixelSize: 12
                palette.buttonText: "#57534E"
                background: Rectangle { radius: 8; color: "#F5F5F4"; border.color: "#E7E5E4" }
                onClicked: {
                    root.close();
                    root.levelSelectRequested();
                }
            }

            Button {
                text: langManager ? langManager.t("next_level") : "Next Level →"
                Layout.preferredHeight: 38
                visible: root.resultData && root.resultData.stars >= 2 && Boolean(root.resultData.primaryConstraintMet) && root.resultData.levelId < 24
                font.bold: true
                font.pixelSize: 12
                palette.buttonText: "#FFFFFF"
                background: Rectangle { radius: 8; color: "#16A34A" }
                onClicked: {
                    root.close();
                    if (gameLevelManager && root.resultData) {
                        gameLevelManager.currentLevel = root.resultData.levelId + 1;
                    }
                }
            }
        }
    }
}
