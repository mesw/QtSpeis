import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(520, (parent ? parent.width : 520) - 16)
    height: Math.min(680, (parent ? parent.height : 680) - 20)
    padding: 0

    property var mealPlanManager: null
    property var langManager: null

    readonly property bool isNarrow: root.width < 420

    property int editMealIndex: -1
    property string selectedType: "endurance"
    property string workoutTime: "17:00"
    property int workoutDuration: 45
    property real customCalories: -1.0
    property real customCarbs: -1.0
    property real customProtein: -1.0
    property real customFat: -1.0

    function openForAdd() {
        editMealIndex = -1;
        selectedType = "endurance";
        workoutTime = "17:00";
        workoutDuration = 45;
        customCalories = -1.0;
        customCarbs = -1.0;
        customProtein = -1.0;
        customFat = -1.0;
        timeInput.text = workoutTime;
        durInput.text = workoutDuration.toString();
        root.open();
    }

    function openWithCustomValues(type, time, duration, calories, carbs, protein, fat) {
        editMealIndex = -1;
        selectedType = (type && type !== "running" && type !== "cycling" && type !== "swimming" && type !== "strength" && type !== "hiit" && type !== "stretch") ? "custom" : (type || "custom");
        workoutTime = time || "17:00";
        workoutDuration = duration || 45;
        customCalories = (calories > 0) ? calories : -1.0;
        customCarbs = (carbs >= 0) ? carbs : -1.0;
        customProtein = (protein >= 0) ? protein : -1.0;
        customFat = (fat >= 0) ? fat : -1.0;
        timeInput.text = workoutTime;
        durInput.text = workoutDuration.toString();
        root.open();
    }

    function openForEdit(mealIndex) {
        if (!mealPlanManager || mealIndex < 0 || mealIndex >= mealPlanManager.meals.length) return;
        let meal = mealPlanManager.meals[mealIndex];
        editMealIndex = mealIndex;
        selectedType = meal.workoutType || "endurance";
        workoutTime = meal.time || "17:00";
        workoutDuration = meal.duration || 45;
        customCalories = (selectedType === "custom") ? (meal.calories || -1.0) : -1.0;
        customCarbs = (selectedType === "custom") ? (meal.carbs || -1.0) : -1.0;
        customProtein = (selectedType === "custom") ? (meal.protein || -1.0) : -1.0;
        customFat = (selectedType === "custom") ? (meal.fat || -1.0) : -1.0;
        timeInput.text = workoutTime;
        durInput.text = workoutDuration.toString();
        root.open();
    }

    // Live preview metrics computed from C++ MealPlanManager
    readonly property var liveMetrics: {
        if (!mealPlanManager) {
            return {
                calories: 0,
                carbs: 0,
                protein: 0,
                fat: 0,
                title: "Workout",
                icon: "🏃",
                color: "#3B82F6"
            };
        }
        return mealPlanManager.calculateWorkoutMetrics(selectedType, workoutDuration, customCalories, customCarbs, customProtein, customFat);
    }

    background: Rectangle {
        color: "#FFFDF9"
        radius: 16
        border.color: "#E2D9C8"
        border.width: 1
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.isNarrow ? 12 : 18
        spacing: root.isNarrow ? 8 : 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 36
                height: 36
                radius: 10
                color: (liveMetrics.color || "#3B82F6") + "20"
                border.color: liveMetrics.color || "#3B82F6"
                Label {
                    anchors.centerIn: parent
                    text: liveMetrics.icon || "🏃"
                    font.pixelSize: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: editMealIndex >= 0
                        ? (langManager ? langManager.t("edit_workout") : "Edit Workout")
                        : (langManager ? langManager.t("add_workout") : "Add Workout Activity")
                    font.bold: true
                    font.pixelSize: root.isNarrow ? 13 : 15
                    color: "#1C1917"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: langManager ? langManager.t("workout_desc") : "Burns energy & macronutrients, increasing daily caloric need"
                    font.pixelSize: 10
                    color: "#78716C"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            RoundButton {
                text: "✕"
                flat: true
                font.pixelSize: 12
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                onClicked: root.close()
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#F5F5F4"
        }

        // Body
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width - 6
                spacing: 12

                // Workout Type Selector Grid
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    implicitHeight: typeCol.implicitHeight + 20

                    ColumnLayout {
                        id: typeCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Label {
                            text: "🏋️ " + (langManager ? langManager.t("workout_type") : "Workout Type")
                            font.bold: true
                            font.pixelSize: 12
                            color: "#44403C"
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: root.isNarrow ? 1 : 2
                            rowSpacing: 6
                            columnSpacing: 6

                            // 1. Stretching & Yoga
                            Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: 8
                                color: root.selectedType === "stretch" ? "#CFFAFE" : "#F8FAFC"
                                border.color: root.selectedType === "stretch" ? "#06B6D4" : "#E2E8F0"
                                border.width: root.selectedType === "stretch" ? 2 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedType = "stretch"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Label { text: "🧘"; font.pixelSize: 16 }
                                    ColumnLayout {
                                        spacing: 0
                                        Label {
                                            text: langManager ? langManager.t("workout_stretch") : "Stretching & Yoga"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#0E7490"
                                        }
                                        Label {
                                            text: "~160 kcal/h • 65% Fat"
                                            font.pixelSize: 9
                                            color: "#64748B"
                                        }
                                    }
                                }
                            }

                            // 2. Endurance Cardio
                            Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: 8
                                color: root.selectedType === "endurance" ? "#DBEAFE" : "#F8FAFC"
                                border.color: root.selectedType === "endurance" ? "#3B82F6" : "#E2E8F0"
                                border.width: root.selectedType === "endurance" ? 2 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedType = "endurance"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Label { text: "🏃"; font.pixelSize: 16 }
                                    ColumnLayout {
                                        spacing: 0
                                        Label {
                                            text: langManager ? langManager.t("workout_endurance") : "Endurance Cardio"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#1D4ED8"
                                        }
                                        Label {
                                            text: "~560 kcal/h • 60% Carbs"
                                            font.pixelSize: 9
                                            color: "#64748B"
                                        }
                                    }
                                }
                            }

                            // 3. Strength Training
                            Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: 8
                                color: root.selectedType === "strength" ? "#FFEDD5" : "#F8FAFC"
                                border.color: root.selectedType === "strength" ? "#EA580C" : "#E2E8F0"
                                border.width: root.selectedType === "strength" ? 2 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedType = "strength"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Label { text: "🏋️"; font.pixelSize: 16 }
                                    ColumnLayout {
                                        spacing: 0
                                        Label {
                                            text: langManager ? langManager.t("workout_strength") : "Strength Training"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#C2410C"
                                        }
                                        Label {
                                            text: "~420 kcal/h • 65% Carbs, 15% Prot"
                                            font.pixelSize: 9
                                            color: "#64748B"
                                        }
                                    }
                                }
                            }

                            // 4. HIIT & Intervals
                            Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: 8
                                color: root.selectedType === "intervals" ? "#FEE2E2" : "#F8FAFC"
                                border.color: root.selectedType === "intervals" ? "#DC2626" : "#E2E8F0"
                                border.width: root.selectedType === "intervals" ? 2 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedType = "intervals"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Label { text: "⚡"; font.pixelSize: 16 }
                                    ColumnLayout {
                                        spacing: 0
                                        Label {
                                            text: langManager ? langManager.t("workout_hiit") : "HIIT & Intervals"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#B91C1C"
                                        }
                                        Label {
                                            text: "~680 kcal/h • 80% Carbs"
                                            font.pixelSize: 9
                                            color: "#64748B"
                                        }
                                    }
                                }
                            }

                            // 5. Custom Workout
                            Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: 8
                                color: root.selectedType === "custom" ? "#F3E8FF" : "#F8FAFC"
                                border.color: root.selectedType === "custom" ? "#8B5CF6" : "#E2E8F0"
                                border.width: root.selectedType === "custom" ? 2 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedType = "custom"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Label { text: "🎯"; font.pixelSize: 16 }
                                    ColumnLayout {
                                        spacing: 0
                                        Label {
                                            text: langManager ? langManager.t("workout_custom") : "Custom Workout"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#6D28D9"
                                        }
                                        Label {
                                            text: "Configurable burn & macros"
                                            font.pixelSize: 9
                                            color: "#64748B"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Time & Duration Row
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    implicitHeight: timingCol.implicitHeight + 20

                    ColumnLayout {
                        id: timingCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // Start Time & Duration Inputs
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Start Time
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: "🕒 " + (langManager ? langManager.t("start_time") : "Start Time")
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#44403C"
                                }
                                TextField {
                                    id: timeInput
                                    Layout.fillWidth: true
                                    text: root.workoutTime
                                    placeholderText: "17:00"
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: TextInput.AlignHCenter
                                    background: Rectangle { radius: 8; color: "#FAFAF9"; border.color: "#E2D9C8" }
                                    onTextEdited: root.workoutTime = text.trim()
                                    onEditingFinished: root.workoutTime = text.trim()
                                }
                            }

                            // Duration
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: "⏱️ " + (langManager ? langManager.t("duration") : "Duration (min)")
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#44403C"
                                }
                                TextField {
                                    id: durInput
                                    Layout.fillWidth: true
                                    text: root.workoutDuration.toString()
                                    validator: IntValidator { bottom: 1; top: 360 }
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: TextInput.AlignHCenter
                                    background: Rectangle { radius: 8; color: "#FAFAF9"; border.color: "#E2D9C8" }
                                    onTextEdited: {
                                        let v = parseInt(text);
                                        if (!isNaN(v) && v >= 1 && v <= 360) root.workoutDuration = v;
                                    }
                                    onEditingFinished: {
                                        let v = parseInt(text);
                                        if (!isNaN(v) && v >= 1 && v <= 360) root.workoutDuration = v;
                                    }
                                }
                            }
                        }

                        // Quick duration preset buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: [15, 30, 45, 60, 90]
                                delegate: Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    text: modelData + "m"
                                    font.pixelSize: 10
                                    font.bold: root.workoutDuration === modelData
                                    palette.buttonText: root.workoutDuration === modelData ? "#FFFFFF" : "#57534E"
                                    background: Rectangle {
                                        radius: 6
                                        color: root.workoutDuration === modelData ? "#3B82F6" : "#F5F5F4"
                                        border.color: root.workoutDuration === modelData ? "#2563EB" : "#E2D9C8"
                                    }
                                    onClicked: {
                                        root.workoutDuration = modelData;
                                        durInput.text = modelData.toString();
                                    }
                                }
                            }
                        }
                    }
                }

                // Custom Calories / Macros override if type == "custom"
                Rectangle {
                    visible: root.selectedType === "custom"
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FAF5FF"
                    border.color: "#E9D5FF"
                    implicitHeight: custCol.implicitHeight + 20

                    ColumnLayout {
                        id: custCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Label {
                            text: langManager ? langManager.t("custom_expenditure_overrides") : "⚙️ Custom Expenditure Overrides"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#7E22CE"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Calories
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: qsTr("Burn (kcal)"); font.pixelSize: 9; color: "#6B21A8" }
                                TextField {
                                    Layout.fillWidth: true
                                    text: root.customCalories > 0 ? Math.round(root.customCalories).toString() : ""
                                    placeholderText: qsTr("Auto")
                                    font.pixelSize: 11
                                    background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#D8B4FE" }
                                    onTextEdited: {
                                        let v = parseFloat(text);
                                        root.customCalories = (!isNaN(v) && v > 0) ? v : -1.0;
                                    }
                                    onEditingFinished: {
                                        let v = parseFloat(text);
                                        root.customCalories = (!isNaN(v) && v > 0) ? v : -1.0;
                                    }
                                }
                            }

                            // Carbs
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: qsTr("Carbs (g)"); font.pixelSize: 9; color: "#6B21A8" }
                                TextField {
                                    Layout.fillWidth: true
                                    text: root.customCarbs >= 0 ? root.customCarbs.toString() : ""
                                    placeholderText: qsTr("Auto")
                                    font.pixelSize: 11
                                    background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#D8B4FE" }
                                    onTextEdited: {
                                        let v = parseFloat(text);
                                        root.customCarbs = (!isNaN(v) && v >= 0) ? v : -1.0;
                                    }
                                    onEditingFinished: {
                                        let v = parseFloat(text);
                                        root.customCarbs = (!isNaN(v) && v >= 0) ? v : -1.0;
                                    }
                                }
                            }

                            // Protein
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: qsTr("Protein (g)"); font.pixelSize: 9; color: "#6B21A8" }
                                TextField {
                                    Layout.fillWidth: true
                                    text: root.customProtein >= 0 ? root.customProtein.toString() : ""
                                    placeholderText: qsTr("Auto")
                                    font.pixelSize: 11
                                    background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#D8B4FE" }
                                    onTextEdited: {
                                        let v = parseFloat(text);
                                        root.customProtein = (!isNaN(v) && v >= 0) ? v : -1.0;
                                    }
                                    onEditingFinished: {
                                        let v = parseFloat(text);
                                        root.customProtein = (!isNaN(v) && v >= 0) ? v : -1.0;
                                    }
                                }
                            }

                            // Fat
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: qsTr("Fat (g)"); font.pixelSize: 9; color: "#6B21A8" }
                                TextField {
                                    Layout.fillWidth: true
                                    text: root.customFat >= 0 ? root.customFat.toString() : ""
                                    placeholderText: qsTr("Auto")
                                    font.pixelSize: 11
                                    background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#D8B4FE" }
                                    onTextEdited: {
                                        let v = parseFloat(text);
                                        root.customFat = (!isNaN(v) && v >= 0) ? v : -1.0;
                                    }
                                    onEditingFinished: {
                                        let v = parseFloat(text);
                                        root.customFat = (!isNaN(v) && v >= 0) ? v : -1.0;
                                    }
                                }
                            }
                        }
                    }
                }

                // Live Metabolic Expenditure Preview Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FEF2F2"
                    border.color: "#FECACA"
                    implicitHeight: burnCol.implicitHeight + 20

                    ColumnLayout {
                        id: burnCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "🔥 " + (langManager ? langManager.t("burned_energy") : "Energy Burned")
                                font.bold: true
                                font.pixelSize: 12
                                color: "#991B1B"
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: "-" + Math.round(root.liveMetrics.calories || 0) + " kcal"
                                font.bold: true
                                font.pixelSize: 15
                                color: "#DC2626"
                            }
                        }

                        Label {
                            text: langManager ? langManager.t("burned_macros") : "Substrate Breakdown (Oxidized):"
                            font.pixelSize: 10
                            color: "#7F1D1D"
                        }

                        // Macro substrate chips
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Carbs
                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 8
                                color: "#FEF3C7"
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Label { text: "🌾 " + qsTr("Carbs"); font.pixelSize: 9; font.bold: true; color: "#92400E" }
                                    Label { text: "-" + Math.round(root.liveMetrics.carbs || 0) + "g"; font.bold: true; font.pixelSize: 11; color: "#B45309" }
                                }
                            }

                            // Protein
                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 8
                                color: "#D1FAE5"
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Label { text: "🍗 " + qsTr("Protein"); font.pixelSize: 9; font.bold: true; color: "#065F46" }
                                    Label { text: "-" + Math.round(root.liveMetrics.protein || 0) + "g"; font.bold: true; font.pixelSize: 11; color: "#047857" }
                                }
                            }

                            // Fat
                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 8
                                color: "#DBEAFE"
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0
                                    Label { text: "🥑 " + qsTr("Fat"); font.pixelSize: 9; font.bold: true; color: "#1E40AF" }
                                    Label { text: "-" + Math.round(root.liveMetrics.fat || 0) + "g"; font.bold: true; font.pixelSize: 11; color: "#1D4ED8" }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Delete button if editing existing
            Button {
                visible: root.editMealIndex >= 0
                text: langManager ? langManager.t("delete_workout_btn") : "🗑️ Delete"
                font.pixelSize: 12
                Layout.preferredHeight: 40
                palette.buttonText: "#DC2626"
                background: Rectangle {
                    radius: 8
                    color: "#FEE2E2"
                    border.color: "#FCA5A5"
                }
                onClicked: {
                    if (mealPlanManager && root.editMealIndex >= 0) {
                        mealPlanManager.removeMeal(root.editMealIndex);
                    }
                    root.close();
                }
            }

            Button {
                text: langManager ? langManager.t("cancel_btn") : "Cancel"
                font.pixelSize: 12
                Layout.preferredHeight: 40
                background: Rectangle {
                    radius: 8
                    color: "#F5F5F4"
                    border.color: "#D6D3D1"
                }
                onClicked: root.close()
            }

            Button {
                id: saveWoBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: root.editMealIndex >= 0
                    ? ("💾 " + (langManager ? langManager.t("save_workout") : "Save Workout"))
                    : ("➕ " + (langManager ? langManager.t("add_workout") : "Add Workout"))
                font.bold: true
                font.pixelSize: 13
                palette.buttonText: "#FFFFFF"
                background: Rectangle {
                    radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#D97706" }
                        GradientStop { position: 1.0; color: "#EA580C" }
                    }
                }
                onClicked: {
                    if (mealPlanManager) {
                        if (root.editMealIndex >= 0) {
                            mealPlanManager.updateWorkout(
                                root.editMealIndex,
                                root.selectedType,
                                root.workoutTime,
                                root.workoutDuration,
                                root.customCalories,
                                root.customCarbs,
                                root.customProtein,
                                root.customFat
                            );
                        } else {
                            mealPlanManager.addWorkout(
                                root.selectedType,
                                root.workoutTime,
                                root.workoutDuration,
                                root.customCalories,
                                root.customCarbs,
                                root.customProtein,
                                root.customFat
                            );
                        }
                    }
                    root.close();
                }
            }
        }
    }
}
