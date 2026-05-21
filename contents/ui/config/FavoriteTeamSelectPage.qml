/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SportStepPage {
    id: root

    property var configRoot
    property string favoriteFilter: ""

    title: i18nc("@title:group", "Favorite Team")
    subtitle: i18nc("@info", "Optional. Choose whether the saved sport follows the league or the team across competitions.")
    filterText: root.favoriteFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search teams")
    onFilterEdited: text => root.favoriteFilter = text

    headerContent: Frame {
        Layout.fillWidth: true
        visible: root.configRoot && root.configRoot.cfg_favoriteTeam.length > 0

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    text: i18nc("@label", "Follow mode")
                    font.bold: true
                }

                Label {
                    Layout.fillWidth: true
                    text: followTeamSwitch.checked ? i18nc("@info", "Show this team across competitions; tables can be switched when more competitions are available.") : i18nc("@info", "Show the selected league; the favorite team is highlighted and sorted first.")
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                }
            }

            Switch {
                id: followTeamSwitch

                text: checked ? i18nc("@option:check", "Team") : i18nc("@option:check", "League")
                enabled: root.configRoot && root.configRoot.cfg_favoriteTeam.length > 0
                checked: root.configRoot && root.configRoot.cfg_followMode === "team"
                onToggled: {
                    if (root.configRoot)
                        root.configRoot.setFollowMode(checked ? "team" : "league");
                }
            }
        }
    }

    Repeater {
        model: root.configRoot ? root.configRoot.filtered(root.configRoot.favoriteOptions(), root.favoriteFilter) : []

        delegate: SportChoiceCard {
            title: modelData.label
            iconName: modelData.value.length > 0 ? "emblem-favorite" : "edit-none"
            selected: root.configRoot && root.configRoot.cfg_favoriteTeam === modelData.value
            onClicked: {
                root.configRoot.cfg_favoriteTeam = modelData.value;
                if (modelData.value.length === 0)
                    root.configRoot.setFollowMode("league");
            }
        }
    }
}
