/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SportStepPage {
    id: root

    property var configRoot
    property string leagueFilter: ""

    title: i18nc("@title:group", "League")
    subtitle: root.configRoot ? i18nc("@info", "Pick the league or cup to follow for %1.", root.configRoot.countryLabel()) : ""
    filterText: root.leagueFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search leagues")
    onFilterEdited: text => root.leagueFilter = text

    Repeater {
        model: root.configRoot ? root.configRoot.filtered(root.configRoot.leagueOptions(), root.leagueFilter) : []

        delegate: SportChoiceCard {
            title: modelData.label
            iconName: "view-calendar-list"
            selected: root.configRoot && root.configRoot.cfg_league === modelData.value
            onClicked: root.configRoot.selectLeague(modelData.value)
        }
    }
}
