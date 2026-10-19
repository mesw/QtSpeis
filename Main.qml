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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Top Header Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Label {
                text: "🕒 Temporal Pie Day Plan"
                font.bold: true
                font.pixelSize: 18
                color: "#F8FAFC"
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
                color: mainChart.zoom > 1.05 ? "rgba(56, 189, 248, 0.15)" :
                       (mainChart.zoom < 0.95 ? "rgba(244, 63, 94, 0.15)" : "rgba(148, 163, 184, 0.15)")
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
                color: rgba(244, 63, 94, 0.18)
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

            Item { Layout.fillWidth: true }

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

            // Left: Circular Pie Chart Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1E293B"
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    TemporalPieChart {
                        id: mainChart
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        zoom: 1.0
                        focusAngle: (9.0 / 24.0) * 2 * Math.PI
                        interactive: true
                        planModel: dayPlanModel

                        onItemClicked: (item) => {
                            inspectorTitle.text = (item.icon ? item.icon + " " : "") + item.title;
                            if (item.isInterval) {
                                inspectorTime.text = item.startClock + " - " + item.endClock + " (" + item.duration.toFixed(1) + "h)";
                            } else {
                                inspectorTime.text = item.startClock + (item.isUntimedStep ? " (Step " + item.orderIndex + ")" : "");
                            }
                            inspectorDesc.text = item.parentTitle ? ("Part of: " + item.parentTitle) : "Top-level Activity";
                            sidePanel.visible = true;
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
                            text: "⏱️ Load 1440-Min Day"
                            onClicked: {
                                dayPlanModel.loadFile("schedule_1440_minutes.yaml");
                            }
                        }

                        Button {
                            text: "📜 Franklin Schedule"
                            onClicked: {
                                dayPlanModel.loadDefaultPlan();
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
                                                text: delegateRoot.modelData.title
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
