#!/usr/bin/env bash
# Build Guidy and install it on a USB-connected Android phone (or an emulator).
# Started by "Guidy - 4 Install on Android.command".
set -uo pipefail
. "$(dirname "$0")/common.sh"

say "Guidy -> Android"
need flutter; need python3
cd "$APP_DIR" || exit 1

# --- Java + SDK --------------------------------------------------------
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
[ -d "$sdk" ] || die "Android SDK not found. Install Android Studio, open it once (it downloads the SDK), then run Setup again."
adb="$sdk/platform-tools/adb"
[ -x "$adb" ] || adb=$(command -v adb) || die "adb not found (Android Studio > Settings > Android SDK > SDK Tools > Platform-Tools)."

# android/gradle.properties in the repo pins a WINDOWS JDK path. Gradle lets
# ~/.gradle/gradle.properties override it, so point that at a Mac JDK once.
jbr="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
if ! grep -qs '^org.gradle.java.home=' "$HOME/.gradle/gradle.properties"; then
  [ -d "$jbr" ] || jbr=$(/usr/libexec/java_home -v 17+ 2>/dev/null) || die "No Java 17+ found. Install Android Studio."
  mkdir -p "$HOME/.gradle"
  printf '\n# Added by Guidy install_android.sh: overrides the Windows path in the repo.\norg.gradle.java.home=%s\n' "$jbr" >> "$HOME/.gradle/gradle.properties"
  ok "Gradle will use Java at $jbr"
fi

# --- Device ------------------------------------------------------------
if ! pick_device android; then
  emu=$(flutter emulators 2>/dev/null | awk -F' • ' 'NF>3 && $NF ~ /android/ {gsub(/ /,"",$1); print $1; exit}')
  if [ -n "$emu" ]; then
    warn "No phone connected. Starting emulator $emu ..."
    flutter emulators --launch "$emu" >/dev/null 2>&1
    for _ in $(seq 1 40); do sleep 3; [ -n "$(list_devices android)" ] && break; done
  fi
  if ! pick_device android; then
    err "No Android device found."
    echo "  Phone: Settings > About phone > tap Build number 7 times, then"
    echo "         Settings > Developer options > USB debugging ON. Plug in and tap Allow."
    echo "  Or create an emulator: Android Studio > More Actions > Virtual Device Manager."
    finish 1
  fi
fi

if [ "$DEVICE_IS_EMULATOR" = 1 ]; then choose_backend emulator; else choose_backend; fi
if [ "${GUIDY_BACKEND_ON_MAC:-0}" = 1 ] && [ "$DEVICE_IS_EMULATOR" != 1 ]; then
  # Also tunnel port 8000 over USB; the app tries 127.0.0.1 as a fallback,
  # which keeps working even if the phone is on a different network.
  "$adb" -s "$DEVICE_ID" reverse tcp:8000 tcp:8000 >/dev/null 2>&1 && ok "USB tunnel for port 8000"
fi

# --- Signing ------------------------------------------------------------
# android/key.properties + the release keystore are in the private repo, so a
# clone signs exactly like the Windows PC. Only a copy without them falls back
# to this Mac's debug key. Places still works either way: it checks the
# ANDROID_CERT_SHA1 header value from secrets.properties, not the real key.
extra=()
if [ ! -f android/key.properties ]; then
  warn "android/key.properties missing -- signing with this Mac's debug key."
  warn "Phones that already have Guidy from the PC will need it uninstalled first."
  extra+=(--android-project-arg=allowDebugSigningFallback=true)
fi

prepare_flutter
python3 tool/secrets_to_defines.py secrets.properties build/dart_defines.json build/Secrets.unused.xcconfig | grep -v MAPS_API_KEY_IOS || die "could not read secrets.properties"

say "Building APK (first build takes 5-10 minutes)"
flutter build apk --release --dart-define-from-file=build/dart_defines.json ${extra[@]+"${extra[@]}"} || die "Build failed (see above)."
apk="build/app/outputs/flutter-apk/app-release.apk"

say "Installing on $DEVICE_NAME"
out=$("$adb" -s "$DEVICE_ID" install -r "$apk" 2>&1); echo "$out" | tail -2
if echo "$out" | grep -q 'INSTALL_FAILED_UPDATE_INCOMPATIBLE\|signatures do not match'; then
  warn "A Guidy signed on another computer is already installed."
  read -r -p "  Uninstall it (its saved data is lost) and install this one? [y/N] " yn || yn=n
  case "$yn" in [yY]*) "$adb" -s "$DEVICE_ID" uninstall "$ANDROID_PACKAGE" >/dev/null
                       out=$("$adb" -s "$DEVICE_ID" install "$apk" 2>&1); echo "$out" | tail -2 ;;
                *) finish 1 ;; esac
fi
echo "$out" | grep -q Success || die "install failed"
"$adb" -s "$DEVICE_ID" shell monkey -p "$ANDROID_PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
ok "installed and launched"
cp "$apk" "$HOME/Desktop/Guidy.apk" 2>/dev/null && ok "a copy is on your Desktop as Guidy.apk (send it to other Android phones)"
finish 0
