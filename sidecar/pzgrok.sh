#!/usr/bin/env bash
# Steam launch-options wrapper:
#   /path/to/AcrossTheRiver/sidecar/pzgrok.sh %command%
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export PYTHONUNBUFFERED=1
python3 "$HERE/pzgrok.py" >>"${XDG_STATE_HOME:-$HOME/.local/state}/pzgrok.log" 2>&1 &
SIDECAR=$!
cleanup() {
  kill "$SIDECAR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
if [[ $# -gt 0 ]]; then
  "$@"
else
  wait "$SIDECAR"
fi
