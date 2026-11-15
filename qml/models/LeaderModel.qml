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
import "leaders.js" as Leaders

// A slice of the goal or point leader table, derived from the games feed
// (see leaders.js). `kind` is 'goals' or 'points'; `first` and `count`
// select which ranks to show (default: just the leader).
ListModel {
    id: root

    // Request factory; overridden by the unit tests (tests/) with a mock.
    property var xhrFactory: function () { return new XMLHttpRequest(); }

    property string kind: 'goals'
    property int first: 0
    property int limit: 1
    property int status: 0

    function refresh() {
        status = 1;
        Leaders.load(root.xhrFactory, function (games) {
            if (!games) {
                status = 4;
                return;
            }
            var table = Leaders.compute(games)[root.kind === 'points' ? 'points' : 'goals'];
            root.clear();
            var end = Math.min(table.length, root.first + root.limit);
            for (var i = root.first; i < end; i++) {
                root.append({
                    name: table[i].name,
                    teamName: table[i].teamName,
                    logo: table[i].logo,
                    detail: Leaders.detail(table[i], root.kind)
                });
            }
            status = 3;
        });
    }

    onKindChanged: root.refresh()
    Component.onCompleted: root.refresh()
}
