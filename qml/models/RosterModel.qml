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

    property int season
    property int gameId
    property int status: 0

    // roleCode ordering, so goalies/defensemen/forwards group sensibly
    // even before `line` is populated. Best guess: C = goalkeeper
    // (maalivahti), P = defenseman (puolustaja), H = forward (hyökkääjä).
    readonly property var _roleOrder: ({ 'C': 0, 'P': 1, 'H': 2 })

    function _fullName(p) {
        return (p.firstName || '') + ' ' + (p.lastName || '');
    }

    function _lineLabel(p) {
        if (p.line !== null && p.line !== undefined && p.line !== '')
            return String(p.line);
        // Lineups aren't always published this far ahead of the game;
        // fall back to grouping by role instead.
        return p.role || '';
    }

    function _mapPlayer(p) {
        return {
            team: p.teamName || '',
            name: root._fullName(p),
            number: p.jersey || 0,
            image: p.pictureUrl || '',
            position: p.role || '',
            positionIndex: root._roleOrder[p.roleCode] !== undefined ?
                               root._roleOrder[p.roleCode] : 99,
            line: root._lineLabel(p),
            captain: !!p.captain,
            alternateCaptain: !!p.alternateCaptain,
            'section-json': JSON.stringify({
                team: p.teamName || '',
                line: root._lineLabel(p)
            })
        };
    }

    function refresh() {
        if (!season || !gameId) {
            root.clear();
            return;
        }

        status = 1;
        var xhr = new XMLHttpRequest();
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
                var home = data.homeTeamPlayers || [];
                var away = data.awayTeamPlayers || [];
                var i;
                for (i = 0; i < home.length; i++)
                    root.append(root._mapPlayer(home[i]));
                for (i = 0; i < away.length; i++)
                    root.append(root._mapPlayer(away[i]));
                status = 3;
            }
        };
        xhr.open('GET', 'https://liiga.fi/api/v2/games/' + season + '/' + gameId);
        xhr.send();
    }

    onSeasonChanged: root.refresh()
    onGameIdChanged: root.refresh()
}
