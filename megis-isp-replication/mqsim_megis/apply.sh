#!/usr/bin/env bash
# Copy the MegIS-modified sources over a clean MQSim checkout.
# Usage: bash mqsim_megis/apply.sh /path/to/MQSim
set -euo pipefail
MQSIM_DIR="${1:?Usage: bash mqsim_megis/apply.sh /path/to/MQSim}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$MQSIM_DIR/src" ]; then
    echo "error: $MQSIM_DIR does not look like an MQSim checkout (no src/ folder)" >&2
    exit 1
fi

cp -v "$HERE"/src/main.cpp "$MQSIM_DIR"/src/
for d in exec host ssd utils; do
    cp -v "$HERE"/src/$d/* "$MQSIM_DIR"/src/$d/
done
echo "MegIS sources copied into $MQSIM_DIR. Build with: cd $MQSIM_DIR && make"
