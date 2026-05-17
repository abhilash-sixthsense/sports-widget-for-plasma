/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string sourceUrl: ""

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
    Layout.preferredHeight: Kirigami.Units.iconSizes.small
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    clip: true
    visible: sourceUrl.length > 0

    Image {
        anchors.fill: parent
        source: root.sourceUrl
        visible: root.sourceUrl.indexOf("file://") === 0
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: width
        sourceSize.height: height
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: root.sourceUrl
        visible: root.sourceUrl.length > 0 && root.sourceUrl.indexOf("file://") !== 0
        isMask: true
        color: Kirigami.Theme.textColor
    }
}
