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

// Standings model, backed by https://liiga.fi/api/v2/standings/ .
// The response has separate arrays per competition phase; `section`
// selects which one ("season" = regular season table, which is what
// StatisticsPage currently shows).
ListModel {
    id: root

    // Request factory; overridden by the unit tests (tests/) with a mock.
    property var xhrFactory: function () { return new XMLHttpRequest(); }

    property string section: 'season'
    property int status: 0

    readonly property string apiUrl: 'https://liiga.fi/api/v2/standings/'

    // TODO: "EP" (extra points) semantics are a guess -- the old site
    // showed W / T / L / EP / P / GD columns. The new API separates
    // regulation vs overtime wins/losses explicitly, so this maps EP to
    // "how many of the wins/losses were decided in overtime". Verify
    // against the real liiga.fi standings page and adjust if wrong.
    function _mapTeam(team) {
        return {
            name: team.teamName || '',
            logo: (team.teamLogos && team.teamLogos.darkBg) || '',
            games: team.games || 0,
            wins: (team.wins || 0) + (team.overtimeWins || 0),
            ties: team.ties || 0,
            losses: (team.losses || 0) + (team.overtimeLosses || 0),
            extraPoints: (team.overtimeWins || 0) + (team.overtimeLosses || 0),
            points: team.points || 0,
            goalsFor: team.goals || 0,
            goalsAgainst: team.goalsAgainst || 0
        };
    }

    function refresh() {
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
                var teams = data[root.section] || [];
                for (var i = 0; i < teams.length; i++)
                    root.append(root._mapTeam(teams[i]));
                status = 3;
            }
        };
        xhr.open('GET', root.apiUrl);
        xhr.send();
    }

    onSectionChanged: root.refresh()

    Component.onCompleted: root.refresh()
}
