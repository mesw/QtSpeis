import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(540, parent.width - 16)
    height: Math.min(680, parent.height - 20)
    padding: 0

    property var savegameManager: null
    property var mealPlanManager: null
    property var gameLevelManager: null
    property var langManager: null

    readonly property bool isNarrow: root.width < 440
    property int currentTab: 0 // 0 = Save Slots, 1 = Files & Backup

    property string selectedSlotId: ""
    property string selectedSlotName: ""

    Connections {
        target: savegameManager
        function onSavegameLoaded() {
            feedbackBanner.show("Savegame loaded successfully!");
        }
        function onImportFailed(err) {
            feedbackBanner.show("Import error: " + err);
        }
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
                width: 34
                height: 34
                radius: 8
                color: "#DCFCE7"
                border.color: "#86EFAC"
                Label {
                    anchors.centerIn: parent
                    text: "💾"
                    font.pixelSize: 16
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: langManager ? langManager.t("save_game") : "Savegame & Meal Plan Storage"
                    font.bold: true
                    font.pixelSize: root.isNarrow ? 13 : 15
                    color: "#1C1917"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: langManager ? langManager.t("savegame_dialog_subtitle") : "Named slots in local storage, files (.json), and autosave"
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

        // Sub-Tab Switcher (Save Slots vs Files & Backup)
        Rectangle {
            Layout.fillWidth: true
            height: 36
            radius: 8
            color: "#F1F5F9"
            border.color: "#E2E8F0"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: root.currentTab === 0 ? "#FFFFFF" : "transparent"
                    border.color: root.currentTab === 0 ? "#CBD5E1" : "transparent"
                    Button {
                        anchors.fill: parent
                        flat: true
                        contentItem: Label {
                            text: (langManager ? langManager.t("tab_slots") : "📁 Save Slots") + " (" + (savegameManager ? savegameManager.slotCount : 0) + ")"
                            font.bold: root.currentTab === 0
                            font.pixelSize: 11
                            color: root.currentTab === 0 ? "#D97706" : "#64748B"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.currentTab = 0
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: root.currentTab === 1 ? "#FFFFFF" : "transparent"
                    border.color: root.currentTab === 1 ? "#CBD5E1" : "transparent"
                    Button {
                        anchors.fill: parent
                        flat: true
                        contentItem: Label {
                            text: langManager ? langManager.t("tab_files") : "💾 Files & Backup"
                            font.bold: root.currentTab === 1
                            font.pixelSize: 11
                            color: root.currentTab === 1 ? "#D97706" : "#64748B"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.currentTab = 1
                    }
                }
            }
        }

        // Scrollable Body
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: root.isNarrow ? 8 : 12

                // ==========================================
                // TAB 0: NAMED SAVEGAME SLOTS (NO FILES REQUIRED)
                // ==========================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.currentTab === 0

                    // Create New Save Slot Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 10
                        color: "#FFFFFF"
                        border.color: "#E2D9C8"
                        border.width: 1
                        implicitHeight: newSlotCol.implicitHeight + (root.isNarrow ? 14 : 20)

                        ColumnLayout {
                            id: newSlotCol
                            anchors.fill: parent
                            anchors.margins: root.isNarrow ? 10 : 14
                            spacing: 8

                            Label {
                                text: qsTr("💾 Save Current Plan to Named Slot:")
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1C1917"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    id: slotNameInput
                                    Layout.fillWidth: true
                                    placeholderText: qsTr("Slot name (e.g. Level 2 - Balanced)...")
                                    font.pixelSize: 12
                                    selectByMouse: true
                                    background: Rectangle {
                                        radius: 6
                                        color: "#FAFAF9"
                                        border.color: slotNameInput.activeFocus ? "#D97706" : "#D6D3D1"
                                    }
                                    onAccepted: saveSlotBtn.clicked()
                                }

                                Button {
                                    id: saveSlotBtn
                                    text: qsTr("💾 Save Slot")
                                    font.bold: true
                                    font.pixelSize: 11
                                    palette.buttonText: "#FFFFFF"
                                    background: Rectangle {
                                        radius: 6
                                        color: "#D97706"
                                    }
                                    onClicked: {
                                        let name = slotNameInput.text.trim();
                                        if (name.length === 0) {
                                            let lvl = gameLevelManager ? gameLevelManager.currentLevel : 1;
                                            name = "Level " + lvl + " Plan";
                                        }
                                        if (savegameManager && mealPlanManager && gameLevelManager) {
                                            let ok = savegameManager.saveToSlot(name, mealPlanManager, gameLevelManager, langManager ? langManager.currentLanguage : "en");
                                            if (ok) {
                                                feedbackBanner.show("Saved to slot '" + name + "'!");
                                                slotNameInput.text = "";
                                            }
                                        }
                                    }
                                }
                            }

                            Label {
                                text: qsTr("Saves your current meals, workout, level stars, and user profile locally (persists across reloads).")
                                font.pixelSize: 10
                                color: "#78716C"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Slots List Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 10
                        color: "#FFFFFF"
                        border.color: "#E2D9C8"
                        border.width: 1
                        implicitHeight: slotsListCol.implicitHeight + (root.isNarrow ? 14 : 20)

                        ColumnLayout {
                            id: slotsListCol
                            anchors.fill: parent
                            anchors.margins: root.isNarrow ? 10 : 14
                            spacing: 8

                            Label {
                                text: qsTr("📁 Saved Slots") + " (" + (savegameManager ? savegameManager.slotCount : 0) + "):"
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1C1917"
                            }

                            // Empty State
                            Label {
                                visible: !savegameManager || savegameManager.slotCount === 0
                                text: langManager ? langManager.t("no_slots_hint") : "No custom save slots yet. Enter a name above to save your current plan!"
                                font.pixelSize: 11
                                color: "#78716C"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            // Slots Repeater
                            Repeater {
                                model: savegameManager ? savegameManager.saveSlots : []

                                delegate: Rectangle {
                                    id: slotDelegate
                                    Layout.fillWidth: true
                                    radius: 8
                                    color: "#F8FAFC"
                                    border.color: "#E2E8F0"
                                    border.width: 1
                                    implicitHeight: slotCardCol.implicitHeight + 14

                                    ColumnLayout {
                                        id: slotCardCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Label {
                                                text: "🍱"
                                                font.pixelSize: 14
                                            }

                                            Label {
                                                text: modelData.name || "Unnamed Slot"
                                                font.bold: true
                                                font.pixelSize: 12
                                                color: "#0F172A"
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: modelData.savedAt || ""
                                                font.pixelSize: 10
                                                color: "#64748B"
                                            }
                                        }

                                        Label {
                                            text: modelData.summary || ""
                                            font.pixelSize: 11
                                            color: "#334155"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Button {
                                                text: "▶️ " + (langManager ? langManager.t("load_slot_btn") : "Load")
                                                font.bold: true
                                                font.pixelSize: 11
                                                palette.buttonText: "#15803D"
                                                background: Rectangle {
                                                    radius: 6
                                                    color: "#DCFCE7"
                                                    border.color: "#86EFAC"
                                                }
                                                onClicked: {
                                                    root.selectedSlotId = modelData.id;
                                                    root.selectedSlotName = modelData.name;
                                                    confirmLoadSlotDialog.open();
                                                }
                                            }

                                            Button {
                                                text: "🔄 " + (langManager ? langManager.t("overwrite_slot_btn") : "Overwrite")
                                                font.pixelSize: 11
                                                palette.buttonText: "#D97706"
                                                background: Rectangle {
                                                    radius: 6
                                                    color: "#FEF3C7"
                                                    border.color: "#FDE68A"
                                                }
                                                onClicked: {
                                                    root.selectedSlotId = modelData.id;
                                                    root.selectedSlotName = modelData.name;
                                                    confirmOverwriteSlotDialog.open();
                                                }
                                            }

                                            Button {
                                                text: "📥 Export"
                                                font.pixelSize: 11
                                                palette.buttonText: "#2563EB"
                                                background: Rectangle {
                                                    radius: 6
                                                    color: "#EFF6FF"
                                                    border.color: "#BFDBFE"
                                                }
                                                onClicked: {
                                                    if (savegameManager) {
                                                        savegameManager.exportSlotToFile(modelData.id);
                                                        feedbackBanner.show("Slot '" + modelData.name + "' exported as file.");
                                                    }
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            RoundButton {
                                                text: "🗑️"
                                                flat: true
                                                font.pixelSize: 12
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                palette.buttonText: "#DC2626"
                                                ToolTip.visible: hovered
                                                ToolTip.text: langManager ? langManager.t("delete_slot_btn") : "Delete"
                                                onClicked: {
                                                    root.selectedSlotId = modelData.id;
                                                    root.selectedSlotName = modelData.name;
                                                    confirmDeleteSlotDialog.open();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // TAB 1: FILES, CLIPBOARD & JSON BACKUP
                // ==========================================
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.currentTab === 1

                    // Current Storage Status Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 10
                        color: "#F8FAFC"
                        border.color: "#E2E8F0"
                        implicitHeight: statusCol.implicitHeight + (root.isNarrow ? 14 : 20)

                        ColumnLayout {
                            id: statusCol
                            anchors.fill: parent
                            anchors.margins: root.isNarrow ? 8 : 12
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: "#16A34A"
                                }
                                Label {
                                    text: langManager ? langManager.t("saved_in_browser") : "Autosave is Active in Browser"
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: "#15803D"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: (savegameManager && savegameManager.hasSavedGame) ? "✓ Synced" : "Pending"
                                    font.pixelSize: 10
                                    color: "#64748B"
                                }
                            }

                            Label {
                                text: savegameManager ? savegameManager.savegameSummary : "Ready"
                                font.bold: true
                                font.pixelSize: 11
                                color: "#0F172A"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: qsTr("Last autosaved:") + " " + (savegameManager ? savegameManager.lastSavedTime : "-")
                                font.pixelSize: 10
                                color: "#64748B"
                            }
                        }
                    }

                    // Action Buttons Grid
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.isNarrow ? 1 : 2
                        rowSpacing: 6
                        columnSpacing: 6

                        // Export to File
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.isNarrow ? 38 : 42
                            text: qsTr("📤 Export File (.json)")
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#15803D"
                            background: Rectangle {
                                radius: 8
                                color: "#DCFCE7"
                                border.color: "#86EFAC"
                            }
                            onClicked: {
                                if (savegameManager && mealPlanManager && gameLevelManager) {
                                    savegameManager.exportToFile(mealPlanManager, gameLevelManager, langManager ? langManager.currentLanguage : "en");
                                    feedbackBanner.show("Savegame downloaded as speis_mealplan.json");
                                }
                            }
                        }

                        // Import from File
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.isNarrow ? 38 : 42
                            text: qsTr("📥 Import File (.json)")
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#2563EB"
                            background: Rectangle {
                                radius: 8
                                color: "#EFF6FF"
                                border.color: "#BFDBFE"
                            }
                            onClicked: {
                                if (savegameManager && mealPlanManager && gameLevelManager) {
                                    savegameManager.requestImportFromFile(mealPlanManager, gameLevelManager, langManager);
                                    feedbackBanner.show("File picker opened. Select your .json savegame.");
                                }
                            }
                        }

                        // Copy to Clipboard
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.isNarrow ? 38 : 42
                            text: qsTr("📋 Copy JSON")
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#475569"
                            background: Rectangle {
                                radius: 8
                                color: "#F1F5F9"
                                border.color: "#CBD5E1"
                            }
                            onClicked: {
                                if (savegameManager && mealPlanManager && gameLevelManager) {
                                    let json = savegameManager.exportSavegameJson(mealPlanManager, gameLevelManager, langManager ? langManager.currentLanguage : "en");
                                    savegameManager.copyToClipboard(json);
                                    feedbackBanner.show("Savegame copied to clipboard!");
                                }
                            }
                        }

                        // Reset to Sample Plan
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.isNarrow ? 38 : 42
                            text: qsTr("🔄 Reset Sample Plan")
                            visible: false
                            font.bold: true
                            font.pixelSize: 11
                            palette.buttonText: "#D97706"
                            background: Rectangle {
                                radius: 8
                                color: "#FEF3C7"
                                border.color: "#FDE68A"
                            }
                            onClicked: {
                                if (mealPlanManager) {
                                    mealPlanManager.loadSamplePlan();
                                    if (savegameManager && gameLevelManager) {
                                        savegameManager.autoSave(mealPlanManager, gameLevelManager, langManager ? langManager.currentLanguage : "en");
                                    }
                                    feedbackBanner.show("Reset to default 4-meal sample plan.");
                                }
                            }
                        }
                    }

                    // Direct Paste Section
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 10
                        color: "#FAFAF9"
                        border.color: "#E7E5E4"
                        implicitHeight: pasteCol.implicitHeight + (root.isNarrow ? 14 : 20)

                        ColumnLayout {
                            id: pasteCol
                            anchors.fill: parent
                            anchors.margins: root.isNarrow ? 8 : 12
                            spacing: 6

                            Label {
                                text: qsTr("Paste JSON Savegame Directly:")
                                font.bold: true
                                font.pixelSize: 11
                                color: "#44403C"
                            }

                            TextArea {
                                id: pasteArea
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                placeholderText: langManager ? langManager.t("paste_json_placeholder") : "Paste {\"app\":\"Speis\", ...} JSON here..."
                                font.pixelSize: 11
                                wrapMode: Text.WrapAnywhere
                                selectByMouse: true
                                background: Rectangle {
                                    radius: 6
                                    color: "#FFFFFF"
                                    border.color: "#D6D3D1"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Button {
                                    text: langManager ? langManager.t("load_pasted_plan") : "Load Pasted Plan"
                                    font.bold: true
                                    font.pixelSize: 11
                                    palette.buttonText: "#FFFFFF"
                                    background: Rectangle { radius: 6; color: "#D97706" }
                                    onClicked: {
                                        let text = pasteArea.text.trim();
                                        if (text.length > 0 && savegameManager && mealPlanManager && gameLevelManager) {
                                            let ok = savegameManager.importSavegameJson(text, mealPlanManager, gameLevelManager, langManager);
                                            if (ok) {
                                                feedbackBanner.show(langManager ? langManager.t("savegame_restored_success") : "Savegame successfully restored!");
                                                pasteArea.text = "";
                                            } else {
                                                feedbackBanner.show(langManager ? langManager.t("savegame_json_invalid") : "Failed to load JSON. Please verify structure.");
                                            }
                                        }
                                    }
                                }

                                Button {
                                    text: langManager ? langManager.t("clear_btn") : "Clear"
                                    font.pixelSize: 11
                                    flat: true
                                    onClicked: pasteArea.text = ""
                                }
                            }
                        }
                    }
                }

                // Feedback banner
                Rectangle {
                    id: feedbackBanner
                    Layout.fillWidth: true
                    implicitHeight: bannerLbl.implicitHeight + 12
                    radius: 6
                    color: "#DCFCE7"
                    border.color: "#86EFAC"
                    visible: bannerLbl.text.length > 0

                    function show(msg) {
                        bannerLbl.text = msg;
                        hideTimer.restart();
                    }

                    Label {
                        id: bannerLbl
                        anchors.centerIn: parent
                        text: ""
                        font.bold: true
                        font.pixelSize: 11
                        color: "#15803D"
                        wrapMode: Text.WordWrap
                    }

                    Timer {
                        id: hideTimer
                        interval: 4000
                        onTriggered: bannerLbl.text = ""
                    }
                }
            }
        }
    }

    // --- Confirmation Dialog for Loading a Slot ---
    Dialog {
        id: confirmLoadSlotDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, (Overlay.overlay ? Overlay.overlay.width : 400) - 24)
        padding: 20
        background: Rectangle {
            color: "#FFFFFF"
            radius: 16
            border.color: "#E2E8F0"
        }
        contentItem: ColumnLayout {
            spacing: 12
            RowLayout {
                spacing: 8
                Label { text: "🍱"; font.pixelSize: 18 }
                Label {
                    text: langManager ? langManager.t("confirm_load_slot_title") : "Load Save Slot?"
                    font.bold: true
                    font.pixelSize: 15
                    color: "#1E293B"
                    Layout.fillWidth: true
                }
            }
            Label {
                text: (langManager ? langManager.t("confirm_load_slot_msg", [root.selectedSlotName]) : ("Load '" + root.selectedSlotName + "'? Any unsaved changes in your current plan will be replaced."))
                font.pixelSize: 12
                color: "#475569"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Layout.topMargin: 4
                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("cancel_btn") : "Cancel"
                    onClicked: confirmLoadSlotDialog.close()
                }
                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("load_slot_btn") : "Load"
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle { radius: 6; color: "#16A34A" }
                    onClicked: {
                        confirmLoadSlotDialog.close();
                        if (savegameManager && mealPlanManager && gameLevelManager) {
                            let ok = savegameManager.loadFromSlot(root.selectedSlotId, mealPlanManager, gameLevelManager, langManager);
                            if (ok) {
                                feedbackBanner.show("Loaded save slot '" + root.selectedSlotName + "'!");
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Confirmation Dialog for Overwriting a Slot ---
    Dialog {
        id: confirmOverwriteSlotDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, (Overlay.overlay ? Overlay.overlay.width : 400) - 24)
        padding: 20
        background: Rectangle {
            color: "#FFFFFF"
            radius: 16
            border.color: "#E2E8F0"
        }
        contentItem: ColumnLayout {
            spacing: 12
            RowLayout {
                spacing: 8
                Label { text: "🔄"; font.pixelSize: 18 }
                Label {
                    text: langManager ? langManager.t("confirm_overwrite_slot_title") : "Overwrite Save Slot?"
                    font.bold: true
                    font.pixelSize: 15
                    color: "#B45309"
                    Layout.fillWidth: true
                }
            }
            Label {
                text: (langManager ? langManager.t("confirm_overwrite_slot_msg", [root.selectedSlotName]) : ("Overwrite '" + root.selectedSlotName + "' with your current meal plan and progress?"))
                font.pixelSize: 12
                color: "#475569"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Layout.topMargin: 4
                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("cancel_btn") : "Cancel"
                    onClicked: confirmOverwriteSlotDialog.close()
                }
                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("overwrite_slot_btn") : "Overwrite"
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle { radius: 6; color: "#D97706" }
                    onClicked: {
                        confirmOverwriteSlotDialog.close();
                        if (savegameManager && mealPlanManager && gameLevelManager) {
                            let ok = savegameManager.overwriteSlot(root.selectedSlotId, mealPlanManager, gameLevelManager, langManager ? langManager.currentLanguage : "en");
                            if (ok) {
                                feedbackBanner.show("Slot '" + root.selectedSlotName + "' updated with current plan!");
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Confirmation Dialog for Deleting a Slot ---
    Dialog {
        id: confirmDeleteSlotDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, (Overlay.overlay ? Overlay.overlay.width : 400) - 24)
        padding: 20
        background: Rectangle {
            color: "#FFFFFF"
            radius: 16
            border.color: "#E2E8F0"
        }
        contentItem: ColumnLayout {
            spacing: 12
            RowLayout {
                spacing: 8
                Label { text: "🗑️"; font.pixelSize: 18 }
                Label {
                    text: langManager ? langManager.t("confirm_delete_slot_title") : "Delete Save Slot?"
                    font.bold: true
                    font.pixelSize: 15
                    color: "#DC2626"
                    Layout.fillWidth: true
                }
            }
            Label {
                text: (langManager ? langManager.t("confirm_delete_slot_msg", [root.selectedSlotName]) : ("Are you sure you want to delete '" + root.selectedSlotName + "'?"))
                font.pixelSize: 12
                color: "#475569"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Layout.topMargin: 4
                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("cancel_btn") : "Cancel"
                    onClicked: confirmDeleteSlotDialog.close()
                }
                Button {
                    Layout.fillWidth: true
                    text: langManager ? langManager.t("delete_slot_btn") : "Delete"
                    palette.buttonText: "#FFFFFF"
                    background: Rectangle { radius: 6; color: "#DC2626" }
                    onClicked: {
                        confirmDeleteSlotDialog.close();
                        if (savegameManager) {
                            savegameManager.deleteSlot(root.selectedSlotId);
                            feedbackBanner.show("Slot '" + root.selectedSlotName + "' deleted.");
                        }
                    }
                }
            }
        }
    }
}
