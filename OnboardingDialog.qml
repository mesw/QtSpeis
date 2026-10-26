import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(540, (parent ? parent.width : 540) - 16)
    height: Math.min(640, (parent ? parent.height : 640) - 20)
    padding: 0

    property var gameLevelManager: null
    property var langManager: null

    signal customizeProfileRequested()
    signal startQuestRequested()

    readonly property bool isNarrow: root.width < 440

    background: Rectangle {
        color: "#FFFDF9"
        radius: 18
        border.color: "#E2D9C8"
        border.width: 1
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.isNarrow ? 12 : 18
        spacing: 12

        // Header Banner
        Rectangle {
            Layout.fillWidth: true
            height: root.isNarrow ? 76 : 88
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#FEF3C7" }
                GradientStop { position: 1.0; color: "#FFFFFF" }
            }
            border.color: "#FDE68A"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    width: root.isNarrow ? 38 : 46
                    height: root.isNarrow ? 38 : 46
                    radius: 12
                    color: "#D97706"
                    Label {
                        anchors.centerIn: parent
                        text: "🥗"
                        font.pixelSize: root.isNarrow ? 20 : 26
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: langManager ? langManager.t("welcome_onboarding_title") : "Willkommen bei Nutrition Quest!"
                        font.bold: true
                        font.pixelSize: root.isNarrow ? 14 : 17
                        color: "#1C1917"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Label {
                        text: langManager ? langManager.t("welcome_onboarding_subtitle") : "Dein evidenzbasiertes Sporternährungs- & Biochemie-Puzzle."
                        font.pixelSize: root.isNarrow ? 10 : 11
                        color: "#78716C"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Onboarding Steps
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width - 4
                spacing: 10

                // Step 1: Profile & BMR
                Rectangle {
                    Layout.fillWidth: true
                    radius: 10
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    border.width: 1
                    implicitHeight: step1Col.implicitHeight + 16

                    ColumnLayout {
                        id: step1Col
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: "#EFF6FF"
                                border.color: "#BFDBFE"
                                Label { anchors.centerIn: parent; text: "👤"; font.pixelSize: 13 }
                            }
                            Label {
                                text: langManager ? langManager.t("onboarding_step1_title") : "1. Athletenprofil einrichten"
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1E40AF"
                            }
                        }

                        Label {
                            text: langManager ? langManager.t("onboarding_step1_desc") : "Passe Grundumsatz (BMR) und Makro-Verteilung an deine Sportart an."
                            font.pixelSize: 11
                            color: "#57534E"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // Step 2: Meals & Foods
                Rectangle {
                    Layout.fillWidth: true
                    radius: 10
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    border.width: 1
                    implicitHeight: step2Col.implicitHeight + 16

                    ColumnLayout {
                        id: step2Col
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: "#FEF3C7"
                                border.color: "#FDE68A"
                                Label { anchors.centerIn: parent; text: "🥑"; font.pixelSize: 13 }
                            }
                            Label {
                                text: langManager ? langManager.t("onboarding_step2_title") : "2. Mahlzeiten zusammenstellen"
                                font.bold: true
                                font.pixelSize: 12
                                color: "#92400E"
                            }
                        }

                        Label {
                            text: langManager ? langManager.t("onboarding_step2_desc") : "Kombiniere Zutaten und Rezepte, um deine Zielwerte genau zu treffen."
                            font.pixelSize: 11
                            color: "#57534E"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                // Step 3: Grade & Progress
                Rectangle {
                    Layout.fillWidth: true
                    radius: 10
                    color: "#FFFFFF"
                    border.color: "#E7E5E4"
                    border.width: 1
                    implicitHeight: step3Col.implicitHeight + 16

                    ColumnLayout {
                        id: step3Col
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: "#ECFDF5"
                                border.color: "#A7F3D0"
                                Label { anchors.centerIn: parent; text: "⭐"; font.pixelSize: 13 }
                            }
                            Label {
                                text: langManager ? langManager.t("onboarding_step3_title") : "3. Plan auswerten & Aufsteigen"
                                font.bold: true
                                font.pixelSize: 12
                                color: "#065F46"
                            }
                        }

                        Label {
                            text: langManager ? langManager.t("onboarding_step3_desc") : "Meistere die Regeln von Level 1 bis 24 und werde zum Großmeister!"
                            font.pixelSize: 11
                            color: "#57534E"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
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
                id: customProfBtn
                text: langManager ? langManager.t("customize_profile_btn") : "⚙️ Profil anpassen"
                Layout.preferredHeight: 40
                Layout.fillWidth: root.isNarrow
                font.pixelSize: 12
                font.bold: true
                palette.buttonText: "#57534E"
                background: Rectangle {
                    radius: 8
                    color: customProfBtn.down ? "#E7E5E4" : (customProfBtn.hovered ? "#F5F5F4" : "#FFFFFF")
                    border.color: "#D6D3D1"
                }
                onClicked: {
                    if (gameLevelManager) gameLevelManager.setOnboardingCompleted(true);
                    root.close();
                    root.customizeProfileRequested();
                }
            }

            Item { visible: !root.isNarrow; Layout.fillWidth: true }

            Button {
                id: startBtn
                text: langManager ? langManager.t("quick_start_btn") : "⚡ Schnellstart"
                Layout.preferredHeight: 40
                Layout.fillWidth: root.isNarrow
                font.pixelSize: 13
                font.bold: true
                palette.buttonText: "#FFFFFF"
                background: Rectangle {
                    radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#D97706" }
                        GradientStop { position: 1.0; color: "#EA580C" }
                    }
                }
                onClicked: {
                    if (gameLevelManager) gameLevelManager.setOnboardingCompleted(true);
                    root.close();
                    root.startQuestRequested();
                }
            }
        }
    }
}
