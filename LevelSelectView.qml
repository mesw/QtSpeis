import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#FDFBF7"

    property var gameLevelManager: null
    property var mealPlanManager: null
    property var foodDatabase: null
    property var langManager: null
    property var planConstraints: ({})

    // Map of expanded tiers: { 1: bool, 2: bool, 3: bool, 4: bool, 5: bool }
    property var expandedTiers: ({ 1: false, 2: false, 3: false, 4: false, 5: false })

    signal levelSelected(int levelId)
    signal closeRequested()

    function refreshConstraints() {
        if (gameLevelManager && mealPlanManager) {
            planConstraints = gameLevelManager.checkAllLevelConstraints(mealPlanManager);
        }
    }

    function brokenEarlierLevels() {
        if (!gameLevelManager || !gameLevelManager.allLevels || !planConstraints) return [];
        var curLvl = gameLevelManager.currentLevel;
        var broken = [];
        for (var i = 0; i < gameLevelManager.allLevels.length; ++i) {
            var lvl = gameLevelManager.allLevels[i];
            if (lvl.unlocked && lvl.id < curLvl) {
                var c = planConstraints[String(lvl.id)];
                if (c && !c.met) {
                    broken.push({ id: lvl.id, title: lvl.title, actual: c.actual, target: c.target, name: c.name });
                }
            }
        }
        return broken;
    }

    function totalEarnedStars() {
        if (!gameLevelManager || !gameLevelManager.allLevels) return 0;
        var s = 0;
        for (var i = 0; i < gameLevelManager.allLevels.length; ++i) {
            s += (gameLevelManager.allLevels[i].stars || 0);
        }
        return s;
    }

    function tierStars(tierNum) {
        if (!gameLevelManager || !gameLevelManager.allLevels) return 0;
        var s = 0;
        for (var i = 0; i < gameLevelManager.allLevels.length; ++i) {
            var lvl = gameLevelManager.allLevels[i];
            if (lvl.tier === tierNum) {
                s += (lvl.stars || 0);
            }
        }
        return s;
    }

    function tierHasUnsatisfied(tierNum) {
        if (!gameLevelManager || !gameLevelManager.allLevels) return false;
        for (var i = 0; i < gameLevelManager.allLevels.length; ++i) {
            var lvl = gameLevelManager.allLevels[i];
            if (lvl.tier === tierNum) {
                var c = planConstraints[String(lvl.id)];
                var stars = lvl.stars || 0;
                if (!c || !c.met || stars < 3) {
                    return true;
                }
            }
        }
        return false;
    }

    function determineInitialTierExpansion() {
        var newExpanded = { 1: false, 2: false, 3: false, 4: false, 5: false };
        var openedTier = 1;
        for (var t = 1; t <= 4; ++t) {
            if (tierHasUnsatisfied(t)) {
                openedTier = t;
                break;
            }
        }
        newExpanded[openedTier] = true;
        expandedTiers = newExpanded;
    }

    function toggleTier(tierNum) {
        var copy = Object.assign({}, expandedTiers);
        copy[tierNum] = !copy[tierNum];
        expandedTiers = copy;
    }

    Component.onCompleted: {
        refreshConstraints();
        determineInitialTierExpansion();
    }

    onVisibleChanged: {
        if (visible) {
            refreshConstraints();
            determineInitialTierExpansion();
        }
    }

    Connections {
        target: mealPlanManager
        function onPlanChanged() {
            root.refreshConstraints();
        }
    }

    Connections {
        target: gameLevelManager
        function onCurrentLevelChanged() {
            root.refreshConstraints();
        }
        function onEvaluationCompleted() {
            root.refreshConstraints();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.width < 600 ? 12 : 20
        spacing: 12

        // ── Top Navigation & Header Bar ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RoundButton {
                text: "← " + (langManager ? langManager.t("nav_back") : "Back")
                font.bold: true
                font.pixelSize: 12
                palette.buttonText: "#44403C"
                background: Rectangle { radius: 8; color: "#F5F5F4"; border.color: "#E7E5E4" }
                onClicked: root.closeRequested()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    spacing: 8
                    Label {
                        text: "⚔️ " + (langManager ? langManager.t("nutrition_quest_title") : "Nutrition Quest")
                        font.bold: true
                        font.pixelSize: root.width < 600 ? 16 : 20
                        color: "#292524"
                    }
                    Rectangle {
                        radius: 12
                        color: "#FEF3C7"
                        border.color: "#FDE68A"
                        implicitWidth: starLabel.implicitWidth + 14
                        implicitHeight: 22
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Label {
                                id: starLabel
                                text: "★ " + root.totalEarnedStars() + " / 72 Stars"
                                font.bold: true
                                font.pixelSize: 11
                                color: "#B45309"
                            }
                        }
                    }

                    // Broken earlier constraints warning icon button
                    Button {
                        id: brokenWarningBtn
                        visible: root.brokenEarlierLevels().length > 0
                        implicitWidth: brokenWarnRow.implicitWidth + 18
                        implicitHeight: 26
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: 26
                        flat: true
                        padding: 0
                        background: Rectangle {
                            radius: 8
                            color: "#FEE2E2"
                            border.color: "#F87171"
                        }
                        contentItem: RowLayout {
                            id: brokenWarnRow
                            spacing: 4
                            Label {
                                Layout.leftMargin: 8
                                text: "⚠"
                                font.pixelSize: 12
                                color: "#DC2626"
                            }
                            Label {
                                Layout.rightMargin: 8
                                text: root.brokenEarlierLevels().length + " " + ((langManager && langManager.currentLanguage === "de") ? "Regel-Verletzungen" : "Broken Rules")
                                font.bold: true
                                font.pixelSize: 10
                                color: "#DC2626"
                            }
                        }
                        onClicked: brokenDialog.open()
                    }
                }

                Label {
                    text: (langManager && langManager.currentLanguage === "de")
                        ? "24 Progressive Biochemische Level • 4 Stufen • 12 Optionale Helden-Modifikatoren"
                        : "24 Progressive Biochemical Levels • 4 Tiers • 12 Optional Hero Challenge Modifiers"
                    font.pixelSize: 11
                    color: "#78716C"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Quick Golden Plan button
            Button {
                visible: false //root.mealPlanManager !== null && root.width >= 560
                text: "🌟 " + qsTr("Golden Plan")
                font.bold: true
                font.pixelSize: 11
                palette.buttonText: "#92400E"
                background: Rectangle {
                    radius: 8
                    color: parent.down ? "#FDE68A" : "#FEF3C7"
                    border.color: "#F59E0B"
                    border.width: 1
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Load mathematically verified Golden Day Plan (satisfies all 24 levels simultaneously)")
                onClicked: {
                    if (gameLevelManager && mealPlanManager) {
                        gameLevelManager.loadGoldenPlan(mealPlanManager, foodDatabase);
                        root.closeRequested();
                    }
                }
            }

            // Quick Cheat Solve All button
            Button {
                visible: false //root.mealPlanManager !== null && root.width >= 560
                text: "👑 " + qsTr("Cheat (Solve All 24★)")
                font.bold: true
                font.pixelSize: 11
                palette.buttonText: "#7C2D12"
                background: Rectangle {
                    radius: 8
                    color: parent.down ? "#FED7AA" : "#FFEDD5"
                    border.color: "#EA580C"
                    border.width: 1
                }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Cheat: Load ideal plan and unlock/solve all 24 levels with 3 stars!")
                onClicked: {
                    if (gameLevelManager && mealPlanManager) {
                        gameLevelManager.cheatSolveAll(mealPlanManager, foodDatabase);
                        root.closeRequested();
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E7E5E4"
        }

        // ── Scrollable List of Collapsible Tiers ──────────────────────────────
        ScrollView {
            id: tiersScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: tiersCol.width

            ColumnLayout {
                id: tiersCol
                width: tiersScrollView.width - 8
                spacing: 14

                // Helper repeater for Tiers 1 to 4
                Repeater {
                    model: [
                        { tier: 1, titleKey: "tier_1_title", fallbackTitle: "Tier I: Energetics & Fuel Balance (Levels 1–6)", icon: "⚡", color: "#EFF6FF", border: "#BFDBFE", textColor: "#1D4ED8" },
                        { tier: 2, titleKey: "tier_2_title", fallbackTitle: "Tier II: Mineral & Electrolyte Stoichiometry (Levels 7–12)", icon: "🦴", color: "#ECFDF5", border: "#A7F3D0", textColor: "#047857" },
                        { tier: 3, titleKey: "tier_3_title", fallbackTitle: "Tier III: Chrono-Nutrition & Diurnal Gates (Levels 13–18)", icon: "☀️", color: "#FDF4FF", border: "#F5D0FE", textColor: "#7E22CE" },
                        { tier: 4, titleKey: "tier_4_title", fallbackTitle: "Tier IV: Grandmaster Synthesis (Levels 19–24)", icon: "👑", color: "#FEF2F2", border: "#FECACA", textColor: "#B91C1C" }
                    ]

                    delegate: Rectangle {
                        id: tierCard
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: modelData.border
                        border.width: 1
                        clip: true

                        property int tierNum: modelData.tier
                        property bool isExpanded: Boolean(root.expandedTiers[tierNum])
                        property bool hasUnsatisfied: root.tierHasUnsatisfied(tierNum)
                        property int stars: root.tierStars(tierNum)

                        implicitHeight: tierHeaderRect.height + (isExpanded ? (tierLevelsGrid.implicitHeight + 20) : 0)
                        Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // ── Collapsible Tier Header ───────────────────────
                            Rectangle {
                                id: tierHeaderRect
                                Layout.fillWidth: true
                                height: 50
                                color: tierHover.containsMouse ? modelData.color : "#FFFFFF"
                                radius: tierCard.isExpanded ? 12 : 12

                                MouseArea {
                                    id: tierHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleTier(tierCard.tierNum)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 10

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 8
                                        color: modelData.color
                                        Label {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.pixelSize: 15
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Label {
                                            text: langManager ? langManager.t(modelData.titleKey) : modelData.fallbackTitle
                                            font.bold: true
                                            font.pixelSize: 13
                                            color: modelData.textColor
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            text: "Levels " + ((tierCard.tierNum - 1) * 6 + 1) + " – " + (tierCard.tierNum * 6)
                                            font.pixelSize: 10
                                            color: "#78716C"
                                        }
                                    }

                                    // Star score pill for this tier
                                    Rectangle {
                                        radius: 10
                                        color: "#FEF3C7"
                                        border.color: "#FDE68A"
                                        implicitWidth: tierStarsLbl.implicitWidth + 12
                                        implicitHeight: 22
                                        Label {
                                            id: tierStarsLbl
                                            anchors.centerIn: parent
                                            text: "★ " + tierCard.stars + " / 18"
                                            font.bold: true
                                            font.pixelSize: 11
                                            color: "#B45309"
                                        }
                                    }

                                    // Satisfaction status pill
                                    Rectangle {
                                        radius: 10
                                        color: tierCard.hasUnsatisfied ? "#FEF3C7" : "#DCFCE7"
                                        border.color: tierCard.hasUnsatisfied ? "#FDE68A" : "#86EFAC"
                                        implicitWidth: tierStatusLbl.implicitWidth + 12
                                        implicitHeight: 22
                                        Label {
                                            id: tierStatusLbl
                                            anchors.centerIn: parent
                                            text: tierCard.hasUnsatisfied
                                                ? ((langManager && langManager.currentLanguage === "de") ? "⚠️ Offen" : "⚠️ Unsatisfied")
                                                : ((langManager && langManager.currentLanguage === "de") ? "✓ Erfüllt" : "✓ Satisfied")
                                            font.bold: true
                                            font.pixelSize: 10
                                            color: tierCard.hasUnsatisfied ? "#B45309" : "#15803D"
                                        }
                                    }

                                    // Chevron
                                    Label {
                                        text: tierCard.isExpanded ? "▲" : "▼"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: "#78716C"
                                    }
                                }
                            }

                            // Divider when expanded
                            Rectangle {
                                visible: tierCard.isExpanded
                                Layout.fillWidth: true
                                height: 1
                                color: "#E7E5E4"
                            }

                            // ── Levels Grid inside Expanded Tier ──────────────
                            Item {
                                visible: tierCard.isExpanded
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.margins: 10

                                GridLayout {
                                    id: tierLevelsGrid
                                    width: parent.width
                                    columns: (root.width < 540) ? 1 : Math.max(2, Math.floor(width / 260))
                                    rowSpacing: 10
                                    columnSpacing: 10

                                    Repeater {
                                        model: {
                                            if (!gameLevelManager || !gameLevelManager.allLevels) return [];
                                            var all = gameLevelManager.allLevels;
                                            var filtered = [];
                                            for (var i = 0; i < all.length; ++i) {
                                                if (all[i].tier === tierCard.tierNum) {
                                                    filtered.push(all[i]);
                                                }
                                            }
                                            return filtered;
                                        }

                                        delegate: Rectangle {
                                            id: levelTile
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 178
                                            radius: 12

                                            property bool isUnlocked: modelData.unlocked
                                            property int stars: modelData.stars || 0
                                            property var cData: root.planConstraints[String(modelData.id)] || ({})
                                            property bool isEarlierBroken: isUnlocked && (modelData.id < (gameLevelManager ? gameLevelManager.currentLevel : 1)) && (!cData.met)
                                            property bool isCurrent: isUnlocked && (modelData.id === (gameLevelManager ? gameLevelManager.currentLevel : 1))

                                            color: isUnlocked ? (isEarlierBroken ? "#FFF8F8" : "#FFFFFF") : "#F5F5F4"
                                            border.color: isUnlocked ? (tileHover.containsMouse ? (isEarlierBroken ? "#DC2626" : "#D97706") : (isEarlierBroken ? "#FCA5A5" : "#E2D9C8")) : "#E7E5E4"
                                            border.width: isUnlocked ? ((tileHover.containsMouse || isEarlierBroken) ? 2 : 1) : 1
                                            opacity: isUnlocked ? 1.0 : 0.65

                                            MouseArea {
                                                id: tileHover
                                                anchors.fill: parent
                                                hoverEnabled: isUnlocked
                                                cursorShape: isUnlocked ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    if (isUnlocked && gameLevelManager) {
                                                        gameLevelManager.currentLevel = modelData.id;
                                                        root.levelSelected(modelData.id);
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 4

                                                // Top row: ID, Badge, Current indicator, Stars
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6

                                                    Rectangle {
                                                        width: 24
                                                        height: 24
                                                        radius: 6
                                                        color: isUnlocked ? (isEarlierBroken ? "#FEE2E2" : "#FEF3C7") : "#E7E5E4"
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: modelData.id
                                                            font.bold: true
                                                            font.pixelSize: 11
                                                            color: isUnlocked ? (isEarlierBroken ? "#DC2626" : "#B45309") : "#78716C"
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: isUnlocked && modelData.id === (gameLevelManager ? gameLevelManager.currentLevel : 1)
                                                        radius: 4
                                                        color: "#FEF3C7"
                                                        border.color: "#F59E0B"
                                                        implicitWidth: curLbl.implicitWidth + 8
                                                        implicitHeight: 18
                                                        Label {
                                                            id: curLbl
                                                            anchors.centerIn: parent
                                                            text: (langManager && langManager.currentLanguage === "de") ? "AKTUELL" : "CURRENT"
                                                            font.bold: true
                                                            font.pixelSize: 9
                                                            color: "#B45309"
                                                        }
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    Row {
                                                        spacing: 2
                                                        visible: isUnlocked
                                                        Repeater {
                                                            model: 3
                                                            delegate: Label {
                                                                text: index < stars ? "★" : "☆"
                                                                font.pixelSize: 14
                                                                color: index < stars ? "#F59E0B" : "#D6D3D1"
                                                            }
                                                        }
                                                    }

                                                    Label {
                                                        visible: !isUnlocked
                                                        text: "🔒"
                                                        font.pixelSize: 13
                                                    }
                                                }

                                                // Level Title
                                                Label {
                                                    text: isUnlocked ? modelData.title : ("Level " + modelData.id + ": Locked")
                                                    font.bold: true
                                                    font.pixelSize: 12
                                                    color: isUnlocked ? (isEarlierBroken ? "#991B1B" : "#1C1917") : "#A8A29E"
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                // Detail Subtitle (Supports 2 Lines as requested!)
                                                Label {
                                                    text: {
                                                        if (!isUnlocked) return "Complete previous levels to unlock";
                                                        if (modelData.id === 1 && mealPlanManager) {
                                                            var tCal = Math.round(mealPlanManager.targetCalories);
                                                            var isDe = langManager && langManager.currentLanguage === "de";
                                                            return "⚡ " + tCal + " kcal • " + (isDe ? ("Zielwert: " + tCal + " kcal (±50 kcal)") : ("Target: " + tCal + " kcal (±50 kcal)"));
                                                        }
                                                        var badgeStr = String(modelData.badge || "").replace(/\uFE0F/g, "");
                                                        var subStr = String(modelData.subtitle || "");
                                                        var firstSpace = badgeStr.indexOf(" ");
                                                        var iconPrefix = firstSpace > 0 ? badgeStr.substring(0, firstSpace) : "";
                                                        return iconPrefix ? (iconPrefix + " " + subStr) : (badgeStr + " • " + subStr);
                                                    }
                                                    font.pixelSize: 10
                                                    color: isUnlocked ? "#57534E" : "#A8A29E"
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                // Constraint Status Pill
                                                Rectangle {
                                                    id: constraintPill
                                                    Layout.fillWidth: true
                                                    height: 24
                                                    radius: 5
                                                    visible: levelTile.isUnlocked && Boolean(levelTile.cData.actual || levelTile.cData.target)

                                                    color: levelTile.isEarlierBroken ? "#FEE2E2" : (levelTile.cData.met ? "#F0FDF4" : (levelTile.isCurrent ? "#FFFBEB" : "#F5F5F4"))
                                                    border.color: levelTile.isEarlierBroken ? "#FCA5A5" : (levelTile.cData.met ? "#86EFAC" : (levelTile.isCurrent ? "#FDE68A" : "#E7E5E4"))
                                                    border.width: 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 6
                                                        anchors.rightMargin: 6
                                                        spacing: 4

                                                        Label {
                                                            text: levelTile.isEarlierBroken ? "⚠️" : (levelTile.cData.met ? "✓" : (levelTile.isCurrent ? "🎯" : "•"))
                                                            font.pixelSize: 10
                                                            color: levelTile.isEarlierBroken ? "#DC2626" : (levelTile.cData.met ? "#16A34A" : (levelTile.isCurrent ? "#D97706" : "#78716C"))
                                                        }

                                                        Label {
                                                            text: levelTile.cData.actual ? levelTile.cData.actual : (levelTile.cData.met ? "Met" : "Pending")
                                                            font.bold: Boolean(levelTile.cData.met || levelTile.isEarlierBroken)
                                                            font.pixelSize: 9
                                                            color: levelTile.isEarlierBroken ? "#B91C1C" : (levelTile.cData.met ? "#15803D" : (levelTile.isCurrent ? "#B45309" : "#78716C"))
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }
                                                }

                                                Item { Layout.fillHeight: true }

                                                // Select Level Button
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 24
                                                    radius: 6
                                                    color: isUnlocked ? (tileHover.containsMouse ? "#D97706" : "#FEF3C7") : "#E7E5E4"
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: isUnlocked
                                                            ? ((langManager && langManager.currentLanguage === "de") ? "Level auswählen →" : "Select Level →")
                                                            : ((langManager && langManager.currentLanguage === "de") ? "Gesperrt" : "Locked")
                                                        font.bold: true
                                                        font.pixelSize: 10
                                                        color: isUnlocked ? (tileHover.containsMouse ? "#FFFFFF" : "#92400E") : "#78716C"
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

                // ── Hero Challenges Collapsible Card ──────────────────────────
                Rectangle {
                    id: heroCard
                    Layout.fillWidth: true
                    radius: 12
                    color: "#FFFFFF"
                    border.color: "#FECACA"
                    border.width: 1
                    clip: true

                    property bool isExpanded: Boolean(root.expandedTiers[5])
                    property int activeCount: gameLevelManager ? gameLevelManager.activeHeroModifiers.length : 0

                    implicitHeight: heroHeaderRect.height + (isExpanded ? (heroInnerCol.implicitHeight + 20) : 0)
                    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Header
                        Rectangle {
                            id: heroHeaderRect
                            Layout.fillWidth: true
                            height: 50
                            color: heroHover.containsMouse ? "#FEF2F2" : "#FFFFFF"
                            radius: 12

                            MouseArea {
                                id: heroHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleTier(5)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 8
                                    color: "#FEE2E2"
                                    Label {
                                        anchors.centerIn: parent
                                        text: "⚔️"
                                        font.pixelSize: 15
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Label {
                                        text: langManager ? langManager.t("hero_challenges_title") : "Hero Challenges (12 Modifiers)"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: "#991B1B"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        text: (langManager && langManager.currentLanguage === "de")
                                            ? "Optionale diätetische Einschränkungen für zusätzliche Meisterschaft"
                                            : "Optional dietary exclusions on top of campaign levels"
                                        font.pixelSize: 10
                                        color: "#78716C"
                                    }
                                }

                                Rectangle {
                                    radius: 10
                                    color: heroCard.activeCount > 0 ? "#FEE2E2" : "#F5F5F4"
                                    border.color: heroCard.activeCount > 0 ? "#FCA5A5" : "#E7E5E4"
                                    implicitWidth: heroActiveLbl.implicitWidth + 12
                                    implicitHeight: 22
                                    Label {
                                        id: heroActiveLbl
                                        anchors.centerIn: parent
                                        text: heroCard.activeCount + " Active"
                                        font.bold: true
                                        font.pixelSize: 10
                                        color: heroCard.activeCount > 0 ? "#B91C1C" : "#78716C"
                                    }
                                }

                                Label {
                                    text: heroCard.isExpanded ? "▲" : "▼"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: "#78716C"
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            visible: heroCard.isExpanded
                            Layout.fillWidth: true
                            height: 1
                            color: "#E7E5E4"
                        }

                        // Hero List Body
                        Item {
                            visible: heroCard.isExpanded
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 10

                            ColumnLayout {
                                id: heroInnerCol
                                width: parent.width
                                spacing: 8

                                Button {
                                    text: (langManager && langManager.currentLanguage === "de") ? "Alle Helden-Herausforderungen zurücksetzen" : "Clear All Heroes"
                                    visible: heroCard.activeCount > 0
                                    font.pixelSize: 11
                                    palette.buttonText: "#DC2626"
                                    background: Rectangle { radius: 6; color: "#FEE2E2"; border.color: "#FECACA" }
                                    onClicked: {
                                        if (gameLevelManager) gameLevelManager.clearHeroModifiers();
                                    }
                                }

                                Repeater {
                                    model: gameLevelManager ? gameLevelManager.heroModifiers : []

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: singleHeroCol.implicitHeight + 16
                                        radius: 8
                                        color: modelData.active ? "#FEF2F2" : "#FFFFFF"
                                        border.color: modelData.active ? "#F87171" : "#E7E5E4"
                                        border.width: modelData.active ? 2 : 1

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (gameLevelManager) gameLevelManager.toggleHeroModifier(modelData.id);
                                            }
                                        }

                                        ColumnLayout {
                                            id: singleHeroCol
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 4

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Rectangle {
                                                    width: 26
                                                    height: 26
                                                    radius: 6
                                                    color: modelData.active ? "#DC2626" : "#F5F5F4"
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: modelData.id
                                                        font.bold: true
                                                        font.pixelSize: 11
                                                        color: modelData.active ? "#FFFFFF" : "#78716C"
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Label {
                                                        text: modelData.badge + " — " + modelData.title
                                                        font.bold: true
                                                        font.pixelSize: 12
                                                        color: modelData.active ? "#991B1B" : "#1C1917"
                                                    }
                                                    Label {
                                                        text: modelData.flavor
                                                        font.pixelSize: 10
                                                        color: "#78716C"
                                                        wrapMode: Text.WordWrap
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                CheckBox {
                                                    checked: modelData.active
                                                    onToggled: {
                                                        if (gameLevelManager) gameLevelManager.toggleHeroModifier(modelData.id);
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
            }
        }
    }

    // ── Broken Rules Details Dialog ──────────────────────────────────────────
    Dialog {
        id: brokenDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(500, root.width - 24)
        title: langManager ? langManager.t("constraint_broken_title") : "Violated Earlier Level Rules"
        standardButtons: Dialog.Close

        contentItem: ColumnLayout {
            spacing: 10
            Label {
                text: langManager ? langManager.t("constraint_broken_desc") : "Your current meal plan violates rules from previously unlocked levels:"
                font.pixelSize: 11
                color: "#57534E"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(240, brokenRepeater.count * 52)
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        id: brokenRepeater
                        model: root.brokenEarlierLevels()

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: bRow.implicitHeight + 12
                            radius: 8
                            color: "#FEF2F2"
                            border.color: "#FECACA"

                            RowLayout {
                                id: bRow
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Label { text: "⚠️"; font.pixelSize: 14 }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Label {
                                        text: "Level " + modelData.id + ": " + modelData.name
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#B91C1C"
                                    }
                                    Label {
                                        text: "Aktuell: " + modelData.actual + " (Soll: " + modelData.target + ")"
                                        font.pixelSize: 10
                                        color: "#7F1D1D"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
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
