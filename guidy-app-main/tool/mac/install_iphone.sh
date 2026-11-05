#!/usr/bin/env bash
# Build Guidy and install it on a USB-connected iPhone (or an iOS simulator).
# Started by "Guidy - 3 Install on iPhone.command".
set -uo pipefail
. "$(dirname "$0")/common.sh"

say "Guidy -> iPhone"
need xcodebuild; need flutter; need pod; need python3
xcodebuild -version >/dev/null 2>&1 || die "Xcode is not set up. Run \"Guidy - 1 Setup Mac.command\"."
# Xcode 16+ ships without the iOS platform; without it every build fails with
# "No Xcode build settings have been found" / "Found no destinations".
if ! xcodebuild -showsdks 2>/dev/null | grep -q -- '-sdk iphoneos'; then
  err "Xcode's iOS platform is not installed."
  echo "  Install it (several GB), then run this again:"
  echo "    xcodebuild -downloadPlatform iOS"
  echo "  or: Xcode > Settings > Components > iOS > Get."
  finish 1
fi
cd "$APP_DIR" || exit 1

if ! pick_device ios; then
  err "No iPhone found."
  echo "  - Connect it with a cable, unlock it and tap \"Trust This Computer\"."
  echo "  - iPhone: Settings > Privacy & Security > Developer Mode > On (it restarts)."
  echo "  - Open Xcode once with the phone connected so it can prepare the device."
  echo "  - Or open Simulator (Xcode > Open Developer Tool > Simulator) to test there."
  finish 1
fi

# A real device needs a signing team; the repo does not carry one.
if [ "$DEVICE_IS_EMULATOR" != 1 ] && ! grep -q 'DEVELOPMENT_TEAM' ios/Runner.xcodeproj/project.pbxproj; then
  say "One-time signing setup"
  echo "  Xcode is opening. In it:"
  echo "   1. Click \"Runner\" (blue icon, top left) > target \"Runner\" > \"Signing & Capabilities\"."
  echo "   2. Tick \"Automatically manage signing\" and choose your Team"
  echo "      (no team? Xcode > Settings > Accounts > + > Apple ID; a free Apple ID works)."
  echo "   3. If it says the bundle id is not available, change it to something unique,"
  echo "      e.g. com.<yourname>.guidy  (local change only -- do not commit it)."
  echo "   4. Wait until the red errors disappear, press Cmd+S, then come back here."
  open ios/Runner.xcworkspace
  read -r -p "Press Return when signing is set... " _ || true
  grep -q 'DEVELOPMENT_TEAM' ios/Runner.xcodeproj/project.pbxproj || die "No team saved yet (did you press Cmd+S?)."
fi

choose_backend
prepare_flutter
[ -d ios/Pods ] || { (cd ios && pod install) || die "pod install failed"; }
python3 tool/secrets_to_defines.py secrets.properties build/dart_defines.json ios/Flutter/Secrets.xcconfig || die "could not read secrets.properties"

if [ "$DEVICE_IS_EMULATOR" = 1 ]; then
  say "Running on the simulator (debug build). Press q here to stop; the app stays installed."
  flutter run -d "$DEVICE_ID" --dart-define-from-file=build/dart_defines.json
  finish $?
fi

say "Building (first build takes 5-15 minutes)"
if ! flutter build ios --release --dart-define-from-file=build/dart_defines.json; then
  err "Build failed. The usual causes:"
  echo "  - Xcode's own error (Flutter hides it):"
  echo "      cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -showBuildSettings 2>&1 | grep -i error"
  echo "  - \"Found no destinations\": xcodebuild -downloadPlatform iOS, then open Xcode >"
  echo "    Window > Devices and Simulators with the iPhone plugged in and wait until it is ready"
  echo "  - signing: open ios/Runner.xcworkspace and fix the red errors under Signing & Capabilities"
  echo "  - pods out of date: cd ios && pod install --repo-update"
  finish 1
fi
app="build/ios/iphoneos/Runner.app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist" 2>/dev/null || echo "$IOS_BUNDLE_ID")

say "Installing on $DEVICE_NAME"
if xcrun devicectl device install app --device "$DEVICE_ID" "$app" \
   && xcrun devicectl device process launch --device "$DEVICE_ID" "$bundle"; then
  ok "installed and launched"
else
  warn "devicectl could not install (older iOS/Xcode?) -- falling back to flutter run."
  echo "  When the app opens on the phone you can press q here; it stays installed."
  flutter run --release -d "$DEVICE_ID" --dart-define-from-file=build/dart_defines.json || die "install failed"
fi

cat <<'TXT'

If the phone says "Untrusted Developer":
  Settings > General > VPN & Device Management > your Apple ID > Trust, then open Guidy.
If it asks to find devices on your local network: Allow (needed to reach the Mac backend).
With a free Apple ID the app stops opening after 7 days -- just run this again.
TXT
finish 0
