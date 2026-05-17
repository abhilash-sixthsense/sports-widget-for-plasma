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
    property string favoriteFilter: ""

    title: i18nc("@title:group", "Favorite Team")
    subtitle: i18nc("@info", "Optional. Favorite teams are highlighted and sorted first when enabled.")
    filterText: root.favoriteFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search teams")
    onFilterEdited: text => root.favoriteFilter = text

    Repeater {
        model: root.configRoot ? root.configRoot.filtered(root.configRoot.favoriteOptions(), root.favoriteFilter) : []

        delegate: SportChoiceCard {
            title: modelData.label
            iconName: modelData.value.length > 0 ? "emblem-favorite" : "edit-none"
            selected: root.configRoot && root.configRoot.cfg_favoriteTeam === modelData.value
            onClicked: root.configRoot.cfg_favoriteTeam = modelData.value
        }
    }
}
