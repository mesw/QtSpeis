import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: ""
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(560, parent.width - 32)
    height: Math.min(640, parent.height - 32)
    padding: 0

    property var targetMealIndex: 0
    property var mealPlanManager: null
    property var foodDb: null
    property var currentProduct: null
    property bool cameraActive: false

    background: Rectangle {
        color: "#FFFDF9"
        radius: 16
        border.color: "#E2D9C8"
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 5
            color: "#D97706"
            radius: 3
        }
    }

    contentItem: ColumnLayout {
        spacing: 16
        anchors.fill: parent
        anchors.margins: 20

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 40
                height: 40
                radius: 10
                color: "#FEF3C7"
                Label {
                    anchors.centerIn: parent
                    text: "📷"
                    font.pixelSize: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: qsTr("Scan Barcode / Open Food Facts")
                    font.bold: true
                    font.pixelSize: 18
                    color: "#292524"
                }
                Label {
                    text: qsTr("Fetch real nutritional data directly via Open Food Facts API")
                    font.pixelSize: 12
                    color: "#78716C"
                }
            }

            RoundButton {
                text: "✕"
                flat: true
                font.pixelSize: 16
                font.bold: true
                palette.buttonText: "#78716C"
                onClicked: root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E7E5E4"
        }

        // Barcode input row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: barcodeField
                Layout.fillWidth: true
                placeholderText: langManager ? langManager.t("barcode_placeholder") : "Enter EAN/UPC Barcode (e.g. 5201051001078)..."
                font.pixelSize: 13
                selectByMouse: true
                color: "#1C1917"
                background: Rectangle {
                    radius: 8
                    color: "#FFFFFF"
                    border.color: barcodeField.activeFocus ? "#D97706" : "#D6D3D1"
                    border.width: barcodeField.activeFocus ? 2 : 1
                }
                onAccepted: searchBtn.clicked()
            }

            Button {
                id: camToggleBtn
                text: root.cameraActive ? "⏹ Stop Cam" : "📷 Camera"
                font.bold: true
                font.pixelSize: 12
                palette.buttonText: root.cameraActive ? "#DC2626" : "#44403C"
                background: Rectangle {
                    radius: 8
                    color: root.cameraActive ? "#FEE2E2" : "#FEF3C7"
                    border.color: root.cameraActive ? "#FCA5A5" : "#F59E0B"
                }
                onClicked: {
                    root.cameraActive = !root.cameraActive;
                }
            }

            Button {
                id: searchBtn
                text: offFetcher.isLoading ? "Fetching..." : "🔍 Lookup"
                enabled: !offFetcher.isLoading && barcodeField.text.trim().length > 0
                font.bold: true
                font.pixelSize: 13
                palette.buttonText: "#FFFFFF"
                background: Rectangle {
                    radius: 8
                    color: searchBtn.enabled ? "#D97706" : "#A8A29E"
                }
                onClicked: {
                    root.cameraActive = false;
                    offFetcher.lookupBarcode(barcodeField.text.trim());
                }
            }
        }

        // Interactive Camera Viewfinder Panel
        Rectangle {
            visible: root.cameraActive
            Layout.fillWidth: true
            height: 120
            radius: 10
            color: "#1C1917"
            border.color: "#F59E0B"
            border.width: 2
            clip: true

            // Animated laser scan line
            Rectangle {
                id: scanLaser
                width: parent.width - 32
                height: 2
                x: 16
                y: 20
                color: "#EF4444"
                SequentialAnimation on y {
                    running: root.cameraActive
                    loops: Animation.Infinite
                    NumberAnimation { from: 18; to: 100; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 100; to: 18; duration: 1100; easing.type: Easing.InOutSine }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                Label {
                    text: "📷 " + qsTr("Point EAN-13 / UPC barcode at camera viewfinder")
                    color: "#FAFAF9"
                    font.bold: true
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: [
                            { label: "Scan Oats (4008400404127)", code: "4008400404127" },
                            { label: "Scan Yogurt (5201051001078)", code: "5201051001078" }
                        ]
                        delegate: Button {
                            text: "🎯 " + modelData.label
                            font.pixelSize: 10
                            onClicked: {
                                barcodeField.text = modelData.code;
                                root.cameraActive = false;
                                offFetcher.lookupBarcode(modelData.code);
                            }
                        }
                    }
                }
            }
        }

        // Sample preset barcodes for fast testing
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                text: qsTr("Quick Test Presets (Click to test):")
                font.pixelSize: 11
                font.bold: true
                color: "#78716C"
            }
            Flickable {
                Layout.fillWidth: true
                height: 34
                contentWidth: presetRow.implicitWidth
                contentHeight: height
                clip: true
                flickableDirection: Flickable.HorizontalFlick

                RowLayout {
                    id: presetRow
                    height: parent.height
                    spacing: 6

                    Button {
                        text: "🥣 Oats"
                        font.pixelSize: 11
                        flat: true
                        background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E7E5E4" }
                        onClicked: {
                            barcodeField.text = "4008400404127";
                            searchBtn.clicked();
                        }
                    }
                    Button {
                        text: "🥛 Greek Yogurt"
                        font.pixelSize: 11
                        flat: true
                        background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E7E5E4" }
                        onClicked: {
                            barcodeField.text = "5201051001078";
                            searchBtn.clicked();
                        }
                    }
                    Button {
                        text: "🍫 Dark Chocolate"
                        font.pixelSize: 11
                        flat: true
                        background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E7E5E4" }
                        onClicked: {
                            barcodeField.text = "7610400070776";
                            searchBtn.clicked();
                        }
                    }
                    Button {
                        text: "🥜 Peanut Butter"
                        font.pixelSize: 11
                        flat: true
                        background: Rectangle { radius: 6; color: "#F5F5F4"; border.color: "#E7E5E4" }
                        onClicked: {
                            barcodeField.text = "0051500241776";
                            searchBtn.clicked();
                        }
                    }
                }
            }
        }

        // Loading or status banner
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            color: offFetcher.isLoading ? "#FEF3C7" : (statusText.text.length > 0 ? "#F5F5F4" : "transparent")
            visible: offFetcher.isLoading || statusText.text.length > 0

            Label {
                id: statusText
                anchors.centerIn: parent
                text: offFetcher.lastStatus
                font.pixelSize: 12
                color: offFetcher.isLoading ? "#B45309" : "#57534E"
            }
        }

        // Product Result Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#FFFFFF"
            border.color: root.currentProduct ? "#D97706" : "#E7E5E4"
            border.width: root.currentProduct ? 2 : 1
            visible: root.currentProduct !== null

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 50
                        height: 50
                        radius: 8
                        color: "#F3F4F6"
                        border.color: "#E5E7EB"

                        Label {
                            anchors.centerIn: parent
                            text: "🏷️"
                            font.pixelSize: 26
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: root.currentProduct ? root.currentProduct.name : ""
                            font.bold: true
                            font.pixelSize: 15
                            color: "#1C1917"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: root.currentProduct ? ("Barcode: " + root.currentProduct.barcode) : ""
                            font.pixelSize: 11
                            color: "#78716C"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#F5F5F4"
                }

                // Nutrition per 100g grid
                Label {
                    text: qsTr("Nutritional Values (per 100g):")
                    font.bold: true
                    font.pixelSize: 12
                    color: "#44403C"
                }

                GridLayout {
                    columns: 4
                    Layout.fillWidth: true
                    rowSpacing: 6
                    columnSpacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 6
                        color: "#FEF2F2"
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Label { text: qsTr("Calories"); font.pixelSize: 10; color: "#991B1B"; horizontalAlignment: Text.AlignHCenter }
                            Label {
                                text: root.currentProduct ? (root.currentProduct.calories + " kcal") : "-"
                                font.bold: true; font.pixelSize: 12; color: "#DC2626"; horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 6
                        color: "#FFFBEB"
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Label { text: qsTr("Carbohydrates"); font.pixelSize: 10; color: "#92400E"; horizontalAlignment: Text.AlignHCenter }
                            Label {
                                text: root.currentProduct ? (root.currentProduct.carbs + " g") : "-"
                                font.bold: true; font.pixelSize: 12; color: "#D97706"; horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 6
                        color: "#F0FDF4"
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Label { text: qsTr("Protein"); font.pixelSize: 10; color: "#166534"; horizontalAlignment: Text.AlignHCenter }
                            Label {
                                text: root.currentProduct ? (root.currentProduct.protein + " g") : "-"
                                font.bold: true; font.pixelSize: 12; color: "#16A34A"; horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 6
                        color: "#EFF6FF"
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Label { text: qsTr("Fat"); font.pixelSize: 10; color: "#1E40AF"; horizontalAlignment: Text.AlignHCenter }
                            Label {
                                text: root.currentProduct ? (root.currentProduct.fat + " g") : "-"
                                font.bold: true; font.pixelSize: 12; color: "#2563EB"; horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                // Portion selector & Meal selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RowLayout {
                        spacing: 6
                        Label { text: qsTr("Amount:"); font.bold: true; font.pixelSize: 12; color: "#44403C" }
                        SpinBox {
                            id: amountSpin
                            from: 10
                            to: 1000
                            stepSize: 10
                            value: 100
                            editable: true
                        }
                        Label { text: qsTr("grams"); font.pixelSize: 12; color: "#78716C" }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 6
                        Label { text: qsTr("Target Meal:"); font.bold: true; font.pixelSize: 12; color: "#44403C" }
                        ComboBox {
                            id: mealCombo
                            model: {
                                if (!root.mealPlanManager || !root.mealPlanManager.meals) return [];
                                let arr = [];
                                for (let i = 0; i < root.mealPlanManager.meals.length; i++) {
                                    let m = root.mealPlanManager.meals[i];
                                    if (m && !m.isWorkout) {
                                        arr.push({ index: i, title: (m.icon ? (m.icon + " ") : "") + (m.title || ("Meal " + (i + 1))) });
                                    }
                                }
                                return arr;
                            }
                            textRole: "title"
                            currentIndex: {
                                if (!model || model.length === 0) return 0;
                                for (let i = 0; i < model.length; i++) {
                                    if (model[i].index === root.targetMealIndex) return i;
                                }
                                return 0;
                            }
                        }
                    }
                }
            }
        }

        // Bottom Action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: qsTr("Cancel")
                Layout.preferredHeight: 38
                flat: true
                palette.buttonText: "#78716C"
                onClicked: root.close()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "➕ " + qsTr("Add to Meal Plan")
                Layout.preferredHeight: 40
                Layout.preferredWidth: 160
                enabled: root.currentProduct !== null && root.mealPlanManager !== null
                font.bold: true
                font.pixelSize: 13
                palette.buttonText: "#FFFFFF"
                background: Rectangle {
                    radius: 8
                    color: parent.enabled ? "#16A34A" : "#9CA3AF"
                }
                onClicked: {
                    if (root.currentProduct && root.mealPlanManager) {
                        let targetIdx = 0;
                        if (mealCombo.model && mealCombo.currentIndex >= 0 && mealCombo.currentIndex < mealCombo.model.length) {
                            targetIdx = mealCombo.model[mealCombo.currentIndex].index;
                        }
                        root.mealPlanManager.addItemToMeal(targetIdx, root.currentProduct, amountSpin.value);
                        if (root.foodDb) {
                            root.foodDb.addFood(root.currentProduct);
                        }
                        root.close();
                    }
                }
            }
        }
    }

    OpenFoodFactsFetcher {
        id: offFetcher
        onBarcodeFound: (product) => {
            root.currentProduct = product;
        }
        onFetchError: (msg) => {
            root.currentProduct = null;
        }
    }
}
