#!/bin/bash
# Run the unit tests, then build the installable RPM with the Sailfish SDK.
#
#   TARGET=SailfishOS-4.6.0.15-aarch64 tools/build-rpm.sh
#
# TARGET must match the phone's architecture (Settings -> About product).
# Run `sfdk tools list` to see the targets installed in your SDK.
set -eu
cd "$(dirname "$0")/.."

if ! command -v sfdk >/dev/null 2>&1; then
    echo "sfdk not found: add the Sailfish SDK's bin directory to PATH" >&2
    exit 1
fi

if [ -z "${TARGET:-}" ]; then
    echo "TARGET is not set. Installed tools/targets:" >&2
    sfdk tools list >&2 || true
    exit 1
fi

echo "== Unit tests"
if command -v qmltestrunner >/dev/null 2>&1; then
    tests/run.sh
else
    echo "qmltestrunner not found, skipping tests" >&2
    echo "(apt install qtdeclarative5-dev-tools qml-module-qttest)" >&2
fi

echo "== Building for $TARGET"
sfdk config --push target "$TARGET"
sfdk build

echo "== Resulting packages"
find . -name '*.rpm' -newer tests/run.sh -print
