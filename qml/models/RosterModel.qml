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

// Roster model, backed by https://liiga.fi/api/v2/games/{season}/{id} ,
// which returns 'homeTeamPlayers'/'awayTeamPlayers' arrays alongside the
// game data itself (see GameModel.qml, which will share the same fetch).
//
// Confirmed field names (from a not-yet-started game, so `line` was null
// for every player -- TODO: verify what `line` looks like once lineups
// are published, e.g. shortly before puck drop):
//   teamName, firstName, lastName, jersey, role, roleCode, line,
//   pictureUrl, captain, alternateCaptain, rookie
ListModel {
    id: root

    // Request factory; overridden by the unit tests (tests/) with a mock.
    property var xhrFactory: function () { return new XMLHttpRequest(); }

    property int season
    property int gameId
    property int status: 0

    // roleCode grouping, so goalies/defensemen/forwards sit together even
    // when `line` is empty. Confirmed from real rosters: MV = GOALIE
    // (maalivahti); P, VP, OP = DEFENSEMAN / LEFT_ / RIGHT_DEFENSEMAN;
    // H, KH, OL, VL = STRIKER / CENTER / RIGHT_WING / LEFT_WING.
    readonly property var _roleOrder: ({
        'MV': 0, 'P': 1, 'VP': 1, 'OP': 1, 'H': 2, 'KH': 2, 'OL': 2, 'VL': 2
    })

    function _fullName(p) {
        return (p.firstName || '') + ' ' + (p.lastName || '');
    }

    // Once a lineup is published every player in it has a line number
    // (1-3; goalies are in lines too). Everyone else is grouped by role.
    function _lineLabel(p, positionIndex) {
        if (p.line !== null && p.line !== undefined && p.line !== '')
            return qsTr('Line %1').arg(p.line);
        switch (positionIndex) {
        case 0: return qsTr('Goalies');
        case 1: return qsTr('Defensemen');
        case 2: return qsTr('Forwards');
        default: return p.role || '';
        }
    }

    function _positionIndex(p) {
        return root._roleOrder[p.roleCode] !== undefined ? root._roleOrder[p.roleCode] : 99;
    }

    function _mapPlayer(p) {
        var positionIndex = root._positionIndex(p);
        var line = root._lineLabel(p, positionIndex);
        return {
            team: p.teamName || '',
            name: root._fullName(p),
            number: p.jersey || 0,
            image: p.pictureUrl || '',
            position: p.role || '',
            positionIndex: positionIndex,
            line: line,
            lineNumber: (p.line !== null && p.line !== undefined && p.line !== '') ? Number(p.line) : 0,
            captain: !!p.captain,
            alternateCaptain: !!p.alternateCaptain,
            'section-json': JSON.stringify({
                team: p.teamName || '',
                line: line
            })
        };
    }

    // One team's players in display order: lineup lines first (1, 2, 3),
    // then the rest by role; within a group goalies, defensemen, forwards,
    // then jersey number. The section headers need equal groups to be
    // contiguous.
    function _sorted(rows) {
        function group(r) { return r.lineNumber > 0 ? r.lineNumber : 10 + r.positionIndex; }
        return rows.slice().sort(function (a, b) {
            return (group(a) - group(b)) || (a.positionIndex - b.positionIndex) || (a.number - b.number);
        });
    }

    function refresh() {
        if (!season || !gameId) {
            root.clear();
            return;
        }

        status = 1;
        var xhr = root.xhrFactory();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status !== 200) {
                    status = 4;
                    return;
                }
                var data;
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {
                    status = 4;
                    return;
                }

                root.clear();
                var rows = root._sorted((data.homeTeamPlayers || []).map(root._mapPlayer))
                               .concat(root._sorted((data.awayTeamPlayers || []).map(root._mapPlayer)));
                for (var i = 0; i < rows.length; i++)
                    root.append(rows[i]);
                status = 3;
            }
        };
        xhr.open('GET', 'https://liiga.fi/api/v2/games/' + season + '/' + gameId);
        xhr.send();
    }

    onSeasonChanged: root.refresh()
    onGameIdChanged: root.refresh()
}
