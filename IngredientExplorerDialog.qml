import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(840, (parent ? parent.width : 840) - 16)
    height: Math.min(760, (parent ? parent.height : 760) - 20)
    padding: 0

    property var foodDatabase: null
    property var mealPlanManager: null
    property var langManager: null

    readonly property bool isNarrow: root.width < 560

    // Search and filter state
    property string searchQuery: ""
    property string selectedCategory: "All"
    property string sortBy: "name" // name, calories, protein, carbs, fat, fiber, calcium, iron, magnesium, potassium, vitamin_c, omega_3
    property bool sortAscending: true
    property int expandedFoodId: -1
    property var openSubsections: ({})
    property real addAmount: 100
    property int targetMealIndex: 0
    property string feedbackMessage: ""
    property bool preserveStateOnShow: false

    function openForMeal(mealIndex, preselectedSortBy) {
        targetMealIndex = mealIndex;
        if (preselectedSortBy) {
            sortBy = preselectedSortBy;
            sortAscending = false;
        }
        preserveStateOnShow = true;
        foodList = refreshFoods();
        root.open();
    }

    function openWithSort(nutrientKey) {
        if (nutrientKey) {
            sortBy = nutrientKey;
            sortAscending = false;
        }
        preserveStateOnShow = true;
        foodList = refreshFoods();
        root.open();
    }

    function findMealOptionIndex(targetIdx) {
        for (var i = 0; i < root.availableMealOptions.length; ++i) {
            if (root.availableMealOptions[i].index === targetIdx) return i;
        }
        return 0;
    }

    function getSortedNutrientBadge(item) {
        if (!item) return "";
        var isDe = langManager && langManager.currentLanguage === "de";
        switch (root.sortBy) {
        case "omega_3":
            return "🐟 Ω-3: " + (item.omega3 || 0).toFixed(2) + "g";
        case "potassium":
            return "⚡ K: " + Math.round(item.potassium || 0) + "mg";
        case "fiber":
            return "🌾 " + (isDe ? "Ballaststoffe: " : "Fiber: ") + (item.fiber || 0).toFixed(1) + "g";
        case "magnesium":
            return "✨ Mg: " + Math.round(item.magnesium || 0) + "mg";
        case "calcium":
            return "🥛 Ca: " + Math.round(item.calcium || 0) + "mg";
        case "iron":
            return "🩸 Fe: " + (item.iron || 0).toFixed(1) + "mg";
        case "zinc":
            return "🛡️ Zn: " + (item.zinc || 0).toFixed(1) + "mg";
        case "vitamin_c":
            return "🍊 Vit C: " + Math.round(item.vitaminC || 0) + "mg";
        case "protein":
            return "🍗 Protein: " + (item.protein || 0).toFixed(1) + "g";
        case "carbs":
            return "🌾 " + (isDe ? "Kohlenhydrate: " : "Carbs: ") + (item.carbs || 0).toFixed(1) + "g";
        case "fat":
            return "🥑 " + (isDe ? "Fett: " : "Fat: ") + (item.fat || 0).toFixed(1) + "g";
        case "sat_fat":
            return "🧈 " + (isDe ? "Ges. Fett: " : "SatFat: ") + (item.satFat || 0).toFixed(1) + "g";
        default:
            return "";
        }
    }

    readonly property var availableMealOptions: {
        if (!mealPlanManager || !mealPlanManager.meals) return [];
        var list = [];
        var all = mealPlanManager.meals;
        for (var i = 0; i < all.length; ++i) {
            var m = all[i];
            if (m && !m.isWorkout) {
                var icon = m.icon ? (m.icon + " ") : "";
                var title = m.title || ("Meal " + (i + 1));
                var time = m.time ? (" (" + m.time + ")") : "";
                list.push({ index: i, title: icon + title + time });
            }
        }
        if (list.length === 0) {
            var defaultName = (langManager && langManager.currentLanguage === "de") ? "🍳 Frühstück (neu anlegen)" : "🍳 Breakfast (create new)";
            list.push({ index: -1, title: defaultName });
        }
        return list;
    }

    function refreshFoods() {
        if (!foodDatabase) return [];
        var lang = langManager ? langManager.currentLanguage : "en";
        var cat = (selectedCategory === "All" || selectedCategory === "Alle") ? "" : selectedCategory;
        return foodDatabase.exploreFoods(searchQuery, cat, sortBy, sortAscending, 200, lang);
    }

    property var foodList: refreshFoods()

    onAboutToShow: {
        if (!preserveStateOnShow) {
            searchQuery = "";
            selectedCategory = "All";
            sortBy = "name";
            sortAscending = true;
            targetMealIndex = 0;
        }
        preserveStateOnShow = false;
        expandedFoodId = -1;
        openSubsections = ({});
        feedbackMessage = "";
        foodList = refreshFoods();
    }

    background: Rectangle {
        color: "#FFFDF9"
        radius: 16
        border.color: "#E2D9C8"
        border.width: 1
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.isNarrow ? 10 : 16
        spacing: 8

        // ── Top Header ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 36
                height: 36
                radius: 10
                color: "#FEF3C7"
                border.color: "#FDE68A"
                Label {
                    anchors.centerIn: parent
                    text: "🔬"
                    font.pixelSize: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Label {
                    text: langManager ? langManager.t("ingredient_explorer") : "Ingredient Explorer"
                    font.bold: true
                    font.pixelSize: root.isNarrow ? 13 : 15
                    color: "#1C1917"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Label {
                    text: langManager ? langManager.t("ingredient_explorer_sub") : "Explore, sort and filter all ingredients, macro profiles and micronutrients"
                    font.pixelSize: 10
                    color: "#78716C"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Notification / Feedback badge
            Rectangle {
                visible: root.feedbackMessage.length > 0
                radius: 8
                color: "#DCFCE7"
                border.color: "#86EFAC"
                implicitWidth: feedbackLbl.implicitWidth + 14
                implicitHeight: 26
                Label {
                    id: feedbackLbl
                    anchors.centerIn: parent
                    text: root.feedbackMessage
                    font.bold: true
                    font.pixelSize: 10
                    color: "#15803D"
                }
            }

            RoundButton {
                text: "✕"
                flat: true
                font.pixelSize: 12
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                palette.buttonText: "#57534E"
                onClicked: root.close()
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E7E5E4"
        }

        // ── Search & Filter Controls Bar ─────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Search field
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 8
                    color: "#FFFFFF"
                    border.color: searchInput.activeFocus ? "#D97706" : "#E2D9C8"
                    border.width: searchInput.activeFocus ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Label {
                            text: "🔍"
                            font.pixelSize: 12
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            placeholderText: (langManager && langManager.currentLanguage === "de")
                                ? "Zutat suchen (z.B. Haferflocken, Lachs, Banane)..."
                                : "Search ingredients (e.g. Oats, Salmon, Banana)..."
                            placeholderTextColor: "#A8A29E"
                            font.pixelSize: 11
                            color: "#1C1917"
                            background: null
                            padding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: {
                                root.searchQuery = text;
                                root.foodList = root.refreshFoods();
                            }
                        }

                        RoundButton {
                            visible: searchInput.text.length > 0
                            text: "✕"
                            flat: true
                            font.pixelSize: 10
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            onClicked: {
                                searchInput.text = "";
                                root.searchQuery = "";
                                root.foodList = root.refreshFoods();
                            }
                        }
                    }
                }

                // Sort Dropdown
                Rectangle {
                    height: 34
                    radius: 8
                    color: "#FFFFFF"
                    border.color: "#E2D9C8"
                    implicitWidth: sortRow.implicitWidth + 12

                    RowLayout {
                        id: sortRow
                        anchors.centerIn: parent
                        spacing: 4

                        Label {
                            text: (langManager && langManager.currentLanguage === "de") ? "Sortierung:" : "Sort:"
                            font.pixelSize: 10
                            color: "#78716C"
                        }

                        ComboBox {
                            id: sortCombo
                            implicitWidth: 110
                            implicitHeight: 30
                            font.pixelSize: 10
                            model: [
                                { key: "name", label: (langManager && langManager.currentLanguage === "de") ? "Name" : "Name" },
                                { key: "calories", label: (langManager && langManager.currentLanguage === "de") ? "Kalorien" : "Calories" },
                                { key: "protein", label: (langManager && langManager.currentLanguage === "de") ? "Eiweiß" : "Protein" },
                                { key: "carbs", label: (langManager && langManager.currentLanguage === "de") ? "Kohlenhydrate" : "Carbs" },
                                { key: "fat", label: (langManager && langManager.currentLanguage === "de") ? "Fett" : "Fat" },
                                { key: "fiber", label: (langManager && langManager.currentLanguage === "de") ? "Ballaststoffe" : "Fiber" },
                                { key: "iron", label: (langManager && langManager.currentLanguage === "de") ? "Eisen (Fe)" : "Iron (Fe)" },
                                { key: "vitamin_c", label: (langManager && langManager.currentLanguage === "de") ? "Vitamin C" : "Vitamin C" },
                                { key: "calcium", label: (langManager && langManager.currentLanguage === "de") ? "Calcium" : "Calcium" },
                                { key: "magnesium", label: (langManager && langManager.currentLanguage === "de") ? "Magnesium" : "Magnesium" },
                                { key: "potassium", label: (langManager && langManager.currentLanguage === "de") ? "Kalium" : "Potassium" },
                                { key: "omega_3", label: (langManager && langManager.currentLanguage === "de") ? "Omega-3" : "Omega-3" }
                            ]
                            textRole: "label"
                            onActivated: (index) => {
                                root.sortBy = model[index].key;
                                root.foodList = root.refreshFoods();
                            }
                        }

                        // Asc / Desc toggle
                        RoundButton {
                            text: root.sortAscending ? "▲" : "▼"
                            flat: true
                            font.pixelSize: 10
                            palette.buttonText: "#B45309"
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            onClicked: {
                                root.sortAscending = !root.sortAscending;
                                root.foodList = root.refreshFoods();
                            }
                        }
                    }
                }
            }

            // Category Filter Pills (Wrapping Flow Layout so all categories are reachable)
            Flow {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: [
                        { key: "All", icon: "🌐", label: (langManager ? langManager.t("cat_all") : "All") },
                        { key: "Grains", icon: "🌾", label: (langManager ? langManager.t("cat_grains") : "Grains") },
                        { key: "Vegetables", icon: "🥦", label: (langManager ? langManager.t("cat_vegetables") : "Vegetables") },
                        { key: "Fruits", icon: "🍎", label: (langManager ? langManager.t("cat_fruits") : "Fruits") },
                        { key: "Legumes", icon: "🫘", label: (langManager ? langManager.t("cat_legumes") : "Legumes") },
                        { key: "Nuts", icon: "🥜", label: (langManager ? langManager.t("cat_nuts") : "Nuts & Seeds") },
                        { key: "Meat", icon: "🥩", label: (langManager ? langManager.t("cat_meat") : "Meat") },
                        { key: "Fish", icon: "🐟", label: (langManager ? langManager.t("cat_fish") : "Fish") },
                        { key: "Dairy", icon: "🥛", label: (langManager ? langManager.t("cat_dairy") : "Dairy") },
                        { key: "Salads", icon: "🥗", label: (langManager ? langManager.t("cat_salads") : "Salads & Greens") },
                        { key: "Oils", icon: "🫒", label: (langManager ? langManager.t("cat_oils") : "Oils & Fats") },
                        { key: "Herbs", icon: "🌿", label: (langManager ? langManager.t("cat_herbs") : "Herbs") },
                        { key: "Beverages", icon: "☕", label: (langManager ? langManager.t("cat_beverages") : "Beverages") },
                        { key: "Eggs", icon: "🥚", label: (langManager ? langManager.t("cat_eggs") : "Eggs") }
                    ]

                    delegate: Rectangle {
                        id: catChip
                        implicitWidth: catChipLbl.implicitWidth + 14
                        implicitHeight: 25
                        radius: 13
                        property bool isSelected: (root.selectedCategory === modelData.key) ||
                                                  (modelData.key === "All" && (root.selectedCategory === "All" || root.selectedCategory === "Alle"))
                        color: isSelected ? "#D97706" : "#FFFFFF"
                        border.color: isSelected ? "#B45309" : "#E2D9C8"

                        Label {
                            id: catChipLbl
                            anchors.centerIn: parent
                            text: modelData.icon + " " + modelData.label
                            font.bold: catChip.isSelected
                            font.pixelSize: 10
                            color: catChip.isSelected ? "#FFFFFF" : "#57534E"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedCategory = modelData.key;
                                root.foodList = root.refreshFoods();
                            }
                        }
                    }
                }
            }
        }

        // ── Main Content Area: Responsive Accordion List of Foods ────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#FFFFFF"
            border.color: "#E7E5E4"
            clip: true

            ListView {
                id: foodListView
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6
                clip: true
                model: root.foodList

                delegate: Rectangle {
                    id: foodCard
                    width: foodListView.width
                    radius: 10
                    property bool isExpanded: (root.expandedFoodId === modelData.id)
                    property bool mineralsExpanded: Boolean(root.openSubsections[String(modelData.id)])
                    readonly property bool isSpice: {
                        var cat = String(modelData.category || "").toLowerCase();
                        var name = String(modelData.name || "").toLowerCase();
                        var sz = Number(modelData.servingSize || 0);
                        return cat.indexOf("herb") !== -1 || cat.indexOf("spice") !== -1 ||
                               cat.indexOf("gewürz") !== -1 || cat.indexOf("kräuter") !== -1 ||
                               name.indexOf("salz") !== -1 || name.indexOf("salt") !== -1 ||
                               name.indexOf("kurkuma") !== -1 || name.indexOf("turmeric") !== -1 ||
                               name.indexOf("pfeffer") !== -1 || name.indexOf("pepper") !== -1 ||
                               (sz > 0 && sz <= 10);
                    }

                    color: isExpanded ? "#FFFDF9" : (cardHover.containsMouse ? "#FAFAF9" : "#FFFFFF")
                    border.color: isExpanded ? "#D97706" : (cardHover.containsMouse ? "#D6D3D1" : "#E7E5E4")
                    border.width: isExpanded ? 2 : 1

                    implicitHeight: isExpanded ? expandedLayout.implicitHeight + 16 : 56

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                    }

                    ColumnLayout {
                        id: expandedLayout
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        spacing: 8

                        // ── Summary Row (Always visible) ────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MouseArea {
                                id: cardHover
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.expandedFoodId === modelData.id) {
                                        root.expandedFoodId = -1;
                                    } else {
                                        root.expandedFoodId = modelData.id;
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 8

                                    // Icon badge
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 8
                                        color: foodCard.isExpanded ? "#FEF3C7" : "#F5F5F4"
                                        Label {
                                            anchors.centerIn: parent
                                            text: (modelData.icon && modelData.icon !== "🍽️" && modelData.icon !== "🍽")
                                                  ? String(modelData.icon).replace(/\uFE0F/g, "")
                                                  : "🥗"
                                            font.pixelSize: 16
                                        }
                                    }

                                    // Name and Category badge
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Label {
                                            text: modelData.name || ""
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: foodCard.isExpanded ? "#B45309" : "#1C1917"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        RowLayout {
                                            spacing: 6
                                            Rectangle {
                                                radius: 4
                                                color: "#F5F5F4"
                                                implicitWidth: catBadge.implicitWidth + 8
                                                implicitHeight: 16
                                                Label {
                                                    id: catBadge
                                                    anchors.centerIn: parent
                                                    text: modelData.category || ""
                                                    font.pixelSize: 9
                                                    color: "#78716C"
                                                }
                                            }

                                            // Special badge for Iron type (Heme vs Non-Heme)
                                            Rectangle {
                                                visible: Boolean(modelData.iron && modelData.iron >= 1.0)
                                                radius: 4
                                                color: modelData.ironType === "heme" ? "#FEE2E2" : "#ECFDF5"
                                                border.color: modelData.ironType === "heme" ? "#FECACA" : "#A7F3D0"
                                                implicitWidth: feBadge.implicitWidth + 8
                                                implicitHeight: 16
                                                Label {
                                                    id: feBadge
                                                    anchors.centerIn: parent
                                                    text: modelData.ironType === "heme"
                                                        ? ("Fe: " + (langManager ? langManager.t("nutrient_iron_heme") : "Heme"))
                                                        : ("Fe: " + (langManager ? langManager.t("nutrient_iron_non_heme") : "Plant"))
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: modelData.ironType === "heme" ? "#B91C1C" : "#047857"
                                                }
                                            }
                                        }
                                    }

                                    // Dynamic Sorted Nutrient Value Badge (Issue #24 / #32a)
                                    Rectangle {
                                        visible: root.sortBy !== "name" && root.sortBy !== "calories" && root.getSortedNutrientBadge(modelData) !== ""
                                        radius: 6
                                        color: "#EFF6FF"
                                        border.color: "#BFDBFE"
                                        implicitWidth: sortedNutrientLbl.implicitWidth + 10
                                        implicitHeight: 20
                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            Label {
                                                id: sortedNutrientLbl
                                                text: root.getSortedNutrientBadge(modelData)
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: "#1D4ED8"
                                            }
                                        }
                                    }

                                    // Macros Pill
                                    ColumnLayout {
                                        spacing: 1
                                        Label {
                                            text: Math.round(modelData.calories || 0) + " kcal"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#B45309"
                                            horizontalAlignment: Text.AlignRight
                                            Layout.alignment: Qt.AlignRight
                                        }
                                        Label {
                                            text: "C:" + Math.round(modelData.carbs || 0) + " P:" + Math.round(modelData.protein || 0) + " F:" + Math.round(modelData.fat || 0)
                                            font.pixelSize: 9
                                            color: "#78716C"
                                            horizontalAlignment: Text.AlignRight
                                            Layout.alignment: Qt.AlignRight
                                        }
                                    }

                                    // Chevron indicator
                                    Label {
                                        text: foodCard.isExpanded ? "▲" : "▼"
                                        font.pixelSize: 10
                                        color: foodCard.isExpanded ? "#B45309" : "#A8A29E"
                                    }
                                }
                            }
                        }

                        // ── Expanded Detail Section (Visible only when expanded) ──
                        ColumnLayout {
                            visible: foodCard.isExpanded
                            Layout.fillWidth: true
                            spacing: 8

                            // Divider
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#F5F5F4"
                            }

                            // ── 1. Macronutrients Card (per 100g) ─────────────
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 8
                                color: "#FAF8F5"
                                border.color: "#E7E5E4"
                                implicitHeight: macroCol.implicitHeight + 14

                                ColumnLayout {
                                    id: macroCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Label {
                                        text: "📊 " + (langManager ? langManager.t("nutrient_macros_energy") : "Macronutrients & Energy") + " " + (langManager ? langManager.t("per_100g") : "(per 100g)")
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#44403C"
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: root.isNarrow ? 2 : 3
                                        rowSpacing: 4
                                        columnSpacing: 6

                                        // Energy
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 6
                                            color: "#FFFBEB"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                Label { text: "⚡ " + (langManager ? langManager.t("nutrient_energy") : "Energy"); font.pixelSize: 10; color: "#92400E" }
                                                Item { Layout.fillWidth: true }
                                                Label { text: Math.round(modelData.calories || 0) + " kcal"; font.bold: true; font.pixelSize: 10; color: "#B45309" }
                                            }
                                        }

                                        // Protein
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 6
                                            color: "#ECFDF5"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                Label { text: "🍗 " + (langManager ? langManager.t("nutrient_protein") : "Protein"); font.pixelSize: 10; color: "#065F46" }
                                                Item { Layout.fillWidth: true }
                                                Label { text: (modelData.protein || 0).toFixed(1) + " g"; font.bold: true; font.pixelSize: 10; color: "#047857" }
                                            }
                                        }

                                        // Carbs
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 6
                                            color: "#EFF6FF"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                Label { text: "🌾 " + (langManager ? langManager.t("nutrient_carbs") : "Carbs"); font.pixelSize: 10; color: "#1E40AF" }
                                                Item { Layout.fillWidth: true }
                                                Label { text: (modelData.carbs || 0).toFixed(1) + " g"; font.bold: true; font.pixelSize: 10; color: "#1D4ED8" }
                                            }
                                        }

                                        // Fat
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 6
                                            color: "#FEF2F2"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                Label { text: "🥑 " + (langManager ? langManager.t("nutrient_fat") : "Fat"); font.pixelSize: 10; color: "#991B1B" }
                                                Item { Layout.fillWidth: true }
                                                Label { text: (modelData.fat || 0).toFixed(1) + " g"; font.bold: true; font.pixelSize: 10; color: "#B91C1C" }
                                            }
                                        }

                                        // Fiber
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 6
                                            color: "#F5F3FF"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                Label { text: "🌾 " + (langManager ? langManager.t("nutrient_fiber") : "Fiber"); font.pixelSize: 10; color: "#5B21B6" }
                                                Item { Layout.fillWidth: true }
                                                Label { text: (modelData.fiber || 0).toFixed(1) + " g"; font.bold: true; font.pixelSize: 10; color: "#6D28D9" }
                                            }
                                        }

                                        // GI Class
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 6
                                            color: "#F5F5F4"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                Label { text: "⏱️ " + (langManager ? langManager.t("nutrient_gi") : "GI"); font.pixelSize: 10; color: "#57534E" }
                                                Item { Layout.fillWidth: true }
                                                Label {
                                                    text: {
                                                        var gi = String(modelData.giClass || "medium").toLowerCase();
                                                        if (gi === "low") return langManager ? langManager.t("gi_low") : "Low";
                                                        if (gi === "high") return langManager ? langManager.t("gi_high") : "High";
                                                        return langManager ? langManager.t("gi_medium") : "Medium";
                                                    }
                                                    font.bold: true; font.pixelSize: 10; color: "#292524"
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── 2. Minerals & Micronutrients (Collapsible Subsection) ──
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 8
                                color: "#FFFFFF"
                                border.color: foodCard.mineralsExpanded ? "#BFDBFE" : "#E7E5E4"
                                implicitHeight: minCol.implicitHeight + 12

                                ColumnLayout {
                                    id: minCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    // Toggle header
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: 6
                                        color: minHover.containsMouse ? "#EFF6FF" : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            spacing: 6

                                            Label {
                                                text: "🦴 " + (langManager ? langManager.t("nutrient_minerals_vitamins") : "Minerals & Vitamins") + " " + (langManager ? langManager.t("per_100g") : "(per 100g)")
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: foodCard.mineralsExpanded ? "#1E40AF" : "#44403C"
                                                Layout.fillWidth: true
                                            }

                                            Label {
                                                text: foodCard.mineralsExpanded ? "▲" : "▼"
                                                font.pixelSize: 10
                                                color: "#64748B"
                                            }
                                        }

                                        MouseArea {
                                            id: minHover
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var key = String(modelData.id);
                                                var cur = Boolean(root.openSubsections[key]);
                                                var updated = Object.assign({}, root.openSubsections);
                                                updated[key] = !cur;
                                                root.openSubsections = updated;
                                            }
                                        }
                                    }

                                    // Minerals Content
                                    GridLayout {
                                        visible: foodCard.mineralsExpanded
                                        Layout.fillWidth: true
                                        columns: root.isNarrow ? 2 : 4
                                        rowSpacing: 4
                                        columnSpacing: 8

                                        // Iron
                                        Label { text: (langManager ? langManager.t("nutrient_iron") : "Iron (Fe)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label {
                                            text: (modelData.iron || 0).toFixed(1) + " mg (" +
                                                  (modelData.ironType === "heme"
                                                      ? (langManager ? langManager.t("nutrient_iron_heme") : "Heme")
                                                      : (langManager ? langManager.t("nutrient_iron_non_heme") : "Plant")) + ")"
                                            font.bold: true; font.pixelSize: 10
                                            color: modelData.ironType === "heme" ? "#B91C1C" : "#047857"
                                        }

                                        // Vitamin C
                                        Label { text: (langManager ? langManager.t("nutrient_vitamin_c") : "Vitamin C") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: Math.round(modelData.vitaminC || 0) + " mg"; font.bold: true; font.pixelSize: 10; color: "#D97706" }

                                        // Calcium
                                        Label { text: (langManager ? langManager.t("nutrient_calcium") : "Calcium (Ca)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: Math.round(modelData.calcium || 0) + " mg"; font.bold: true; font.pixelSize: 10; color: "#292524" }

                                        // Magnesium
                                        Label { text: (langManager ? langManager.t("nutrient_magnesium") : "Magnesium (Mg)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: Math.round(modelData.magnesium || 0) + " mg"; font.bold: true; font.pixelSize: 10; color: "#292524" }

                                        // Potassium
                                        Label { text: (langManager ? langManager.t("nutrient_potassium") : "Potassium (K)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: Math.round(modelData.potassium || 0) + " mg"; font.bold: true; font.pixelSize: 10; color: "#292524" }

                                        // Sodium
                                        Label { text: (langManager ? langManager.t("nutrient_sodium") : "Sodium (Na)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: Math.round(modelData.sodium || 0) + " mg"; font.bold: true; font.pixelSize: 10; color: "#292524" }

                                        // Zinc
                                        Label { text: (langManager ? langManager.t("nutrient_zinc") : "Zinc (Zn)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: (modelData.zinc || 0).toFixed(1) + " mg"; font.bold: true; font.pixelSize: 10; color: "#292524" }

                                        // Copper
                                        Label { text: (langManager ? langManager.t("nutrient_copper") : "Copper (Cu)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: (modelData.copper || 0).toFixed(2) + " mg"; font.bold: true; font.pixelSize: 10; color: "#292524" }

                                        // Omega-3
                                        Label { text: (langManager ? langManager.t("nutrient_omega3") : "Omega-3") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: (modelData.omega3 || 0).toFixed(2) + " g"; font.bold: true; font.pixelSize: 10; color: "#2563EB" }

                                        // Leucine
                                        Label { text: (langManager ? langManager.t("nutrient_leucine") : "L-Leucine (MPS)") + ":"; font.pixelSize: 10; color: "#57534E" }
                                        Label { text: (modelData.leucine || 0).toFixed(2) + " g"; font.bold: true; font.pixelSize: 10; color: "#047857" }
                                    }
                                }
                            }

                            // ── 3. Add to Meal Plan Action Card ───────────────
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 8
                                color: "#FEF3C7"
                                border.color: "#FDE68A"
                                implicitHeight: addCol.implicitHeight + 14

                                ColumnLayout {
                                    id: addCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Label {
                                        text: "➕ " + (langManager ? langManager.t("add_to_meal_btn") : "Add to Meal Plan")
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#92400E"
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // Target meal picker
                                        Label {
                                            text: langManager ? langManager.t("target_meal") : "Meal:"
                                            font.pixelSize: 10
                                            color: "#78716C"
                                        }

                                        ComboBox {
                                            id: mealCombo
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            font.pixelSize: 10
                                            model: root.availableMealOptions
                                            textRole: "title"
                                            currentIndex: root.findMealOptionIndex(root.targetMealIndex)
                                            onActivated: (idx) => {
                                                if (idx >= 0 && idx < root.availableMealOptions.length) {
                                                    root.targetMealIndex = root.availableMealOptions[idx].index;
                                                }
                                            }
                                        }

                                        // Amount input
                                        Label {
                                            text: langManager ? langManager.t("portion_size_g") : "Amount:"
                                            font.pixelSize: 10
                                            color: "#78716C"
                                        }

                                        SpinBox {
                                            id: portionSpin
                                            Layout.preferredWidth: 126
                                            Layout.preferredHeight: 32
                                            from: foodCard.isSpice ? 1 : 10
                                            to: foodCard.isSpice ? 250 : 1000
                                            stepSize: foodCard.isSpice ? 1 : 10
                                            value: foodCard.isSpice ? (modelData.servingSize > 0 ? modelData.servingSize : 2) : root.addAmount
                                            editable: true
                                            font.pixelSize: 11
                                            font.bold: true
                                            leftPadding: 28
                                            rightPadding: 28
                                            onValueModified: root.addAmount = value

                                            contentItem: TextInput {
                                                z: 2
                                                text: portionSpin.textFromValue(portionSpin.value, portionSpin.locale)
                                                font: portionSpin.font
                                                color: "#1C1917"
                                                selectionColor: "#F59E0B"
                                                selectedTextColor: "#FFFFFF"
                                                horizontalAlignment: Qt.AlignHCenter
                                                verticalAlignment: Qt.AlignVCenter
                                                readOnly: !portionSpin.editable
                                                validator: portionSpin.validator
                                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            }

                                            down.indicator: Rectangle {
                                                x: 0
                                                height: parent.height
                                                implicitWidth: 26
                                                radius: 6
                                                color: portionSpin.down.pressed ? "#FDE68A" : "#FEF3C7"
                                                border.color: "#F59E0B"
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "−"
                                                    font.bold: true
                                                    font.pixelSize: 13
                                                    color: portionSpin.value > portionSpin.from ? "#B45309" : "#D6D3D1"
                                                }
                                            }

                                            up.indicator: Rectangle {
                                                x: parent.width - width
                                                height: parent.height
                                                implicitWidth: 26
                                                radius: 6
                                                color: portionSpin.up.pressed ? "#FDE68A" : "#FEF3C7"
                                                border.color: "#F59E0B"
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    font.bold: true
                                                    font.pixelSize: 13
                                                    color: portionSpin.value < portionSpin.to ? "#B45309" : "#D6D3D1"
                                                }
                                            }

                                            background: Rectangle {
                                                implicitWidth: 126
                                                implicitHeight: 32
                                                radius: 6
                                                color: "#FFFFFF"
                                                border.color: "#F59E0B"
                                            }
                                        }

                                        // Add button
                                        Button {
                                            Layout.preferredHeight: 32
                                            text: "➕ " + (langManager ? langManager.t("add_to_meal_btn") : "Add")
                                            font.bold: true
                                            font.pixelSize: 10
                                            palette.buttonText: "#FFFFFF"
                                            background: Rectangle {
                                                radius: 6
                                                color: "#D97706"
                                            }
                                            onClicked: {
                                                if (root.mealPlanManager && root.availableMealOptions.length > 0) {
                                                    var sel = (mealCombo.currentIndex >= 0 && mealCombo.currentIndex < root.availableMealOptions.length)
                                                        ? root.availableMealOptions[mealCombo.currentIndex]
                                                        : root.availableMealOptions[0];
                                                    var targetIdx = sel ? sel.index : 0;
                                                    if (targetIdx < 0) {
                                                        // Create new default breakfast meal if plan was empty
                                                        targetIdx = root.mealPlanManager.addMeal(
                                                            (langManager && langManager.currentLanguage === "de") ? "Frühstück" : "Breakfast",
                                                            "08:00", "🍳", "#F59E0B"
                                                        );
                                                    }
                                                    root.mealPlanManager.addItemToMeal(targetIdx, modelData, portionSpin.value);
                                                    var mealTitle = (sel && sel.index >= 0) ? sel.title : ((langManager && langManager.currentLanguage === "de") ? "Frühstück" : "Breakfast");
                                                    root.feedbackMessage = (langManager
                                                        ? langManager.t("added_to_meal_feedback", [portionSpin.value, modelData.name, mealTitle])
                                                        : ("Added " + portionSpin.value + "g " + modelData.name + " to " + mealTitle + "!"));
                                                }
                                            }
                                        }
                                    }

                                    // Quick portion chips
                                    RowLayout {
                                        spacing: 4
                                        Repeater {
                                            model: foodCard.isSpice ? [1, 2, 5, 10, 15] : [50, 100, 150, 200, 250]
                                            delegate: Rectangle {
                                                width: 44
                                                height: 22
                                                radius: 4
                                                color: portionSpin.value === modelData ? "#D97706" : "#FFFFFF"
                                                border.color: "#D97706"
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: modelData + "g"
                                                    font.pixelSize: 9
                                                    font.bold: portionSpin.value === modelData
                                                    color: portionSpin.value === modelData ? "#FFFFFF" : "#B45309"
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        portionSpin.value = modelData;
                                                        root.addAmount = modelData;
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

                // Empty state placeholder
                Label {
                    anchors.centerIn: parent
                    visible: root.foodList.length === 0
                    text: langManager ? langManager.t("no_foods_found") : "No ingredients found. Adjust your search or filters."
                    font.pixelSize: 12
                    color: "#A8A29E"
                }
            }
        }
    }
}
