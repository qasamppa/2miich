2miich
======

Liiga scores app for SailfishOS

Fork notes
----------

This is a fork of [inzanity/2miich](https://github.com/inzanity/2miich) by
Santtu Lakkala. The original app read its data by scraping the old
liiga.fi website; this fork ports it to the liiga.fi JSON API v2
(`https://liiga.fi/api/v2/`) and keeps the existing QML user interface.

The original author wrote the app and holds the copyright on the
original code (see the license headers in the source files). This fork
is distributed under the same license, the GNU General Public License
version 2 or, at your option, any later version (see `COPYING`). Modified
and new files are recorded in the git history.

### What uses the API now

- Scores list, schedule and next/previous day navigation
- Standings
- Game details: goals, penalties, goalie pulled/returning, timeouts
- Shot map
- Rosters, including lineup lines once they are published
- Goal and point leaders (Maalipörssi / Pistepörssi), summed from the
  goals in the games feed, because no statistics endpoint is known
- Team logos from the API (teams missing from the bundled logo sprite,
  such as K-Espoo, fall back to the official logo)
- Finnish translations for the new texts

### Known gaps

- Goalie replacements (`goalKeeperChanges`) are not shown: the field has
  been empty in every game seen so far, so its format is unknown.
- The extra points (EP) column in the standings is a best guess at what
  the old site meant by it.
- The shot map assumes a 1000 x 500 coordinate space, inferred from data.
- Goals with some goal-type codes (for example `VT`, `SR`, `TV`, `RL0`)
  are shown with the raw code, since their meaning is not documented.
- The liiga.fi API is not documented publicly. Field names here come from
  observed responses and may change without notice.

### Building

Clone with submodules (they are mirrored on GitHub):

    git clone --recurse-submodules https://github.com/qasamppa/2miich.git

Then build the RPM with the Sailfish SDK. The script runs the unit tests
first if `qmltestrunner` is installed:

    sfdk tools list
    TARGET=<a target from the list> tools/build-rpm.sh

Pick a target whose architecture matches the phone (aarch64 or armv7hl).

Note: the build regenerates `translations/harbour-toomiich-fi.ts`; run
`git checkout -- translations/harbour-toomiich-fi.ts` before committing or
applying patches.

### Tests

The model tests run offline against trimmed real API responses and a mock
`XMLHttpRequest`:

    apt install qtdeclarative5-dev-tools qml-module-qttest   # Debian/Ubuntu
    tests/run.sh

See `tests/README.md`.

### Credits

- Original app: Santtu Lakkala (https://github.com/inzanity/2miich)
- API v2 port: prepared with assistance from Claude (Anthropic) and
  tested on a device by the fork maintainer. Edit this line to taste.
