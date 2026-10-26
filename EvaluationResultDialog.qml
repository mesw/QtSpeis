import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(580, parent.width - 20)
    height: Math.min(680, parent.height - 20)
    padding: 0

    property var resultData: null
    property var gameLevelManager: null
    property var langManager: null
    signal retryRequested()
    signal nextLevelRequested()
    signal levelSelectRequested()

    background: Rectangle {
        color: "#FFFDF9"
        radius: 18
        border.color: "#E2D9C8"
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 6
            color: (root.resultData && root.resultData.stars >= 2) ? "#16A34A" : ((root.resultData && root.resultData.stars === 1) ? "#D97706" : "#DC2626")
            radius: 3
        }
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.width < 500 ? 12 : 20
        spacing: root.width < 500 ? 10 : 14

        // Celebratory Stars Banner
        Rectangle {
            Layout.fillWidth: true
            height: 110
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: (root.resultData && root.resultData.stars >= 2) ? "#FEF3C7" : "#F5F5F4" }
                GradientStop { position: 1.0; color: "#FFFFFF" }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                // Star glyphs (0 to 3)
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: 3
                        delegate: Label {
                            property int starCount: root.resultData ? root.resultData.stars : 0
                            text: index < starCount ? "★" : "☆"
                            font.pixelSize: 38
                            color: index < starCount ? "#F59E0B" : "#D6D3D1"
                        }
                    }
                }

                // Title
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.resultData
                          ? String(root.resultData.starTitle || "").replace(/^[★☆]+\s*/, "")
                          : (langManager ? langManager.t("evaluating") : "Evaluating...")
                    font.bold: true
                    font.pixelSize: 18
                    color: "#292524"
                }
            }
        }

        // Summary Accuracy Scorecards
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Calorie Accuracy Card
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 10
                color: "#FFFFFF"
                border.color: "#E7E5E4"
                border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label { text: langManager ? langManager.t("calorie_accuracy") : "Calorie Accuracy"; font.pixelSize: 11; color: "#78716C" }
                    Label {
                        text: root.resultData ? (root.resultData.calorieAccuracy + "%") : "-"
                        font.bold: true; font.pixelSize: 18; color: "#D97706"
                    }
                    Label {
                        property real diff: root.resultData ? root.resultData.calorieDiff : 0
                        text: langManager ? langManager.t("diff_kcal", [(diff >= 0 ? "+" : "") + Math.round(diff)]) : ((diff >= 0 ? "+" : "") + Math.round(diff) + " kcal diff")
                        font.pixelSize: 10; color: "#78716C"
                    }
                }
            }

            // Macro Accuracy Card
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 10
                color: "#FFFFFF"
                border.color: "#E7E5E4"
                border.width: 1
                visible: root.resultData ? root.resultData.hasMacroTarget : false

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label { text: langManager ? langManager.t("macro_accuracy") : "Macro Balance Accuracy"; font.pixelSize: 11; color: "#78716C" }
                    Label {
                        text: root.resultData ? (root.resultData.macroAccuracy + "%") : "-"
                        font.bold: true; font.pixelSize: 18; color: "#16A34A"
                    }
                    Label {
                        text: root.resultData
                              ? (Math.round(root.resultData.actualCarbs || 0) + "% C • " +
                                 Math.round(root.resultData.actualProtein || 0) + "% P • " +
                                 Math.round(root.resultData.actualFat || 0) + "% F (" +
                                 Math.round(root.resultData.targetCarbs || 55) + "/" +
                                 Math.round(root.resultData.targetProtein || 15) + "/" +
                                 Math.round(root.resultData.targetFat || 30) + "%)")
                              : "55% C • 15% P • 30% F"
                        font.pixelSize: 10; color: "#78716C"
                    }
                }
            }
        }

        // Constraints Checklist
        Label {
            text: (root.resultData && root.resultData.levelId && root.resultData.levelId !== 24)
                  ? ("Level " + root.resultData.levelId + " Constraint:")
                  : (langManager ? langManager.t("constraints_breakdown") : "Constraints Breakdown:")
            font.bold: true
            font.pixelSize: 12
            color: "#44403C"
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.resultData ? root.resultData.constraints : []

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(44, constraintCol.implicitHeight + 14)
                        radius: 8
                        color: modelData.met ? "#F0FDF4" : "#FEF2F2"
                        border.color: modelData.met ? "#BBF7D0" : "#FECACA"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Label {
                                text: modelData.met ? "✔" : "✘"
                                font.bold: true
                                font.pixelSize: 16
                                color: modelData.met ? "#16A34A" : "#DC2626"
                            }

                            ColumnLayout {
                                id: constraintCol
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: modelData.name
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: "#1C1917"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Label {
                                    visible: modelData.target ? true : false
                                    text: "Target: " + modelData.target
                                    font.pixelSize: 10
                                    color: "#78716C"
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            ColumnLayout {
                                spacing: 1
                                Label {
                                    text: modelData.actual
                                    font.bold: true
                                    font.pixelSize: 11
                                    color: modelData.met ? "#15803D" : "#B91C1C"
                                    Layout.alignment: Qt.AlignRight
                                }
                                Label {
                                    visible: modelData.grade ? true : false
                                    text: modelData.grade
                                    font.pixelSize: 9
                                    color: modelData.met ? "#16A34A" : "#DC2626"
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }

                // Hero Constraints Breakdown (if active)
                Repeater {
                    model: root.resultData ? root.resultData.heroConstraints : []

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 8
                        color: modelData.met ? "#F0FDF4" : "#FEF2F2"
                        border.color: modelData.met ? "#BBF7D0" : "#FECACA"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Label {
                                text: modelData.met ? "🛡️ ✔" : "⚔️ ✘"
                                font.bold: true
                                font.pixelSize: 13
                                color: modelData.met ? "#16A34A" : "#DC2626"
                            }

                            Label {
                                text: "Hero Challenge " + modelData.heroId
                                font.bold: true
                                font.pixelSize: 12
                                color: "#1C1917"
                            }

                            Label {
                                text: modelData.reason
                                font.pixelSize: 11
                                color: modelData.met ? "#15803D" : "#B91C1C"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Educational Coaching Tip Card
                Rectangle {
                    Layout.fillWidth: true
                    radius: 10
                    color: "#FEF9C3"
                    border.color: "#FEF08A"
                    border.width: 1
                    implicitHeight: tipCol.implicitHeight + 16

                    ColumnLayout {
                        id: tipCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            spacing: 6
                            Label { text: "💡"; font.pixelSize: 14 }
                            Label {
                                text: langManager ? langManager.t("coach_feedback") : "Nutrition Coach's Feedback:"
                                font.bold: true
                                font.pixelSize: 11
                                color: "#854D0E"
                            }
                        }

                        Label {
                            text: root.resultData ? root.resultData.coachingTip : ""
                            font.pixelSize: 11
                            color: "#713F12"
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
                text: langManager ? langManager.t("keep_editing") : "✏️ Keep Editing"
                Layout.preferredHeight: 38
                flat: true
                font.pixelSize: 12
                palette.buttonText: "#78716C"
                onClicked: root.close()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: langManager ? langManager.t("levels_menu") : "🏆 Levels Menu"
                Layout.preferredHeight: 38
                font.pixelSize: 12
                palette.buttonText: "#57534E"
                background: Rectangle { radius: 8; color: "#F5F5F4"; border.color: "#E7E5E4" }
                onClicked: {
                    root.close();
                    root.levelSelectRequested();
                }
            }

            Button {
                text: langManager ? langManager.t("next_level") : "Next Level →"
                Layout.preferredHeight: 38
                visible: root.resultData && root.resultData.stars >= 1 && root.resultData.levelId < 24
                font.bold: true
                font.pixelSize: 12
                palette.buttonText: "#FFFFFF"
                background: Rectangle { radius: 8; color: "#16A34A" }
                onClicked: {
                    root.close();
                    if (gameLevelManager && root.resultData) {
                        gameLevelManager.currentLevel = root.resultData.levelId + 1;
                    }
                }
            }
        }
    }
}
