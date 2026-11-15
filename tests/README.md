# Model unit tests

QML unit tests for the liiga.fi API v2 models, run offline against trimmed
real API responses (`fixtures.js`) through a mock `XMLHttpRequest`
(models take an `xhrFactory` property for this).

    apt install qtdeclarative5-dev-tools qml-module-qttest   # Debian/Ubuntu
    tests/run.sh

Verified with Qt 5.15 (Sailfish ships an older Qt, but the models only use
plain QtQuick 2.0 `ListModel` and JavaScript). `run.sh` sets
`TZ=Europe/Helsinki` because `LiigaModel` filters games by local day.
