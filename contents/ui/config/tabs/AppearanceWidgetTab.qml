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

    Switch {
        id: widgetMatchRotation

        Kirigami.FormData.label: i18nc("@label:checkbox", "Match rotation:")
        text: checked ? i18nc("@option:check", "Enabled") : i18nc("@option:check", "Disabled")
        checked: widgetTab.configRoot.cfg_widgetMatchRotationEnabled
        onToggled: widgetTab.configRoot.cfg_widgetMatchRotationEnabled = checked
    }

    SpinBox {
        Kirigami.FormData.label: i18nc("@label:spinbox", "Rotation interval:")
        visible: widgetMatchRotation.checked
        enabled: visible
        from: 5
        to: 300
        stepSize: 5
        editable: true
        value: Math.max(5, widgetTab.configRoot.cfg_widgetMatchRotationInterval || 30)
        textFromValue: (value) => i18ncp("@item:valuesuffix seconds", "%1 second", "%1 seconds", value)
        valueFromText: (text) => {
            const value = parseInt(text, 10);
            return Number.isFinite(value) ? value : 30;
        }
        onValueModified: widgetTab.configRoot.cfg_widgetMatchRotationInterval = value
    }
}
