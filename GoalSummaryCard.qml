import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 16
    color: "#FFFDF9"
    border.color: "#E5DEC9"
    border.width: 1

    property var mealPlanManager: null
    property var gameLevelManager: null
    property var langManager: null
    property int planRevision: 0
    signal evaluateRequested()
    signal profileRequested()

    Connections {
        target: root.mealPlanManager
        function onPlanChanged() { root.planRevision++; }
        function onUserProfileChanged() { root.planRevision++; }
    }

    Connections {
        target: root.gameLevelManager
        function onCurrentLevelChanged() { root.planRevision++; }
        function onLevelsChanged() { root.planRevision++; }
    }

    readonly property var activeConstraint: {
        var _rev = root.planRevision;
        var _cals = mealPlanManager ? mealPlanManager.totalCalories : 0;
        var _tgt = mealPlanManager ? mealPlanManager.targetCalories : 2000;
        var _items = mealPlanManager ? mealPlanManager.totalItemCount : 0;
        var _lvl = gameLevelManager ? gameLevelManager.currentLevel : 1;
        if (!gameLevelManager || !mealPlanManager) return null;
        var all = gameLevelManager.checkAllLevelConstraints(mealPlanManager);
        return all[String(_lvl)] || null;
    }
    readonly property bool isObjectiveMet: Boolean(activeConstraint && activeConstraint.met)

    ScrollView {
        anchors.fill: parent
        anchors.margins: 14
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 12

        // Card Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 38
                height: 38
                radius: 10
                color: "#FEF3C7"
                Label {
                    anchors.centerIn: parent
                    text: "🎯"
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Label {
                    Layout.fillWidth: true
                    text: gameLevelManager ? gameLevelManager.currentLevelData.title : "Level Objective"
                    font.bold: true
                    font.pixelSize: 15
                    color: "#1C1917"
                    wrapMode: Text.WordWrap
                }

                Label {
                    Layout.fillWidth: true
                    text: {
                        if (!gameLevelManager) return "";
                        if (gameLevelManager.currentLevel === 1 && mealPlanManager) {
                            var isDe = langManager && langManager.currentLanguage === "de";
                            var tCal = Math.round(mealPlanManager.targetCalories);
                            return isDe ? ("Zielwert: " + tCal + " kcal (±50 kcal)") : ("Target: " + tCal + " kcal (±50 kcal)");
                        }
                        return gameLevelManager.currentLevelData.subtitle;
                    }
                    font.pixelSize: 11
                    color: "#78716C"
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E7E5E4"
        }

        // Calorie Gauge Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: langManager ? langManager.t("daily_calories") : "Daily Energy (Calories)"
                    font.bold: true
                    font.pixelSize: 12
                    color: "#44403C"
                }
                Item { Layout.fillWidth: true }
                Label {
                    property real cur: mealPlanManager ? mealPlanManager.totalCalories : 0
                    property real tgt: mealPlanManager ? mealPlanManager.targetCalories : 2000
                    text: Math.round(cur) + " / " + Math.round(tgt) + " kcal"
                    font.bold: true
                    font.pixelSize: 13
                    color: {
                        let diff = Math.abs(cur - tgt);
                        if (diff <= 50) return "#16A34A";
                        if (diff <= 150) return "#D97706";
                        return "#DC2626";
                    }
                }
            }

            // Calorie Progress Bar
            Rectangle {
                Layout.fillWidth: true
                height: 12
                radius: 6
                color: "#E7E5E4"
                clip: true

                Rectangle {
                    property real cur: mealPlanManager ? mealPlanManager.totalCalories : 0
                    property real tgt: mealPlanManager ? mealPlanManager.targetCalories : 2000
                    property real progress: tgt > 0 ? Math.min(1.2, cur / tgt) : 0
                    width: parent.width * Math.min(1.0, progress)
                    height: parent.height
                    radius: 6
                    color: {
                        let diff = Math.abs(cur - tgt);
                        if (diff <= 50) return "#16A34A"; // Green: Bullseye
                        if (diff <= 150) return "#F59E0B"; // Amber: Very close
                        if (cur > tgt) return "#EF4444"; // Red: Overshoot
                        return "#3B82F6"; // Blue: Still building
                    }

                    Behavior on width {
                        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                    }
                }
            }

            // Calorie status label
            RowLayout {
                Layout.fillWidth: true
                Label {
                    property real cur: mealPlanManager ? mealPlanManager.totalCalories : 0
                    property real tgt: mealPlanManager ? mealPlanManager.targetCalories : 2000
                    property real diff: cur - tgt
                    text: {
                        if (Math.abs(diff) <= 50) return "🎯 Perfect bullseye (±50 kcal)!";
                        if (diff > 0) return "▲ " + Math.round(diff) + " kcal over target";
                        return "▼ " + Math.round(Math.abs(diff)) + " kcal remaining";
                    }
                    font.pixelSize: 11
                    color: Math.abs(cur - tgt) <= 50 ? "#16A34A" : "#78716C"
                }
                Item { Layout.fillWidth: true }
                Label {
                    property real cur: mealPlanManager ? mealPlanManager.totalCalories : 0
                    property real tgt: mealPlanManager ? mealPlanManager.targetCalories : 2000
                    property real pct: tgt > 0 ? (cur / tgt) * 100 : 0
                    text: pct.toFixed(1) + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#57534E"
                }
            }

            // Target Breakdown Pill (Base Need + Workouts) with link to profile
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 6
                color: profMouseArea.containsMouse ? "#FEF3C7" : "#F5F5F4"
                border.color: profMouseArea.containsMouse ? "#D97706" : "#E7E5E4"

                MouseArea {
                    id: profMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.profileRequested()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 4

                    Label {
                        text: "👤 " + (mealPlanManager ? mealPlanManager.userName : "Player") + " • " +
                              Math.round(mealPlanManager ? mealPlanManager.baseCalories : 2000) + " (Base) + " +
                              Math.round(mealPlanManager ? mealPlanManager.totalWorkoutCalories : 0) + " (" + (mealPlanManager ? mealPlanManager.workoutCount : 0) + " WO) = " +
                              Math.round(mealPlanManager ? mealPlanManager.targetCalories : 2000) + " kcal"
                        font.pixelSize: 10
                        font.bold: true
                        color: profMouseArea.containsMouse ? "#92400E" : "#57534E"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Label {
                        text: "✏️"
                        font.pixelSize: 10
                    }
                }
            }
        }

        // Macro Distribution Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: langManager ? langManager.t("macro_split") : "Macronutrient Split (% of energy)"
                    font.bold: true
                    font.pixelSize: 12
                    color: "#44403C"
                }
                Item { Layout.fillWidth: true }
                Label {
                    visible: Boolean(gameLevelManager && gameLevelManager.currentLevelData && gameLevelManager.currentLevelData.hasMacroTarget === true)
                    text: {
                        if (mealPlanManager) {
                            var minP = Math.round(mealPlanManager.minProteinPercent);
                            var maxP = Math.round(mealPlanManager.maxProteinPercent);
                            var minF = Math.round(mealPlanManager.minFatPercent);
                            var maxF = Math.round(mealPlanManager.maxFatPercent);
                            var pStr = (minP === maxP) ? (minP + "P") : (minP + "-" + maxP + "P");
                            var fStr = (minF === maxF) ? (minF + "F") : (minF + "-" + maxF + "F");
                            return "Target: " + Math.round(mealPlanManager.targetCarbPercent) + "C / " + pStr + " / " + fStr;
                        }
                        return "Target: 55C / 12-18P / 27-33F";
                    }
                    font.pixelSize: 11
                    font.bold: true
                    color: "#78716C"
                }
            }

            // Stacked Macro Ratio Bar
            Rectangle {
                Layout.fillWidth: true
                height: 16
                radius: 8
                color: "#E7E5E4"
                clip: true

                Row {
                    anchors.fill: parent
                    spacing: 0

                    // Carbs (Amber)
                    Rectangle {
                        height: parent.height
                        width: parent.width * ((mealPlanManager ? mealPlanManager.carbPercent : 0) / 100.0)
                        color: "#F59E0B"
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                    // Protein (Emerald)
                    Rectangle {
                        height: parent.height
                        width: parent.width * ((mealPlanManager ? mealPlanManager.proteinPercent : 0) / 100.0)
                        color: "#10B981"
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                    // Fat (Blue)
                    Rectangle {
                        height: parent.height
                        width: parent.width * ((mealPlanManager ? mealPlanManager.fatPercent : 0) / 100.0)
                        color: "#3B82F6"
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }
            }

            // Macro details row
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Carbs Pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 8
                    color: "#FEF3C7"
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1
                        Label {
                            text: "🌾 " + (langManager ? langManager.t("carbs") : "Carbs")
                            font.pixelSize: 10
                            font.bold: true
                            color: "#92400E"
                        }
                        Label {
                            property real pct: mealPlanManager ? mealPlanManager.carbPercent : 0
                            property real g: mealPlanManager ? mealPlanManager.totalCarbs : 0
                            text: pct.toFixed(1) + "% (" + Math.round(g) + "g)"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#B45309"
                        }
                    }
                }

                // Protein Pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 8
                    color: "#D1FAE5"
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1
                        Label {
                            text: "🍗 " + (langManager ? langManager.t("protein") : "Protein")
                            font.pixelSize: 10
                            font.bold: true
                            color: "#065F46"
                        }
                        Label {
                            property real pct: mealPlanManager ? mealPlanManager.proteinPercent : 0
                            property real g: mealPlanManager ? mealPlanManager.totalProtein : 0
                            text: pct.toFixed(1) + "% (" + Math.round(g) + "g)"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#047857"
                        }
                    }
                }

                // Fat Pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: 8
                    color: "#DBEAFE"
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1
                        Label {
                            text: "🥑 " + (langManager ? langManager.t("fat") : "Fat")
                            font.pixelSize: 10
                            font.bold: true
                            color: "#1E40AF"
                        }
                        Label {
                            property real pct: mealPlanManager ? mealPlanManager.fatPercent : 0
                            property real g: mealPlanManager ? mealPlanManager.totalFat : 0
                            text: pct.toFixed(1) + "% (" + Math.round(g) + "g)"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#1D4ED8"
                        }
                    }
                }
            }
        }

        // Active Level Objective Status Card (Especially for levels >= 2)
        Rectangle {
            id: objectiveCard
            Layout.fillWidth: true
            visible: Boolean(gameLevelManager && gameLevelManager.currentLevel >= 2 && root.activeConstraint)
            radius: 10
            color: root.isObjectiveMet ? "#F0FDF4" : "#FEF3C7"
            border.color: root.isObjectiveMet ? "#86EFAC" : "#FDE68A"
            border.width: 1
            implicitHeight: constraintCol.implicitHeight + 16

            ColumnLayout {
                id: constraintCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        text: root.isObjectiveMet ? "✅" : "⚠️"
                        font.pixelSize: 14
                    }

                    Label {
                        text: root.activeConstraint ? root.activeConstraint.name : "Level Objective"
                        font.bold: true
                        font.pixelSize: 12
                        color: root.isObjectiveMet ? "#15803D" : "#92400E"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // Target row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        text: (langManager && langManager.currentLanguage === "de") ? "Ziel:" : "Target:"
                        font.bold: true
                        font.pixelSize: 10
                        color: "#78716C"
                    }
                    Label {
                        text: root.activeConstraint ? root.activeConstraint.target : ""
                        font.pixelSize: 10
                        font.bold: true
                        color: "#44403C"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Actual row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        text: (langManager && langManager.currentLanguage === "de") ? "Aktuell:" : "Actual:"
                        font.bold: true
                        font.pixelSize: 10
                        color: "#78716C"
                    }
                    Label {
                        text: root.activeConstraint ? root.activeConstraint.actual : ""
                        font.pixelSize: 11
                        font.bold: true
                        color: root.isObjectiveMet ? "#15803D" : "#B45309"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Feedback / Grade
                Rectangle {
                    visible: Boolean(root.activeConstraint && root.activeConstraint.grade)
                    Layout.fillWidth: true
                    radius: 6
                    color: root.isObjectiveMet ? "#DCFCE7" : "#FEE2E2"
                    implicitHeight: gradeLbl.implicitHeight + 8

                    Label {
                        id: gradeLbl
                        anchors.fill: parent
                        anchors.margins: 6
                        text: root.activeConstraint ? root.activeConstraint.grade : ""
                        font.pixelSize: 10
                        color: root.isObjectiveMet ? "#166534" : "#991B1B"
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Finish & Grade Button
        Button {
            id: gradeBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            text: "⭐ " + (langManager ? langManager.t("btn_evaluate").replace(/&/g, "&&") : "Finish && Grade Meal Plan")
            font.bold: true
            font.pixelSize: 14
            palette.buttonText: "#FFFFFF"
            background: Rectangle {
                radius: 10
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#D97706" }
                    GradientStop { position: 1.0; color: "#EA580C" }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "#000000"
                    opacity: gradeBtn.down ? 0.15 : (gradeBtn.hovered ? 0.08 : 0.0)
                }
            }
            onClicked: root.evaluateRequested()
        }
    }
}
}
