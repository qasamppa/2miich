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

// Goal/point leaders ("Maalipörssi" / "Pistepörssi"), derived from the
// liiga.fi API v2 games feed.
//
// The feed (https://liiga.fi/api/v2/games) carries every goal of every
// finished game, with its scorer and assistants, per team. Summing those
// gives the regular-season leader tables without needing a dedicated
// statistics endpoint (none is known yet). Shootout goals (period 5) do
// not count towards player statistics and are skipped; only regular
// season (RUNKOSARJA) games are counted.
//
// The download is a couple of megabytes, so it is shared between the four
// leader models on the statistics page and cached for a short while.
.pragma library

var URL = 'https://liiga.fi/api/v2/games';
var MAX_AGE_MS = 60 * 1000;

var _cache = null;
var _cacheTime = 0;
var _pending = null;

function clear() {
    _cache = null;
    _cacheTime = 0;
    _pending = null;
}

// Calls callback(games) with the parsed games array, or callback(null) on
// any network/parse error. `factory` creates the XMLHttpRequest (so tests
// can mock it).
function load(factory, callback) {
    if (_cache && Date.now() - _cacheTime < MAX_AGE_MS) {
        callback(_cache);
        return;
    }
    if (_pending) {
        _pending.push(callback);
        return;
    }
    _pending = [callback];

    var xhr = factory();
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== 4)
            return;
        var waiting = _pending;
        _pending = null;

        var data = null;
        if (xhr.status === 200) {
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {
                data = null;
            }
        }
        if (data) {
            _cache = data;
            _cacheTime = Date.now();
        }
        for (var i = 0; i < waiting.length; i++)
            waiting[i](data);
    };
    xhr.open('GET', URL);
    xhr.send();
}

function _name(p) {
    return ((p.firstName || '') + ' ' + (p.lastName || '')).trim();
}

function _player(table, p, team) {
    var key = String(p.playerId);
    if (!table[key]) {
        table[key] = {
            id: p.playerId,
            name: _name(p),
            teamName: team.teamName || '',
            logo: (team.logos && team.logos.darkBg) || '',
            goals: 0,
            assists: 0,
            points: 0
        };
    }
    return table[key];
}

function _countTeam(table, team) {
    var events = team.goalEvents || [];
    for (var i = 0; i < events.length; i++) {
        var e = events[i];
        if (e.period > 4)
            continue;                       // shootout
        if (e.scorerPlayer && e.scorerPlayer.playerId !== undefined) {
            var s = _player(table, e.scorerPlayer, team);
            s.goals++;
            s.points++;
        }
        var assists = e.assistantPlayers || [];
        for (var j = 0; j < assists.length; j++) {
            if (assists[j].playerId === undefined)
                continue;
            var a = _player(table, assists[j], team);
            a.assists++;
            a.points++;
        }
    }
}

// Returns { goals: [...], points: [...] }, each sorted best first.
function compute(games) {
    var table = {};
    for (var i = 0; i < games.length; i++) {
        var g = games[i];
        if (g.serie !== 'RUNKOSARJA')
            continue;
        _countTeam(table, g.homeTeam || {});
        _countTeam(table, g.awayTeam || {});
    }

    var players = [];
    for (var k in table)
        players.push(table[k]);

    function byName(a, b) { return a.name < b.name ? -1 : a.name > b.name ? 1 : 0; }

    var goals = players.slice().sort(function (a, b) {
        return (b.goals - a.goals) || (b.points - a.points) || byName(a, b);
    });
    var points = players.slice().sort(function (a, b) {
        return (b.points - a.points) || (b.goals - a.goals) || byName(a, b);
    });
    return { goals: goals, points: points };
}

// Text for the right-hand column: "12" for goals, "12 (5+7)" for points
// (points, goals+assists), as on liiga.fi.
function detail(player, kind) {
    if (kind === 'points')
        return player.points + ' (' + player.goals + '+' + player.assists + ')';
    return String(player.goals);
}
