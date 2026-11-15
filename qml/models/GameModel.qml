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

// Game event timeline, backed by
// https://liiga.fi/api/v2/games/{season}/{id} .
//
// CONFIRMED (from real finished games): goalEvents[] per team, with
// scorerPlayer{firstName,lastName}, assistantPlayers[]{firstName,lastName},
// gameTime (elapsed seconds), period (1-3 = regulation, 4 = overtime,
// 5 = shootout), goalTypes[] (abbreviations: YV/YV2 = power play,
// AV = short handed, TM = empty net, VL = shootout winner,
// IM = own goal, RL = penalty shot), homeTeamScore/awayTeamScore
// (running score after this goal).
//
// NOT YET IMPLEMENTED: penaltyEvents, goalKeeperEvents,
// goalKeeperChanges. These arrays exist on the single-game endpoint
// (confirmed present, but empty on every sample we've seen so far --
// either the game hadn't been played, or the bulk /games list doesn't
// include them at all). Need a finished game's *per-game* endpoint
// response with penalties/goalie changes actually populated before
// these can be added without guessing field names.
ListModel {
    id: root

    // Request factory; overridden by the unit tests (tests/) with a mock.
    property var xhrFactory: function () { return new XMLHttpRequest(); }

    property int season
    property int gameId
    property int status: 0

    function _formatTime(secs) {
        var m = Math.floor(secs / 60);
        var s = secs % 60;
        return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }

    function _periodInfo(periodNum) {
        if (periodNum <= 3)
            return JSON.stringify({ text: QT_TR_NOOP('%1 period'), num: periodNum });
        if (periodNum === 4)
            return JSON.stringify({ text: QT_TR_NOOP('Overtime') });
        return JSON.stringify({ text: QT_TR_NOOP('Shootout') });
    }

    function _goalTypeLabel(code) {
        switch (code) {
        case 'YV': return qsTr('power play');
        case 'YV2': return qsTr('5-on-3 power play');
        case 'AV': return qsTr('short handed');
        case 'TM': return qsTr('empty net');
        case 'VL': return qsTr('shootout winner');
        case 'IM': return qsTr('own goal');
        case 'RL': return qsTr('penalty shot');
        default: return code;
        }
    }

    function _playerName(p) {
        return p ? ((p.firstName || '') + ' ' + (p.lastName || '')) : '';
    }

    function _mapGoal(ev, team) {
        var types = (ev.goalTypes || []).map(root._goalTypeLabel).join(', ');
        var assists = (ev.assistantPlayers || []).map(root._playerName).join(', ');

        return {
            gameTime: ev.gameTime,
            time: root._formatTime(ev.gameTime),
            team: team,
            period: root._periodInfo(ev.period),
            event: {
                type: 'goal',
                text: root._playerName(ev.scorerPlayer) + ' ' +
                      ev.homeTeamScore + '-' + ev.awayTeamScore +
                      (types ? ' (' + types + ')' : ''),
                detail: assists ? qsTr('Assists: ') + assists : ''
            }
        };
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

                var game = data.game || data;
                var events = [];
                var i;
                var home = (game.homeTeam && game.homeTeam.goalEvents) || [];
                var away = (game.awayTeam && game.awayTeam.goalEvents) || [];

                for (i = 0; i < home.length; i++)
                    events.push(root._mapGoal(home[i], 'home'));
                for (i = 0; i < away.length; i++)
                    events.push(root._mapGoal(away[i], 'away'));

                events.sort(function (a, b) { return a.gameTime - b.gameTime; });

                root.clear();
                for (i = 0; i < events.length; i++)
                    root.append(events[i]);

                status = 3;
            }
        };
        xhr.open('GET', 'https://liiga.fi/api/v2/games/' + season + '/' + gameId);
        xhr.send();
    }

    onSeasonChanged: root.refresh()
    onGameIdChanged: root.refresh()
}
