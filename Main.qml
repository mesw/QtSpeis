import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtSpeis

Window {
    id: window
    width: 1100
    height: 800
    minimumWidth: 320
    minimumHeight: 480
    visible: true
    title: langManager.t("app_title")
    color: "#FDFBF7"

    readonly property bool isMobile: width < 768
    property int mobilePlannerSubTab: 0 // 0 = Meals, 1 = Goal & Grade

    LanguageManager {
        id: langManager
        onLanguageChanged: (lang) => {
            foodDb.currentLanguage = lang;
            mealPlanManager.updateLanguage(lang, foodDb);
            if (savegameManager) {
                savegameManager.autoSave(mealPlanManager, gameLevelManager, lang);
            }
        }
    }

    // --- Backend Managers & Models ---
    FoodDatabase {
        id: foodDb
    }

    MealPlanManager {
        id: mealPlanManager
        onPlanChanged: {
            mealPlanManager.syncToDayPlanModel(dayPlanModel);
            if (savegameManager) {
                savegameManager.autoSave(mealPlanManager, gameLevelManager, langManager.currentLanguage);
            }
        }
    }

    GameLevelManager {
        id: gameLevelManager
        onCurrentLevelChanged: {
            if (savegameManager) {
                savegameManager.autoSave(mealPlanManager, gameLevelManager, langManager.currentLanguage);
            }
        }
        onLevelsChanged: {
            if (savegameManager) {
                savegameManager.autoSave(mealPlanManager, gameLevelManager, langManager.currentLanguage);
            }
        }
    }

    DayPlanModel {
        id: dayPlanModel
    }

    SavegameManager {
        id: savegameManager
    }

    RecipeManager {
        id: recipeManager
    }

    Component.onCompleted: {
        let loaded = savegameManager.autoLoad(mealPlanManager, gameLevelManager, langManager);
        if (!loaded) {
            mealPlanManager.loadEmptyPlan();
        }
        foodDb.currentLanguage = langManager.currentLanguage;
        mealPlanManager.updateLanguage(langManager.currentLanguage, foodDb);
        mealPlanManager.syncToDayPlanModel(dayPlanModel);

        if (gameLevelManager && !gameLevelManager.isOnboardingCompleted()) {
            onboardingDialog.open();
        }
    }

    // --- Main Layout ---
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: isMobile ? 8 : 16
        spacing: isMobile ? 8 : 12

        // Top Header Bar
        Rectangle {
            Layout.fillWidth: true
            height: isMobile ? 52 : 56
            radius: 14
            color: "#FFFFFF"
            border.color: "#E7E5E4"
            border.width: 1

            // --- Desktop Single Row Layout ---
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                visible: !isMobile

                // App Branding
                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 10
                        color: "#FEF3C7"
                        Label {
                            anchors.centerIn: parent
                            text: "🥗"
                            font.pixelSize: 20
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        Label {
                            text: "Speis"
                            font.bold: true
                            font.pixelSize: 17
                            color: "#1C1917"
                        }
                        Label {
                            text: "Nutrition Quest"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#D97706"
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 28
                    color: "#E7E5E4"
                }

                // Level Button: Clicking toggles between Planner and Levels screen
                Rectangle {
                    implicitHeight: 34
                    Layout.preferredHeight: 34
                    radius: 8
                    color: (viewStack.currentIndex === 1) ? "#D97706" : (levelHover.containsMouse ? "#FEF3C7" : "#F5F5F4")
                    border.color: (viewStack.currentIndex === 1) ? "#B45309" : (levelHover.containsMouse ? "#D97706" : "#E7E5E4")
                    implicitWidth: levelRow.implicitWidth + 20
                    Layout.preferredWidth: implicitWidth

                    MouseArea {
                        id: levelHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            viewStack.currentIndex = (viewStack.currentIndex === 1) ? 0 : 1;
                        }
                    }

                    RowLayout {
                        id: levelRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label {
                            text: (viewStack.currentIndex === 1)
                                ? "← " + (langManager ? langManager.t("tab_planner") : "Meal Planner")
                                : ("🏆 " + (gameLevelManager ? gameLevelManager.currentLevelData.title : "Level 1"))
                            font.bold: true
                            font.pixelSize: 12
                            color: (viewStack.currentIndex === 1) ? "#FFFFFF" : "#292524"
                        }
                        Label {
                            visible: viewStack.currentIndex !== 1
                            text: "▾"
                            font.pixelSize: 11
                            color: "#78716C"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // User Profile Button
                Rectangle {
                    implicitHeight: 36
                    Layout.preferredHeight: 36
                    radius: 8
                    color: profHover.containsMouse ? "#EFF6FF" : "#F5F5F4"
                    border.color: profHover.containsMouse ? "#3B82F6" : "#E7E5E4"
                    implicitWidth: profBtnRow.implicitWidth + 16
                    Layout.preferredWidth: implicitWidth

                    MouseArea {
                        id: profHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: profileDialog.open()
                    }

                    RowLayout {
                        id: profBtnRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label { text: "👤"; font.pixelSize: 13 }
                        Label {
                            text: (mealPlanManager ? mealPlanManager.userName : "Profile") + " (" + Math.round(mealPlanManager ? mealPlanManager.targetCalories : 2000) + " kcal)"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#1D4ED8"
                        }
                    }
                }

                // Ingredient Explorer Button
                Rectangle {
                    implicitHeight: 36
                    Layout.preferredHeight: 36
                    radius: 8
                    color: ingrHover.containsMouse ? "#FEF3C7" : "#F5F5F4"
                    border.color: ingrHover.containsMouse ? "#F59E0B" : "#E7E5E4"
                    implicitWidth: ingrBtnRow.implicitWidth + 16
                    Layout.preferredWidth: implicitWidth

                    MouseArea {
                        id: ingrHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ingredientExplorerDialog.open()
                    }

                    RowLayout {
                        id: ingrBtnRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label { text: "🔬"; font.pixelSize: 13 }
                        Label {
                            text: langManager ? langManager.t("ingredient_explorer") : "Ingredient Explorer"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#B45309"
                        }
                    }
                }

                // Savegame Dialog Button
                Rectangle {
                    implicitHeight: 36
                    Layout.preferredHeight: 36
                    radius: 8
                    color: saveHover.containsMouse ? "#DCFCE7" : "#F5F5F4"
                    border.color: saveHover.containsMouse ? "#86EFAC" : "#E7E5E4"
                    implicitWidth: saveBtnRow.implicitWidth + 16
                    Layout.preferredWidth: implicitWidth

                    MouseArea {
                        id: saveHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: saveDialog.open()
                    }

                    RowLayout {
                        id: saveBtnRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label { text: "💾"; font.pixelSize: 13 }
                        Label {
                            text: langManager ? langManager.t("save_game") : "Save / Export"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#15803D"
                        }
                    }
                }

                // About & Legal Dialog Button
                Rectangle {
                    implicitHeight: 36
                    Layout.preferredHeight: 36
                    radius: 8
                    color: legalHover.containsMouse ? "#FEF3C7" : "#F5F5F4"
                    border.color: legalHover.containsMouse ? "#D97706" : "#E7E5E4"
                    implicitWidth: legalBtnRow.implicitWidth + 16
                    Layout.preferredWidth: implicitWidth

                    MouseArea {
                        id: legalHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aboutLegalDialog.open()
                    }

                    RowLayout {
                        id: legalBtnRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label { text: "⚖️"; font.pixelSize: 13 }
                        Label {
                            text: langManager ? langManager.t("about_legal_btn") : "Legal & Privacy"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#92400E"
                        }
                    }
                }

                // Guide & Onboarding Button
                Rectangle {
                    implicitHeight: 36
                    Layout.preferredHeight: 36
                    radius: 8
                    color: guideHover.containsMouse ? "#EFF6FF" : "#F5F5F4"
                    border.color: guideHover.containsMouse ? "#93C5FD" : "#E7E5E4"
                    implicitWidth: guideBtnRow.implicitWidth + 16
                    Layout.preferredWidth: implicitWidth

                    MouseArea {
                        id: guideHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: onboardingDialog.open()
                    }

                    RowLayout {
                        id: guideBtnRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label { text: "❓"; font.pixelSize: 13 }
                        Label {
                            text: (langManager && langManager.currentLanguage === "de") ? "Einführung" : "Guide"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#1E40AF"
                        }
                    }
                }

                // Grade / Finish Plan Button
                Button {
                    id: headerGradeBtn
                    text: "⭐ " + (langManager ? langManager.t("btn_evaluate").replace(/&/g, "&&") : "Finish && Grade Meal Plan")
                    font.bold: true
                    font.pixelSize: 12
                    palette.buttonText: "#FFFFFF"
                    Layout.preferredHeight: 36
                    background: Rectangle {
                        radius: 8
                        color: "#D97706"
                    }
                    onClicked: evaluateCurrentPlan()
                }
            }

            // --- Mobile Single Row Header with Integrated Sub-Tabs ---
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6
                visible: isMobile

                // Speis icon & label
                Label {
                    text: "🥗"
                    font.pixelSize: 18
                }

                // Level Button: Click to open Levels, or click to go back to Plan
                Rectangle {
                    height: 32
                    radius: 8
                    color: (viewStack.currentIndex === 1) ? "#D97706" : "#FEF3C7"
                    border.color: (viewStack.currentIndex === 1) ? "#B45309" : "#FDE68A"
                    width: mobLvlLbl.implicitWidth + 14

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            viewStack.currentIndex = (viewStack.currentIndex === 1) ? 0 : 1;
                        }
                    }

                    Label {
                        id: mobLvlLbl
                        anchors.centerIn: parent
                        text: (viewStack.currentIndex === 1) ? "← Plan" : ("🏆 L" + (gameLevelManager ? gameLevelManager.currentLevel : 1))
                        font.bold: true
                        font.pixelSize: 11
                        color: (viewStack.currentIndex === 1) ? "#FFFFFF" : "#B45309"
                    }
                }

                // Sub-tabs: Meal Plan vs Target & Grade (Only shown in Planner view)
                Rectangle {
                    visible: viewStack.currentIndex === 0
                    Layout.fillWidth: true
                    height: 32
                    radius: 8
                    color: "#F5F5F4"
                    border.color: "#E7E5E4"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 2

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            color: mobilePlannerSubTab === 0 ? "#FFFFFF" : "transparent"
                            border.color: mobilePlannerSubTab === 0 ? "#E2D9C8" : "transparent"
                            Button {
                                id: planSubTabBtn
                                anchors.fill: parent
                                text: window.width < 500
                                    ? "🍱"
                                    : ("🍱 " + (langManager ? langManager.t("mobile_plan_tab") : "Meal Plan"))
                                flat: true
                                font.pixelSize: window.width < 500 ? 14 : 11
                                font.bold: mobilePlannerSubTab === 0
                                palette.buttonText: mobilePlannerSubTab === 0 ? "#D97706" : "#57534E"
                                ToolTip.visible: hovered
                                ToolTip.delay: 300
                                ToolTip.text: langManager ? langManager.t("mobile_plan_tab") : "Meal Plan"
                                onClicked: mobilePlannerSubTab = 0
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            color: mobilePlannerSubTab === 1 ? "#FFFFFF" : "transparent"
                            border.color: mobilePlannerSubTab === 1 ? "#E2D9C8" : "transparent"
                            Button {
                                id: goalSubTabBtn
                                anchors.fill: parent
                                text: window.width < 500
                                    ? "🎯"
                                    : ("🎯 " + (langManager ? langManager.t("mobile_goal_tab").replace(/&/g, "&&") : "Target && Grade"))
                                flat: true
                                font.pixelSize: window.width < 500 ? 14 : 11
                                font.bold: mobilePlannerSubTab === 1
                                palette.buttonText: mobilePlannerSubTab === 1 ? "#D97706" : "#57534E"
                                ToolTip.visible: hovered
                                ToolTip.delay: 300
                                ToolTip.text: langManager ? langManager.t("mobile_goal_tab") : "Target & Grade"
                                onClicked: mobilePlannerSubTab = 1
                            }
                        }
                    }
                }

                Item {
                    visible: viewStack.currentIndex !== 0
                    Layout.fillWidth: true
                }

                // Mobile Ingredient Explorer button
                RoundButton {
                    text: "🔬"
                    font.pixelSize: 13
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    palette.buttonText: "#B45309"
                    background: Rectangle { radius: 16; color: "#FEF3C7"; border.color: "#FDE68A" }
                    onClicked: ingredientExplorerDialog.open()
                }

                // Mobile User Profile button
                RoundButton {
                    text: "👤"
                    font.pixelSize: 13
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    palette.buttonText: "#1D4ED8"
                    background: Rectangle { radius: 16; color: "#EFF6FF"; border.color: "#BFDBFE" }
                    onClicked: profileDialog.open()
                }

                // Mobile Save button
                RoundButton {
                    text: "💾"
                    font.pixelSize: 13
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    palette.buttonText: "#15803D"
                    background: Rectangle { radius: 16; color: "#DCFCE7"; border.color: "#86EFAC" }
                    onClicked: saveDialog.open()
                }

                // Mobile About & Legal button
                RoundButton {
                    text: "⚖️"
                    font.pixelSize: 13
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    palette.buttonText: "#92400E"
                    background: Rectangle { radius: 16; color: "#FEF3C7"; border.color: "#FDE68A" }
                    onClicked: aboutLegalDialog.open()
                }
            }
        }

        // View Stack
        StackLayout {
            id: viewStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            // --- View 0: Cozy Shopping List & Planner ---
            Item {
                // Desktop side-by-side view
                RowLayout {
                    anchors.fill: parent
                    spacing: 14
                    visible: !isMobile

                    CozyShoppingList {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        mealPlanManager: mealPlanManager
                        foodDb: foodDb
                        gameLevelManager: gameLevelManager
                        langManager: langManager
                        recipeManager: recipeManager
                        onLevelSelectRequested: viewStack.currentIndex = 1
                        onScanBarcodeRequested: (mealIndex) => {
                            barcodeDialog.targetMealIndex = mealIndex;
                            barcodeDialog.open();
                        }
                        onAddWorkoutRequested: workoutDialog.openForAdd()
                        onEditWorkoutRequested: (mealIndex) => workoutDialog.openForEdit(mealIndex)
                        onOpenRecipeLibraryRequested: (category) => recipeLibraryDialog.openWithCategory(category)
                        onOpenWorkoutLibraryRequested: () => workoutLibraryDialog.open()
                        onOpenIngredientExplorerRequested: () => ingredientExplorerDialog.open()
                        onBrowseMealRequested: (mealIndex) => ingredientExplorerDialog.openForMeal(mealIndex)
                    }

                    GoalSummaryCard {
                        Layout.preferredWidth: 350
                        Layout.fillHeight: true
                        mealPlanManager: mealPlanManager
                        gameLevelManager: gameLevelManager
                        langManager: langManager
                        onEvaluateRequested: evaluateCurrentPlan()
                        onProfileRequested: profileDialog.open()
                        onOpenSortedExplorerRequested: (nutrientKey) => ingredientExplorerDialog.openWithSort(nutrientKey)
                    }
                }

                // Mobile responsive view (Sub-tab navigation handled in header)
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    visible: isMobile

                    // Content Stack for Mobile Planner
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: mobilePlannerSubTab

                        // 0: Meals Shopping List
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 6

                                CozyShoppingList {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    mealPlanManager: mealPlanManager
                                    foodDb: foodDb
                                    gameLevelManager: gameLevelManager
                                    langManager: langManager
                                    recipeManager: recipeManager
                                    onLevelSelectRequested: viewStack.currentIndex = 1
                                    onScanBarcodeRequested: (mealIndex) => {
                                        barcodeDialog.targetMealIndex = mealIndex;
                                        barcodeDialog.open();
                                    }
                                    onAddWorkoutRequested: workoutDialog.openForAdd()
                                    onEditWorkoutRequested: (mealIndex) => workoutDialog.openForEdit(mealIndex)
                                    onOpenRecipeLibraryRequested: (category) => recipeLibraryDialog.openWithCategory(category)
                                    onOpenWorkoutLibraryRequested: () => workoutLibraryDialog.open()
                                    onOpenIngredientExplorerRequested: () => ingredientExplorerDialog.open()
                                    onBrowseMealRequested: (mealIndex) => ingredientExplorerDialog.openForMeal(mealIndex)
                                }

                                // Sticky Bottom Summary Pill on Mobile
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 44
                                    radius: 10
                                    color: "#FFFFFF"
                                    border.color: "#E2D9C8"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8

                                        Label {
                                            property real tgt: (gameLevelManager && gameLevelManager.currentLevel === 1)
                                                ? (mealPlanManager ? mealPlanManager.targetCalories : 2000)
                                                : (gameLevelManager ? (gameLevelManager.currentLevelData.targetCalories || 2000) : 2000)
                                            text: "🔥 " + Math.round(mealPlanManager.totalCalories) + " / " + Math.round(tgt) + " kcal"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#1C1917"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Button {
                                            text: "🎯 Goals"
                                            font.pixelSize: 10
                                            font.bold: true
                                            Layout.preferredHeight: 30
                                            onClicked: mobilePlannerSubTab = 1
                                        }

                                        Button {
                                            text: "⭐ Grade"
                                            font.bold: true
                                            font.pixelSize: 10
                                            Layout.preferredHeight: 30
                                            palette.buttonText: "#FFFFFF"
                                            background: Rectangle { radius: 6; color: "#D97706" }
                                            onClicked: evaluateCurrentPlan()
                                        }
                                    }
                                }
                            }
                        }

                        // 1: Goal & Progress Card
                        Item {
                            GoalSummaryCard {
                                anchors.fill: parent
                                mealPlanManager: mealPlanManager
                                gameLevelManager: gameLevelManager
                                langManager: langManager
                                onEvaluateRequested: evaluateCurrentPlan()
                                onProfileRequested: profileDialog.open()
                            }
                        }
                    }
                }
            }

            // --- View 1: Level Select ---
            LevelSelectView {
                gameLevelManager: gameLevelManager
                mealPlanManager: mealPlanManager
                foodDatabase: foodDb
                langManager: langManager
                onLevelSelected: (lvlId) => {
                    viewStack.currentIndex = 0;
                }
                onCloseRequested: {
                    viewStack.currentIndex = 0;
                }
            }
        }
    }

    // --- Helper to trigger plan evaluation ---
    function evaluateCurrentPlan() {
        if (gameLevelManager && mealPlanManager) {
            let res = gameLevelManager.evaluatePlan(mealPlanManager);
            evalDialog.resultData = res;
            evalDialog.open();
        }
    }

    // --- Dialogs ---
    BarcodeLookupDialog {
        id: barcodeDialog
        mealPlanManager: mealPlanManager
        foodDb: foodDb
    }

    EvaluationResultDialog {
        id: evalDialog
        gameLevelManager: gameLevelManager
        mealPlanManager: mealPlanManager
        langManager: langManager
        onLevelSelectRequested: viewStack.currentIndex = 1
    }

    SavegameDialog {
        id: saveDialog
        savegameManager: savegameManager
        mealPlanManager: mealPlanManager
        gameLevelManager: gameLevelManager
        langManager: langManager
    }

    UserProfileDialog {
        id: profileDialog
        mealPlanManager: mealPlanManager
        gameLevelManager: gameLevelManager
        langManager: langManager
    }

    IngredientExplorerDialog {
        id: ingredientExplorerDialog
        foodDatabase: foodDb
        mealPlanManager: mealPlanManager
        langManager: langManager
    }

    WorkoutDialog {
        id: workoutDialog
        mealPlanManager: mealPlanManager
        langManager: langManager
    }

    RecipeLibraryDialog {
        id: recipeLibraryDialog
        recipeManager: recipeManager
        mealPlanManager: mealPlanManager
        langManager: langManager
    }

    WorkoutLibraryDialog {
        id: workoutLibraryDialog
        recipeManager: recipeManager
        mealPlanManager: mealPlanManager
        langManager: langManager
        onCustomizeRequested: (type, time, duration, calories, carbs, protein, fat) => {
            workoutDialog.openWithCustomValues(type, time, duration, calories, carbs, protein, fat);
        }
    }

    AboutLegalDialog {
        id: aboutLegalDialog
        langManager: langManager
    }

    OnboardingDialog {
        id: onboardingDialog
        gameLevelManager: gameLevelManager
        langManager: langManager
        onCustomizeProfileRequested: profileDialog.open()
    }
}
