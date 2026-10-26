import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(680, (parent ? parent.width : 680) - 20)
    height: Math.min(720, (parent ? parent.height : 720) - 24)
    padding: 0

    property var langManager: null
    readonly property bool isNarrow: root.width < 520
    property int currentTab: 0 // 0: About & License, 1: Data Sources, 2: AI Database, 3: Privacy Policy

    background: Rectangle {
        color: "#FFFDF9"
        radius: 16
        border.color: "#E2D9C8"
        border.width: 1
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.isNarrow ? 12 : 18
        spacing: 12

        // --- Dialog Header ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 38
                height: 38
                radius: 10
                color: "#FEF3C7"
                border.color: "#FDE68A"
                border.width: 1
                Label {
                    anchors.centerIn: parent
                    text: "⚖️"
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: langManager ? langManager.t("about_legal_title") : "About, Licenses & Privacy"
                    font.bold: true
                    font.pixelSize: 16
                    color: "#1C1917"
                }
                Label {
                    text: "QtSpeis — GPLv3 Open Source Nutrition Planner"
                    font.pixelSize: 11
                    color: "#78716C"
                }
            }

            // Close button
            Rectangle {
                width: 32
                height: 32
                radius: 8
                color: closeHover.containsMouse ? "#FEE2E2" : "#F5F5F4"
                border.color: closeHover.containsMouse ? "#FCA5A5" : "#E7E5E4"
                Label {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 13
                    font.bold: true
                    color: closeHover.containsMouse ? "#DC2626" : "#57534E"
                }
                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        // --- Tab Selection Pills ---
        Rectangle {
            Layout.fillWidth: true
            height: root.isNarrow ? 76 : 40
            radius: 10
            color: "#F5F5F4"
            border.color: "#E7E5E4"
            border.width: 1

            GridLayout {
                anchors.fill: parent
                anchors.margins: 3
                columns: root.isNarrow ? 2 : 4
                rows: root.isNarrow ? 2 : 1
                rowSpacing: 3
                columnSpacing: 3

                // Tab 0: About & License
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 7
                    color: root.currentTab === 0 ? "#FFFFFF" : "transparent"
                    border.color: root.currentTab === 0 ? "#E2D9C8" : "transparent"
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Label { text: "📜"; font.pixelSize: 13 }
                        Label {
                            text: langManager ? langManager.t("tab_about_license") : "License & Code"
                            font.bold: root.currentTab === 0
                            font.pixelSize: 11
                            color: root.currentTab === 0 ? "#B45309" : "#57534E"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 0
                    }
                }

                // Tab 1: Data Sources
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 7
                    color: root.currentTab === 1 ? "#FFFFFF" : "transparent"
                    border.color: root.currentTab === 1 ? "#E2D9C8" : "transparent"
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Label { text: "🥗"; font.pixelSize: 13 }
                        Label {
                            text: langManager ? langManager.t("tab_data_sources") : "Data Sources"
                            font.bold: root.currentTab === 1
                            font.pixelSize: 11
                            color: root.currentTab === 1 ? "#B45309" : "#57534E"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 1
                    }
                }

                // Tab 2: AI Database
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 7
                    color: root.currentTab === 2 ? "#FFFFFF" : "transparent"
                    border.color: root.currentTab === 2 ? "#E2D9C8" : "transparent"
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Label { text: "🤖"; font.pixelSize: 13 }
                        Label {
                            text: langManager ? langManager.t("tab_ai_notice") : "AI Database"
                            font.bold: root.currentTab === 2
                            font.pixelSize: 11
                            color: root.currentTab === 2 ? "#B45309" : "#57534E"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 2
                    }
                }

                // Tab 3: Privacy Policy
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 7
                    color: root.currentTab === 3 ? "#FFFFFF" : "transparent"
                    border.color: root.currentTab === 3 ? "#E2D9C8" : "transparent"
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Label { text: "🔒"; font.pixelSize: 13 }
                        Label {
                            text: langManager ? langManager.t("tab_privacy_policy") : "Privacy Policy"
                            font.bold: root.currentTab === 3
                            font.pixelSize: 11
                            color: root.currentTab === 3 ? "#B45309" : "#57534E"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = 3
                    }
                }
            }
        }

        // --- Tab Content Area ---
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentTab

            // ==========================================
            // TAB 0: About, Repository & Qt GPLv3 License
            // ==========================================
            Flickable {
                clip: true
                contentWidth: width
                contentHeight: tab0Col.implicitHeight + 20
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: tab0Col
                    width: parent.width
                    spacing: 14

                    // App Intro Box
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: introLayout.implicitHeight + 24

                        RowLayout {
                            id: introLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 12

                            Rectangle {
                                width: 48
                                height: 48
                                radius: 12
                                color: "#FEF3C7"
                                Label {
                                    anchors.centerIn: parent
                                    text: "🥗"
                                    font.pixelSize: 26
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Label {
                                    text: "Speis: Cozy Meal Planner & Nutrition Quest"
                                    font.bold: true
                                    font.pixelSize: 15
                                    color: "#1C1917"
                                }
                                Label {
                                    text: "Free & Open Source Educational Game and Daily Meal Planner under the GNU General Public License v3.0 (GPLv3)."
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    font.pixelSize: 11
                                    color: "#57534E"
                                }
                            }
                        }
                    }

                    // Links & Repository Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: repoCol.implicitHeight + 24

                        ColumnLayout {
                            id: repoCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 10

                            Label {
                                text: "🌐 Project Links & Source Code"
                                font.bold: true
                                font.pixelSize: 13
                                color: "#1C1917"
                            }

                            // GitHub Repo Row
                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 8
                                color: ghHover.containsMouse ? "#EFF6FF" : "#F8FAFC"
                                border.color: ghHover.containsMouse ? "#3B82F6" : "#E2E8F0"
                                MouseArea {
                                    id: ghHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally("https://github.com/mesw/QtSpeis")
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Label { text: "💻"; font.pixelSize: 15 }
                                    Label {
                                        text: "Source Code Repository:"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#334155"
                                    }
                                    Label {
                                        text: "github.com/mesw/QtSpeis ↗"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#2563EB"
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            // WebAssembly Live Demo Row
                            Rectangle {
                                Layout.fillWidth: true
                                height: 40
                                radius: 8
                                color: wasmHover.containsMouse ? "#ECFDF5" : "#F8FAFC"
                                border.color: wasmHover.containsMouse ? "#10B981" : "#E2E8F0"
                                MouseArea {
                                    id: wasmHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally("https://mesw.github.io/QtSpeis")
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Label { text: "🚀"; font.pixelSize: 15 }
                                    Label {
                                        text: "Live WebAssembly App:"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#334155"
                                    }
                                    Label {
                                        text: "mesw.github.io/QtSpeis ↗"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#059669"
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }

                    // Qt & WebAssembly Static Linking Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: qtCol.implicitHeight + 24

                        ColumnLayout {
                            id: qtCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                spacing: 8
                                Label { text: "📦"; font.pixelSize: 16 }
                                Label {
                                    text: "Qt License & WebAssembly Static Linking"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "QtSpeis is built using the Qt 6 framework (Qt Quick, Qt Quick Controls 2, Qt Network, Qt Sql).\n\n" +
                                      "In the WebAssembly version, all Qt libraries and C++ application modules are statically linked into a single WebAssembly binary (appQtSpeis.wasm). Because static linking combines Qt libraries directly into the target binary under the terms of the GNU General Public License v3 (GPLv3), QtSpeis is obligated to and fully released under the terms of the GNU General Public License version 3 (GPLv3).\n\n" +
                                      "In accordance with GPLv3 Section 6, the complete corresponding machine-readable source code, CMake build configurations, and compilation recipes are publicly hosted and freely accessible at github.com/mesw/QtSpeis."
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11
                                lineHeight: 1.35
                                color: "#44403C"
                            }
                        }
                    }
                }
            }

            // ==========================================
            // TAB 1: Used Data Sources & Copyright
            // ==========================================
            Flickable {
                clip: true
                contentWidth: width
                contentHeight: tab1Col.implicitHeight + 20
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: tab1Col
                    width: parent.width
                    spacing: 12

                    // Overview preamble
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 10
                        color: "#FEF3C7"
                        border.color: "#FDE68A"
                        border.width: 1
                        implicitHeight: preamTxt.implicitHeight + 20

                        Text {
                            id: preamTxt
                            anchors.fill: parent
                            anchors.margins: 12
                            text: "Speis compiles, normalizes, and imputes nutrient values from official national and international food composition databases. All data remains the intellectual property of their respective publishing agencies and research institutions."
                            wrapMode: Text.WordWrap
                            font.pixelSize: 12
                            font.bold: true
                            color: "#92400E"
                            lineHeight: 1.3
                        }
                    }

                    // 1. USDA FDC
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: src1Col.implicitHeight + 24

                        ColumnLayout {
                            id: src1Col
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Label { text: "🇺🇸"; font.pixelSize: 18 }
                                Label {
                                    text: "USDA FoodData Central (FDC)"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "<a href='https://fdc.nal.usda.gov/' style='color:#2563EB; text-decoration:none; font-weight:bold;'>fdc.nal.usda.gov ↗</a>"
                                    font.pixelSize: 11
                                    textFormat: Text.RichText
                                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://fdc.nal.usda.gov/")
                                    }
                                }
                            }
                            Label {
                                text: "U.S. Department of Agriculture, Agricultural Research Service. Comprehensive Foundation Foods, SR Legacy, and FNDDS nutrient profiles."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 11
                                color: "#44403C"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                radius: 6
                                color: "#F0FDF4"
                                border.color: "#BBF7D0"
                                Label {
                                    anchors.centerIn: parent
                                    text: "Copyright & License: Public Domain (U.S. Government Work)."
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#166534"
                                }
                            }
                        }
                    }

                    // 2. Swiss Food Composition Database
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: src2Col.implicitHeight + 24

                        ColumnLayout {
                            id: src2Col
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Label { text: "🇨🇭"; font.pixelSize: 18 }
                                Label {
                                    text: "Swiss Food Composition Database"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "<a href='https://naehrwertdaten.ch/' style='color:#2563EB; text-decoration:none; font-weight:bold;'>naehrwertdaten.ch ↗</a>"
                                    font.pixelSize: 11
                                    textFormat: Text.RichText
                                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://naehrwertdaten.ch/")
                                    }
                                }
                            }
                            Label {
                                text: "Federal Food Safety and Veterinary Office (FSVO / BLV) & ETH Zurich. Standard Swiss nutritional values (Version 6.0+)."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 11
                                color: "#44403C"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                radius: 6
                                color: "#F0FDF4"
                                border.color: "#BBF7D0"
                                Label {
                                    anchors.centerIn: parent
                                    text: "Copyright & License: © Federal Food Safety and Veterinary Office (FSVO), Switzerland / Open Government Data (OGD)."
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#166534"
                                }
                            }
                        }
                    }

                    // 3. French Ciqual Database
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: src3Col.implicitHeight + 24

                        ColumnLayout {
                            id: src3Col
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Label { text: "🇫🇷"; font.pixelSize: 18 }
                                Label {
                                    text: "French Ciqual Database"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "<a href='https://ciqual.anses.fr/' style='color:#2563EB; text-decoration:none; font-weight:bold;'>ciqual.anses.fr ↗</a>"
                                    font.pixelSize: 11
                                    textFormat: Text.RichText
                                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://ciqual.anses.fr/")
                                    }
                                }
                            }
                            Label {
                                text: "French Agency for Food, Environmental and Occupational Health & Safety (ANSES). Nutritional composition of over 3,000 foods."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 11
                                color: "#44403C"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                radius: 6
                                color: "#F0FDF4"
                                border.color: "#BBF7D0"
                                Label {
                                    anchors.centerIn: parent
                                    text: "Copyright & License: © ANSES / Open Licence (Licence Ouverte / Etalab)."
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#166534"
                                }
                            }
                        }
                    }

                    // 4. German BLS
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: src4Col.implicitHeight + 24

                        ColumnLayout {
                            id: src4Col
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Label { text: "🇩🇪"; font.pixelSize: 18 }
                                Label {
                                    text: "Bundeslebensmittelschlüssel (BLS)"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "<a href='https://www.mri.bund.de/de/institute/ernaehrung-und-verhalten/forschungsprojekte/bls/' style='color:#2563EB; text-decoration:none; font-weight:bold;'>mri.bund.de/bls ↗</a>"
                                    font.pixelSize: 11
                                    textFormat: Text.RichText
                                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://www.mri.bund.de/de/institute/ernaehrung-und-verhalten/forschungsprojekte/bls/")
                                    }
                                }
                            }
                            Label {
                                text: "Max Rubner-Institut (MRI), Federal Research Institute of Nutrition and Food, Germany. Standard German reference nutrient database."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 11
                                color: "#44403C"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                radius: 6
                                color: "#F0FDF4"
                                border.color: "#BBF7D0"
                                Label {
                                    anchors.centerIn: parent
                                    text: "Copyright & License: © Max Rubner-Institut (MRI), Federal Ministry of Food and Agriculture (BMEL)."
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#166534"
                                }
                            }
                        }
                    }

                    // 5. FlavorDB & Aroma Networks
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: src5Col.implicitHeight + 24

                        ColumnLayout {
                            id: src5Col
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Label { text: "🔬"; font.pixelSize: 18 }
                                Label {
                                    text: "FlavorDB & Aroma Networks"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "<a href='https://cosylab.iiitd.edu.in/flavordb/' style='color:#2563EB; text-decoration:none; font-weight:bold;'>cosylab.iiitd.edu.in/flavordb ↗</a>"
                                    font.pixelSize: 11
                                    textFormat: Text.RichText
                                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("https://cosylab.iiitd.edu.in/flavordb/")
                                    }
                                }
                            }
                            Label {
                                text: "Computational biology resource of 25,000+ flavor molecule pairings and chemical odor profile graphs (Garg et al., IIIT-Delhi)."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 11
                                color: "#44403C"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                radius: 6
                                color: "#F0FDF4"
                                border.color: "#BBF7D0"
                                Label {
                                    anchors.centerIn: parent
                                    text: "Copyright & License: Open Academic Resource / CC BY-NC 4.0."
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#166534"
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // TAB 2: AI Generation Notice & Disclaimer
            // ==========================================
            Flickable {
                clip: true
                contentWidth: width
                contentHeight: tab2Col.implicitHeight + 20
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: tab2Col
                    width: parent.width
                    spacing: 14

                    // AI Generation Disclosure Banner
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FEF2F2"
                        border.color: "#FECACA"
                        border.width: 1
                        implicitHeight: aiDiscCol.implicitHeight + 24

                        ColumnLayout {
                            id: aiDiscCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                spacing: 8
                                Label { text: "⚠️"; font.pixelSize: 18 }
                                Label {
                                    text: "AI Generation Disclosure & Error Notice"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#991B1B"
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "The database speis.db was generated and compiled from national and international food composition databases using Artificial Intelligence (AI) and automated statistical imputation pipelines.\n\n" +
                                      "Due to variations in laboratory measurement protocols across countries, language translations, and automated normalization algorithms, the database may contain inaccuracies or errors.\n\n" +
                                      "Users should be aware that data values may not always reflect exact clinical lab measurements for specific commercial brands or variations in regional agricultural produce."
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11
                                lineHeight: 1.35
                                color: "#7F1D1D"
                            }
                        }
                    }

                    // Educational Purpose Disclaimer
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: eduCol.implicitHeight + 24

                        ColumnLayout {
                            id: eduCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                spacing: 8
                                Label { text: "🎓"; font.pixelSize: 16 }
                                Label {
                                    text: "Educational Simulation & Gaming Purpose Only"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "QtSpeis is designed as an interactive educational simulation and game to help users intuitively understand macronutrient balances, calorie targets, and dietary diversity.\n\n" +
                                      "The nutritional figures, scores, and coaching tips provided in this software are for educational and informational purposes only. QtSpeis does not provide medical, diagnostic, or clinical dietary advice. Always consult a qualified registered dietitian or medical healthcare professional for personal medical conditions, allergies, or therapeutic diets."
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11
                                lineHeight: 1.35
                                color: "#44403C"
                            }
                        }
                    }
                }
            }

            // ==========================================
            // TAB 3: Privacy Policy & Local Storage
            // ==========================================
            Flickable {
                clip: true
                contentWidth: width
                contentHeight: tab3Col.implicitHeight + 20
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: tab3Col
                    width: parent.width
                    spacing: 14

                    // Privacy summary card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#F0FDF4"
                        border.color: "#BBF7D0"
                        border.width: 1
                        implicitHeight: privTopCol.implicitHeight + 24

                        ColumnLayout {
                            id: privTopCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                spacing: 8
                                Label { text: "🛡️"; font.pixelSize: 18 }
                                Label {
                                    text: "100% Client-Side Privacy — Zero Server Tracking"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#166534"
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "QtSpeis is built with a strict privacy-first architecture. All user data, meal plans, custom recipes, athletic workouts, profile metrics, and game level progression remain exclusively inside your own browser or local desktop installation.\n\n" +
                                      "No user data is ever transmitted, synchronized, or uploaded to any external server or cloud analytics platform."
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11
                                lineHeight: 1.35
                                color: "#14532D"
                            }
                        }
                    }

                    // How and Where Data Is Stored
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: "#FFFFFF"
                        border.color: "#E7E5E4"
                        border.width: 1
                        implicitHeight: storCol.implicitHeight + 24

                        ColumnLayout {
                            id: storCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                spacing: 8
                                Label { text: "💾"; font.pixelSize: 16 }
                                Label {
                                    text: "How & Where Data Is Stored (Save Game System)"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: "#1C1917"
                                }
                            }

                            // WASM Storage
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 8
                                color: "#F8FAFC"
                                border.color: "#E2E8F0"
                                implicitHeight: wasmStorCol.implicitHeight + 16

                                ColumnLayout {
                                    id: wasmStorCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Label {
                                        text: "🌐 WebAssembly In-Browser Storage:"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#1E293B"
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: "In the web version, save game data is stored directly in your browser's standard HTML5 window.localStorage. The keys used are:\n" +
                                              "  • speis_savegame_v1 : Autosaved active meal plan and campaign progress.\n" +
                                              "  • speis_savegame_slots_v1 : Custom named save slots created by you.\n" +
                                              "This data stays entirely inside your private browser profile on your device."
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: 11
                                        lineHeight: 1.3
                                        color: "#475569"
                                    }
                                }
                            }

                            // Desktop Storage
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 8
                                color: "#F8FAFC"
                                border.color: "#E2E8F0"
                                implicitHeight: dskStorCol.implicitHeight + 16

                                ColumnLayout {
                                    id: dskStorCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Label {
                                        text: "💻 Desktop Native Storage:"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#1E293B"
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: "In native desktop builds, data is stored locally via Qt QSettings in the user's standard configuration directory under organization 'SpeisApp' and application 'SaveGame'. No background services or network sync daemons are utilized."
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: 11
                                        lineHeight: 1.3
                                        color: "#475569"
                                    }
                                }
                            }

                            // JSON File Backup
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 8
                                color: "#F8FAFC"
                                border.color: "#E2E8F0"
                                implicitHeight: jsonStorCol.implicitHeight + 16

                                ColumnLayout {
                                    id: jsonStorCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Label {
                                        text: "📁 Manual JSON Backup & Export:"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#1E293B"
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: "You can download/export your full meal plan, recipes, and game progress as a local .json file or import existing files. File processing occurs completely in-memory on your device without transmitting file contents anywhere."
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: 11
                                        lineHeight: 1.3
                                        color: "#475569"
                                    }
                                }
                            }

                            // Optional Network Request: Open Food Facts
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 8
                                color: "#F8FAFC"
                                border.color: "#E2E8F0"
                                implicitHeight: netCol.implicitHeight + 16

                                ColumnLayout {
                                    id: netCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Label {
                                        text: "📡 Optional Network Feature (Barcode Scanner):"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#1E293B"
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: "If and only if you explicitly choose to scan or look up a barcode, the application makes an outgoing HTTPS GET query to the public Open Food Facts API (world.openfoodfacts.org) to retrieve product nutrition information. No personal identifiers or meal plans are sent with this lookup."
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: 11
                                        lineHeight: 1.3
                                        color: "#475569"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Dialog Footer ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Button {
                text: langManager ? langManager.t("btn_close") : "Close"
                font.bold: true
                font.pixelSize: 11
                Layout.preferredHeight: 34
                Layout.preferredWidth: 90
                palette.buttonText: "#292524"
                background: Rectangle {
                    radius: 8
                    color: parent.hovered ? "#E7E5E4" : "#F5F5F4"
                    border.color: "#D6D3D1"
                }
                onClicked: root.close()
            }
        }
    }
}
