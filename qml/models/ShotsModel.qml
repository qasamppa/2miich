import QtQuick 2.0

// Shot map, backed by https://liiga.fi/api/v2/shotmap/{season}/{gameId} .
//
// CONFIRMED (from a real finished game): the response is a JSON array of
// shots with type (EvenStrengthShot / PowerplayShot / ShorthandedShot),
// shootingTeamId, leftTeam, rightTeam, gameTime, period, shotX, shotY,
// shooterId, blockerId, eventType (GOAL / MISSED / GOALIE_BLOCKED /
// PLAYER_BLOCKED) and xg.
//
// Coordinates are absolute positions on the rink. Teams change ends
// between periods (confirmed: the home team attacks right in period 1 and
// left in period 2), and leftTeam/rightTeam name whichever team defends
// the left/right goal in that period; the leftTeam always shoots towards
// x > 500. leftTeam is NOT necessarily the home team, so we identify the
// shooter's side by comparing shootingTeamId to homeId, and draw the
// coordinates as given. Fields such as xg and playerStartPositions may be
// null/empty and are ignored.
//
// ASSUMPTION: the coordinate space is 1000 x 500 (observed ranges are
// x 79..987, y 11..494). If shots look stretched on a real device, adjust
// `width`/`height` below.
ListModel {
    id: root

    property int season
    property int gameId
    property string homeId
    property int status: 0

    property real width: 1000
    property real height: 500

    function refresh() {
        if (!season || !gameId)
            return;
        status = 1;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
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
            for (var i = 0; i < data.length; i++) {
                var s = data[i];
                root.append({
                    // position as a fraction of the rink (0..1)
                    fx: Math.max(0, Math.min(1, s.shotX / root.width)),
                    fy: Math.max(0, Math.min(1, s.shotY / root.height)),
                    home: String(s.shootingTeamId) === String(root.homeId),
                    goal: s.eventType === 'GOAL',
                    period: s.period,
                    gameTime: s.gameTime
                });
            }
            status = 3;
        };
        xhr.open('GET', 'https://liiga.fi/api/v2/shotmap/' + season + '/' + gameId);
        xhr.send();
    }

    onSeasonChanged: refresh()
    onGameIdChanged: refresh()
    onHomeIdChanged: refresh()
}
