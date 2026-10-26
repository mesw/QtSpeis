import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var mealPlanManager: null
    property var foodDb: null
    property alias foodDatabase: root.foodDb
    property var gameLevelManager: null
    property var offFetcher: null
    property var langManager: null
    property var recipeManager: null
    signal scanBarcodeRequested(int mealIndex)
    signal addWorkoutRequested()
    signal editWorkoutRequested(int mealIndex)
    signal levelSelectRequested()
    signal openRecipeLibraryRequested(string category)
    signal openWorkoutLibraryRequested()
    signal openIngredientExplorerRequested()

    readonly property bool isNarrow: root.width < 560

    // Track collapsed meal cards by index
    property var collapsedMeals: ({})

    function isMealCollapsed(idx) {
        return Boolean(collapsedMeals[idx]);
    }

    function toggleMealCollapsed(idx) {
        var copy = Object.assign({}, collapsedMeals);
        if (copy[idx]) {
            delete copy[idx];
        } else {
            copy[idx] = true;
        }
        collapsedMeals = copy;
    }

    function collapseAll() {
        var all = {};
        if (mealPlanManager && mealPlanManager.meals) {
            for (var i = 0; i < mealPlanManager.meals.length; ++i) {
                all[i] = true;
            }
        }
        collapsedMeals = all;
    }

    function expandAll() {
        collapsedMeals = ({});
    }

    function areAllCollapsed() {
        if (!mealPlanManager || !mealPlanManager.meals || mealPlanManager.meals.length === 0) return false;
        for (var i = 0; i < mealPlanManager.meals.length; ++i) {
            if (!collapsedMeals[i]) return false;
        }
        return true;
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff


        ColumnLayout {
            id: contentCol
            width: scrollView.availableWidth
            spacing: 16

            // Level Task & Action Header
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 10
                        color: "#FEF3C7"
                        border.color: "#FDE68A"
                        Label {
                            anchors.centerIn: parent
                            text: {
                                if (gameLevelManager && gameLevelManager.currentLevelData && gameLevelManager.currentLevelData.badge) {
                                    var b = gameLevelManager.currentLevelData.badge;
                                    var parts = b.split(" ");
                                    if (parts.length > 0 && parts[0].length > 0) return parts[0];
                                }
                                return "🏆";
                            }
                            font.pixelSize: 20
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.levelSelectRequested()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Label {
                            text: (gameLevelManager && gameLevelManager.currentLevelData && gameLevelManager.currentLevelData.title)
                                ? gameLevelManager.currentLevelData.title
                                : "Level 1: Caloric Equilibrium"
                            font.bold: true
                            font.pixelSize: root.isNarrow ? 14 : 16
                            color: "#1C1917"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                text: "🎯"
                                font.pixelSize: 11
                            }
                            Label {
                                text: {
                                    if (gameLevelManager && gameLevelManager.currentLevel === 1 && mealPlanManager) {
                                        var tCal = Math.round(mealPlanManager.targetCalories);
                                        var isDe = langManager && langManager.currentLanguage === "de";
                                        return isDe ? ("Zielwert: " + tCal + " kcal (±50 kcal)") : ("Energy Target: " + tCal + " kcal (±50 kcal bullseye)");
                                    }
                                    return (gameLevelManager && gameLevelManager.currentLevelData && gameLevelManager.currentLevelData.subtitle)
                                        ? gameLevelManager.currentLevelData.subtitle
                                        : "Energy Target: 2,000 kcal (±50 kcal bullseye)";
                                }
                                font.pixelSize: 11
                                font.bold: true
                                color: "#D97706"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Actions on wide screens (desktop / tablet landscape)
                    RowLayout {
                        visible: !root.isNarrow
                        spacing: 4

                        Button {
                            text: root.areAllCollapsed() ? "📂 Expand All" : "📁 Collapse All"
                            flat: true
                            font.pixelSize: 11
                            palette.buttonText: "#57534E"
                            onClicked: root.areAllCollapsed() ? root.expandAll() : root.collapseAll()
                        }

                        Button {
                            visible: false
                            text: "✨ Reset Sample"
                            flat: true
                            font.pixelSize: 11
                            palette.buttonText: "#78716C"
                            ToolTip.visible: hovered
                            ToolTip.delay: 300
                            ToolTip.text: langManager ? langManager.t("reset_sample_title") : "Reset to Sample Plan"
                            onClicked: resetConfirmDialog.open()
                        }

                        Button {
                            visible: false
                            text: "👑 Cheat"
                            flat: true
                            font.pixelSize: 11
                            palette.buttonText: "#EA580C"
                            ToolTip.visible: hovered
                            ToolTip.delay: 300
                            ToolTip.text: langManager ? langManager.t("cheat_button_desc") : "Cheat: Load Ideal Plan & Solve All Levels"
                            onClicked: cheatConfirmDialog.open()
                        }

                        Button {
                            text: "🗑️ Clear"
                            flat: true
                            font.pixelSize: 11
                            palette.buttonText: "#DC2626"
                            ToolTip.visible: hovered
                            ToolTip.delay: 300
                            ToolTip.text: langManager ? langManager.t("clear_plan_title") : "Clear Plan"
                            onClicked: clearConfirmDialog.open()
                        }
                    }

                    // Compact icon actions on narrow screens (single row, saving vertical space)
                    RowLayout {
                        visible: root.isNarrow
                        spacing: 2

                        RoundButton {
                            text: root.areAllCollapsed() ? "📂" : "📁"
                            flat: true
                            font.pixelSize: 13
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            palette.buttonText: "#57534E"
                            ToolTip.visible: hovered
                            ToolTip.delay: 300
                            ToolTip.text: root.areAllCollapsed() ? "Expand All Meals" : "Collapse All Meals"
                            onClicked: root.areAllCollapsed() ? root.expandAll() : root.collapseAll()
                        }

                        RoundButton {
                            text: "✨"
                            flat: true
                            font.pixelSize: 13
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            palette.buttonText: "#78716C"
                            ToolTip.visible: hovered
                            ToolTip.delay: 300
                            ToolTip.text: langManager ? langManager.t("reset_sample_title") : "Reset to Sample Plan"
                            onClicked: resetConfirmDialog.open()
                        }

                        RoundButton {
                            text: "👑"
                            flat: true
                            font.pixelSize: 13
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            palette.buttonText: "#EA580C"
                            ToolTip.visible: hovered
                            ToolTip.delay: 300
                            ToolTip.text: langManager ? langManager.t("cheat_button_desc") : "Cheat: Load Ideal Plan & Solve All Levels"
                            onClicked: cheatConfirmDialog.open()
                        }

                        RoundButton {
                            text: "🗑️"
                            flat: true
                            font.pixelSize: 13
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            palette.buttonText: "#DC2626"
                            ToolTip.visible: hovered
                            ToolTip.delay: 300
                            ToolTip.text: langManager ? langManager.t("clear_plan_title") : "Clear Plan"
                            onClicked: clearConfirmDialog.open()
                        }
                    }
                }
            }

            // Quick Add Meal Bar (Horizontally scrollable on mobile)
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 12
                color: "#FBF9F5"
                border.color: "#E7E5E4"

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 4
                    contentWidth: quickMealRow.implicitWidth + 8
                    contentHeight: height
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    RowLayout {
                        id: quickMealRow
                        height: parent.height
                        spacing: 8

                        Label {
                            text: langManager ? langManager.t("quick_add") : "Quick Add:"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#57534E"
                            Layout.leftMargin: 6
                        }

                        Button {
                            text: langManager ? langManager.t("recipes_btn") : "📖 Recipes (32)"
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#1D4ED8"
                            background: Rectangle { radius: 6; color: "#DBEAFE"; border.color: "#93C5FD" }
                            ToolTip.visible: hovered
                            ToolTip.text: "Browse 32 real balanced chef recipes"
                            onClicked: root.openRecipeLibraryRequested("All")
                        }

                        Button {
                            property int tplCount: (recipeManager ? recipeManager.customTemplateCount : 0)
                            text: (langManager ? langManager.t("custom_meals_tab") : "⭐ Saved Meals") + (tplCount > 0 ? (" (" + tplCount + ")") : "")
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#047857"
                            background: Rectangle { radius: 6; color: "#D1FAE5"; border.color: "#6EE7B7" }
                            ToolTip.visible: hovered
                            ToolTip.text: "Load your saved custom meals"
                            onClicked: root.openRecipeLibraryRequested("Custom")
                        }

                        Button {
                            text: langManager ? langManager.t("workout_library_btn") : "🏋️ Workout Library"
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#C2410C"
                            background: Rectangle { radius: 6; color: "#FFEDD5"; border.color: "#FDBA74" }
                            ToolTip.visible: hovered
                            ToolTip.text: "Browse athletic workout presets"
                            onClicked: root.openWorkoutLibraryRequested()
                        }

                        Button {
                            text: (langManager && langManager.currentLanguage === "de") ? "🔬 Zutaten-Explorer" : "🔬 Ingredient Explorer"
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#B45309"
                            background: Rectangle { radius: 6; color: "#FEF3C7"; border.color: "#FDE68A" }
                            ToolTip.visible: hovered
                            ToolTip.text: langManager ? langManager.t("ingredient_explorer_sub") : "Explore all foods and nutrients"
                            onClicked: root.openIngredientExplorerRequested()
                        }

                        Button {
                            text: "🍳 " + (langManager ? langManager.t("meal_breakfast") : "Breakfast")
                            font.pixelSize: 11
                            background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#E2D9C8" }
                            onClicked: if (mealPlanManager) mealPlanManager.addMeal(langManager ? langManager.t("meal_breakfast") : "Breakfast", "08:00", "🍳", "#F59E0B")
                        }

                        Button {
                            text: "🥗 " + (langManager ? langManager.t("meal_lunch") : "Lunch")
                            font.pixelSize: 11
                            background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#E2D9C8" }
                            onClicked: if (mealPlanManager) mealPlanManager.addMeal(langManager ? langManager.t("meal_lunch") : "Lunch", "12:30", "🥗", "#10B981")
                        }

                        Button {
                            text: "🍎 " + (langManager ? langManager.t("meal_snack") : "Snack")
                            font.pixelSize: 11
                            background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#E2D9C8" }
                            onClicked: if (mealPlanManager) mealPlanManager.addMeal(langManager ? langManager.t("meal_snack") : "Snack", "16:00", "🍎", "#EC4899")
                        }

                        Button {
                            text: "🍲 " + (langManager ? langManager.t("meal_dinner") : "Dinner")
                            font.pixelSize: 11
                            background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#E2D9C8" }
                            onClicked: if (mealPlanManager) mealPlanManager.addMeal(langManager ? langManager.t("meal_dinner") : "Dinner", "19:30", "🍲", "#8B5CF6")
                        }

                        Button {
                            text: "➕ Custom Meal"
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#15803D"
                            background: Rectangle { radius: 6; color: "#DCFCE7"; border.color: "#86EFAC" }
                            onClicked: customMealDialog.open()
                        }

                        Button {
                            text: "🏃 " + (langManager ? langManager.t("add_workout") : "Workout")
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#C2410C"
                            background: Rectangle { radius: 6; color: "#FFEDD5"; border.color: "#FDBA74" }
                            onClicked: root.addWorkoutRequested()
                        }
                    }
                }
            }

            // Meal Cards Repeater
            Repeater {
                id: mealRepeater
                model: mealPlanManager ? mealPlanManager.meals : []

                delegate: Rectangle {
                    id: mealCard
                    Layout.fillWidth: true
                    property int mealIndex: index
                    property var mealData: modelData
                    readonly property bool isWorkout: Boolean(mealData && mealData.isWorkout)
                    readonly property bool isNarrowCard: root.isNarrow
                    readonly property bool isCollapsed: root.isMealCollapsed(mealIndex)

                    implicitHeight: isWorkout ? (workoutCol.implicitHeight + 28) : (mealCol.implicitHeight + 28)
                    radius: 14
                    color: isWorkout ? "#FAFAFA" : "#FFFFFF"
                    border.color: isWorkout ? (mealData.color || "#3B82F6") : "#E7E5E4"
                    border.width: isWorkout ? 2 : 1

                    // --- WORKOUT CARD LAYOUT ---
                    ColumnLayout {
                        id: workoutCol
                        visible: mealCard.isWorkout
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        // Top Row: Icon + Title + Time + Duration + Burned Kcal + Edit + Delete
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Collapse Chevron Button
                            RoundButton {
                                text: mealCard.isCollapsed ? "▶" : "▼"
                                flat: true
                                font.pixelSize: 10
                                font.bold: true
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 28
                                palette.buttonText: "#78716C"
                                ToolTip.visible: hovered
                                ToolTip.text: mealCard.isCollapsed ? "Expand Workout" : "Collapse Workout"
                                onClicked: root.toggleMealCollapsed(mealIndex)
                            }

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 8
                                color: (mealData.color || "#3B82F6") + "20"
                                border.color: mealData.color || "#3B82F6"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: mealData.icon || "🏃"
                                    font.pixelSize: 18
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleMealCollapsed(mealIndex)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    text: mealData.title || "Workout"
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: "#1C1917"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: "🕒 " + (mealData.time || "17:00") + " • ⏱️ " + (mealData.duration || 45) + " min"
                                    font.pixelSize: 11
                                    color: "#78716C"
                                }
                            }

                            // Burned Calories Pill
                            Rectangle {
                                radius: 8
                                color: "#FEE2E2"
                                border.color: "#FCA5A5"
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: woBurnLbl.implicitWidth + 14
                                Label {
                                    id: woBurnLbl
                                    anchors.centerIn: parent
                                    text: "-" + Math.round(mealData.calories || 0) + " kcal"
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: "#DC2626"
                                }
                            }

                            // Edit Workout Button
                            Button {
                                text: "✏️"
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 30
                                background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E2D9C8" }
                                ToolTip.visible: hovered
                                ToolTip.text: langManager ? langManager.t("edit_workout") : "Edit Workout"
                                onClicked: root.editWorkoutRequested(mealIndex)
                            }

                            // Delete Workout Button
                            RoundButton {
                                text: "🗑️"
                                flat: true
                                font.pixelSize: 12
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                ToolTip.visible: hovered
                                ToolTip.text: "Delete Workout"
                                onClicked: {
                                    if (mealPlanManager) mealPlanManager.removeMeal(mealIndex);
                                }
                            }
                        }

                        // Substrate Oxidation (Burned Macros) Row
                        RowLayout {
                            visible: !mealCard.isCollapsed
                            Layout.fillWidth: true
                            spacing: 6

                            // Carbs
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 6
                                color: "#FEF3C7"
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Label { text: "🌾"; font.pixelSize: 11 }
                                    Label {
                                        text: "-" + Math.round(mealData.carbs || 0) + "g carbs"
                                        font.bold: true
                                        font.pixelSize: 10
                                        color: "#92400E"
                                    }
                                }
                            }

                            // Protein
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 6
                                color: "#D1FAE5"
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Label { text: "🍗"; font.pixelSize: 11 }
                                    Label {
                                        text: "-" + Math.round(mealData.protein || 0) + "g protein"
                                        font.bold: true
                                        font.pixelSize: 10
                                        color: "#065F46"
                                    }
                                }
                            }

                            // Fat
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 6
                                color: "#DBEAFE"
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Label { text: "🥑"; font.pixelSize: 11 }
                                    Label {
                                        text: "-" + Math.round(mealData.fat || 0) + "g fat"
                                        font.bold: true
                                        font.pixelSize: 10
                                        color: "#1E40AF"
                                    }
                                }
                            }
                        }
                    }

                    // --- MEAL CARD LAYOUT ---
                    ColumnLayout {
                        id: mealCol
                        visible: !mealCard.isWorkout
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        // Meal Card Header
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Primary Header Row (Always visible)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // Collapse Chevron Button
                                RoundButton {
                                    text: mealCard.isCollapsed ? "▶" : "▼"
                                    flat: true
                                    font.pixelSize: 10
                                    font.bold: true
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 28
                                    palette.buttonText: "#78716C"
                                    ToolTip.visible: hovered
                                    ToolTip.text: mealCard.isCollapsed ? "Expand Meal" : "Collapse Meal"
                                    onClicked: root.toggleMealCollapsed(mealIndex)
                                }

                                // Meal icon & color badge
                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 8
                                    color: (mealData.color || "#3B82F6") + "20"
                                    border.color: mealData.color || "#3B82F6"
                                    border.width: 1
                                    Label {
                                        anchors.centerIn: parent
                                        text: mealData.icon || "🍽️"
                                        font.pixelSize: 16
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleMealCollapsed(mealIndex)
                                    }
                                }

                                // Meal Title
                                TextField {
                                    id: mealTitleField
                                    text: mealData.title || "Meal"
                                    Binding on text {
                                        value: (mealData && mealData.title) ? mealData.title : "Meal"
                                    }
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: "#1C1917"
                                    background: Item {}
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 60
                                    onEditingFinished: {
                                        if (mealPlanManager) mealPlanManager.updateMealTitle(mealIndex, text);
                                    }
                                }

                                // Time badge (On wide screens shown in row 1; on narrow screens in row 2)
                                Rectangle {
                                    visible: !mealCard.isNarrowCard
                                    radius: 6
                                    color: "#F5F5F4"
                                    border.color: "#D6D3D1"
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: 68

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Label { text: "🕒"; font.pixelSize: 10 }
                                        TextField {
                                            id: timeFieldWide
                                            text: mealData.time || "12:00"
                                            Binding on text {
                                                value: (mealData && mealData.time) ? mealData.time : "12:00"
                                            }
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#44403C"
                                            background: Item {}
                                            padding: 0
                                            topPadding: 0
                                            bottomPadding: 0
                                            leftPadding: 0
                                            rightPadding: 0
                                            implicitWidth: 38
                                            implicitHeight: 20
                                            horizontalAlignment: TextInput.AlignHCenter
                                            verticalAlignment: TextInput.AlignVCenter
                                            onEditingFinished: {
                                                if (mealPlanManager) mealPlanManager.updateMealTime(mealIndex, text);
                                            }
                                        }
                                    }
                                }

                                // Meal Subtotal Pill
                                Rectangle {
                                    radius: 8
                                    color: "#FEF3C7"
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: subtotalLbl.implicitWidth + 14

                                    Label {
                                        id: subtotalLbl
                                        anchors.centerIn: parent
                                        text: mealCard.isNarrowCard
                                            ? (Math.round(mealData.calories || 0) + " kcal")
                                            : (Math.round(mealData.calories || 0) + " kcal • C:" + Math.round(mealData.carbs || 0) + "g P:" + Math.round(mealData.protein || 0) + "g F:" + Math.round(mealData.fat || 0) + "g")
                                        font.bold: true
                                        font.pixelSize: 10
                                        color: "#B45309"
                                    }
                                }

                                // Item Count Pill when Collapsed
                                Rectangle {
                                    visible: mealCard.isCollapsed && Boolean(mealData.items && mealData.items.length > 0)
                                    radius: 6
                                    color: "#F5F5F4"
                                    border.color: "#E7E5E4"
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: itemCountLbl.implicitWidth + 10
                                    Label {
                                        id: itemCountLbl
                                        anchors.centerIn: parent
                                        text: (mealData.items ? mealData.items.length : 0) + " items"
                                        font.pixelSize: 9
                                        color: "#78716C"
                                    }
                                }

                                // Save Meal as Custom Meal Template
                                RoundButton {
                                    text: "💾"
                                    flat: true
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    ToolTip.visible: hovered
                                    ToolTip.text: langManager ? langManager.t("save_as_template_btn") : "Save as Custom Meal"
                                    enabled: Boolean(mealData.items && mealData.items.length > 0)
                                    onClicked: {
                                        saveCustomTemplateDialog.targetMealIndex = mealIndex;
                                        saveCustomTemplateDialog.initialName = mealData.title || "Custom Meal";
                                        saveCustomTemplateDialog.openDialog();
                                    }
                                }

                                // Delete Meal Button
                                RoundButton {
                                    text: "🗑️"
                                    flat: true
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Remove Meal"
                                    onClicked: {
                                        if (mealPlanManager) mealPlanManager.removeMeal(mealIndex);
                                    }
                                }
                            }

                            // Secondary Header Row for Narrow / Mobile View (Time + Macros breakdown)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: mealCard.isNarrowCard

                                // Time badge
                                Rectangle {
                                    radius: 6
                                    color: "#F5F5F4"
                                    border.color: "#D6D3D1"
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: 64

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Label { text: "🕒"; font.pixelSize: 9 }
                                        TextField {
                                            id: timeFieldNarrow
                                            text: mealData.time || "12:00"
                                            Binding on text {
                                                value: (mealData && mealData.time) ? mealData.time : "12:00"
                                            }
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#44403C"
                                            background: Item {}
                                            padding: 0
                                            topPadding: 0
                                            bottomPadding: 0
                                            leftPadding: 0
                                            rightPadding: 0
                                            implicitWidth: 36
                                            implicitHeight: 18
                                            horizontalAlignment: TextInput.AlignHCenter
                                            verticalAlignment: TextInput.AlignVCenter
                                            onEditingFinished: {
                                                if (mealPlanManager) mealPlanManager.updateMealTime(mealIndex, text);
                                            }
                                        }
                                    }
                                }

                                // Macro breakdown text
                                Label {
                                    text: "C: " + Math.round(mealData.carbs || 0) + "g • P: " + Math.round(mealData.protein || 0) + "g • F: " + Math.round(mealData.fat || 0) + "g"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#78716C"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            visible: !mealCard.isCollapsed
                            Layout.fillWidth: true
                            height: 1
                            color: "#F5F5F4"
                        }

                        // Food Items List
                        ColumnLayout {
                            visible: !mealCard.isCollapsed
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                id: itemRepeater
                                model: mealData.items || []

                                delegate: Rectangle {
                                    id: itemRow
                                    Layout.fillWidth: true
                                    implicitHeight: isNarrowItem ? (itemColLayout.implicitHeight + 14) : 44
                                    radius: 8
                                    color: itemMouseArea.containsMouse ? "#FFFBEB" : "#FAFAF9"
                                    border.color: itemMouseArea.containsMouse ? "#FDE68A" : "#F5F5F4"

                                    property int itemIndex: index
                                    property var itemData: modelData
                                    readonly property bool isNarrowItem: root.isNarrow
                                    readonly property real servSize: (itemData && itemData.servingSize) ? Number(itemData.servingSize) : 0

                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    // --- Wide Layout (Single Row) ---
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8
                                        visible: !itemRow.isNarrowItem

                                        Label {
                                            text: (itemData.icon && itemData.icon !== "🍽️" && itemData.icon !== "🍽")
                                                  ? String(itemData.icon).replace(/\uFE0F/g, "")
                                                  : "🥗"
                                            font.pixelSize: 16
                                        }

                                        Label {
                                            text: itemData.name || "Food Item"
                                            font.bold: true
                                            font.pixelSize: 13
                                            color: "#292524"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        // Wide Stepper
                                        RowLayout {
                                            spacing: 3

                                            // Decrement serving
                                            RoundButton {
                                                id: wideMinusServingBtn
                                                visible: itemRow.servSize > 0
                                                text: "−" + itemRow.servSize
                                                padding: 0
                                                leftPadding: 4
                                                rightPadding: 4
                                                Layout.preferredWidth: visible ? (itemRow.servSize >= 100 ? 44 : 38) : 0
                                                Layout.preferredHeight: 28
                                                font.pixelSize: 10
                                                font.bold: true
                                                palette.buttonText: "#B45309"
                                                contentItem: Label {
                                                    text: wideMinusServingBtn.text
                                                    font: wideMinusServingBtn.font
                                                    color: "#B45309"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                background: Rectangle {
                                                    radius: 14
                                                    color: wideMinusServingBtn.hovered ? "#FDE68A" : "#FEF3C7"
                                                    border.color: "#F59E0B"
                                                    border.width: 1
                                                }
                                                ToolTip.visible: hovered
                                                ToolTip.text: (langManager && langManager.currentLanguage === "de")
                                                    ? ("−1 Portion (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                    : ("−1 serving (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                onClicked: {
                                                    let cur = itemData.amount || 100;
                                                    let next = cur - itemRow.servSize;
                                                    if (next <= 0) {
                                                        if (mealPlanManager) mealPlanManager.removeItemFromMeal(mealIndex, itemIndex);
                                                    } else {
                                                        if (mealPlanManager) mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                    }
                                                }
                                            }

                                            // Decrement 10g
                                            RoundButton {
                                                id: wideMinusGramBtn
                                                text: "−"
                                                Layout.preferredWidth: 26
                                                Layout.preferredHeight: 28
                                                font.pixelSize: 13
                                                font.bold: true
                                                palette.buttonText: "#44403C"
                                                background: Rectangle {
                                                    radius: 14
                                                    color: wideMinusGramBtn.hovered ? "#E7E5E4" : "#F5F5F4"
                                                    border.color: "#D6D3D1"
                                                }
                                                ToolTip.visible: hovered
                                                ToolTip.text: {
                                                    let cur = itemData.amount || 100;
                                                    let step = cur > 10 ? 10 : (cur > 1 ? 1 : 0.25);
                                                    return "-" + step + " " + (itemData.unit || "g");
                                                }
                                                onClicked: {
                                                    let cur = itemData.amount || 100;
                                                    let step = cur > 10 ? 10 : (cur > 1 ? 1 : 0.25);
                                                    let next = Math.round((cur - step) * 100) / 100;
                                                    if (!mealPlanManager) return;
                                                    if (next <= 0.001) {
                                                        mealPlanManager.removeItemFromMeal(mealIndex, itemIndex);
                                                    } else {
                                                        mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                    }
                                                }
                                            }

                                            // Amount field
                                            TextField {
                                                text: itemData.amount || 100
                                                Binding on text {
                                                    value: itemData.amount ? itemData.amount.toString() : "100"
                                                }
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: "#1C1917"
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.preferredWidth: 44
                                                background: Rectangle { radius: 4; color: "#FFFFFF"; border.color: "#E7E5E4" }
                                                onEditingFinished: {
                                                    let val = parseFloat(text);
                                                    if (!isNaN(val) && val > 0 && mealPlanManager) {
                                                        mealPlanManager.updateItemAmount(mealIndex, itemIndex, val);
                                                    }
                                                }
                                            }

                                            // Unit
                                            Label {
                                                text: itemData.unit || "g"
                                                font.pixelSize: 11
                                                color: "#78716C"
                                                Layout.rightMargin: 4
                                            }

                                            // Increment 10g
                                            RoundButton {
                                                id: widePlusGramBtn
                                                text: "+"
                                                Layout.preferredWidth: 26
                                                Layout.preferredHeight: 28
                                                font.pixelSize: 13
                                                font.bold: true
                                                palette.buttonText: "#44403C"
                                                background: Rectangle {
                                                    radius: 14
                                                    color: widePlusGramBtn.hovered ? "#E7E5E4" : "#F5F5F4"
                                                    border.color: "#D6D3D1"
                                                }
                                                ToolTip.visible: hovered
                                                ToolTip.text: {
                                                    let cur = itemData.amount || 100;
                                                    let step = cur < 1 ? 0.25 : (cur < 10 ? 1 : 10);
                                                    return "+" + step + " " + (itemData.unit || "g");
                                                }
                                                onClicked: {
                                                    let cur = itemData.amount || 100;
                                                    let step = cur < 1 ? 0.25 : (cur < 10 ? 1 : 10);
                                                    let next = Math.round((cur + step) * 100) / 100;
                                                    if (mealPlanManager) mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                }
                                            }

                                            // Increment serving
                                            RoundButton {
                                                id: widePlusServingBtn
                                                visible: itemRow.servSize > 0
                                                text: "+" + itemRow.servSize
                                                padding: 0
                                                leftPadding: 4
                                                rightPadding: 4
                                                Layout.preferredWidth: visible ? (itemRow.servSize >= 100 ? 44 : 38) : 0
                                                Layout.preferredHeight: 28
                                                font.pixelSize: 10
                                                font.bold: true
                                                palette.buttonText: "#B45309"
                                                contentItem: Label {
                                                    text: widePlusServingBtn.text
                                                    font: widePlusServingBtn.font
                                                    color: "#B45309"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                background: Rectangle {
                                                    radius: 14
                                                    color: widePlusServingBtn.hovered ? "#FDE68A" : "#FEF3C7"
                                                    border.color: "#F59E0B"
                                                    border.width: 1
                                                }
                                                ToolTip.visible: hovered
                                                ToolTip.text: (langManager && langManager.currentLanguage === "de")
                                                    ? ("+1 Portion (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                    : ("+1 serving (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                onClicked: {
                                                    let cur = itemData.amount || 100;
                                                    let next = cur + itemRow.servSize;
                                                    if (mealPlanManager) mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                }
                                            }
                                        }

                                        // Item Calories badge
                                        Rectangle {
                                            radius: 6
                                            color: "#EFF6FF"
                                            height: 24
                                            width: calLblWide.implicitWidth + 12
                                            Label {
                                                id: calLblWide
                                                anchors.centerIn: parent
                                                text: Math.round(itemData.calories || 0) + " kcal"
                                                font.bold: true
                                                font.pixelSize: 10
                                                color: "#2563EB"
                                            }
                                        }

                                        // Delete item button
                                        RoundButton {
                                            text: "✕"
                                            flat: true
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 26
                                            Layout.preferredHeight: 26
                                            palette.buttonText: "#A8A29E"
                                            onClicked: {
                                                if (mealPlanManager) mealPlanManager.removeItemFromMeal(mealIndex, itemIndex);
                                            }
                                        }
                                    }

                                    // --- Narrow Layout (2 Rows: Row 1 = Name + Kcal + Delete, Row 2 = Macros + Stepper) ---
                                    ColumnLayout {
                                        id: itemColLayout
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        anchors.topMargin: 7
                                        anchors.bottomMargin: 7
                                        spacing: 5
                                        visible: itemRow.isNarrowItem

                                        // Row 1: Icon + Name + Calories + Delete
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Label {
                                                text: (itemData.icon && itemData.icon !== "🍽️" && itemData.icon !== "🍽")
                                                      ? String(itemData.icon).replace(/\uFE0F/g, "")
                                                      : "🥗"
                                                font.pixelSize: 15
                                            }

                                            Label {
                                                text: itemData.name || "Food Item"
                                                font.bold: true
                                                font.pixelSize: 12
                                                color: "#292524"
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                radius: 6
                                                color: "#EFF6FF"
                                                height: 22
                                                width: calLblNarrow.implicitWidth + 10
                                                Label {
                                                    id: calLblNarrow
                                                    anchors.centerIn: parent
                                                    text: Math.round(itemData.calories || 0) + " kcal"
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: "#2563EB"
                                                }
                                            }

                                            RoundButton {
                                                text: "✕"
                                                flat: true
                                                font.pixelSize: 12
                                                Layout.preferredWidth: 24
                                                Layout.preferredHeight: 24
                                                palette.buttonText: "#A8A29E"
                                                onClicked: {
                                                    if (mealPlanManager) mealPlanManager.removeItemFromMeal(mealIndex, itemIndex);
                                                }
                                            }
                                        }

                                        // Row 2: Macros breakdown (left) + Stepper (right)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Label {
                                                visible: root.width >= 350
                                                text: "C:" + Math.round(itemData.carbs || 0) + "g P:" + Math.round(itemData.protein || 0) + "g F:" + Math.round(itemData.fat || 0) + "g"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: "#78716C"
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Item {
                                                visible: root.width < 350
                                                Layout.fillWidth: true
                                            }

                                            // Narrow Stepper
                                            RowLayout {
                                                Layout.alignment: Qt.AlignRight
                                                spacing: 2

                                                // Decrement serving
                                                RoundButton {
                                                    id: narrowMinusServingBtn
                                                    visible: itemRow.servSize > 0
                                                    text: "−" + itemRow.servSize
                                                    padding: 0
                                                    leftPadding: 3
                                                    rightPadding: 3
                                                    Layout.preferredWidth: visible ? (itemRow.servSize >= 100 ? 40 : 34) : 0
                                                    Layout.preferredHeight: 26
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    palette.buttonText: "#B45309"
                                                    contentItem: Label {
                                                        text: narrowMinusServingBtn.text
                                                        font: narrowMinusServingBtn.font
                                                        color: "#B45309"
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                    background: Rectangle {
                                                        radius: 13
                                                        color: narrowMinusServingBtn.hovered ? "#FDE68A" : "#FEF3C7"
                                                        border.color: "#F59E0B"
                                                        border.width: 1
                                                    }
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: (langManager && langManager.currentLanguage === "de")
                                                        ? ("−1 Portion (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                        : ("−1 serving (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                    onClicked: {
                                                        let cur = itemData.amount || 100;
                                                        let next = cur - itemRow.servSize;
                                                        if (next <= 0) {
                                                            if (mealPlanManager) mealPlanManager.removeItemFromMeal(mealIndex, itemIndex);
                                                        } else {
                                                            if (mealPlanManager) mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                        }
                                                    }
                                                }

                                                // Decrement 10g
                                                RoundButton {
                                                    id: narrowMinusGramBtn
                                                    text: "−"
                                                    Layout.preferredWidth: 24
                                                    Layout.preferredHeight: 26
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    palette.buttonText: "#44403C"
                                                    background: Rectangle {
                                                        radius: 13
                                                        color: narrowMinusGramBtn.hovered ? "#E7E5E4" : "#F5F5F4"
                                                        border.color: "#D6D3D1"
                                                    }
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: {
                                                        let cur = itemData.amount || 100;
                                                        let step = cur > 10 ? 10 : (cur > 1 ? 1 : 0.25);
                                                        return "-" + step + " " + (itemData.unit || "g");
                                                    }
                                                    onClicked: {
                                                        let cur = itemData.amount || 100;
                                                        let step = cur > 10 ? 10 : (cur > 1 ? 1 : 0.25);
                                                        let next = Math.round((cur - step) * 100) / 100;
                                                        if (!mealPlanManager) return;
                                                        if (next <= 0.001) {
                                                            mealPlanManager.removeItemFromMeal(mealIndex, itemIndex);
                                                        } else {
                                                            mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                        }
                                                    }
                                                }

                                                // Amount field
                                                TextField {
                                                    text: itemData.amount || 100
                                                    Binding on text {
                                                        value: itemData.amount ? itemData.amount.toString() : "100"
                                                    }
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    color: "#1C1917"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    Layout.preferredWidth: 38
                                                    Layout.preferredHeight: 26
                                                    background: Rectangle { radius: 4; color: "#FFFFFF"; border.color: "#E7E5E4" }
                                                    onEditingFinished: {
                                                        let val = parseFloat(text);
                                                        if (!isNaN(val) && val > 0 && mealPlanManager) {
                                                            mealPlanManager.updateItemAmount(mealIndex, itemIndex, val);
                                                        }
                                                    }
                                                }

                                                // Unit
                                                Label {
                                                    text: itemData.unit || "g"
                                                    font.pixelSize: 10
                                                    color: "#78716C"
                                                    Layout.rightMargin: 2
                                                }

                                                // Increment 10g
                                                RoundButton {
                                                    id: narrowPlusGramBtn
                                                    text: "+"
                                                    Layout.preferredWidth: 24
                                                    Layout.preferredHeight: 26
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    palette.buttonText: "#44403C"
                                                    background: Rectangle {
                                                        radius: 13
                                                        color: narrowPlusGramBtn.hovered ? "#E7E5E4" : "#F5F5F4"
                                                        border.color: "#D6D3D1"
                                                    }
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: {
                                                        let cur = itemData.amount || 100;
                                                        let step = cur < 1 ? 0.25 : (cur < 10 ? 1 : 10);
                                                        return "+" + step + " " + (itemData.unit || "g");
                                                    }
                                                    onClicked: {
                                                        let cur = itemData.amount || 100;
                                                        let step = cur < 1 ? 0.25 : (cur < 10 ? 1 : 10);
                                                        let next = Math.round((cur + step) * 100) / 100;
                                                        if (mealPlanManager) mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                    }
                                                }

                                                // Increment serving
                                                RoundButton {
                                                    id: narrowPlusServingBtn
                                                    visible: itemRow.servSize > 0
                                                    text: "+" + itemRow.servSize
                                                    padding: 0
                                                    leftPadding: 3
                                                    rightPadding: 3
                                                    Layout.preferredWidth: visible ? (itemRow.servSize >= 100 ? 40 : 34) : 0
                                                    Layout.preferredHeight: 26
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    palette.buttonText: "#B45309"
                                                    contentItem: Label {
                                                        text: narrowPlusServingBtn.text
                                                        font: narrowPlusServingBtn.font
                                                        color: "#B45309"
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                    background: Rectangle {
                                                        radius: 13
                                                        color: narrowPlusServingBtn.hovered ? "#FDE68A" : "#FEF3C7"
                                                        border.color: "#F59E0B"
                                                        border.width: 1
                                                    }
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: (langManager && langManager.currentLanguage === "de")
                                                        ? ("+1 Portion (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                        : ("+1 serving (" + itemRow.servSize + (itemData.unit || "g") + ")")
                                                    onClicked: {
                                                        let cur = itemData.amount || 100;
                                                        let next = cur + itemRow.servSize;
                                                        if (mealPlanManager) mealPlanManager.updateItemAmount(mealIndex, itemIndex, next);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty items placeholder
                            Label {
                                visible: (!mealData.items || mealData.items.length === 0)
                                text: "No ingredients added yet. Type below to search or scan a barcode!"
                                font.italic: true
                                font.pixelSize: 12
                                color: "#A8A29E"
                                Layout.leftMargin: 4
                            }
                        }

                        // Add Ingredient Input Row with Autocomplete
                        RowLayout {
                            visible: !mealCard.isCollapsed
                            Layout.fillWidth: true
                            spacing: 8
                            z: 10

                            Item {
                                Layout.fillWidth: true
                                height: 36

                                TextField {
                                    id: ingredientInput
                                    anchors.fill: parent
                                    placeholderText: langManager ? langManager.t("add_ingredient") : "Type ingredient (e.g. Oats, Egg, Avocado)..."
                                    font.pixelSize: 12
                                    selectByMouse: true
                                    color: "#1C1917"
                                    background: Rectangle {
                                        radius: 8
                                        color: "#FAFAF9"
                                        border.color: ingredientInput.activeFocus ? "#D97706" : "#E7E5E4"
                                        border.width: ingredientInput.activeFocus ? 2 : 1
                                    }

                                    onTextChanged: {
                                        if (text.trim().length > 0 && foodDb) {
                                            autocompletePopup.model = foodDb.search(text.trim(), 8);
                                            autocompletePopup.open();
                                        } else {
                                            autocompletePopup.close();
                                        }
                                    }
                                }

                                // Autocomplete dropdown popup
                                Popup {
                                    id: autocompletePopup
                                    y: ingredientInput.height + 4
                                    width: ingredientInput.width
                                    height: Math.min(280, (model ? model.length : 0) * 46 + 10)
                                    padding: 4
                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                    property var model: []

                                    background: Rectangle {
                                        radius: 10
                                        color: "#FFFFFF"
                                        border.color: "#D97706"
                                        border.width: 1
                                    }

                                    contentItem: ListView {
                                        model: autocompletePopup.model
                                        clip: true
                                        delegate: Rectangle {
                                            width: autocompletePopup.width - 8
                                            height: (modelData && modelData.matchedInOtherLanguage) ? 46 : 38
                                            radius: 6
                                            color: itemArea.containsMouse ? "#FEF3C7" : "transparent"

                                            MouseArea {
                                                id: itemArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    if (mealPlanManager) {
                                                        let serving = modelData.servingSize || 100;
                                                        mealPlanManager.addItemToMeal(mealIndex, modelData, serving);
                                                        ingredientInput.text = "";
                                                        autocompletePopup.close();
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                Label {
                                                    text: (modelData.icon && modelData.icon !== "🍽️" && modelData.icon !== "🍽")
                                                          ? String(modelData.icon).replace(/\uFE0F/g, "")
                                                          : "🥗"
                                                    font.pixelSize: 16
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 0

                                                    Label {
                                                        text: modelData.name || ""
                                                        font.bold: true
                                                        font.pixelSize: 12
                                                        color: "#1C1917"
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Label {
                                                        visible: Boolean(modelData.matchedInOtherLanguage)
                                                        text: modelData.matchedInOtherLanguage ? (langManager ? langManager.t("matched_in", [modelData.matchedLanguage, modelData.matchedText]) : ("Matched " + modelData.matchedLanguage + ": \"" + modelData.matchedText + "\"")) : ""
                                                        font.pixelSize: 9
                                                        color: "#D97706"
                                                        font.italic: true
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Label {
                                                    text: modelData.calories + " kcal / 100g"
                                                    font.pixelSize: 11
                                                    color: "#D97706"
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Scan Barcode Button
                            Button {
                                text: mealCard.isNarrowCard ? "📷" : (langManager ? langManager.t("scan_barcode") : "📷 Barcode / OFF")
                                font.pixelSize: 11
                                font.bold: true
                                Layout.preferredHeight: 36
                                Layout.preferredWidth: mealCard.isNarrowCard ? 38 : -1
                                palette.buttonText: "#78350F"
                                background: Rectangle {
                                    radius: 8
                                    color: "#FEF3C7"
                                    border.color: "#FDE68A"
                                }
                                ToolTip.visible: hovered
                                ToolTip.text: langManager ? langManager.t("scan_barcode") : "Scan Barcode / Open Food Facts"
                                onClicked: root.scanBarcodeRequested(mealIndex)
                            }
                        }
                    }
                }
            }

            // Bottom Add Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    text: langManager ? langManager.t("add_meal") : "➕ Add Meal"
                    font.bold: true
                    font.pixelSize: 13
                    palette.buttonText: "#44403C"
                    background: Rectangle {
                        radius: 10
                        color: "#F5F5F4"
                        border.color: "#E7E5E4"
                        border.width: 1
                    }
                    onClicked: customMealDialog.open()
                }

                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    text: "🏃 " + (langManager ? langManager.t("add_workout") : "Add Workout")
                    font.bold: true
                    font.pixelSize: 13
                    palette.buttonText: "#9A3412"
                    background: Rectangle {
                        radius: 10
                        color: "#FFEDD5"
                        border.color: "#FDBA74"
                        border.width: 1
                    }
                    onClicked: root.addWorkoutRequested()
                }
            }
        }
    }

    // Custom Meal Creation Dialog
    Dialog {
        id: customMealDialog
        title: "Add Custom Meal"
        anchors.centerIn: parent
        modal: true
        width: Math.min(380, parent.width - 24)

        background: Rectangle {
            radius: 12
            color: "#FFFDF9"
            border.color: "#E5DEC9"
        }

        ColumnLayout {
            spacing: 12
            anchors.fill: parent

            TextField {
                id: customMealName
                Layout.fillWidth: true
                placeholderText: "Meal Name (e.g. Post-Workout Snack)..."
                font.pixelSize: 13
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Time:" }
                TextField {
                    id: customMealTime
                    text: "15:00"
                    Layout.fillWidth: true
                    font.pixelSize: 13
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: customMealDialog.close()
                }
                Button {
                    text: "Add Meal"
                    font.bold: true
                    Layout.fillWidth: true
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle { radius: 6; color: "#D97706" }
                    onClicked: {
                        if (mealPlanManager && customMealName.text.trim().length > 0) {
                            mealPlanManager.addMeal(customMealName.text.trim(), customMealTime.text.trim(), "🍽️", "#3B82F6");
                            customMealName.text = "";
                            customMealDialog.close();
                        }
                    }
                }
            }
        }
    }

    // --- Confirmation Dialog for Clear Plan ---
    Dialog {
        id: clearConfirmDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, (Overlay.overlay ? Overlay.overlay.width : 400) - 24)
        padding: 20
        background: Rectangle {
            color: "#FFFFFF"
            radius: 16
            border.color: "#E5E7EB"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 14

            RowLayout {
                spacing: 10
                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: "#FEE2E2"
                    Label {
                        anchors.centerIn: parent
                        text: "🗑️"
                        font.pixelSize: 18
                    }
                }
                Label {
                    text: langManager ? langManager.t("clear_plan_title") : "Clear Meal Plan?"
                    font.bold: true
                    font.pixelSize: 16
                    color: "#991B1B"
                    Layout.fillWidth: true
                }
            }

            Label {
                text: langManager ? langManager.t("clear_plan_confirm") : "Are you sure you want to clear all meals and ingredients? Your current meal plan will be removed. This cannot be undone."
                font.pixelSize: 13
                color: "#4B5563"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.topMargin: 6

                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("cancel_btn") : "Cancel"
                    onClicked: clearConfirmDialog.close()
                }

                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("clear_plan_btn") : "Clear Plan"
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle {
                        radius: 6
                        color: "#DC2626"
                    }
                    onClicked: {
                        clearConfirmDialog.close();
                        if (mealPlanManager) mealPlanManager.clearPlan();
                    }
                }
            }
        }
    }

    // --- Confirmation Dialog for Reset Sample Plan ---
    Dialog {
        id: resetConfirmDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, (Overlay.overlay ? Overlay.overlay.width : 400) - 24)
        padding: 20
        background: Rectangle {
            color: "#FFFFFF"
            radius: 16
            border.color: "#E5E7EB"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 14

            RowLayout {
                spacing: 10
                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: "#FEF3C7"
                    Label {
                        anchors.centerIn: parent
                        text: "✨"
                        font.pixelSize: 18
                    }
                }
                Label {
                    text: langManager ? langManager.t("reset_sample_title") : "Reset to Sample Plan?"
                    font.bold: true
                    font.pixelSize: 16
                    color: "#92400E"
                    Layout.fillWidth: true
                }
            }

            Label {
                text: langManager ? langManager.t("reset_sample_confirm") : "Are you sure you want to replace your current meal plan with the default sample meals?"
                font.pixelSize: 13
                color: "#4B5563"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.topMargin: 6

                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("cancel_btn") : "Cancel"
                    onClicked: resetConfirmDialog.close()
                }

                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("reset_sample_btn") : "Reset Plan"
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle {
                        radius: 6
                        color: "#D97706"
                    }
                    onClicked: {
                        resetConfirmDialog.close();
                        if (mealPlanManager) mealPlanManager.loadSamplePlan();
                    }
                }
            }
        }
    }

    // --- Confirmation Dialog for Cheat / Ideal Plan ---
    Dialog {
        id: cheatConfirmDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(420, (Overlay.overlay ? Overlay.overlay.width : 440) - 24)
        padding: 20
        background: Rectangle {
            color: "#FFFFFF"
            radius: 16
            border.color: "#FED7AA"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 14

            RowLayout {
                spacing: 10
                Rectangle {
                    width: 36
                    height: 36
                    radius: 10
                    color: "#FFEDD5"
                    Label {
                        anchors.centerIn: parent
                        text: "👑"
                        font.pixelSize: 18
                    }
                }
                Label {
                    text: langManager ? langManager.t("cheat_button_title") : "Grandmaster Cheat"
                    font.bold: true
                    font.pixelSize: 16
                    color: "#9A3412"
                    Layout.fillWidth: true
                }
            }

            Label {
                text: langManager ? langManager.t("cheat_button_confirm") : "Load the mathematically verified ideal day plan and unlock/solve all 24 levels with 3 stars?"
                font.pixelSize: 13
                color: "#4B5563"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.topMargin: 6

                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("cancel_btn") : "Cancel"
                    onClicked: cheatConfirmDialog.close()
                }

                Button {
                    Layout.fillWidth: true
                    text: "👑 " + (langManager ? langManager.t("cheat_btn_action") : "Load & Solve All")
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle {
                        radius: 6
                        color: "#EA580C"
                    }
                    onClicked: {
                        cheatConfirmDialog.close();
                        if (gameLevelManager && mealPlanManager) {
                            gameLevelManager.cheatSolveAll(mealPlanManager, foodDatabase);
                        }
                    }
                }
            }
        }
    }

    // Save Meal as Custom Template Dialog
    Dialog {
        id: saveCustomTemplateDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(420, root.width - 20)
        title: langManager ? langManager.t("save_as_template_btn") : "Save as Custom Meal"

        property int targetMealIndex: -1
        property string initialName: ""

        function openDialog() {
            templateNameInput.text = initialName;
            saveCustomTemplateDialog.open();
        }

        contentItem: ColumnLayout {
            spacing: 12

            Label {
                text: "Save this meal with all its ingredients and portion sizes into your personal recipe library:"
                font.pixelSize: 12
                color: "#57534E"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            TextField {
                id: templateNameInput
                Layout.fillWidth: true
                placeholderText: langManager ? langManager.t("template_name_placeholder") : "Meal name (e.g. My Power Breakfast)..."
                font.pixelSize: 13
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: "#FFFFFF"
                    border.color: templateNameInput.activeFocus ? "#10B981" : "#D6D3D1"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Layout.topMargin: 4

                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("cancel_btn") : "Cancel"
                    onClicked: saveCustomTemplateDialog.close()
                }

                Button {
                    Layout.fillWidth: true
                    text: "💾 Save"
                    font.bold: true
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle {
                        radius: 8
                        color: "#10B981"
                    }
                    onClicked: {
                        if (recipeManager && mealPlanManager && saveCustomTemplateDialog.targetMealIndex >= 0) {
                            recipeManager.saveMealAsTemplate(saveCustomTemplateDialog.targetMealIndex, templateNameInput.text, mealPlanManager);
                            saveCustomTemplateDialog.close();
                            toastBanner.show("✨ Meal saved to your custom library!");
                        }
                    }
                }
            }
        }
    }

    // Floating Toast Notification Banner
    Rectangle {
        id: toastBanner
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        height: 38
        width: toastText.implicitWidth + 30
        radius: 19
        color: "#1E293B"
        opacity: 0.0
        visible: opacity > 0.0
        z: 999

        property string message: ""

        function show(msg) {
            message = msg;
            toastAnim.restart();
        }

        Label {
            id: toastText
            anchors.centerIn: parent
            text: toastBanner.message
            color: "#FFFFFF"
            font.bold: true
            font.pixelSize: 12
        }

        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toastBanner; property: "opacity"; to: 0.95; duration: 200 }
            PauseAnimation { duration: 2500 }
            NumberAnimation { target: toastBanner; property: "opacity"; to: 0.0; duration: 300 }
        }
    }
}
