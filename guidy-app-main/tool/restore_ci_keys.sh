#!/bin/sh
# CI only: put the real Google API keys back into a checkout of the PUBLIC
# mirror, whose snapshot has them replaced by placeholders (tool/ci_keys.env).
# Each key comes from an environment variable fed by a repository secret:
#   FIREBASE_API_KEY_ANDROID  android/app/google-services.json, firebase_options.dart
#   FIREBASE_API_KEY_APPLE    ios+macos GoogleService-Info.plist, firebase_options.dart
#   MAPS_API_KEY_ANDROID      places_service.dart default (Android)
#   MAPS_API_KEY_IOS          places_service.dart default (iOS)
# An unset variable leaves its placeholder: the app still builds and launches,
# that service just gets rejected at runtime. In the private repo there are no
# placeholders and this does nothing. Values are never printed.
#
# Pass the names to restore (a job only gets its own platform's secrets);
# with no arguments all four are attempted.
#   sh tool/restore_ci_keys.sh FIREBASE_API_KEY_ANDROID MAPS_API_KEY_ANDROID
set -eu
wanted=${*:-FIREBASE_API_KEY_ANDROID FIREBASE_API_KEY_APPLE MAPS_API_KEY_ANDROID MAPS_API_KEY_IOS}
cd "$(dirname "$0")/.."
. tool/ci_keys.env
files=$(grep -rlE "$CI_PH_FB_ANDROID|$CI_PH_FB_APPLE|$CI_PH_PLACES_ANDROID|$CI_PH_PLACES_IOS" \
  lib android ios macos 2>/dev/null || true)
if [ -z "$files" ]; then echo "No redacted keys in this checkout; nothing to restore."; exit 0; fi
restore() {
  name=$1 ph=$2 val=$3
  case " $wanted " in *" $name "*) ;; *) return 0 ;; esac
  if [ -z "$val" ]; then
    echo "::notice::$name secret not set; its placeholder stays (that service will be rejected at runtime)."
    return 0
  fi
  if ! printf '%s' "$val" | grep -Eq '^AIza[0-9A-Za-z_-]{35}$'; then
    echo "::error::$name secret is malformed (expected AIza + 35 characters, nothing else)."
    exit 1
  fi
  for f in $files; do sed -i.bak "s/$ph/$val/g" "$f" && rm -f "$f.bak"; done
  echo "$name restored."
}
restore FIREBASE_API_KEY_ANDROID "$CI_PH_FB_ANDROID"     "${FIREBASE_API_KEY_ANDROID:-}"
restore FIREBASE_API_KEY_APPLE   "$CI_PH_FB_APPLE"       "${FIREBASE_API_KEY_APPLE:-}"
restore MAPS_API_KEY_ANDROID     "$CI_PH_PLACES_ANDROID" "${MAPS_API_KEY_ANDROID:-}"
restore MAPS_API_KEY_IOS         "$CI_PH_PLACES_IOS"     "${MAPS_API_KEY_IOS:-}"
