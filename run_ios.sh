#!/usr/bin/env bash
# Run Guidy on an iPhone (or the iOS simulator) from a Mac.
#
#   ./run_ios.sh                      # pick a device interactively
#   ./run_ios.sh -d <device-id>       # any extra args go to `flutter run`
#   GUIDY_LOCAL_BACKEND=1 ./run_ios.sh   # use the backend running on THIS Mac
#   API_BASE_URL=http://x:8000/api ./run_ios.sh
#
# The macOS counterpart of run_app.bat. It turns secrets.properties into:
#   - build/dart_defines.json      -> --dart-define-from-file (Places key,
#                                     AdMob ids, API_BASE_URL)
#   - ios/Flutter/Secrets.xcconfig -> MAPS_API_KEY_IOS for the native Maps
#                                     SDK (Info.plist GMSApiKey)
# Both outputs are gitignored.
set -euo pipefail
cd "$(dirname "$0")"

[ -f secrets.properties ] || { echo "secrets.properties not found in $(pwd)"; exit 1; }

if [ "${GUIDY_LOCAL_BACKEND:-0}" = 1 ] && [ -z "${API_BASE_URL:-}" ]; then
  ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
  [ -n "$ip" ] || { echo "Could not find this Mac's Wi-Fi/Ethernet IP"; exit 1; }
  export API_BASE_URL="http://$ip:8000/api"
fi

mkdir -p build
python3 tool/secrets_to_defines.py secrets.properties build/dart_defines.json ios/Flutter/Secrets.xcconfig

# google_mobile_ads is CocoaPods-only and webview_flutter_wkwebview uses
# Swift Package Manager; Flutter refuses a project that needs both unless
# SPM is off (same switch CI flips).
flutter config --no-enable-swift-package-manager >/dev/null
flutter pub get
flutter gen-l10n

exec flutter run --dart-define-from-file=build/dart_defines.json "$@"
