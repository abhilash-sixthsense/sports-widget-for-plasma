/*
 * Copyright 2026  Petar Nedyalkov
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var scheduleModel
    property string favoriteTeam: ""
    property bool loading: false
    property int selectedIndex: 0
    property string emptyText: i18nc("@info:placeholder", "No scheduled matches")
    property string loadingText: i18nc("@info:status", "Loading schedules")
    property string emptyIconName: "view-calendar-day"
    property var collapsedGroups: ({})

    signal matchSelected(int index)

    function isGroupCollapsed(group) {
        return Boolean(root.collapsedGroups[String(group || "")]);
    }

    function toggleGroup(group) {
        const key = String(group || "");
        const next = {};
        for (let existingKey in root.collapsedGroups)
            next[existingKey] = root.collapsedGroups[existingKey];
        next[key] = !root.isGroupCollapsed(key);
        root.collapsedGroups = next;
    }

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    ListView {
        id: scheduleList

        anchors.fill: parent
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        model: root.scheduleModel
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

        section.property: "leagueGroup"
        section.criteria: ViewSection.FullString
        section.delegate: RoundSectionHeader {
            width: scheduleList.contentColumnWidth
            text: section
            collapsible: true
            collapsed: root.isGroupCollapsed(section)
            onToggled: root.toggleGroup(section)
        }

        EmptyState {
            anchors.fill: parent
            visible: scheduleList.count === 0 && !root.loading
            text: root.emptyText
            iconName: root.emptyIconName
        }

        delegate: ScoreDelegate {
            width: scheduleList.contentColumnWidth
            visible: !root.isGroupCollapsed(model.leagueGroup)
            height: visible ? implicitHeight : 0
            enabled: visible
            sport: model.sport
            league: model.league
            homeTeam: model.homeTeam
            awayTeam: model.awayTeam
            homeScore: model.homeScore
            awayScore: model.awayScore
            status: model.status
            minute: model.minute
            startTime: model.startTime
            matchday: model.matchday || ""
            stadium: model.stadium || ""
            homeBadge: model.homeBadge
            awayBadge: model.awayBadge
            poster: model.poster
            popular: model.popular
            showScore: model.showScore !== false
            splitLeagueAndTimeLines: true
            splitDateAndTimeLines: true
            favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
            selected: index === root.selectedIndex
            onClicked: root.matchSelected(index)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
        visible: root.loading && scheduleList.count === 0
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Layout.preferredWidth
            running: root.loading
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: root.loadingText
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    component EmptyState: Item {
        property string text: ""
        property string iconName: "view-calendar-day"

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                source: parent.parent.iconName
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
