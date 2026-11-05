#!/usr/bin/env bash
# Starts the backend that sits next to the app. Started by
# "Guidy - 2 Start Backend.command".
set -uo pipefail
. "$(dirname "$0")/common.sh"
bd=$(require_backend_dir) || finish 1
ok "backend folder: $bd"
[ -f "$bd/run_backend.sh" ] || die "$bd has no run_backend.sh -- update it: cd \"$bd\" && git pull"
chmod +x "$bd/run_backend.sh" "$bd/Start Backend.command" 2>/dev/null
exec bash "$bd/run_backend.sh"
