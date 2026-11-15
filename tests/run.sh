#!/bin/sh
# Runs the QML unit tests headlessly (needs qmltestrunner from Qt 5, e.g.
# `apt install qtdeclarative5-dev-tools qml-module-qttest`).
cd "$(dirname "$0")" || exit 1
export QT_QPA_PLATFORM=offscreen
export TZ=Europe/Helsinki   # LiigaModel filters by the device's local day
if command -v python3 >/dev/null 2>&1; then
    python3 check-translations.py || exit 1
fi
exec qmltestrunner -input tst_models.qml "$@"
