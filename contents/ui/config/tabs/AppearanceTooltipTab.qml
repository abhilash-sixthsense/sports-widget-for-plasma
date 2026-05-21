/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: tooltipTab

    Kirigami.Separator {
        Kirigami.FormData.label: i18nc("@title:group", "Tooltip")
        Kirigami.FormData.isSection: true
    }

    Label {
        Kirigami.FormData.label: ""
        Layout.fillWidth: true
        opacity: 0.7
        text: i18nc("@info", "No tooltip appearance options are available yet.")
        wrapMode: Text.WordWrap
    }
}
