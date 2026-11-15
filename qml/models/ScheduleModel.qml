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

// Full-season schedule, backed by https://liiga.fi/api/v2/games .
// Same endpoint as LiigaModel, but unfiltered and sorted, since
// SchedulePage wants to show/scroll through the whole season.
ListModel {
    id: root

    // Request factory; overridden by the unit tests (tests/) with a mock.
    property var xhrFactory: function () { return new XMLHttpRequest(); }

    property bool ready: false
    property int status: 0

    readonly property string apiUrl: 'https://liiga.fi/api/v2/games'

    // `date`/`time` are kept as separate "yyyyMMdd"/"hh:mm" strings (as
    // the old HTML-scraped version produced) so SchedulePage's existing
    // section grouping and TzDateParser-based formatting don't need to
    // change. `gameStartDateTime` is already local Helsinki wall-clock
    // time (its ISO offset is +02:00/+03:00), so we can slice it
    // directly instead of doing any timezone math ourselves.
    function _dateStr(iso) {
        return iso.substring(0, 4) + iso.substring(5, 7) + iso.substring(8, 10);
    }

    function _timeStr(iso) {
        return iso.substring(11, 16);
    }

    function _resultStr(game) {
        if (!game.started)
            return '';
        return game.homeTeam.goals + ' - ' + game.awayTeam.goals;
    }

    // Confirmed enum, see LiigaModel.qml.
    function _overtimeStr(game) {
        switch (game.finishedType) {
        case 'ENDED_DURING_WINNING_SHOT_COMPETITION':
            return ' ' + qsTr('SO');
        case 'ENDED_DURING_EXTENDED_GAME_TIME':
            return ' ' + qsTr('OT');
        default:
            return '';
        }
    }

    function _mapGame(game) {
        var home = game.homeTeam || {};
        var away = game.awayTeam || {};
        var localStart = home.gameStartDateTime || game.start;

        return {
            id: game.id,
            season: game.season,
            date: root._dateStr(localStart),
            time: root._timeStr(localStart),
            home: home.teamName || '',
            away: away.teamName || '',
            homelogo: (home.logos && home.logos.darkBg) || '',
            awaylogo: (away.logos && away.logos.darkBg) || '',
            result: root._resultStr(game),
            overtime: root._overtimeStr(game)
        };
    }

    function refresh() {
        ready = false;
        status = 1;
        var xhr = root.xhrFactory();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status !== 200) {
                    status = 4;
                    ready = true;
                    return;
                }
                var data;
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {
                    status = 4;
                    ready = true;
                    return;
                }

                data.sort(function (a, b) {
                    return new Date(a.start) - new Date(b.start);
                });

                root.clear();
                for (var i = 0; i < data.length; i++)
                    root.append(root._mapGame(data[i]));

                status = 3;
                ready = true;
            }
        };
        xhr.open('GET', root.apiUrl);
        xhr.send();
    }

    Component.onCompleted: root.refresh()
}
