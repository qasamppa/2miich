/*
 * 2miich - Liiga scores app
 * Copyright (C) 2014 Santtu Lakkala <inz@inz.fi>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0

import '..'
import '../effects'
import '../widgets'
import '../models'

Page {
    id: page
    property variant details

    RosterModel {
        id: rosterModel
        season: details ? details.season : 0
        gameId: details ? details.id : 0
    }

    SilicaListView {
        anchors.fill: parent
        model: rosterModel

        header: Column {
	    anchors.left: parent.left
	    anchors.right: parent.right
            PageHeader {
                anchors.left: parent.left
		anchors.right: parent.right
                title: qsTr('Rosters')
            }
            Item {
                anchors.left: parent.left
		anchors.right: parent.right
                height: 0
                Image {
                    id: bgHome
                    source: 'image://cache/' + details['homelogo']
                    anchors.right: parent.left
                    anchors.rightMargin: -width / 2
                }
                MonochromeEffect {
                    sourceItem: bgHome
                    opacity: 0.3
                    scale: page.height * 1.5 / sourceItem.height
                    transformOrigin: Item.Top
                }
            }
        }

        footer: Item {
            anchors.left: parent.left
            width: 0
            height: 0
            Image {
                id: bgAway
                source: 'image://cache/' + details['awaylogo']
                anchors.right: parent.left
                anchors.rightMargin: -width / 2
		anchors.bottom: parent.bottom
            }
            MonochromeEffect {
                sourceItem: bgAway
                opacity: 0.3
                scale: page.height * 1.5 / sourceItem.height
                transformOrigin: Item.Bottom
            }
        }

        delegate: BackgroundItem {
            anchors.left: parent.left
            anchors.right: parent.right
            id: bgItem
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.paddingMedium
                Image {
                    source: 'image://cache/' + image
                    sourceSize.height: bgItem.height
                }
                Label {
                    text: number + ' ' + name
                }
            }
        }

        section.property: 'section-json'
        section.delegate: Rectangle {
            color: Theme.rgba(Theme.highlightBackgroundColor, 0.2)
            anchors.left: parent.left
            anchors.right: parent.right
            height: sectItem.height + 2 * Theme.paddingMedium

            Row {
                anchors.top: parent.top
                anchors.topMargin: Theme.paddingMedium
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingMedium

                height: childrenRect.height
                id: sectItem
                property var sectData: JSON.parse(section)

                Label {
                    text: sectItem.sectData.team + ' '
                }
                Label {
                    text: sectItem.sectData.line
                }
            }
        }

    }
}
