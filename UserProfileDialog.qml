import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(500, (parent ? parent.width : 500) - 16)
    height: Math.min(680, (parent ? parent.height : 680) - 20)
    padding: 0

    property var mealPlanManager: null
    property var gameLevelManager: null
    property var langManager: null

    readonly property bool isNarrow: root.width < 420

    // Local form state
    property string formName: ""
    property real formBaseCalories: 2000
    property int formAge: 30
    property real formWeight: 75.0
    property real formHeight: 178.0
    property string formSex: "male"
    property string formSport: "endurance_power"
    property string pendingLanguage: ""

    function initFromManager() {
        if (!mealPlanManager) return;
        formName = mealPlanManager.userName;
        formBaseCalories = mealPlanManager.baseCalories;
        formAge = mealPlanManager.userAge;
        formWeight = mealPlanManager.userWeight;
        formHeight = mealPlanManager.userHeight;
        formSex = mealPlanManager.userSex;
        formSport = mealPlanManager.userSport || "endurance_power";
    }

    onAboutToShow: {
        initFromManager();
    }

    // Mifflin-St Jeor estimate calculation
    readonly property real liveEstimatedBmr: {
        if (!mealPlanManager) return 2000;
        return mealPlanManager.calculateEstimatedBmr(formWeight, formHeight, formAge, formSex);
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

        // Dialog Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 36
                height: 36
                radius: 10
                color: "#EFF6FF"
                border.color: "#BFDBFE"
                Label {
                    anchors.centerIn: parent
                    text: "👤"
                    font.pixelSize: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: langManager ? langManager.t("user_profile_title") : "User Profile & Metabolism"
                    font.bold: true
                    font.pixelSize: root.isNarrow ? 13 : 15
                    color: "#1C1917"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: "Personalize your resting energy needs (Grundumsatz)"
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

        // Scrollable Body
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width - 6
                spacing: 14

                // Name Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    implicitHeight: nameCol.implicitHeight + 24

                    ColumnLayout {
                        id: nameCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 6

                        Label {
                            text: "👤 " + (langManager ? langManager.t("user_name") : "Name / Nickname")
                            font.bold: true
                            font.pixelSize: 12
                            color: "#44403C"
                        }

                        TextField {
                            id: nameField
                            Layout.fillWidth: true
                            text: root.formName
                            placeholderText: "e.g. Alex, Runner99"
                            font.pixelSize: 13
                            background: Rectangle {
                                radius: 8
                                color: "#FAFAF9"
                                border.color: nameField.activeFocus ? "#3B82F6" : "#E2D9C8"
                            }
                            onTextChanged: root.formName = text
                        }
                    }
                }

                // Base Calorie Need (Grundumsatz) Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    implicitHeight: baseCol.implicitHeight + 24

                    ColumnLayout {
                        id: baseCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "🔥 " + (langManager ? langManager.t("base_calories") : "Base Calorie Need (BMR)")
                                font.bold: true
                                font.pixelSize: 12
                                color: "#44403C"
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: Math.round(root.formBaseCalories) + " kcal"
                                font.bold: true
                                font.pixelSize: 14
                                color: "#D97706"
                            }
                        }

                        Label {
                            text: langManager ? langManager.t("base_calories_hint") : "Daily resting energy expenditure without exercise"
                            font.pixelSize: 10
                            color: "#78716C"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Calorie input and quick-step buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            TextField {
                                id: baseCalField
                                Layout.fillWidth: true
                                text: Math.round(root.formBaseCalories).toString()
                                validator: IntValidator { bottom: 800; top: 6000 }
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: TextInput.AlignHCenter
                                background: Rectangle {
                                    radius: 8
                                    color: "#FAFAF9"
                                    border.color: baseCalField.activeFocus ? "#D97706" : "#E2D9C8"
                                }
                                onEditingFinished: {
                                    let v = parseInt(text);
                                    if (!isNaN(v) && v >= 800 && v <= 6000) {
                                        root.formBaseCalories = v;
                                    } else {
                                        text = Math.round(root.formBaseCalories).toString();
                                    }
                                }
                            }

                            Button {
                                text: "-100"
                                font.pixelSize: 11
                                Layout.preferredHeight: 36
                                background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E2D9C8" }
                                onClicked: root.formBaseCalories = Math.max(800, root.formBaseCalories - 100)
                            }
                            Button {
                                text: "-50"
                                font.pixelSize: 11
                                Layout.preferredHeight: 36
                                background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E2D9C8" }
                                onClicked: root.formBaseCalories = Math.max(800, root.formBaseCalories - 50)
                            }
                            Button {
                                text: "+50"
                                font.pixelSize: 11
                                Layout.preferredHeight: 36
                                background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E2D9C8" }
                                onClicked: root.formBaseCalories = Math.min(6000, root.formBaseCalories + 50)
                            }
                            Button {
                                text: "+100"
                                font.pixelSize: 11
                                Layout.preferredHeight: 36
                                background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E2D9C8" }
                                onClicked: root.formBaseCalories = Math.min(6000, root.formBaseCalories + 100)
                            }
                        }
                    }
                }

                // BMR Estimator Card (Mifflin-St Jeor)
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#F8FAFC"
                    border.color: "#CBD5E1"
                    implicitHeight: estCol.implicitHeight + 24

                    ColumnLayout {
                        id: estCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label {
                                text: "📐 " + (langManager ? langManager.t("bmr_estimator") : "Estimate BMR (Mifflin-St Jeor)")
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1E293B"
                            }
                        }

                        // Sex Selector
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: langManager ? langManager.t("sex") : "Sex"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#475569"
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 160
                                height: 32
                                radius: 8
                                color: "#E2E8F0"

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 2

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 6
                                        color: root.formSex === "male" ? "#3B82F6" : "transparent"
                                        Button {
                                            anchors.fill: parent
                                            text: "♂️ " + (langManager ? langManager.t("male") : "Male")
                                            flat: true
                                            font.pixelSize: 11
                                            font.bold: root.formSex === "male"
                                            palette.buttonText: root.formSex === "male" ? "#FFFFFF" : "#475569"
                                            onClicked: root.formSex = "male"
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 6
                                        color: root.formSex === "female" ? "#EC4899" : "transparent"
                                        Button {
                                            anchors.fill: parent
                                            text: "♀️ " + (langManager ? langManager.t("female") : "Female")
                                            flat: true
                                            font.pixelSize: 11
                                            font.bold: root.formSex === "female"
                                            palette.buttonText: root.formSex === "female" ? "#FFFFFF" : "#475569"
                                            onClicked: root.formSex = "female"
                                        }
                                    }
                                }
                            }
                        }

                        // Age, Weight, Height Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Age
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: langManager ? langManager.t("age") : "Age (years)"
                                    font.pixelSize: 10
                                    color: "#64748B"
                                }
                                TextField {
                                    id: ageField
                                    Layout.fillWidth: true
                                    text: root.formAge.toString()
                                    validator: IntValidator { bottom: 10; top: 120 }
                                    horizontalAlignment: TextInput.AlignHCenter
                                    font.pixelSize: 12
                                    background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#CBD5E1" }
                                    onEditingFinished: {
                                        let v = parseInt(text);
                                        if (!isNaN(v) && v >= 10 && v <= 120) root.formAge = v;
                                    }
                                }
                            }

                            // Weight
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: langManager ? langManager.t("weight") : "Weight (kg)"
                                    font.pixelSize: 10
                                    color: "#64748B"
                                }
                                TextField {
                                    id: weightField
                                    Layout.fillWidth: true
                                    text: root.formWeight.toString()
                                    validator: DoubleValidator { bottom: 30.0; top: 300.0; decimals: 1 }
                                    horizontalAlignment: TextInput.AlignHCenter
                                    font.pixelSize: 12
                                    background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#CBD5E1" }
                                    onEditingFinished: {
                                        let v = parseFloat(text);
                                        if (!isNaN(v) && v >= 30 && v <= 300) root.formWeight = v;
                                    }
                                }
                            }

                            // Height
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: langManager ? langManager.t("height") : "Height (cm)"
                                    font.pixelSize: 10
                                    color: "#64748B"
                                }
                                TextField {
                                    id: heightField
                                    Layout.fillWidth: true
                                    text: root.formHeight.toString()
                                    validator: DoubleValidator { bottom: 100.0; top: 250.0; decimals: 1 }
                                    horizontalAlignment: TextInput.AlignHCenter
                                    font.pixelSize: 12
                                    background: Rectangle { radius: 6; color: "#FFFFFF"; border.color: "#CBD5E1" }
                                    onEditingFinished: {
                                        let v = parseFloat(text);
                                        if (!isNaN(v) && v >= 100 && v <= 250) root.formHeight = v;
                                    }
                                }
                            }
                        }

                        // Apply Button
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            text: "⚡ " + (langManager ? langManager.t("apply_estimate", [Math.round(root.liveEstimatedBmr)]) : ("Apply Estimate (" + Math.round(root.liveEstimatedBmr) + " kcal)"))
                            font.bold: true
                            font.pixelSize: 12
                            palette.buttonText: "#0F766E"
                            background: Rectangle {
                                radius: 8
                                color: "#CCFBF1"
                                border.color: "#5EEAD4"
                            }
                            onClicked: {
                                root.formBaseCalories = Math.round(root.liveEstimatedBmr);
                                baseCalField.text = root.formBaseCalories.toString();
                            }
                        }
                    }
                }

                // Athletic Discipline & Personalized Sport Macro Ratio
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#F8FAFC"
                    border.color: "#CBD5E1"
                    implicitHeight: sportCol.implicitHeight + 26

                    ColumnLayout {
                        id: sportCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: "🏅"; font.pixelSize: 14 }
                            Label {
                                text: langManager ? langManager.t("sport_discipline") : "Sportart & Trainingsphase"
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1E293B"
                            }
                        }

                        // ComboBox for Sport selection
                        ComboBox {
                            id: sportCombo
                            Layout.fillWidth: true
                            model: mealPlanManager ? mealPlanManager.availableSports : []
                            textRole: (langManager && langManager.currentLanguage === "de") ? "nameDe" : "name"
                            valueRole: "id"
                            currentIndex: {
                                if (!model) return 0;
                                for (let i = 0; i < model.length; ++i) {
                                    if (model[i].id === root.formSport) return i;
                                }
                                return 0;
                            }
                            onActivated: function(index) {
                                if (model && model[index]) {
                                    root.formSport = model[index].id;
                                }
                            }
                        }

                        // Selected Sport Description & Targets
                        readonly property var currentSportData: {
                            if (!mealPlanManager || !mealPlanManager.availableSports) return null;
                            for (let i = 0; i < mealPlanManager.availableSports.length; ++i) {
                                if (mealPlanManager.availableSports[i].id === root.formSport) {
                                    return mealPlanManager.availableSports[i];
                                }
                            }
                            return mealPlanManager.availableSports[0];
                        }

                        Label {
                            text: sportCol.currentSportData ? sportCol.currentSportData.description : ""
                            font.pixelSize: 11
                            color: "#64748B"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Macro Percentages & Gram Calculation Card
                        Rectangle {
                            Layout.fillWidth: true
                            radius: 8
                            color: "#EFF6FF"
                            border.color: "#BFDBFE"
                            implicitHeight: macroPreviewCol.implicitHeight + 18

                            ColumnLayout {
                                id: macroPreviewCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                spacing: 4

                                readonly property var sd: sportCol.currentSportData
                                readonly property real baseKcal: root.formBaseCalories

                                // Calorie percentages
                                Label {
                                    text: "🎯 Ziel-Verteilung (Kalorien-%): " +
                                          (macroPreviewCol.sd ? (Math.round(macroPreviewCol.sd.carbPercent) + "% Kohlenhydrate • " +
                                           Math.round(macroPreviewCol.sd.minProtein) + (macroPreviewCol.sd.minProtein !== macroPreviewCol.sd.maxProtein ? ("–" + Math.round(macroPreviewCol.sd.maxProtein)) : "") + "% Eiweiß • " +
                                           Math.round(macroPreviewCol.sd.minFat) + (macroPreviewCol.sd.minFat !== macroPreviewCol.sd.maxFat ? ("–" + Math.round(macroPreviewCol.sd.maxFat)) : "") + "% Fette") : "")
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: "#1E40AF"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                // Converted Grams at current Base Calories
                                Label {
                                    readonly property real carbG: macroPreviewCol.sd ? (macroPreviewCol.baseKcal * (macroPreviewCol.sd.carbPercent / 100.0) / 4.0) : 0
                                    readonly property real protMinG: macroPreviewCol.sd ? (macroPreviewCol.baseKcal * (macroPreviewCol.sd.minProtein / 100.0) / 4.0) : 0
                                    readonly property real protMaxG: macroPreviewCol.sd ? (macroPreviewCol.baseKcal * (macroPreviewCol.sd.maxProtein / 100.0) / 4.0) : 0
                                    readonly property real fatMinG: macroPreviewCol.sd ? (macroPreviewCol.baseKcal * (macroPreviewCol.sd.minFat / 100.0) / 9.0) : 0
                                    readonly property real fatMaxG: macroPreviewCol.sd ? (macroPreviewCol.baseKcal * (macroPreviewCol.sd.maxFat / 100.0) / 9.0) : 0

                                    text: "⚖️ Grammbudget bei " + Math.round(macroPreviewCol.baseKcal) + " kcal: " +
                                          Math.round(carbG) + "g Carbs (4 kcal/g) • " +
                                          Math.round(protMinG) + (Math.round(protMinG) !== Math.round(protMaxG) ? ("–" + Math.round(protMaxG)) : "") + "g Protein (4 kcal/g) • " +
                                          Math.round(fatMinG) + (Math.round(fatMinG) !== Math.round(fatMaxG) ? ("–" + Math.round(fatMaxG)) : "") + "g Fett (9 kcal/g)"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#2563EB"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Educational Box: Warum Kalorien-% nicht gleich Gramm-% sind
                        Rectangle {
                            Layout.fillWidth: true
                            radius: 8
                            color: "#FEF9C3"
                            border.color: "#FDE047"
                            implicitHeight: eduCol.implicitHeight + 18

                            ColumnLayout {
                                id: eduCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                spacing: 3

                                Label {
                                    text: "💡 Warum Kalorien-% nicht gleich Gramm-% sind"
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: "#854D0E"
                                }

                                Label {
                                    text: "Die Makronährstoffe liefern pro Gramm unterschiedlich viel Energie (physiologischer Brennwert):\n• 1 g Kohlenhydrate = 4 kcal (17 kJ)\n• 1 g Eiweiß = 4 kcal (17 kJ)\n• 1 g Fett = 9 kcal (37 kJ)\nFett liefert mehr als doppelt so viele Kalorien wie Kohlenhydrate oder Eiweiß. Wenn du deine Kalorien-% in Gramm umrechnest, teilst du die jeweiligen Kalorien bei Kohlenhydraten und Eiweiß durch 4 und bei Fett durch 9."
                                    font.pixelSize: 10
                                    color: "#713F12"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // Daily Target Equation Preview Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FEF3C7"
                    border.color: "#FDE68A"
                    implicitHeight: eqCol.implicitHeight + 22

                    ColumnLayout {
                        id: eqCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 4

                        Label {
                            text: "📊 Daily Energy Target Calculation"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#92400E"
                        }

                        Label {
                            property real wCals: mealPlanManager ? mealPlanManager.totalWorkoutCalories : 0
                            property real totalTgt: root.formBaseCalories + wCals
                            text: Math.round(root.formBaseCalories) + " kcal (Base Need) + " + Math.round(wCals) + " kcal (" + (mealPlanManager ? mealPlanManager.workoutCount : 0) + " Workouts) = " + Math.round(totalTgt) + " kcal Target"
                            font.bold: true
                            font.pixelSize: 11
                            color: "#B45309"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // Language & Region Card
                Rectangle {
                    visible: root.langManager !== null
                    Layout.fillWidth: true
                    radius: 12
                    color: "#F8FAFC"
                    border.color: "#E2E8F0"
                    implicitHeight: langCol.implicitHeight + 24

                    ColumnLayout {
                        id: langCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: "🌐 " + (langManager ? langManager.t("language_region") : "Language & Region")
                                font.bold: true
                                font.pixelSize: 12
                                color: "#334155"
                            }

                            Item { Layout.fillWidth: true }

                            Label {
                                text: (langManager && langManager.currentLanguage === "de") ? "🇩🇪 Deutsch" : "🇬🇧 English"
                                font.bold: true
                                font.pixelSize: 11
                                color: "#2563EB"
                            }
                        }

                        Label {
                            text: langManager ? langManager.t("lang_restart_hint") : "Applying language changes will restart QtSpeis."
                            font.pixelSize: 10
                            color: "#64748B"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // English Button
                            Rectangle {
                                id: enBtn
                                Layout.fillWidth: true
                                height: 36
                                radius: 8
                                property bool isCurrent: (langManager && langManager.currentLanguage === "en")
                                color: isCurrent ? "#EFF6FF" : "#FFFFFF"
                                border.color: isCurrent ? "#3B82F6" : "#CBD5E1"
                                border.width: isCurrent ? 2 : 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Label { text: "🇬🇧"; font.pixelSize: 14 }
                                    Label {
                                        text: "English"
                                        font.bold: enBtn.isCurrent
                                        font.pixelSize: 11
                                        color: enBtn.isCurrent ? "#1D4ED8" : "#475569"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (langManager && langManager.currentLanguage !== "en") {
                                            root.pendingLanguage = "en";
                                            restartConfirmDialog.open();
                                        }
                                    }
                                }
                            }

                            // Deutsch Button
                            Rectangle {
                                id: deBtn
                                Layout.fillWidth: true
                                height: 36
                                radius: 8
                                property bool isCurrent: (langManager && langManager.currentLanguage === "de")
                                color: isCurrent ? "#EFF6FF" : "#FFFFFF"
                                border.color: isCurrent ? "#3B82F6" : "#CBD5E1"
                                border.width: isCurrent ? 2 : 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Label { text: "🇩🇪"; font.pixelSize: 14 }
                                    Label {
                                        text: "Deutsch"
                                        font.bold: deBtn.isCurrent
                                        font.pixelSize: 11
                                        color: deBtn.isCurrent ? "#1D4ED8" : "#475569"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (langManager && langManager.currentLanguage !== "de") {
                                            root.pendingLanguage = "de";
                                            restartConfirmDialog.open();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Game Progress & Reset Card
                Rectangle {
                    visible: root.gameLevelManager !== null
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FEF2F2"
                    border.color: "#FECACA"
                    implicitHeight: progressCol.implicitHeight + 24

                    ColumnLayout {
                        id: progressCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: "🏆 " + (langManager && langManager.currentLanguage === "de" ? "Spiel-Fortschritt" : "Game Progress")
                                font.bold: true
                                font.pixelSize: 12
                                color: "#991B1B"
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                radius: 10
                                color: "#FEE2E2"
                                border.color: "#FCA5A5"
                                implicitWidth: progressStarsLbl.implicitWidth + 12
                                implicitHeight: 20
                                Label {
                                    id: progressStarsLbl
                                    anchors.centerIn: parent
                                    text: {
                                        var s = 0;
                                        if (root.gameLevelManager && root.gameLevelManager.allLevels) {
                                            for (var i = 0; i < root.gameLevelManager.allLevels.length; ++i) {
                                                s += (root.gameLevelManager.allLevels[i].stars || 0);
                                            }
                                        }
                                        return "★ " + s + " / 72 Stars";
                                    }
                                    font.bold: true
                                    font.pixelSize: 10
                                    color: "#B91C1C"
                                }
                            }
                        }

                        Label {
                            text: (langManager && langManager.currentLanguage === "de")
                                ? "Möchtest du alle freigeschalteten Level und Sterne zurücksetzen (z.B. nach Verwendung des Cheats)?"
                                : "Reset all unlocked levels and earned stars back to initial state (e.g. after testing the cheat plan)?"
                            font.pixelSize: 10
                            color: "#7F1D1D"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Button {
                            id: resetProgressBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            text: "🗑️ " + (langManager ? langManager.t("reset_progress") : "Reset All Game Progress")
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#B91C1C"
                            background: Rectangle {
                                radius: 8
                                color: resetProgressBtn.down ? "#FEE2E2" : "#FFFFFF"
                                border.color: "#F87171"
                                border.width: 1
                            }
                            onClicked: confirmResetDialog.open()
                        }
                    }
                }
            }
        }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "Cancel"
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
                id: saveBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: "💾 " + (langManager ? langManager.t("save_profile") : "Save Profile")
                font.bold: true
                font.pixelSize: 13
                palette.buttonText: "#FFFFFF"
                background: Rectangle {
                    radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#16A34A" }
                        GradientStop { position: 1.0; color: "#15803D" }
                    }
                }
                onClicked: {
                    if (mealPlanManager) {
                        mealPlanManager.setUserProfile(
                            root.formName.trim().length > 0 ? root.formName.trim() : "Player",
                            root.formBaseCalories,
                            root.formWeight,
                            root.formHeight,
                            root.formAge,
                            root.formSex,
                            root.formSport
                        );
                    }
                    root.close();
                }
            }
        }
    }

    Dialog {
        id: confirmResetDialog
        title: langManager ? langManager.t("reset_progress_confirm_title") : "Reset Game Progress?"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Reset

        Label {
            width: 320
            wrapMode: Text.WordWrap
            text: langManager ? langManager.t("reset_progress_confirm_msg") : "This will reset all unlocked levels back to Level 1 and clear all earned stars (0/72 ★). Your current meal plan will remain intact. Are you sure?"
            font.pixelSize: 12
            color: "#1C1917"
        }

        onReset: {
            if (root.gameLevelManager) {
                root.gameLevelManager.resetAllProgress();
            }
        }
    }

    Dialog {
        id: restartConfirmDialog
        title: langManager ? langManager.t("restart_confirm_title") : "Restart Required"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.No | Dialog.Yes

        contentItem: ColumnLayout {
            spacing: 8
            Label {
                width: 320
                wrapMode: Text.WordWrap
                text: langManager ? langManager.t("restart_confirm_msg") : "Changing the language requires restarting the application. Do you want to proceed and restart now?"
                font.pixelSize: 12
                color: "#1C1917"
            }
        }

        onAccepted: {
            if (root.pendingLanguage && langManager) {
                if (mealPlanManager) {
                    mealPlanManager.setUserProfile(
                        root.formName.trim().length > 0 ? root.formName.trim() : "Player",
                        root.formBaseCalories,
                        root.formWeight,
                        root.formHeight,
                        root.formAge,
                        root.formSex,
                        root.formSport
                    );
                }
                langManager.currentLanguage = root.pendingLanguage;
                langManager.restartApplication();
            }
        }
        onRejected: {
            root.pendingLanguage = "";
        }
    }
}
