import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtSpeis

Window {
    id: window
    width: 1080
    height: 760
    minimumWidth: 780
    minimumHeight: 620
    visible: true
    title: qsTr("Temporal Pie Chart Prototype with YAML Day Plan (Qt 6.8 / WebAssembly)")
    color: "#0F172A"

    DayPlanModel {
        id: dayPlanModel
    }

    TvProgramFetcher {
        id: tvFetcher
        targetModel: dayPlanModel
        daysToFetch: 7
        onFetchFinished: (success, msg) => {
            if (success) {
                yamlEditor.text = dayPlanModel.rawYaml;
            }
        }
    }

    Component.onCompleted: {
        dayPlanModel.loadFile("schedule_week.yaml");
        yamlEditor.text = dayPlanModel.rawYaml;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Top Header Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Label {
                text: "🌀 QtSpeis Schedule & Calendar"
                font.bold: true
                font.pixelSize: 18
                color: "#F8FAFC"
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: "#334155"
            }

            ButtonGroup {
                id: viewModeGroup
            }

            // Radial / Spiral View Selector
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 280
                radius: 8
                color: "#0F172A"
                border.color: "#334155"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: spiral3Btn.checked ? "#2563EB" : "transparent"

                        Button {
                            id: spiral3Btn
                            anchors.fill: parent
                            text: "🌀 3-Day"
                            checkable: true
                            checked: true
                            ButtonGroup.group: viewModeGroup
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Spiral View: 3-Day (72 Hours)"
                            contentItem: Label {
                                text: spiral3Btn.text
                                font.bold: spiral3Btn.checked
                                font.pixelSize: 11
                                color: spiral3Btn.checked ? "#FFFFFF" : "#94A3B8"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Item {}
                            onClicked: {
                                mainChart.currentIndex = 0;
                                spiralChart.daysCount = 3;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: spiral7Btn.checked ? "#2563EB" : "transparent"

                        Button {
                            id: spiral7Btn
                            anchors.fill: parent
                            text: "🌀 7-Day"
                            checkable: true
                            checked: false
                            ButtonGroup.group: viewModeGroup
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Spiral View: 7-Day Week"
                            contentItem: Label {
                                text: spiral7Btn.text
                                font.bold: spiral7Btn.checked
                                font.pixelSize: 11
                                color: spiral7Btn.checked ? "#FFFFFF" : "#94A3B8"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Item {}
                            onClicked: {
                                mainChart.currentIndex = 0;
                                spiralChart.daysCount = 7;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: circleBtn.checked ? "#2563EB" : "transparent"

                        Button {
                            id: circleBtn
                            anchors.fill: parent
                            text: "🕒 24h Dial"
                            checkable: true
                            checked: false
                            ButtonGroup.group: viewModeGroup
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Circular View: 24-Hour Dial"
                            contentItem: Label {
                                text: circleBtn.text
                                font.bold: circleBtn.checked
                                font.pixelSize: 11
                                color: circleBtn.checked ? "#FFFFFF" : "#94A3B8"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Item {}
                            onClicked: mainChart.currentIndex = 1
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: "#334155"
            }

            // Tabular Calendar View Selector (24h, 3 days, 7 days)
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 320
                radius: 8
                color: "#0F172A"
                border.color: "#334155"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: table24Btn.checked ? "#2563EB" : "transparent"

                        Button {
                            id: table24Btn
                            anchors.fill: parent
                            text: "📅 24h Table"
                            checkable: true
                            checked: false
                            ButtonGroup.group: viewModeGroup
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Tabular Calendar: 24-Hour Straight Time Axis (No Scrolling)"
                            contentItem: Label {
                                text: table24Btn.text
                                font.bold: table24Btn.checked
                                font.pixelSize: 11
                                color: table24Btn.checked ? "#FFFFFF" : "#94A3B8"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Item {}
                            onClicked: {
                                mainChart.currentIndex = 2;
                                tableChart.daysCount = 1;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: table3Btn.checked ? "#2563EB" : "transparent"

                        Button {
                            id: table3Btn
                            anchors.fill: parent
                            text: "📅 3-Day Table"
                            checkable: true
                            checked: false
                            ButtonGroup.group: viewModeGroup
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Tabular Calendar: 3 Days (72h) Straight Time Axes (No Scrolling)"
                            contentItem: Label {
                                text: table3Btn.text
                                font.bold: table3Btn.checked
                                font.pixelSize: 11
                                color: table3Btn.checked ? "#FFFFFF" : "#94A3B8"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Item {}
                            onClicked: {
                                mainChart.currentIndex = 2;
                                tableChart.daysCount = 3;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: table7Btn.checked ? "#2563EB" : "transparent"

                        Button {
                            id: table7Btn
                            anchors.fill: parent
                            text: "📅 7-Day Week"
                            checkable: true
                            checked: false
                            ButtonGroup.group: viewModeGroup
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Tabular Calendar: 7-Day Week Straight Time Axes (No Scrolling)"
                            contentItem: Label {
                                text: table7Btn.text
                                font.bold: table7Btn.checked
                                font.pixelSize: 11
                                color: table7Btn.checked ? "#FFFFFF" : "#94A3B8"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Item {}
                            onClicked: {
                                mainChart.currentIndex = 2;
                                tableChart.daysCount = 7;
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: "#334155"
            }

            // Status Badge
            Rectangle {
                Layout.preferredHeight: 26
                Layout.preferredWidth: statusLabel.implicitWidth + 18
                radius: 13
                color: mainChart.zoom > 1.05 ? "#2638BDF8" :
                       (mainChart.zoom < 0.95 ? "#26F43F5E" : "#2694A3B8")
                border.color: mainChart.zoom > 1.05 ? "#38BDF8" :
                              (mainChart.zoom < 0.95 ? "#F43F5E" : "#64748B")
                border.width: 1

                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: mainChart.zoom > 1.05 ? "Enlarged (" + mainChart.zoom.toFixed(1) + "x)" :
                          (mainChart.zoom < 0.95 ? "Shrunk (" + mainChart.zoom.toFixed(2) + "x)" : "Equitemporal (1.0x)")
                    font.pixelSize: 11
                    font.bold: true
                    color: mainChart.zoom > 1.05 ? "#38BDF8" :
                           (mainChart.zoom < 0.95 ? "#FB7185" : "#94A3B8")
                }
            }

            // Live Time Following Badge
            Rectangle {
                visible: mainChart.followTime
                Layout.preferredHeight: 26
                Layout.preferredWidth: liveLabel.implicitWidth + 24
                radius: 13
                color: "#2EF43F5E"
                border.color: "#F43F5E"
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        width: 7; height: 7; radius: 3.5; color: "#F43F5E"
                    }
                    Label {
                        id: liveLabel
                        text: "LIVE TIME"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#FDA4AF"
                    }
                }
            }

            // TV Fetcher Status Pill
            Rectangle {
                visible: tvFetcher.statusMessage !== ""
                Layout.preferredHeight: 26
                Layout.preferredWidth: tvStatusLabel.implicitWidth + 24
                radius: 13
                color: tvFetcher.isLoading ? "#2638BDF8" : "#2610B981"
                border.color: tvFetcher.isLoading ? "#38BDF8" : "#10B981"
                border.width: 1

                Label {
                    id: tvStatusLabel
                    anchors.centerIn: parent
                    text: tvFetcher.statusMessage
                    font.pixelSize: 11
                    font.bold: true
                    color: tvFetcher.isLoading ? "#38BDF8" : "#34D399"
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                id: topOrfRefreshBtn
                text: tvFetcher.isLoading ? "⏳ Fetching ORF 1..." : "📡 Refresh ORF 1"
                enabled: !tvFetcher.isLoading
                highlighted: true
                ToolTip.visible: hovered
                ToolTip.text: "Fetch live TV program from https://tv.orf.at/program/orf1/"
                onClicked: {
                    tvFetcher.fetchProgram("orf1");
                }
            }

            Button {
                text: sidePanel.visible ? "Hide Plan / YAML Panel" : "Show Plan / YAML Panel"
                onClicked: sidePanel.visible = !sidePanel.visible
            }

            Button {
                text: "Reset to Equitemporal (1.0x)"
                highlighted: true
                onClicked: mainChart.resetZoom()
            }
        }

        // Subheader Gesture Instructions
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: "#1E293B"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Label {
                    text: "💡 Gestures: Pinch out / Wheel up to enlarge • Pinch in / Wheel down to shrink • Drag to pan focus • Click items to inspect"
                    color: "#94A3B8"
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "YAML Model Loaded (" + dayPlanModel.totalItemCount + " items)"
                    color: "#38BDF8"
                    font.bold: true
                    font.pixelSize: 11
                }
            }
        }

        // --- Center Canvas & Side Inspector Area ---
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Left: Dial & Spiral Chart Display Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1E293B"
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    StackLayout {
                        id: mainChart
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: 0

                        property real zoom: 1.0
                        property real focusAngle: (12.0 / 24.0) * 2 * Math.PI
                        property bool followTime: false
                        property int daysCount: spiralChart.daysCount
                        property var selectedItem: null

                        signal itemClicked(var item)

                        function resetZoom() {
                            spiralChart.resetZoom();
                            pieChart.resetZoom();
                            tableChart.resetZoom();
                            mainChart.zoom = 1.0;
                        }

                        function updateCurrentTime() {
                            spiralChart.updateCurrentTime();
                            pieChart.updateCurrentTime();
                            tableChart.updateCurrentTime();
                        }

                        function isItemVisibleOnDial(item) {
                            if (mainChart.currentIndex === 0) {
                                return spiralChart.isItemVisibleOnDial(item);
                            } else if (mainChart.currentIndex === 1) {
                                return pieChart.isItemVisibleOnDial(item);
                            } else if (mainChart.currentIndex === 2) {
                                return tableChart.isItemVisibleOnDial(item);
                            }
                            return true;
                        }

                        onZoomChanged: {
                            if (spiralChart.zoom !== mainChart.zoom) spiralChart.zoom = mainChart.zoom;
                            if (pieChart.zoom !== mainChart.zoom) pieChart.zoom = mainChart.zoom;
                            if (tableChart.zoom !== mainChart.zoom) tableChart.zoom = mainChart.zoom;
                        }

                        onFocusAngleChanged: {
                            if (spiralChart.focusAngle !== mainChart.focusAngle) spiralChart.focusAngle = mainChart.focusAngle;
                            if (pieChart.focusAngle !== mainChart.focusAngle) pieChart.focusAngle = mainChart.focusAngle;
                            if (tableChart.focusAngle !== mainChart.focusAngle) tableChart.focusAngle = mainChart.focusAngle;
                        }

                        onFollowTimeChanged: {
                            if (spiralChart.followTime !== mainChart.followTime) spiralChart.followTime = mainChart.followTime;
                            if (pieChart.followTime !== mainChart.followTime) pieChart.followTime = mainChart.followTime;
                            if (tableChart.followTime !== mainChart.followTime) tableChart.followTime = mainChart.followTime;
                        }

                        onSelectedItemChanged: {
                            if (spiralChart.selectedItem !== mainChart.selectedItem) spiralChart.selectedItem = mainChart.selectedItem;
                            if (pieChart.selectedItem !== mainChart.selectedItem) pieChart.selectedItem = mainChart.selectedItem;
                            if (tableChart.selectedItem !== mainChart.selectedItem) tableChart.selectedItem = mainChart.selectedItem;
                        }

                        onItemClicked: (item) => {
                            mainChart.selectedItem = item;
                            inspectorTitle.text = (item.icon ? item.icon + " " : "") + item.title;
                            if (item.isInterval) {
                                inspectorTime.text = (item.dayName ? item.dayName + " • " : "") + item.startClock + " - " + item.endClock + " (" + item.duration.toFixed(1) + "h)";
                            } else {
                                inspectorTime.text = (item.dayName ? item.dayName + " • " : "") + item.startClock + (item.isUntimedStep ? " (Step " + item.orderIndex + ")" : "");
                            }
                            inspectorDesc.text = item.parentTitle ? ("Part of: " + item.parentTitle) : "Top-level Activity";
                            sidePanel.visible = true;
                        }

                        // Index 0: Spiral View (3-Day 72h or 7-Day Week)
                        TemporalSpiralChart {
                            id: spiralChart
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            interactive: true
                            planModel: dayPlanModel
                            daysCount: 3
                            zoom: mainChart.zoom
                            focusAngle: mainChart.focusAngle
                            followTime: mainChart.followTime

                            onZoomChanged: {
                                if (mainChart.currentIndex === 0 && mainChart.zoom !== zoom) mainChart.zoom = zoom;
                            }
                            onFocusAngleChanged: {
                                if (mainChart.currentIndex === 0 && mainChart.focusAngle !== focusAngle) mainChart.focusAngle = focusAngle;
                            }
                            onFollowTimeChanged: {
                                if (mainChart.currentIndex === 0 && mainChart.followTime !== followTime) mainChart.followTime = followTime;
                            }
                            onSelectedItemChanged: {
                                if (mainChart.currentIndex === 0 && mainChart.selectedItem !== selectedItem) mainChart.selectedItem = selectedItem;
                            }
                            onItemClicked: (item) => mainChart.itemClicked(item)
                        }

                        // Index 1: 24h Circle Dial View
                        TemporalPieChart {
                            id: pieChart
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            interactive: true
                            planModel: dayPlanModel
                            zoom: mainChart.zoom
                            focusAngle: mainChart.focusAngle
                            followTime: mainChart.followTime

                            onZoomChanged: {
                                if (mainChart.currentIndex === 1 && mainChart.zoom !== zoom) mainChart.zoom = zoom;
                            }
                            onFocusAngleChanged: {
                                if (mainChart.currentIndex === 1 && mainChart.focusAngle !== focusAngle) mainChart.focusAngle = focusAngle;
                            }
                            onFollowTimeChanged: {
                                if (mainChart.currentIndex === 1 && mainChart.followTime !== followTime) mainChart.followTime = followTime;
                            }
                            onSelectedItemChanged: {
                                if (mainChart.currentIndex === 1 && mainChart.selectedItem !== selectedItem) mainChart.selectedItem = selectedItem;
                            }
                            onItemClicked: (item) => mainChart.itemClicked(item)
                        }

                        // Index 2: Tabular Calendar View (24h, 3-Day, 7-Day Straight Time Axes)
                        TemporalTableChart {
                            id: tableChart
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            interactive: true
                            planModel: dayPlanModel
                            daysCount: 7
                            zoom: mainChart.zoom
                            focusAngle: mainChart.focusAngle
                            followTime: mainChart.followTime

                            onZoomChanged: {
                                if (mainChart.currentIndex === 2 && mainChart.zoom !== zoom) mainChart.zoom = zoom;
                            }
                            onFocusAngleChanged: {
                                if (mainChart.currentIndex === 2 && mainChart.focusAngle !== focusAngle) mainChart.focusAngle = focusAngle;
                            }
                            onFollowTimeChanged: {
                                if (mainChart.currentIndex === 2 && mainChart.followTime !== followTime) mainChart.followTime = followTime;
                            }
                            onSelectedItemChanged: {
                                if (mainChart.currentIndex === 2 && mainChart.selectedItem !== selectedItem) mainChart.selectedItem = selectedItem;
                            }
                            onItemClicked: (item) => mainChart.itemClicked(item)
                        }
                    }

                    // Quick Presets
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Label {
                            text: "Plans:"
                            color: "#94A3B8"
                            font.bold: true
                            font.pixelSize: 12
                        }

                        Button {
                            text: tvFetcher.isLoading ? "⏳ Fetching..." : "📡 ORF 1 Live"
                            enabled: !tvFetcher.isLoading
                            highlighted: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Fetch live TV program from https://tv.orf.at/program/orf1/"
                            onClicked: {
                                tvFetcher.fetchProgram("orf1");
                            }
                        }

                        Button {
                            text: "🗓️ 3-Day (72h) Plan"
                            highlighted: spiral3Btn.checked
                            onClicked: {
                                dayPlanModel.loadFile("schedule_week.yaml");
                                yamlEditor.text = dayPlanModel.rawYaml;
                                spiral3Btn.checked = true;
                                mainChart.currentIndex = 0;
                                spiralChart.daysCount = 3;
                            }
                        }

                        Button {
                            text: "📅 7-Day Week Plan"
                            highlighted: spiral7Btn.checked
                            onClicked: {
                                dayPlanModel.loadFile("schedule_week.yaml");
                                yamlEditor.text = dayPlanModel.rawYaml;
                                spiral7Btn.checked = true;
                                mainChart.currentIndex = 0;
                                spiralChart.daysCount = 7;
                            }
                        }

                        Button {
                            text: "⏱️ Load 1440-Min Day"
                            onClicked: {
                                dayPlanModel.loadFile("schedule_1440_minutes.yaml");
                                yamlEditor.text = dayPlanModel.rawYaml;
                            }
                        }

                        Button {
                            text: "📜 Franklin Schedule"
                            onClicked: {
                                dayPlanModel.loadDefaultPlan();
                                yamlEditor.text = dayPlanModel.rawYaml;
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 20
                            color: "#334155"
                        }

                        Label {
                            text: "Focus Presets:"
                            color: "#94A3B8"
                            font.pixelSize: 12
                        }

                        Button {
                            text: mainChart.followTime ? "🔴 Tracking Now" : "⏱️ Jump to Now"
                            highlighted: mainChart.followTime
                            onClicked: {
                                mainChart.followTime = !mainChart.followTime;
                                if (mainChart.followTime) {
                                    mainChart.updateCurrentTime();
                                    if (mainChart.zoom < 1.5) mainChart.zoom = 3.0;
                                }
                            }
                        }

                        Button {
                            text: "☀️ Noon (12:00)"
                            onClicked: {
                                mainChart.followTime = false;
                                mainChart.focusAngle = (12.0 / 24.0) * 2 * Math.PI;
                                mainChart.zoom = 1.0;
                            }
                        }

                        Button {
                            text: "🔍 Minute Zoom (12:05)"
                            onClicked: {
                                mainChart.followTime = false;
                                mainChart.focusAngle = (12.0833 / 24.0) * 2 * Math.PI;
                                mainChart.zoom = 12.0;
                            }
                        }

                        Button {
                            text: "🌙 Midnight (00:00)"
                            onClicked: {
                                mainChart.followTime = false;
                                mainChart.focusAngle = 0.0;
                                mainChart.zoom = 3.5;
                            }
                        }
                    }
                }
            }

            // Right: Collapsible Side Panel (Item Inspector & YAML Editor)
            Rectangle {
                id: sidePanel
                visible: true
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                color: "#1E293B"
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // Panel Tabs
                    TabBar {
                        id: panelTabBar
                        Layout.fillWidth: true
                        TabButton { text: "🔍 Inspector" }
                        TabButton { text: "📝 Edit YAML" }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: panelTabBar.currentIndex

                        // 1. Inspector View
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 110
                                    color: "#0F172A"
                                    radius: 8

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        Label {
                                            id: inspectorTitle
                                            text: mainChart.selectedItem ?
                                                ((mainChart.selectedItem.icon ? mainChart.selectedItem.icon + " " : "") + mainChart.selectedItem.title) :
                                                "Select an Activity"
                                            font.bold: true
                                            font.pixelSize: 15
                                            color: "#38BDF8"
                                        }

                                        Label {
                                            id: inspectorTime
                                            text: mainChart.selectedItem ?
                                                (mainChart.selectedItem.isInterval ?
                                                    (mainChart.selectedItem.startClock + " - " + mainChart.selectedItem.endClock + " (" +
                                                     (mainChart.selectedItem.duration < 0.95 ? Math.round(mainChart.selectedItem.duration * 60) + " min" : mainChart.selectedItem.duration.toFixed(1) + "h") + ")") :
                                                    (mainChart.selectedItem.isUntimedStep ?
                                                        (mainChart.selectedItem.startClock + " (Step " + mainChart.selectedItem.orderIndex + " of " + mainChart.selectedItem.totalSteps + ")") :
                                                        mainChart.selectedItem.startClock)) :
                                                "Click any arc band or icon on the dial"
                                            color: "#F8FAFC"
                                            font.pixelSize: 13
                                        }

                                        Label {
                                            id: inspectorDesc
                                            text: mainChart.selectedItem ?
                                                ("Level " + mainChart.selectedItem.level + (mainChart.selectedItem.parentTitle ? (" • Sub-item of: " + mainChart.selectedItem.parentTitle) : " • Top-level block")) :
                                                "Supports start+end, start+duration, and nested checklist steps"
                                            color: "#94A3B8"
                                            font.pixelSize: 11
                                        }

                                        Item { Layout.fillHeight: true }

                                        Button {
                                            text: "🎯 Focus & Zoom on Activity"
                                            visible: mainChart.selectedItem !== null
                                            Layout.fillWidth: true
                                            onClicked: {
                                                if (mainChart.selectedItem) {
                                                    let h = mainChart.selectedItem.startTime;
                                                    mainChart.focusAngle = (h / 24.0) * 2 * Math.PI;
                                                    mainChart.zoom = 3.6;
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: "Activities (" + dayPlanModel.totalItemCount + "):"
                                        color: "#94A3B8"
                                        font.bold: true
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                    }

                                    ComboBox {
                                        id: levelFilterCombo
                                        Layout.preferredWidth: 135
                                        model: ["Visible on Dial", "All Activities", "Top & Periods", "Hours", "Minutes"]
                                    }
                                }

                                // List of plan items (optimized with reuseItems and visible culling)
                                ListView {
                                    id: planListView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    reuseItems: true
                                    model: dayPlanModel.flatItems
                                    spacing: 4

                                    delegate: Rectangle {
                                        id: delegateRoot
                                        required property var modelData
                                        visible: {
                                            let _z = mainChart.zoom;
                                            let _f = mainChart.focusAngle;
                                            if (levelFilterCombo.currentIndex === 0) {
                                                return mainChart.isItemVisibleOnDial(delegateRoot.modelData);
                                            }
                                            if (levelFilterCombo.currentIndex === 2) return delegateRoot.modelData.level <= 1;
                                            if (levelFilterCombo.currentIndex === 3) return delegateRoot.modelData.level <= 2;
                                            if (levelFilterCombo.currentIndex === 4) return delegateRoot.modelData.level === 3;
                                            return true;
                                        }
                                        width: ListView.view.width
                                        height: visible ? 36 : 0
                                        radius: 6
                                        color: (mainChart.selectedItem && mainChart.selectedItem.title === delegateRoot.modelData.title) ? "#334155" : "#0F172A"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: (delegateRoot.modelData.level * 10) + 8
                                            anchors.rightMargin: 8
                                            visible: delegateRoot.visible

                                            Label {
                                                text: delegateRoot.modelData.icon ? delegateRoot.modelData.icon : "📌"
                                                font.pixelSize: 13
                                            }

                                            Label {
                                                text: (delegateRoot.modelData.dayName ? "[" + delegateRoot.modelData.dayName.substring(0, 3).toUpperCase() + "] " : "") + delegateRoot.modelData.title
                                                color: "#F8FAFC"
                                                font.pixelSize: 11
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: delegateRoot.modelData.isInterval ?
                                                    (delegateRoot.modelData.startClock + " - " + delegateRoot.modelData.endClock) :
                                                    (delegateRoot.modelData.isUntimedStep ? (delegateRoot.modelData.startClock + " • Step " + delegateRoot.modelData.orderIndex) : delegateRoot.modelData.startClock)
                                                color: delegateRoot.modelData.isInterval ? "#38BDF8" : "#F59E0B"
                                                font.pixelSize: 10
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: delegateRoot.visible
                                            onClicked: {
                                                mainChart.selectedItem = delegateRoot.modelData;
                                                mainChart.itemClicked(delegateRoot.modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. YAML Editor View
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8

                                Label {
                                    text: "Live Day Plan YAML:"
                                    color: "#94A3B8"
                                    font.pixelSize: 12
                                }

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    TextArea {
                                        id: yamlEditor
                                        text: dayPlanModel.rawYaml
                                        font.family: "Consolas, Courier, monospace"
                                        font.pixelSize: 11
                                        color: "#F8FAFC"
                                        background: Rectangle {
                                            color: "#0F172A"
                                            radius: 6
                                        }
                                        selectByMouse: true
                                        wrapMode: TextArea.NoWrap
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Button {
                                        text: "Apply YAML"
                                        highlighted: true
                                        Layout.fillWidth: true
                                        onClicked: {
                                            dayPlanModel.loadYaml(yamlEditor.text);
                                        }
                                    }

                                    Button {
                                        text: "Reset Default"
                                        Layout.fillWidth: true
                                        onClicked: {
                                            dayPlanModel.loadDefaultPlan();
                                            yamlEditor.text = dayPlanModel.rawYaml;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Controls Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            color: "#1E293B"
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                Label {
                    text: "Zoom:"
                    color: "#94A3B8"
                    font.bold: true
                }

                Label {
                    text: mainChart.zoom.toFixed(2) + "x"
                    color: mainChart.zoom > 1.05 ? "#38BDF8" : (mainChart.zoom < 0.95 ? "#F43F5E" : "#94A3B8")
                    font.bold: true
                    Layout.preferredWidth: 45
                }

                Slider {
                    Layout.fillWidth: true
                    from: 0.15
                    to: 24.0
                    stepSize: 0.05
                    value: mainChart.zoom
                    onMoved: mainChart.zoom = value
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: "#334155"
                }

                CheckBox {
                    id: followTimeCheckBox
                    text: "Follow Time"
                    checked: mainChart.followTime
                    onClicked: {
                        mainChart.followTime = checked;
                        if (mainChart.followTime) {
                            mainChart.updateCurrentTime();
                        }
                    }
                    Binding {
                        target: followTimeCheckBox
                        property: "checked"
                        value: mainChart.followTime
                    }
                    contentItem: Text {
                        text: followTimeCheckBox.text
                        font.bold: true
                        font.pixelSize: 12
                        color: followTimeCheckBox.checked ? "#38BDF8" : "#94A3B8"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: followTimeCheckBox.indicator.width + followTimeCheckBox.spacing
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: "#334155"
                }

                Label {
                    text: "Focus Time:"
                    color: mainChart.followTime ? "#64748B" : "#94A3B8"
                    font.bold: true
                }

                Label {
                    readonly property real hours: (mainChart.focusAngle / (2 * Math.PI)) * 24
                    readonly property int h: Math.floor(hours)
                    readonly property int m: Math.floor((hours % 1) * 60)
                    text: (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
                    color: mainChart.followTime ? "#38BDF8" : "#F59E0B"
                    font.bold: true
                    Layout.preferredWidth: 45
                }

                Slider {
                    id: focusTimeSlider
                    Layout.fillWidth: true
                    from: 0.0
                    to: 2 * Math.PI
                    value: mainChart.focusAngle
                    enabled: !mainChart.followTime
                    opacity: mainChart.followTime ? 0.45 : 1.0
                    onMoved: {
                        mainChart.followTime = false;
                        mainChart.focusAngle = value;
                    }
                }
            }
        }
    }
}
