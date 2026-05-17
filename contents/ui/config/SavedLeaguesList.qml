/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportVisuals.js" as SportVisuals
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var configRoot
    property int renameIndex: -1

    spacing: Kirigami.Units.smallSpacing

    function openRenameDialog(index, entry) {
        root.renameIndex = index;
        leagueNameField.text = root.configRoot.displayLeagueLabel(entry);
        countryNameField.text = root.configRoot.displayCountryLabel(entry);
        favoriteNameField.text = root.configRoot.displayFavoriteTeam(entry);
        renameDialog.open();
    }

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Heading {
            text: i18nc("@title:group", "Saved Leagues")
            level: 4
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.separatorColor
            opacity: 0.6
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.configRoot && root.configRoot.savedLeagues().length === 0
        text: i18nc("@info", "Save leagues here to switch quickly between them with their favorite team.")
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.configRoot ? root.configRoot.savedLeagues() : []

        delegate: ItemDelegate {
            id: savedDelegate

            required property int index
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: savedContent.implicitHeight + Kirigami.Units.smallSpacing
            hoverEnabled: true
            onClicked: root.configRoot.applySavedLeague(modelData, savedDelegate.index)

            readonly property bool active: root.configRoot && root.configRoot.sameEntry(modelData, root.configRoot.currentEntry())

            background: Rectangle {
                radius: 4
                color: savedDelegate.active ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.20) : savedDelegate.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.10) : "transparent"
                border.color: savedDelegate.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.separatorColor
                border.width: savedDelegate.active ? 1 : 0
            }

            contentItem: RowLayout {
                id: savedContent

                spacing: Kirigami.Units.smallSpacing

                CountryFlag {
                    sourceUrl: modelData.countryIcon || root.configRoot.countryIconForEntry(modelData)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: root.configRoot.displayLeagueLabel(modelData)
                        color: savedDelegate.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        font.bold: savedDelegate.active
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: {
                            const parts = [SportVisuals.label(modelData.sport), root.configRoot.displayCountryLabel(modelData)];
                            const favorite = root.configRoot.displayFavoriteTeam(modelData);
                            if (favorite.length > 0)
                                parts.push(i18nc("@label", "Favorite: %1", favorite));
                            return parts.join(" · ");
                        }
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }

                ToolButton {
                    icon.name: modelData.starred ? "starred-symbolic" : "non-starred-symbolic"
                    display: AbstractButton.IconOnly
                    text: i18nc("@action:button", "Default")
                    ToolTip.visible: hovered
                    ToolTip.text: modelData.starred ? i18nc("@info:tooltip", "Favorite league") : i18nc("@info:tooltip", "Mark as favorite")
                    onClicked: root.configRoot.starSavedLeague(savedDelegate.index)
                }

                ToolButton {
                    icon.name: "edit-rename"
                    display: AbstractButton.IconOnly
                    text: i18nc("@action:button", "Rename")
                    ToolTip.visible: hovered
                    ToolTip.text: i18nc("@info:tooltip", "Rename saved league labels")
                    onClicked: root.openRenameDialog(savedDelegate.index, modelData)
                }

                ToolButton {
                    icon.name: "configure"
                    display: AbstractButton.IconOnly
                    text: i18nc("@action:button", "Edit")
                    ToolTip.visible: hovered
                    ToolTip.text: i18nc("@info:tooltip", "Change sport, country, league or favorite team")
                    onClicked: root.configRoot.openEditSavedLeague(modelData, savedDelegate.index)
                }

                ToolButton {
                    icon.name: "edit-delete"
                    display: AbstractButton.IconOnly
                    text: i18nc("@action:button", "Delete")
                    ToolTip.visible: hovered
                    ToolTip.text: i18nc("@info:tooltip", "Remove saved league")
                    onClicked: root.configRoot.removeSavedLeague(savedDelegate.index)
                }
            }
        }
    }

    Dialog {
        id: renameDialog

        modal: true
        title: i18nc("@title:window", "Rename Saved League")
        standardButtons: Dialog.Ok | Dialog.Cancel

        GridLayout {
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            Label {
                text: i18nc("@label:textbox", "League:")
            }

            TextField {
                id: leagueNameField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                selectByMouse: true
            }

            Label {
                text: i18nc("@label:textbox", "Country:")
            }

            TextField {
                id: countryNameField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                selectByMouse: true
            }

            Label {
                text: i18nc("@label:textbox", "Team:")
            }

            TextField {
                id: favoriteNameField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                selectByMouse: true
                placeholderText: i18nc("@info:placeholder", "No favorite team")
            }
        }

        onAccepted: root.configRoot.renameSavedLeague(root.renameIndex, leagueNameField.text, countryNameField.text, favoriteNameField.text)
    }
}
