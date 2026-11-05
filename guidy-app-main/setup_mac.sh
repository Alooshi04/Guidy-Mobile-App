#!/usr/bin/env bash
# One-time Mac setup for building Guidy for iOS. Safe to re-run.
#   ./setup_mac.sh      (or double-click "Guidy - 1 Setup Mac.command")
# Needs: Xcode from the App Store (opened once), Homebrew (https://brew.sh).
# Android Studio is optional (only for "Install on Android").
set -uo pipefail
cd "$(dirname "$0")" || exit 1
for p in /opt/homebrew/bin /usr/local/bin; do [ -d "$p" ] && PATH="$p:$PATH"; done
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m   %s\n' "$*"; }

echo "== Xcode"
if xcodebuild -version >/dev/null 2>&1; then
  ok "$(xcodebuild -version | head -1)"
else
  warn "Xcode not ready. Install it from the App Store, open it once, then run:"
  echo "       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "       sudo xcodebuild -runFirstLaunch"
  exit 1
fi
if xcodebuild -showsdks 2>/dev/null | grep -q -- '-sdk iphoneos'; then
  ok "iOS platform installed"
else
  warn "iOS platform missing -- downloading it now (several GB) ..."
  xcodebuild -downloadPlatform iOS && ok "iOS platform installed" \
    || warn "Download failed: Xcode > Settings > Components > iOS > Get"
fi

echo "== Homebrew tools"
command -v brew >/dev/null || { warn "Homebrew missing: https://brew.sh"; exit 1; }
command -v pod     >/dev/null && ok "CocoaPods $(pod --version)"  || brew install cocoapods
command -v flutter >/dev/null && ok "$(flutter --version | head -1)" || brew install --cask flutter
if command -v python3.12 >/dev/null || command -v python3.13 >/dev/null; then ok "modern Python present"
else brew install python@3.12; fi

echo "== Flutter"
flutter config --no-enable-swift-package-manager >/dev/null   # see run_ios.sh
flutter precache --ios >/dev/null
flutter doctor

echo "== Project"
[ -f secrets.properties ] && ok "secrets.properties present" || warn "secrets.properties missing"
flutter pub get >/dev/null && ok "pub get"
(cd ios && pod install) && ok "pod install"

echo "== Android (optional)"
sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [ -d "/Applications/Android Studio.app" ] && [ -d "$sdk" ]; then
  ok "Android Studio + SDK"
  flutter config --android-sdk "$sdk" >/dev/null
  # android/gradle.properties pins the Windows PC's JDK; ~/.gradle wins over it.
  jbr="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  if [ -d "$jbr" ] && ! grep -qs '^org.gradle.java.home=' "$HOME/.gradle/gradle.properties"; then
    mkdir -p "$HOME/.gradle"
    printf '\n# Added by Guidy setup_mac.sh: overrides the Windows path in the repo.\norg.gradle.java.home=%s\n' "$jbr" >> "$HOME/.gradle/gradle.properties"
    ok "Gradle uses Android Studio's Java"
  fi
  flutter doctor --android-licenses < <(yes 2>/dev/null) >/dev/null 2>&1 && ok "Android licenses accepted"
else
  warn "Android Studio not installed (only needed for Android): brew install --cask android-studio,"
  echo "       open it once and finish its setup wizard, then run this again."
fi

echo "== Backend"
# shellcheck source=tool/mac/common.sh
. tool/mac/common.sh
if bd=$(backend_dir) || { clone_backend && bd=$(backend_dir); }; then
  ok "backend folder: $bd"
  chmod +x "$bd/run_backend.sh" "$bd/Start Backend.command" 2>/dev/null
else
  warn "No backend yet. Clone it next to this folder:"
  echo "       git clone https://github.com/youssefezat/guidy-backend.git \"$(cd .. && pwd)/guidy-backend-main\""
fi
chmod +x ./*.command setup_mac.sh run_ios.sh tool/mac/*.sh 2>/dev/null

cat <<'TXT'

Next:
  1. Xcode: open ios/Runner.xcworkspace > Runner target > Signing & Capabilities
     > tick "Automatically manage signing" and pick a Team (a free Apple ID works:
     Xcode > Settings > Accounts > +). If Xcode says com.guidy.guidyApp is not
     available, you are on a different team than the one that owns it -- either
     join that team or change the bundle id locally (don't commit that).
  2. iPhone: plug in, Trust, then Settings > Privacy & Security > Developer Mode.
  3. Double-click "Guidy - 3 Install on iPhone.command"
     (it starts the backend on this Mac for you if you pick option 1).
     Android: "Guidy - 4 Install on Android.command".
  First launch of a free-team build: Settings > General > VPN & Device
  Management > trust the developer.
TXT
[ -t 0 ] && read -r -p "Press Return to close this window..." _
exit 0
