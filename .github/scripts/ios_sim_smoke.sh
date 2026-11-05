#!/usr/bin/env bash
# Boot an iPhone simulator, install the simulator build, launch it, and fail
# if the app is not still running after SMOKE_SECONDS.
#
# A compile says nothing about launch: a missing plist key, a native SDK
# initialised in the wrong order (Google Maps crashes if provideAPIKey was
# never called) or a Firebase config problem only shows up once the process
# starts. This is the cheapest check that the iOS app actually opens.
#
# Usage: ios_sim_smoke.sh <path/to/Runner.app> <out-dir>
set -euo pipefail

APP="$1"
OUT="$2"
BUNDLE_ID="${BUNDLE_ID:-com.guidy.guidyApp}"
SMOKE_SECONDS="${SMOKE_SECONDS:-45}"
mkdir -p "$OUT"

[ -d "$APP" ] || { echo "::error::no app bundle at $APP"; exit 1; }

# Newest available iOS runtime, first iPhone on it.
UDID=$(xcrun simctl list --json devices available | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
rts = sorted((k for k in d if "iOS" in k),
             key=lambda k: [int(x) for x in k.rsplit("iOS-", 1)[-1].split("-") if x.isdigit()])
for rt in reversed(rts):
    for dev in d[rt]:
        if dev["name"].startswith("iPhone"):
            print(dev["udid"]); sys.exit(0)
sys.exit("no available iPhone simulator")
')
echo "Using simulator $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b

xcrun simctl install "$UDID" "$APP"
# Pre-grant location so the first frame isn't hidden behind the prompt
# (grant can fail on older simctl; not fatal).
xcrun simctl privacy "$UDID" grant location-always "$BUNDLE_ID" || true
xcrun simctl spawn "$UDID" log stream --style compact \
  --predicate "process == \"Runner\"" > "$OUT/runner.log" 2>&1 &
LOG_PID=$!

xcrun simctl launch "$UDID" "$BUNDLE_ID" | tee "$OUT/launch.txt"
PID=$(awk -F': ' '{print $2}' "$OUT/launch.txt" | tr -d '[:space:]')
echo "Launched pid=$PID; waiting ${SMOKE_SECONDS}s"

alive() { xcrun simctl spawn "$UDID" launchctl list | awk -v id="$BUNDLE_ID" '$3 ~ id && $1 != "-" {found=1} END {exit !found}'; }

status=0
for i in $(seq 1 "$SMOKE_SECONDS"); do
  sleep 1
  if ! alive; then
    echo "::error::Guidy exited ${i}s after launch on the iOS simulator"
    status=1
    break
  fi
  if [ "$i" = 15 ]; then
    xcrun simctl io "$UDID" screenshot "$OUT/launch-15s.png" || true
  fi
done

xcrun simctl io "$UDID" screenshot "$OUT/launch-final.png" || true
kill "$LOG_PID" 2>/dev/null || true
pkill -f "log stream --style compact" 2>/dev/null || true
# Any crash report the simulator wrote for Runner.
find "$HOME/Library/Logs/DiagnosticReports" -name 'Runner*' -newer "$OUT/launch.txt" \
  -exec cp {} "$OUT/" \; 2>/dev/null || true
if ls "$OUT"/Runner*.ips >/dev/null 2>&1; then
  echo "::error::a crash report was written for Runner"
  status=1
fi

grep -iE "fatal|terminating app|uncaught exception" "$OUT/runner.log" | head -20 || true
[ "$status" = 0 ] && echo "Guidy stayed up for ${SMOKE_SECONDS}s on the iOS simulator."
exit "$status"
