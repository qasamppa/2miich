import QtQuick 2.0
import QtTest 1.0
import "../qml/models"
import "fixtures.js" as Fx
import "../qml/models/leaders.js" as Leaders

// Unit tests for the liiga.fi API v2 models. Network access is replaced by
// a mock XMLHttpRequest that serves trimmed real API responses
// (tests/fixtures.js), so these run offline with `tests/run.sh`.
TestCase {
    id: tc
    name: "Models"

    property var requests: []

    // Returns an xhrFactory that answers every request with `body`/`status`
    function mock(body, status) {
        return function () {
            return {
                readyState: 0, status: 0, responseText: '', onreadystatechange: null,
                open: function (method, url) { this.url = url; },
                send: function () {
                    tc.requests.push(this.url);
                    this.status = status === undefined ? 200 : status;
                    this.responseText = typeof body === 'string' ? body : JSON.stringify(body);
                    this.readyState = 4;
                    this.onreadystatechange();
                }
            };
        };
    }

    function init() { requests = []; Leaders.clear(); }

    function find(model, key, value) {
        for (var i = 0; i < model.count; i++)
            if (model.get(i)[key] === value)
                return model.get(i);
        return null;
    }

    function gameById(id) {
        for (var i = 0; i < Fx.games.length; i++)
            if (Fx.games[i].id === id)
                return Fx.games[i];
        return null;
    }

    Component { id: liigaC; LiigaModel {} }
    Component { id: standingsC; StandingsModel {} }
    Component { id: rosterC; RosterModel {} }
    Component { id: gameC; GameModel {} }
    Component { id: scheduleC; ScheduleModel {} }
    Component { id: shotsC; ShotsModel {} }
    Component { id: leaderC; LeaderModel {} }
    Component { id: playersC; PlayerListModel {} }

    // ---------------------------------------------------------- LiigaModel

    function liiga(body, status, date) {
        return liigaC.createObject(tc, { xhrFactory: mock(body, status), date: date || new Date(2026, 7, 7, 12, 0) });
    }

    function test_liiga_filters_by_day() {
        var m = liiga(Fx.games);
        compare(m.status, 3);
        compare(m.count, 13);               // 2026-08-07 in Helsinki time
        compare(requests.length, 1);
        compare(requests[0], 'https://liiga.fi/api/v2/games');
    }

    function test_liiga_changing_date_does_not_refetch() {
        var m = liiga(Fx.games);
        m.date = new Date(2026, 7, 8, 12, 0);
        compare(m.count, 1);
        compare(m.get(0).id, 2712855);
        compare(requests.length, 1);
    }

    function test_liiga_next_prev() {
        var m = liiga(Fx.games);
        compare(m.prev, undefined);          // nothing before 7 Aug in the fixture
        compare(m.next.getDate(), 8);
        m.date = new Date(2026, 7, 8, 12, 0);
        compare(m.prev.getDate(), 7);
        compare(m.next.getDate(), 13);       // skips days without games
    }

    function test_liiga_finished_regulation_game() {
        var g = find(liiga(Fx.games), 'id', 2705868);   // Sport 2-0 TPS
        compare(g.home, 'Sport');
        compare(g.away, 'TPS');
        compare(g.homescore, 2);
        compare(g.awayscore, 0);
        compare(g.started, true);
        compare(g.finished, true);
        compare(g.overtime, '');
        compare(g.played, '');
    }

    function test_liiga_overtime_label() {
        var g = find(liiga(Fx.games), 'id', 2701824);   // Tappara 3-2 Ilves, OT
        compare(g.overtime, 'OT');
        compare(g.finished, true);
    }

    function test_liiga_shootout_label() {
        var g = find(liiga(Fx.games), 'id', 2703997);   // KalPa 3-2 Jukurit, SO
        compare(g.overtime, 'SO');
    }

    function test_liiga_not_started_game() {
        var m = liiga(Fx.games, 200, new Date(2026, 8, 15, 12, 0));
        compare(m.count, 3);
        var g = m.get(0);
        compare(g.started, false);
        compare(g.finished, false);
        compare(g.homescore, '');
        compare(g.awayscore, '');
        compare(g.played, '');
        compare(g.overtime, '');
    }

    function test_liiga_live_game_played_time() {
        var live = JSON.parse(JSON.stringify(gameById(2705868)));
        live.ended = false; live.finishedType = 'ACTIVE_OR_NOT_STARTED';
        live.gameTime = 1773;                            // 29:33
        live.homeTeam.goals = 1; live.awayTeam.goals = 0;
        var g = liiga([live]).get(0);
        compare(g.started, true);
        compare(g.finished, false);
        compare(g.played, '29:33');
        compare(g.homescore, 1);
    }

    function test_liiga_tournament_code() {
        var m = liiga(Fx.games, 200, new Date(2026, 8, 1, 12, 0));
        compare(m.get(0).tournament, 'rs');              // RUNKOSARJA
    }

    function test_liiga_logos_are_absolute_urls() {
        var m = liiga(Fx.games);
        for (var i = 0; i < m.count; i++) {
            verify(m.get(i).homelogo.indexOf('https://') === 0, 'home logo ' + i);
            verify(m.get(i).awaylogo.indexOf('https://') === 0, 'away logo ' + i);
        }
    }

    function test_liiga_team_ids() {
        var g = find(liiga(Fx.games), 'id', 2705868);
        compare(g.homeid, '626537494');
        compare(g.awayid, '651304385');
    }

    function test_liiga_http_error() {
        compare(liiga('boom', 500).status, 4);
    }

    function test_liiga_invalid_json() {
        compare(liiga('<html>not json', 200).status, 4);
    }

    function test_liiga_empty_payload() {
        var m = liiga([]);
        compare(m.status, 3);
        compare(m.count, 0);
    }

    // ------------------------------------------------------ StandingsModel

    function test_standings_real_sample() {
        var m = standingsC.createObject(tc, { xhrFactory: mock(Fx.standings) });
        compare(m.status, 3);
        compare(m.count, 17);
        compare(requests[0], 'https://liiga.fi/api/v2/standings/');
        compare(m.get(0).name, 'HIFK');
        verify(m.get(0).logo.indexOf('https://') === 0);
    }

    function test_standings_mapping_arithmetic() {
        var data = { season: [{ teamName: 'X', games: 10, wins: 4, overtimeWins: 2, losses: 3,
                                overtimeLosses: 1, ties: 0, points: 17, goals: 30, goalsAgainst: 25 }] };
        var r = standingsC.createObject(tc, { xhrFactory: mock(data) }).get(0);
        compare(r.wins, 6);          // regulation + overtime wins
        compare(r.losses, 4);
        compare(r.extraPoints, 3);   // see TODO in StandingsModel about EP semantics
        compare(r.points, 17);
        compare(r.goalsFor, 30);
        compare(r.goalsAgainst, 25);
    }

    function test_standings_section_switch_refetches() {
        var m = standingsC.createObject(tc, { xhrFactory: mock(Fx.standings) });
        m.section = 'playoffs';
        compare(m.count, 0);
        compare(requests.length, 2);
    }

    function test_standings_error() {
        compare(standingsC.createObject(tc, { xhrFactory: mock('', 503) }).status, 4);
    }

    // --------------------------------------------------------- RosterModel

    function roster(body, status) {
        return rosterC.createObject(tc, { xhrFactory: mock(body, status), season: 2027, gameId: 2701489 });
    }

    function test_roster_real_sample() {
        var m = roster(Fx.roster);
        compare(m.status, 3);
        compare(m.count, 26 + 32);
        compare(requests[0], 'https://liiga.fi/api/v2/games/2027/2701489');
        var p = m.get(0);
        compare(p.name, 'Toni Utunen');
        compare(p.number, 3);
        compare(p.team, 'Ilves');
        compare(p.positionIndex, 1);          // defenseman
        compare(p.line, 'DEFENSEMAN');        // line is null before lineups: falls back to role
        compare(p.captain, false);
    }

    function test_roster_goalies_sort_first_by_index() {
        var m = roster(Fx.roster);
        var goalie = null;
        for (var i = 0; i < m.count; i++)
            if (m.get(i).positionIndex === 0) { goalie = m.get(i); break; }
        verify(goalie !== null, 'no goalie found');
        compare(goalie.position, 'GOALIE');
    }

    function test_roster_line_used_when_present() {
        var data = JSON.parse(JSON.stringify(Fx.roster));
        data.homeTeamPlayers[0].line = 2;
        compare(roster(data).get(0).line, '2');
    }

    function test_roster_no_request_without_game() {
        var m = rosterC.createObject(tc, { xhrFactory: mock(Fx.roster) });
        compare(requests.length, 0);
        compare(m.count, 0);
    }

    function test_roster_error() {
        compare(roster('', 404).status, 4);
    }

    // ----------------------------------------------------------- GameModel

    function game(body, status, id) {
        return gameC.createObject(tc, { xhrFactory: mock(body, status), season: 2027, gameId: id || 2704005 });
    }

    function test_game_goal_count_matches_score() {
        var m = game(Fx.gameBusy);                  // Ässät 8-3 Lukko
        compare(m.status, 3);
        compare(m.count, 11);
        compare(requests[0], 'https://liiga.fi/api/v2/games/2027/2704005');
    }

    function test_game_events_sorted_and_formatted() {
        var m = game(Fx.gameBusy);
        for (var i = 0; i < m.count; i++) {
            var e = m.get(i);
            verify(/^\d\d:\d\d$/.test(e.time), 'time format: ' + e.time);
            if (i > 0)
                verify(e.gameTime >= m.get(i - 1).gameTime, 'sorted at ' + i);
        }
        var last = m.get(m.count - 1);
        verify(/ 8-3/.test(last.event.text), 'final score in text: ' + last.event.text);
    }

    function test_game_event_shape() {
        var m = game(Fx.gameBusy);
        var e = m.get(0);
        compare(e.event.type, 'goal');
        verify(e.team === 'home' || e.team === 'away');
        compare(JSON.parse(e.period).num, 1);
    }

    function test_game_assists_detail() {
        var data = { game: { homeTeam: { goalEvents: [{ gameTime: 65, period: 1, goalTypes: [],
            scorerPlayer: { firstName: 'A', lastName: 'B' },
            assistantPlayers: [{ firstName: 'C', lastName: 'D' }, { firstName: 'E', lastName: 'F' }],
            homeTeamScore: 1, awayTeamScore: 0 }] }, awayTeam: { goalEvents: [] } } };
        var e = game(data).get(0);
        compare(e.time, '01:05');
        compare(e.event.text, 'A B 1-0');
        verify(e.event.detail.indexOf('C D, E F') !== -1);
    }

    function test_game_goal_types_and_periods() {
        var data = { game: { homeTeam: { goalEvents: [
            { gameTime: 100, period: 1, goalTypes: ['YV'], scorerPlayer: {}, homeTeamScore: 1, awayTeamScore: 0 },
            { gameTime: 3700, period: 4, goalTypes: [], scorerPlayer: {}, homeTeamScore: 2, awayTeamScore: 0 },
            { gameTime: 3900, period: 5, goalTypes: ['VL'], scorerPlayer: {}, homeTeamScore: 3, awayTeamScore: 0 }] },
            awayTeam: { goalEvents: [] } } };
        var m = game(data);
        verify(m.get(0).event.text.indexOf('power play') !== -1);
        compare(JSON.parse(m.get(1).period).text, 'Overtime');
        compare(JSON.parse(m.get(2).period).text, 'Shootout');
        verify(m.get(2).event.text.indexOf('shootout winner') !== -1);
    }

    function test_game_shootout_sample() {
        var m = game(Fx.gameShootout, 200, 2703997);
        compare(m.count, 5);
        compare(JSON.parse(m.get(m.count - 1).period).text, 'Shootout');
    }

    function test_game_error() {
        compare(game('', 500).status, 4);
    }

    // ------------------------------------------------------- ScheduleModel

    function test_schedule_sorted_with_local_times() {
        var m = scheduleC.createObject(tc, { xhrFactory: mock(Fx.games.slice().reverse()) });
        compare(m.status, 3);
        compare(m.ready, true);
        compare(m.count, 23);
        compare(m.get(0).date, '20260807');
        compare(m.get(0).time, '08:45');     // Helsinki wall clock, not UTC
        for (var i = 1; i < m.count; i++)
            verify(m.get(i - 1).date + m.get(i - 1).time <= m.get(i).date + m.get(i).time, 'order at ' + i);
    }

    function test_schedule_result_and_overtime() {
        var m = scheduleC.createObject(tc, { xhrFactory: mock(Fx.games) });
        var ot = find(m, 'id', 2701824);
        compare(ot.result, '3 - 2');
        compare(ot.overtime, ' OT');
        compare(find(m, 'id', 2703997).overtime, ' SO');
        compare(find(m, 'id', 2705868).overtime, '');
        compare(find(m, 'id', 2701298).result, '');   // not started
    }

    function test_schedule_error_still_becomes_ready() {
        var m = scheduleC.createObject(tc, { xhrFactory: mock('', 500) });
        compare(m.status, 4);
        compare(m.ready, true);
    }

    // ----------------------------------------------------------- ShotsModel

    function shots(body, status, homeId) {
        return shotsC.createObject(tc, { xhrFactory: mock(body, status), season: 2027, gameId: 2705868,
                                         homeId: homeId === undefined ? '626537494' : homeId });
    }

    function test_shots_real_sample() {
        var m = shots(Fx.shotmapSport);             // Sport (home) 2-0 TPS
        compare(m.status, 3);
        compare(m.count, 32);
        compare(requests.length, 1);                // one request, not one per property
        compare(requests[0], 'https://liiga.fi/api/v2/shotmap/2027/2705868');
    }

    function test_shots_goals_and_sides() {
        var m = shots(Fx.shotmapSport);
        var goals = 0, home = 0;
        for (var i = 0; i < m.count; i++) {
            if (m.get(i).goal) { goals++; compare(m.get(i).home, true); }
            if (m.get(i).home) home++;
        }
        compare(goals, 2);
        compare(home, 16);
    }

    function test_shots_coordinates_normalised() {
        var m = shots(Fx.shotmapAssat, 200, '679171680');
        compare(m.count, 88);
        for (var i = 0; i < m.count; i++) {
            verify(m.get(i).fx >= 0 && m.get(i).fx <= 1, 'fx ' + i);
            verify(m.get(i).fy >= 0 && m.get(i).fy <= 1, 'fy ' + i);
        }
        compare(m.get(0).fx, Fx.shotmapAssat[0].shotX / 1000);
    }

    function test_shots_coordinates_clamped() {
        var data = [{ shotX: 1500, shotY: -20, shootingTeamId: 1, eventType: 'MISSED', period: 1, gameTime: 1 }];
        var s = shots(data, 200, '1').get(0);
        compare(s.fx, 1);
        compare(s.fy, 0);
    }

    function test_shots_no_request_until_ready() {
        shotsC.createObject(tc, { xhrFactory: mock([]), season: 2027, gameId: 2705868 });
        compare(requests.length, 0);
    }

    function test_shots_error() {
        compare(shots('', 500).status, 4);
        compare(shots('nope', 200).status, 4);
    }

    // -------------------------------------------------------- leaders

    // The fixture's games are preseason; relabel two real finished games as
    // regular-season games so they count.
    function leaderGames() {
        var busy = JSON.parse(JSON.stringify(Fx.gameBusy.game));       // Assat 8-3 Lukko
        var so = JSON.parse(JSON.stringify(Fx.gameShootout.game));     // KalPa 3-2 Jukurit (SO)
        busy.serie = 'RUNKOSARJA';
        so.serie = 'RUNKOSARJA';
        return [busy, so];
    }

    function totalGoals(table) {
        var n = 0;
        for (var i = 0; i < table.length; i++)
            n += table[i].goals;
        return n;
    }

    function test_leaders_only_regular_season_counts() {
        var r = Leaders.compute(Fx.games);        // only game 2701280 is RUNKOSARJA
        compare(totalGoals(r.goals), 8);
        compare(r.goals.length, 17);
    }

    function test_leaders_shootout_goals_are_skipped() {
        var games = [leaderGames()[1]];
        compare(totalGoals(Leaders.compute(games).goals), 4);   // 5 goal events, 1 in the shootout
    }

    function test_leaders_real_game_top_scorer() {
        var r = Leaders.compute([leaderGames()[0]]);
        compare(r.goals[0].name, 'Carl Klingberg');
        compare(r.goals[0].teamName, 'Ässät');
        compare(r.goals[0].goals, 3);
        compare(r.goals[0].assists, 1);
        compare(r.goals[0].points, 4);
        compare(totalGoals(r.goals), 11);
        compare(r.goals.length, 21);
        verify(r.goals[0].logo.indexOf('https://') === 0);
    }

    function test_leaders_points_include_assists_and_tiebreak_on_goals() {
        function ev(scorer, assists) {
            return { period: 1, scorerPlayer: scorer, assistantPlayers: assists };
        }
        var A = { playerId: 1, firstName: 'A', lastName: 'Scorer' };
        var B = { playerId: 2, firstName: 'B', lastName: 'Setup' };
        var C = { playerId: 3, firstName: 'C', lastName: 'Setup2' };
        var game = { serie: 'RUNKOSARJA', awayTeam: { goalEvents: [] },
                     homeTeam: { teamName: 'T', goalEvents: [ev(A, [B, C]), ev(A, [B]), ev(A, [B])] } };
        var r = Leaders.compute([game]);
        compare(r.goals[0].name, 'A Scorer');            // 3 goals
        compare(r.points[0].name, 'A Scorer');           // 3 points...
        compare(r.points[1].name, 'B Setup');            // ...ties are broken by goals, B has 3 assists
        compare(r.points[1].points, 3);
        compare(r.points[2].points, 1);
        compare(Leaders.detail(r.points[1], 'points'), '3 (0+3)');
        compare(Leaders.detail(r.goals[0], 'goals'), '3');
    }

    function test_leader_models_slice_the_table() {
        var f = mock(leaderGames());
        var leader = leaderC.createObject(tc, { xhrFactory: f, kind: 'points' });
        var rest = playersC.createObject(tc, { xhrFactory: f, kind: 'points' });
        compare(leader.status, 3);
        compare(leader.count, 1);
        compare(leader.get(0).name, 'Carl Klingberg');
        compare(leader.get(0).detail, '4 (3+1)');
        compare(rest.count, 9);
        verify(rest.get(0).name !== leader.get(0).name);
    }

    function test_leader_goals_detail_is_plain_number() {
        var m = leaderC.createObject(tc, { xhrFactory: mock(leaderGames()), kind: 'goals' });
        compare(m.get(0).detail, '3');
        compare(m.get(0).teamName, 'Ässät');
    }

    function test_leader_models_share_one_download() {
        var f = mock(leaderGames());
        leaderC.createObject(tc, { xhrFactory: f, kind: 'points' });
        leaderC.createObject(tc, { xhrFactory: f, kind: 'goals' });
        playersC.createObject(tc, { xhrFactory: f, kind: 'goals' });
        compare(requests.length, 1);
        compare(requests[0], 'https://liiga.fi/api/v2/games');
    }

    function test_leader_empty_before_season_starts() {
        var m = leaderC.createObject(tc, { xhrFactory: mock(Fx.games.slice(0, 5)) });   // preseason only
        compare(m.status, 3);
        compare(m.count, 0);
    }

    function test_leader_error() {
        compare(leaderC.createObject(tc, { xhrFactory: mock('', 500) }).status, 4);
        Leaders.clear();
        compare(leaderC.createObject(tc, { xhrFactory: mock('<html>', 200) }).status, 4);
    }
}
