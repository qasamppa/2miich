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

// Games list model, backed by the liiga.fi API v2 (https://liiga.fi/api/v2/games).
//
// NOTE: the games endpoint does not appear to take a date filter (at least
// none is confirmed), so we fetch the whole payload once and filter/re-filter
// client side whenever `date` changes. This also gives us `next`/`prev`
// for free, by scanning for the nearest other date that has games.
ListModel {
    id: root

    // Day currently displayed. Settable; changing it re-filters the
    // already-fetched game list (no new network request).
    property variant date: new Date()

    // Nearest date (before/after `date`) that has games scheduled, or
    // undefined if none found in the currently loaded payload.
    property variant next: undefined
    property variant prev: undefined

    // 0 = not loaded, 1 = loading, 3 = ready, 4 = error
    property int status: 0

    property var allGames: []

    readonly property string apiUrl: 'https://liiga.fi/api/v2/games'

    function _dateKey(d) {
        return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
    }

    function _sameDay(a, b) {
        return root._dateKey(a) === root._dateKey(b);
    }

    // TODO: verify against a real finished game. Best guess based on the
    // `periods[].category` values seen so far (NORMAL / OVERTIME /
    // WINNING_SHOT_COMPETITION) plus goals scored in that period.
    function _overtimeLabel(game) {
        if (!game.ended)
            return '';
        var periods = game.periods || [];
        for (var i = 0; i < periods.length; i++) {
            var p = periods[i];
            if (p.category === 'WINNING_SHOT_COMPETITION' &&
                    (p.homeTeamGoals || p.awayTeamGoals))
                return qsTr('SO');
            if (p.category === 'OVERTIME' &&
                    (p.homeTeamGoals || p.awayTeamGoals))
                return qsTr('OT');
        }
        return '';
    }

    // TODO: verify against a live game. `gameTime` is assumed to be
    // elapsed seconds; format matches the old "mm:ss" display.
    function _formatPlayed(game) {
        if (!game.started || game.ended)
            return '';
        var secs = game.gameTime || 0;
        var m = Math.floor(secs / 60);
        var s = secs % 60;
        return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }

    function _tournamentCode(game) {
        // 'rs' (runkosarja/regular season) vs anything else ('po' = playoffs,
        // kept as a catch-all until we've seen playoff `serie` values).
        return game.serie === 'RUNKOSARJA' ? 'rs' : 'po';
    }

    function _mapGame(game) {
        var home = game.homeTeam || {};
        var away = game.awayTeam || {};

        return {
            id: game.id,
            season: game.season,
            home: home.teamName || '',
            away: away.teamName || '',
            homelogo: (home.logos && home.logos.darkBg) || '',
            awaylogo: (away.logos && away.logos.darkBg) || '',
            homescore: game.started ? home.goals : '',
            awayscore: game.started ? away.goals : '',
            started: !!game.started,
            finished: !!game.ended,
            played: root._formatPlayed(game),
            overtime: root._overtimeLabel(game),
            startTime: new Date(game.start),
            tournament: root._tournamentCode(game),
            // Not present on the games list; would need a per-game endpoint.
            detail: '',
            // Kept around for DetailsPage/RosterPage to build a per-game
            // request once we know that endpoint's shape.
            report: game.id + ':' + game.season,
            rosters: game.id + ':' + game.season
        };
    }

    function _applyFilter() {
        root.clear();

        var nextDate = undefined;
        var prevDate = undefined;

        for (var i = 0; i < root.allGames.length; i++) {
            var g = root.allGames[i];
            var gd = new Date(g.start);

            if (root._sameDay(gd, root.date)) {
                root.append(root._mapGame(g));
            } else if (gd > root.date && (!nextDate || gd < nextDate)) {
                nextDate = gd;
            } else if (gd < root.date && (!prevDate || gd > prevDate)) {
                prevDate = gd;
            }
        }

        root.next = nextDate;
        root.prev = prevDate;
    }

    function refresh() {
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
                root.allGames = data;
                root._applyFilter();
                status = 3;
            }
        };
        xhr.open('GET', root.apiUrl);
        xhr.send();
    }

    onDateChanged: root._applyFilter()

    Component.onCompleted: root.refresh()
}
