import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(920, (parent ? parent.width : 920) - 20)
    height: Math.min(720, (parent ? parent.height : 720) - 24)
    padding: 0

    property var recipeManager: null
    property var mealPlanManager: null
    property var langManager: null

    readonly property bool isNarrow: root.width < 640

    property string searchQuery: ""
    property string activeCategory: "All"
    property int selectedRecipeId: 1
    property int selectedCustomIndex: 0
    property int chosenServings: 1
    property string chosenTime: "12:00"

    // Filtered recipes list
    readonly property var filteredRecipes: {
        if (!recipeManager || !recipeManager.recipes) return [];
        let list = recipeManager.recipes;
        let q = searchQuery.trim().toLowerCase();
        let cat = activeCategory;

        return list.filter(function(r) {
            // Category match
            if (cat !== "All" && cat !== "Custom") {
                if (r.category !== cat) return false;
            }
            // Search query match
            if (q.length > 0) {
                let matchTitle = (r.title || "").toLowerCase().indexOf(q) !== -1;
                let matchCat = (r.category || "").toLowerCase().indexOf(q) !== -1;
                let matchIng = false;
                if (r.ingredients) {
                    for (let i = 0; i < r.ingredients.length; ++i) {
                        let ing = r.ingredients[i];
                        if ((ing.name || "").toLowerCase().indexOf(q) !== -1 ||
                            (ing.name_de || "").toLowerCase().indexOf(q) !== -1 ||
                            (ing.name_en || "").toLowerCase().indexOf(q) !== -1) {
                            matchIng = true;
                            break;
                        }
                    }
                }
                if (!matchTitle && !matchCat && !matchIng) return false;
            }
            return true;
        });
    }

    // Active selected recipe object
    readonly property var currentRecipe: {
        if (activeCategory === "Custom") return null;
        let list = filteredRecipes;
        for (let i = 0; i < list.length; ++i) {
            if (list[i].id === selectedRecipeId) return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    onCurrentRecipeChanged: {
        if (currentRecipe) {
            chosenServings = currentRecipe.servings || 1;
            chosenTime = currentRecipe.defaultTime || "12:00";
        }
    }

    function openWithCategory(category) {
        if (category) activeCategory = category;
        root.open();
    }

    background: Rectangle {
        radius: 16
        color: "#FDFBF7"
        border.color: "#E2D9C8"
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        // --- 1. DIALOG HEADER ---
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
                    text: "📖"
                    font.pixelSize: 26
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: langManager ? langManager.t("recipes_title") : "Recipe & Meal Library"
                        font.bold: true
                        font.pixelSize: root.isNarrow ? 15 : 17
                        color: "#1C1917"
                    }

                    Label {
                        text: langManager ? langManager.t("recipes_subtitle") : "32 authentic balanced recipes & saved custom meals"
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

        // --- 2. SEARCH & CATEGORY FILTER BAR ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: filterBarCol.implicitHeight + 16
            color: "#FAF8F5"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#E7E5E4"
            }

            ColumnLayout {
                id: filterBarCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 6

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    placeholderText: "🔍 " + (langManager ? langManager.t("add_ingredient") : "Search recipes or ingredients...")
                    font.pixelSize: 12
                    selectByMouse: true
                    onTextChanged: root.searchQuery = text

                    background: Rectangle {
                        radius: 8
                        color: "#FFFFFF"
                        border.color: searchField.activeFocus ? "#3B82F6" : "#D6D3D1"
                    }
                }

                // Category chips (Wrapping Flow Layout so all categories are visible and clickable)
                Flow {
                    id: categoryFlow
                    Layout.fillWidth: true
                    spacing: 6

                    // All tab
                    Rectangle {
                        height: 28
                        width: allLabel.implicitWidth + 16
                        radius: 8
                        color: root.activeCategory === "All" ? "#1E293B" : "#FFFFFF"
                        border.color: root.activeCategory === "All" ? "#1E293B" : "#E2D9C8"

                        Label {
                            id: allLabel
                            anchors.centerIn: parent
                            text: "🌟 All (32)"
                            font.bold: root.activeCategory === "All"
                            font.pixelSize: 11
                            color: root.activeCategory === "All" ? "#FFFFFF" : "#475569"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeCategory = "All"
                        }
                    }

                    // 6 culinary categories
                    Repeater {
                        model: [
                            { name: "Frühstück & Breie", icon: "🥣", label: "Breakfast (5)" },
                            { name: "Shakes", icon: "🥤", label: "Shakes (4)" },
                            { name: "Aufstriche & Salate", icon: "🥗", label: "Spreads & Salads (6)" },
                            { name: "Suppen & Nudelgerichte", icon: "🍲", label: "Soups & Pasta (6)" },
                            { name: "Hauptgerichte", icon: "🥘", label: "Mains (8)" },
                            { name: "Süßspeisen", icon: "🍰", label: "Desserts (3)" }
                        ]

                        delegate: Rectangle {
                            id: catTabRect
                            height: 28
                            width: catLabel.implicitWidth + 16
                            radius: 8
                            property bool isSelected: root.activeCategory === modelData.name
                            color: isSelected ? "#3B82F6" : "#FFFFFF"
                            border.color: isSelected ? "#3B82F6" : "#E2D9C8"

                            Label {
                                id: catLabel
                                anchors.centerIn: parent
                                text: modelData.icon + " " + modelData.name
                                font.bold: catTabRect.isSelected
                                font.pixelSize: 11
                                color: catTabRect.isSelected ? "#FFFFFF" : "#334155"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeCategory = modelData.name
                            }
                        }
                    }

                    // Custom Saved Meals Tab
                    Rectangle {
                        id: customTabRect
                        height: 28
                        width: customLabel.implicitWidth + 16
                        radius: 8
                        property bool isSelected: root.activeCategory === "Custom"
                        color: isSelected ? "#059669" : "#FFFFFF"
                        border.color: isSelected ? "#059669" : "#E2D9C8"

                        Label {
                            id: customLabel
                            anchors.centerIn: parent
                            property int count: recipeManager ? recipeManager.customTemplateCount : 0
                            text: "⭐ " + (langManager ? langManager.t("custom_meals_tab") : "Saved Meals") + " (" + count + ")"
                            font.bold: customTabRect.isSelected
                            font.pixelSize: 11
                            color: customTabRect.isSelected ? "#FFFFFF" : "#059669"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeCategory = "Custom"
                        }
                    }
                }
            }
        }

        // --- 3. MAIN BODY SPLIT VIEW ---
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // --- LEFT COLUMN: RECIPE / TEMPLATE LIST ---
            Rectangle {
                Layout.preferredWidth: root.isNarrow ? parent.width : (root.activeCategory === "Custom" ? 380 : 360)
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

                // If Custom tab is active
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    visible: root.activeCategory === "Custom"

                    ListView {
                        id: customListView
                        width: parent.width
                        spacing: 8
                        topMargin: 10
                        bottomMargin: 10
                        leftMargin: 10
                        rightMargin: 10
                        model: recipeManager ? recipeManager.customMealTemplates : []

                        // Empty State for Custom Meals
                        Label {
                            visible: customListView.count === 0
                            anchors.centerIn: parent
                            width: parent.width - 40
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            text: langManager ? langManager.t("no_saved_meals_hint") : "No saved custom meals yet.\nBuild a meal in your plan and click '💾 Save as Custom Meal'!"
                            font.pixelSize: 12
                            color: "#78716C"
                        }

                        delegate: Rectangle {
                            width: customListView.width - 20
                            implicitHeight: customCardCol.implicitHeight + 16
                            radius: 10
                            property bool isSelected: root.selectedCustomIndex === index
                            color: isSelected ? "#F0FDF4" : "#FFFFFF"
                            border.color: isSelected ? "#10B981" : "#E2D9C8"
                            border.width: isSelected ? 2 : 1

                            ColumnLayout {
                                id: customCardCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.icon || "🍽️"
                                        font.pixelSize: 20
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Label {
                                            text: modelData.title || "Custom Meal"
                                            font.bold: true
                                            font.pixelSize: 13
                                            color: "#1C1917"
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: (modelData.items ? modelData.items.length : 0) + " items · " + Math.round(modelData.calories || 0) + " kcal"
                                            font.pixelSize: 11
                                            color: "#059669"
                                            font.bold: true
                                        }
                                    }

                                    Button {
                                        text: "➕ Add"
                                        font.bold: true
                                        font.pixelSize: 11
                                        palette.buttonText: "#FFFFFF"
                                        background: Rectangle { radius: 6; color: "#10B981" }
                                        onClicked: {
                                            if (recipeManager && mealPlanManager) {
                                                recipeManager.loadTemplateIntoPlan(index, "", mealPlanManager);
                                                root.close();
                                            }
                                        }
                                    }

                                    RoundButton {
                                        text: "🗑️"
                                        flat: true
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        palette.buttonText: "#DC2626"
                                        onClicked: {
                                            deleteTemplateConfirm.targetIndex = index;
                                            deleteTemplateConfirm.targetName = modelData.title || "Meal";
                                            deleteTemplateConfirm.open();
                                        }
                                    }
                                }

                                // Macros pill
                                RowLayout {
                                    spacing: 8
                                    Label { text: "C: " + Math.round(modelData.carbs || 0) + "g"; font.pixelSize: 10; color: "#D97706" }
                                    Label { text: "P: " + Math.round(modelData.protein || 0) + "g"; font.pixelSize: 10; color: "#2563EB" }
                                    Label { text: "F: " + Math.round(modelData.fat || 0) + "g"; font.pixelSize: 10; color: "#DC2626" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                onClicked: root.selectedCustomIndex = index
                            }
                        }
                    }
                }

                // Standard 32 Recipes List
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    visible: root.activeCategory !== "Custom"

                    ListView {
                        id: recipeListView
                        width: parent.width
                        spacing: 8
                        topMargin: 10
                        bottomMargin: 10
                        leftMargin: 10
                        rightMargin: 10
                        model: root.filteredRecipes

                        Label {
                            visible: recipeListView.count === 0
                            anchors.centerIn: parent
                            text: "No recipes matched your search filter."
                            font.pixelSize: 12
                            color: "#78716C"
                        }

                        delegate: Rectangle {
                            width: recipeListView.width - 20
                            implicitHeight: rCardCol.implicitHeight + 16
                            radius: 10
                            property bool isSelected: root.selectedRecipeId === modelData.id
                            color: isSelected ? "#EFF6FF" : "#FFFFFF"
                            border.color: isSelected ? "#3B82F6" : "#E2D9C8"
                            border.width: isSelected ? 2 : 1

                            ColumnLayout {
                                id: rCardCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.icon || "🍽️"
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
                                            Rectangle {
                                                radius: 4
                                                color: (modelData.color || "#3B82F6") + "20"
                                                height: 18
                                                width: catBadge.implicitWidth + 8
                                                Label {
                                                    id: catBadge
                                                    anchors.centerIn: parent
                                                    text: modelData.category
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: modelData.color || "#3B82F6"
                                                }
                                            }

                                            Label {
                                                text: (modelData.servings || 1) + " " + (langManager ? langManager.t("servings_label") : "Servings")
                                                font.pixelSize: 10
                                                color: "#78716C"
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Label {
                                            text: Math.round(modelData.calories_per_serving) + " kcal"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: "#1E293B"
                                            Layout.alignment: Qt.AlignRight
                                        }
                                        Label {
                                            text: "per serving"
                                            font.pixelSize: 9
                                            color: "#94A3B8"
                                            Layout.alignment: Qt.AlignRight
                                        }
                                    }
                                }

                                // Quick macro badges
                                RowLayout {
                                    spacing: 8
                                    Layout.leftMargin: 30
                                    Label { text: "C: " + Math.round(modelData.carbs_per_serving) + "g"; font.pixelSize: 10; color: "#D97706" }
                                    Label { text: "P: " + Math.round(modelData.protein_per_serving) + "g"; font.pixelSize: 10; color: "#2563EB" }
                                    Label { text: "F: " + Math.round(modelData.fat_per_serving) + "g"; font.pixelSize: 10; color: "#DC2626" }
                                    Label { text: (modelData.ingredients ? modelData.ingredients.length : 0) + " ingredients"; font.pixelSize: 10; color: "#64748B" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedRecipeId = modelData.id
                            }
                        }
                    }
                }
            }

            // --- RIGHT COLUMN: RECIPE DETAILS & INGREDIENTS PREVIEW ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                visible: !root.isNarrow || root.activeCategory !== "Custom"

                ScrollView {
                    anchors.fill: parent
                    clip: true
                    topPadding: 16
                    bottomPadding: 16

                    ColumnLayout {
                        width: parent.width - 28
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        // Detail Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: root.currentRecipe ? (root.currentRecipe.icon || "🍽️") : "🍽️"
                                font.pixelSize: 34
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: root.currentRecipe ? root.currentRecipe.title : ""
                                    font.bold: true
                                    font.pixelSize: 17
                                    color: "#1C1917"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 8
                                    Label {
                                        text: root.currentRecipe ? root.currentRecipe.category : ""
                                        font.pixelSize: 12
                                        color: root.currentRecipe ? (root.currentRecipe.color || "#3B82F6") : "#3B82F6"
                                        font.bold: true
                                    }

                                    Label {
                                        text: "·  Base recipe: " + (root.currentRecipe ? root.currentRecipe.servings : 1) + " serving(s)"
                                        font.pixelSize: 11
                                        color: "#78716C"
                                    }
                                }
                            }
                        }

                        // Servings & Time Adjusters Card
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: adjustRow.implicitHeight + 16
                            radius: 12
                            color: "#FAF8F5"
                            border.color: "#E2D9C8"

                            RowLayout {
                                id: adjustRow
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 14

                                // Servings Stepper
                                ColumnLayout {
                                    spacing: 4
                                    Label {
                                        text: langManager ? langManager.t("servings_label") : "Servings to Add:"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#475569"
                                    }

                                    RowLayout {
                                        spacing: 6

                                        RoundButton {
                                            text: "−"
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            enabled: root.chosenServings > 1
                                            onClicked: if (root.chosenServings > 1) root.chosenServings--
                                        }

                                        Rectangle {
                                            width: 48
                                            height: 32
                                            radius: 6
                                            color: "#FFFFFF"
                                            border.color: "#D6D3D1"

                                            Label {
                                                anchors.centerIn: parent
                                                text: root.chosenServings.toString()
                                                font.bold: true
                                                font.pixelSize: 14
                                                color: "#1E293B"
                                            }
                                        }

                                        RoundButton {
                                            text: "+"
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            enabled: root.chosenServings < 20
                                            onClicked: if (root.chosenServings < 20) root.chosenServings++
                                        }
                                    }
                                }

                                // Meal Time Selector
                                ColumnLayout {
                                    spacing: 4
                                    Label {
                                        text: langManager ? langManager.t("start_time") : "Meal Time:"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#475569"
                                    }

                                    TextField {
                                        text: root.chosenTime
                                        font.pixelSize: 13
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 32
                                        horizontalAlignment: Text.AlignHCenter
                                        onTextChanged: root.chosenTime = text
                                        background: Rectangle {
                                            radius: 6
                                            color: "#FFFFFF"
                                            border.color: "#D6D3D1"
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Scaled Calories Tag
                                ColumnLayout {
                                    spacing: 1
                                    Layout.alignment: Qt.AlignRight
                                    Label {
                                        readonly property real totalKcal: root.currentRecipe ? (root.currentRecipe.calories_per_serving * root.chosenServings) : 0
                                        text: Math.round(totalKcal) + " kcal"
                                        font.bold: true
                                        font.pixelSize: 18
                                        color: "#10B981"
                                        Layout.alignment: Qt.AlignRight
                                    }
                                    Label {
                                        text: "scaled total"
                                        font.pixelSize: 10
                                        color: "#78716C"
                                        Layout.alignment: Qt.AlignRight
                                    }
                                }
                            }
                        }

                        // Scaled Macronutrient Metrics Row
                        Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 10
                            color: "#FFFFFF"
                            border.color: "#E2D9C8"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                readonly property real scale: root.currentRecipe ? (root.chosenServings / (root.currentRecipe.servings || 1)) : 1.0

                                // Carbs
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: "#FEF3C7"
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Label {
                                            text: "Carbs: " + Math.round((root.currentRecipe ? root.currentRecipe.total_carbs : 0) * parent.parent.scale) + "g"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#B45309"
                                        }
                                    }
                                }

                                // Protein
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: "#DBEAFE"
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Label {
                                            text: "Protein: " + Math.round((root.currentRecipe ? root.currentRecipe.total_protein : 0) * parent.parent.scale) + "g"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#1D4ED8"
                                        }
                                    }
                                }

                                // Fat
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: "#FEE2E2"
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Label {
                                            text: "Fat: " + Math.round((root.currentRecipe ? root.currentRecipe.total_fat : 0) * parent.parent.scale) + "g"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#B91C1C"
                                        }
                                    }
                                }

                                // Fiber
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 6
                                    color: "#F3E8FF"
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Label {
                                            text: "Fiber: " + Math.round((root.currentRecipe ? root.currentRecipe.total_fiber : 0) * parent.parent.scale) + "g"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#7E22CE"
                                        }
                                    }
                                }
                            }
                        }

                        // Ingredients Breakdown Table
                        Label {
                            property int count: root.currentRecipe && root.currentRecipe.ingredients ? root.currentRecipe.ingredients.length : 0
                            text: "Ingredients Breakdown (" + count + " items):"
                            font.bold: true
                            font.pixelSize: 12
                            color: "#334155"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: ingCol.implicitHeight + 12
                            radius: 10
                            color: "#F8FAFC"
                            border.color: "#E2E8F0"

                            ColumnLayout {
                                id: ingCol
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                readonly property real ingScale: root.currentRecipe ? (root.chosenServings / (root.currentRecipe.servings || 1)) : 1.0

                                Repeater {
                                    model: root.currentRecipe ? root.currentRecipe.ingredients : []

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 32
                                        radius: 6
                                        color: index % 2 === 0 ? "#FFFFFF" : "#F1F5F9"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            Label {
                                                text: modelData.name || modelData.name_de || modelData.name_en
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: "#1E293B"
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            // Gram weight (scaled)
                                            Label {
                                                readonly property real g: modelData.weight_g * ingCol.ingScale
                                                text: (g >= 10 ? Math.round(g) : g.toFixed(1)) + " g"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: "#0F766E"
                                            }

                                            // Calories
                                            Label {
                                                readonly property real kcal: modelData.calories * ingCol.ingScale
                                                text: Math.round(kcal) + " kcal"
                                                font.pixelSize: 10
                                                color: "#64748B"
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ADD TO PLAN BUTTON
                        Button {
                            Layout.fillWidth: true
                            height: 44
                            text: "✨ " + (langManager ? langManager.t("add_to_plan_btn") : "Add to Meal Plan") + " (" + root.chosenServings + "x)"
                            font.bold: true
                            font.pixelSize: 13
                            palette.buttonText: "#FFFFFF"
                            background: Rectangle {
                                radius: 10
                                color: "#10B981"
                            }
                            onClicked: {
                                if (recipeManager && mealPlanManager && root.currentRecipe) {
                                    recipeManager.loadRecipeIntoPlan(root.currentRecipe.id, root.chosenServings, root.chosenTime, mealPlanManager);
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Confirmation dialog for deleting custom template
    Dialog {
        id: deleteTemplateConfirm
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 380
        title: langManager ? langManager.t("confirm_delete_template_title") : "Delete Saved Meal?"
        property int targetIndex: -1
        property string targetName: ""

        Label {
            text: langManager ? langManager.t("confirm_delete_template_msg", [deleteTemplateConfirm.targetName]) : ("Are you sure you want to delete '" + deleteTemplateConfirm.targetName + "'?")
            wrapMode: Text.WordWrap
            width: parent.width
        }

        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            if (targetIndex >= 0 && recipeManager) {
                recipeManager.deleteCustomMealTemplate(targetIndex);
            }
        }
    }
}
