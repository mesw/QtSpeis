import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(840, (parent ? parent.width : 840) - 20)
    height: Math.min(680, (parent ? parent.height : 680) - 24)
    padding: 0

    property var recipeManager: null
    property var mealPlanManager: null
    property var langManager: null

    readonly property bool isNarrow: root.width < 580

    property string activeTypeFilter: "all"
    property int selectedWorkoutIndex: 0
    property int chosenDuration: 45
    property string chosenTime: "17:00"

    signal customizeRequested(string type, string time, int duration, real calories, real carbs, real protein, real fat)

    // Filtered workout presets
    readonly property var filteredWorkouts: {
        if (!recipeManager || !recipeManager.workoutTemplates) return [];
        let list = recipeManager.workoutTemplates;
        let f = activeTypeFilter;
        if (f === "all") return list;

        return list.filter(function(w) {
            if (f === "custom") return !w.isDefault;
            if (f === "cardio") return w.type === "running" || w.type === "cycling" || w.type === "swimming" || w.type === "cardio";
            if (f === "strength") return w.type === "strength";
            if (f === "hiit") return w.type === "hiit";
            if (f === "mobility") return w.type === "mobility";
            return true;
        });
    }

    readonly property var currentWorkout: {
        let list = filteredWorkouts;
        if (selectedWorkoutIndex >= 0 && selectedWorkoutIndex < list.length) {
            return list[selectedWorkoutIndex];
        }
        return list.length > 0 ? list[0] : null;
    }

    onCurrentWorkoutChanged: {
        if (currentWorkout) {
            chosenDuration = currentWorkout.duration || 45;
        }
    }

    background: Rectangle {
        radius: 16
        color: "#FDFBF7"
        border.color: "#E2D9C8"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        // --- 1. HEADER ---
        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: "#FFFFFF"
            radius: 16

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#E7E5E4"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: "🏋️"
                    font.pixelSize: 26
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: langManager ? langManager.t("workout_library_title") : "Athletic Workout Library"
                        font.bold: true
                        font.pixelSize: root.isNarrow ? 15 : 17
                        color: "#1C1917"
                    }

                    Label {
                        text: langManager ? langManager.t("workout_library_subtitle") : "Standard athletic disciplines with metabolic energy burn"
                        font.pixelSize: 11
                        color: "#78716C"
                        elide: Text.ElideRight
                    }
                }

                RoundButton {
                    text: "✕"
                    flat: true
                    font.pixelSize: 13
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    palette.buttonText: "#78716C"
                    onClicked: root.close()
                }
            }
        }

        // --- 2. FILTER CHIPS ROW ---
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: "#FAF8F5"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#E7E5E4"
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: filterRow.implicitWidth + 10
                contentHeight: height
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: filterRow
                    height: parent.height
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "all", label: "🌟 All (12)" },
                            { id: "cardio", label: "🏃 Cardio" },
                            { id: "strength", label: "🏋️ Strength" },
                            { id: "hiit", label: "⚡ High Intensity" },
                            { id: "mobility", label: "🧘 Mobility & Recovery" },
                            { id: "custom", label: "⭐ Custom" }
                        ]

                        delegate: Rectangle {
                            id: chipRect
                            height: 32
                            width: chipLabel.implicitWidth + 18
                            radius: 8
                            property bool isSelected: root.activeTypeFilter === modelData.id
                            color: isSelected ? "#C2410C" : "#FFFFFF"
                            border.color: isSelected ? "#C2410C" : "#E2D9C8"

                            Label {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                font.bold: chipRect.isSelected
                                font.pixelSize: 11
                                color: chipRect.isSelected ? "#FFFFFF" : "#475569"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeTypeFilter = modelData.id;
                                    root.selectedWorkoutIndex = 0;
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- 3. BODY SPLIT VIEW ---
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // LEFT COLUMN: WORKOUT LIST
            Rectangle {
                Layout.preferredWidth: root.isNarrow ? parent.width : 340
                Layout.fillWidth: root.isNarrow
                Layout.fillHeight: true
                color: "#FAF8F5"

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: "#E7E5E4"
                    visible: !root.isNarrow
                }

                ScrollView {
                    anchors.fill: parent
                    clip: true

                    ListView {
                        id: workoutListView
                        width: parent.width
                        spacing: 8
                        topMargin: 10
                        bottomMargin: 10
                        leftMargin: 10
                        rightMargin: 10
                        model: root.filteredWorkouts

                        Label {
                            visible: workoutListView.count === 0
                            anchors.centerIn: parent
                            text: langManager ? langManager.t("no_workouts_in_category") : "No workouts in this category."
                            font.pixelSize: 12
                            color: "#78716C"
                        }

                        delegate: Rectangle {
                            width: workoutListView.width - 20
                            implicitHeight: wCardCol.implicitHeight + 16
                            radius: 10
                            property bool isSelected: root.selectedWorkoutIndex === index
                            color: isSelected ? "#FFF7ED" : "#FFFFFF"
                            border.color: isSelected ? "#EA580C" : "#E2D9C8"
                            border.width: isSelected ? 2 : 1

                            ColumnLayout {
                                id: wCardCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.icon || "🏃"
                                        font.pixelSize: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Label {
                                            text: modelData.title
                                            font.bold: true
                                            font.pixelSize: 13
                                            color: "#1C1917"
                                            elide: Text.ElideRight
                                        }

                                        RowLayout {
                                            spacing: 6
                                            Label {
                                                text: "⏱️ " + modelData.duration + " min"
                                                font.pixelSize: 10
                                                color: "#78716C"
                                            }
                                            Label {
                                                text: "·"
                                                color: "#D6D3D1"
                                            }
                                            Label {
                                                text: "🔥 " + Math.round(modelData.calories) + " kcal"
                                                font.bold: true
                                                font.pixelSize: 10
                                                color: "#C2410C"
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 8
                                    Layout.leftMargin: 30
                                    Label { text: "Carbs: " + Math.round(modelData.carbs) + "g"; font.pixelSize: 9; color: "#D97706" }
                                    Label { text: "Prot: " + Math.round(modelData.protein) + "g"; font.pixelSize: 9; color: "#2563EB" }
                                    Label { text: "Fat: " + Math.round(modelData.fat) + "g"; font.pixelSize: 9; color: "#DC2626" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedWorkoutIndex = index
                            }
                        }
                    }
                }
            }

            // RIGHT COLUMN: WORKOUT DETAILS & DURATION SCALER
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                visible: !root.isNarrow

                ScrollView {
                    anchors.fill: parent
                    clip: true
                    topPadding: 16
                    bottomPadding: 16

                    ColumnLayout {
                        width: parent.width - 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        // Detail Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: root.currentWorkout ? (root.currentWorkout.icon || "🏃") : "🏃"
                                font.pixelSize: 34
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: root.currentWorkout ? root.currentWorkout.title : ""
                                    font.bold: true
                                    font.pixelSize: 17
                                    color: "#1C1917"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Label {
                                    text: root.currentWorkout ? root.currentWorkout.description : ""
                                    font.pixelSize: 11
                                    color: "#78716C"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Duration Scaling Slider Card
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: durCol.implicitHeight + 20
                            radius: 12
                            color: "#FAF8F5"
                            border.color: "#E2D9C8"

                            ColumnLayout {
                                id: durCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: "⏱️ " + (langManager ? langManager.t("duration") : "Duration:")
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: "#334155"
                                    }

                                    Item { Layout.fillWidth: true }

                                    Label {
                                        text: root.chosenDuration + " minutes"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#EA580C"
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 15
                                    to: 180
                                    stepSize: 5
                                    value: root.chosenDuration
                                    onMoved: root.chosenDuration = Math.round(value)
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: "15m"; font.pixelSize: 9; color: "#94A3B8" }
                                    Item { Layout.fillWidth: true }
                                    Label { text: "45m"; font.pixelSize: 9; color: "#94A3B8" }
                                    Item { Layout.fillWidth: true }
                                    Label { text: "90m"; font.pixelSize: 9; color: "#94A3B8" }
                                    Item { Layout.fillWidth: true }
                                    Label { text: "180m"; font.pixelSize: 9; color: "#94A3B8" }
                                }
                            }
                        }

                        // Scaled Burn Metrics Card
                        readonly property real durRatio: root.currentWorkout ? (root.chosenDuration / (root.currentWorkout.duration || 45)) : 1.0
                        readonly property real scaledKcal: root.currentWorkout ? (root.currentWorkout.calories * durRatio) : 0
                        readonly property real scaledCarbs: root.currentWorkout ? (root.currentWorkout.carbs * durRatio) : 0
                        readonly property real scaledProtein: root.currentWorkout ? (root.currentWorkout.protein * durRatio) : 0
                        readonly property real scaledFat: root.currentWorkout ? (root.currentWorkout.fat * durRatio) : 0

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: metricCol.implicitHeight + 20
                            radius: 12
                            color: "#FFF7ED"
                            border.color: "#FDBA74"

                            ColumnLayout {
                                id: metricCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 1
                                        Label {
                                            text: langManager ? langManager.t("total_burned_energy") : "Total Burned Energy"
                                            font.pixelSize: 11
                                            color: "#9A3412"
                                        }
                                        Label {
                                            text: "-" + Math.round(root.scaledKcal) + " kcal"
                                            font.bold: true
                                            font.pixelSize: 22
                                            color: "#C2410C"
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Time picker
                                    ColumnLayout {
                                        spacing: 2
                                        Label {
                                            text: langManager ? langManager.t("start_time") : "Start Time:"
                                            font.pixelSize: 10
                                            color: "#9A3412"
                                        }
                                        TextField {
                                            text: root.chosenTime
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 70
                                            Layout.preferredHeight: 30
                                            horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: root.chosenTime = text
                                            background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#FDBA74" }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: "#FED7AA" }

                                Label {
                                    text: langManager ? langManager.t("substrates_burned") : "Substrates Burned (Metabolic Demand):"
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: "#9A3412"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 38
                                        radius: 6
                                        color: "#FFFFFF"
                                        border.color: "#FDBA74"
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 1
                                            Label { text: langManager ? langManager.t("carbs") : "Carbohydrates"; font.pixelSize: 9; color: "#78716C" }
                                            Label { text: Math.round(root.scaledCarbs) + "g"; font.bold: true; font.pixelSize: 12; color: "#D97706" }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 38
                                        radius: 6
                                        color: "#FFFFFF"
                                        border.color: "#FDBA74"
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 1
                                            Label { text: langManager ? langManager.t("protein") : "Protein"; font.pixelSize: 9; color: "#78716C" }
                                            Label { text: Math.round(root.scaledProtein) + "g"; font.bold: true; font.pixelSize: 12; color: "#2563EB" }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 38
                                        radius: 6
                                        color: "#FFFFFF"
                                        border.color: "#FDBA74"
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 1
                                            Label { text: langManager ? langManager.t("fat") : "Fat"; font.pixelSize: 9; color: "#78716C" }
                                            Label { text: Math.round(root.scaledFat) + "g"; font.bold: true; font.pixelSize: 12; color: "#DC2626" }
                                        }
                                    }
                                }
                            }
                        }

                        // Action Buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Button {
                                Layout.fillWidth: true
                                height: 44
                                text: langManager ? langManager.t("add_workout_to_plan") : "🏃 Add Workout to Plan"
                                font.bold: true
                                font.pixelSize: 13
                                palette.buttonText: "#FFFFFF"
                                background: Rectangle {
                                    radius: 10
                                    color: "#EA580C"
                                }
                                onClicked: {
                                    if (recipeManager && mealPlanManager && root.currentWorkout) {
                                        mealPlanManager.addWorkout(
                                            root.currentWorkout.type,
                                            root.chosenTime,
                                            root.chosenDuration,
                                            root.scaledKcal,
                                            root.scaledCarbs,
                                            root.scaledProtein,
                                            root.scaledFat
                                        );
                                        root.close();
                                    }
                                }
                            }

                            Button {
                                height: 44
                                text: langManager ? langManager.t("custom_workout_details") : "⚙️ Custom Details..."
                                font.pixelSize: 11
                                palette.buttonText: "#475569"
                                background: Rectangle {
                                    radius: 10
                                    color: "#F1F5F9"
                                    border.color: "#CBD5E1"
                                }
                                onClicked: {
                                    if (root.currentWorkout) {
                                        root.customizeRequested(
                                            root.currentWorkout.type,
                                            root.chosenTime,
                                            root.chosenDuration,
                                            root.scaledKcal,
                                            root.scaledCarbs,
                                            root.scaledProtein,
                                            root.scaledFat
                                        );
                                        root.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
