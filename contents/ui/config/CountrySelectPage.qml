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
    property string countryFilter: ""

    title: i18nc("@title:group", "Country")
    subtitle: i18nc("@info", "Only one country can be active for the selected sport.")
    filterText: root.countryFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search countries")
    onFilterEdited: text => root.countryFilter = text

    Repeater {
        model: root.configRoot ? root.configRoot.filtered(root.configRoot.countryOptions(), root.countryFilter) : []

        delegate: SportChoiceCard {
            title: modelData.label
            flagSource: String(modelData.icon || "").indexOf("file://") === 0 ? modelData.icon : ""
            iconName: String(modelData.icon || "").indexOf("file://") === 0 ? "" : modelData.icon || ""
            infoText: modelData.infoText || ""
            selected: root.configRoot && root.configRoot.cfg_country === modelData.value
            onClicked: root.configRoot.selectCountry(modelData.value)
        }
    }
}
