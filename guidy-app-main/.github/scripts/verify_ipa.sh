#!/usr/bin/env bash
# Sanity-check the unsigned device IPA before it is published: right
# bundle id, arm64 device binary, and the Info.plist keys a sideloaded
# build needs to reach the dev backend and show maps.
#
# Usage: verify_ipa.sh <Guidy-unsigned.ipa>
set -euo pipefail
IPA="$1"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$WORK/Payload/Runner.app"
PLIST="$APP/Info.plist"
fail=0
check() { # key expected
  local got
  got=$(/usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null) || got="<missing>"
  if [ "$got" = "$2" ]; then echo "ok   $1 = $got"
  else echo "::error::$1 is '$got', expected '$2'"; fail=1; fi
}
[ -f "$APP/Runner" ] || { echo "::error::no Runner executable in the IPA"; exit 1; }
check CFBundleIdentifier com.guidy.guidyApp
check NSAppTransportSecurity:NSAllowsLocalNetworking true
/usr/libexec/PlistBuddy -c "Print :NSLocalNetworkUsageDescription" "$PLIST" >/dev/null \
  && echo "ok   NSLocalNetworkUsageDescription present" \
  || { echo "::error::NSLocalNetworkUsageDescription missing"; fail=1; }
# GMSApiKey must have been expanded by Xcode, never left as the literal.
key=$(/usr/libexec/PlistBuddy -c "Print :GMSApiKey" "$PLIST" 2>/dev/null) || key="<missing>"
case "$key" in
  '$('*|'<missing>') echo "::error::GMSApiKey was not expanded ('$key')"; fail=1 ;;
  '') echo "::warning::GMSApiKey is empty -- no MAPS_API_KEY_IOS secret, map tiles will be blank" ;;
  AIza???????????????????????????????????) echo "ok   GMSApiKey set (well-formed)" ;;
  *) echo "::error::GMSApiKey is set but malformed (${#key} chars, expected AIza + 35)"; fail=1 ;;
esac
plat=$(/usr/libexec/PlistBuddy -c "Print :DTPlatformName" "$PLIST")
[ "$plat" = iphoneos ] && echo "ok   DTPlatformName = iphoneos" \
  || { echo "::error::built for '$plat', not iphoneos"; fail=1; }
lipo -info "$APP/Runner" | tee /dev/stderr | grep -q arm64 \
  || { echo "::error::Runner is not an arm64 device binary"; fail=1; }
[ -f "$APP/Frameworks/App.framework/App" ] \
  || { echo "::error::App.framework (compiled Dart) missing"; fail=1; }
[ -f "$APP/GoogleService-Info.plist" ] \
  || { echo "::error::GoogleService-Info.plist not bundled"; fail=1; }
ls -la "$IPA"
exit "$fail"
