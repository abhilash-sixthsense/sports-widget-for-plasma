/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: widgetTab

    required property var configRoot

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    Kirigami.Separator {
        Kirigami.FormData.label: i18nc("@title:group", "Widget")
        Kirigami.FormData.isSection: true
    }

    ComboBox {
        id: widgetTabs

        Kirigami.FormData.label: i18nc("@label:listbox", "Widget layout:")
        Layout.fillWidth: true
        textRole: "label"
        valueRole: "value"
        model: [{
            "label": i18nc("@item:inlistbox", "All tabs"),
            "value": "all"
        }, {
            "label": i18nc("@item:inlistbox", "Live + Schedules + Recent Results"),
            "value": "liveStats"
        }, {
            "label": i18nc("@item:inlistbox", "Live + Schedules + Tables"),
            "value": "liveTables"
        }, {
            "label": i18nc("@item:inlistbox", "Live + Schedules"),
            "value": "liveOnly"
        }]
        Component.onCompleted: currentIndex = widgetTab.indexFor(model, widgetTab.configRoot.cfg_widgetTabs || "all")
        onActivated: widgetTab.configRoot.cfg_widgetTabs = currentValue
    }
}
