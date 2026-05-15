/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: root

    property string sport: ""
    property string league: ""
    property string homeTeam: ""
    property string awayTeam: ""
    property string homeScore: ""
    property string awayScore: ""
    property string status: ""
    property string minute: ""
    property string startTime: ""
    property string stadium: ""
    property string homeBadge: ""
    property string awayBadge: ""
    property string poster: ""
    property bool popular: false
    property bool favorite: false

    function scoreText() {
        if (root.homeScore.length === 0 && root.awayScore.length === 0)
            return "-";

        return root.homeScore + " - " + root.awayScore;
    }

    function centerTimeText() {
        if (root.minute.length > 0)
            return root.minute;

        if (root.startTime.length > 0)
            return root.startTime;

        return root.status === "Live" ? root.status : "";
    }

    height: Kirigami.Units.gridUnit * 3.6
    color: favorite ? Qt.rgba(1, 0.59, 0.31, 0.14) : "transparent"

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: "#29464f"
    }

    Item {
        id: rowContent

        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing

        ColumnLayout {
            id: scoreColumn

            width: Kirigami.Units.gridUnit * 5.5
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            PlasmaComponents.Label {
                width: parent.width
                text: scoreText()
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
                font.pixelSize: Kirigami.Units.gridUnit
            }

            PlasmaComponents.Label {
                width: parent.width
                text: centerTimeText()
                color: root.status === "Live" ? "#6ee7a7" : "#9db7be"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            PlasmaComponents.Label {
                width: parent.width
                visible: root.stadium.length > 0
                text: root.stadium
                color: "#9db7be"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize - 1)
            }

        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: scoreColumn.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            TeamLogo {
                sourceUrl: root.homeBadge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.homeTeam
                    color: "#e7fbff"
                    elide: Text.ElideRight
                    font.bold: true
                }

            }
        }

        RowLayout {
            anchors.left: scoreColumn.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Kirigami.Units.smallSpacing
            spacing: 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.awayTeam
                    color: "#e7fbff"
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    font.bold: true
                }

            }

            TeamLogo {
                sourceUrl: root.awayBadge
            }

        }

    }

    component TeamLogo: Item {
        property string sourceUrl: ""

        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Layout.preferredWidth

        Image {
            anchors.fill: parent
            source: sourceUrl
            visible: sourceUrl.length > 0
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: width
            sourceSize.height: height
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: "emblem-favorite"
            visible: sourceUrl.length === 0
            color: "#9db7be"
            opacity: 0.5
        }

    }

}
