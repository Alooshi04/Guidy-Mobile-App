# Guidy on a Mac

Double-clickable launchers live in this folder:

| File | What it does |
|---|---|
| `Guidy - 1 Setup Mac.command` | One-time setup: checks Xcode, installs Flutter/CocoaPods/Python with Homebrew, `pod install`, Android licenses. Safe to re-run. |
| `Guidy - 2 Start Backend.command` | Starts the backend from `../guidy-backend-main` on port 8000 (same as `Start Backend.command` in the backend folder). |
| `Guidy - 3 Install on iPhone.command` | Builds a release build and installs + opens it on a USB-connected iPhone (or runs it in the Simulator). |
| `Guidy - 4 Install on Android.command` | Builds a release APK, installs + opens it on a USB-connected Android phone or emulator, and copies `Guidy.apk` to the Desktop. |

The installers ask which backend to use: **1 = this Mac** (starts it for you if it isn't running), 2 = the URL in `secrets.properties`, 3 = any URL.
The URL is baked into the build, so re-run the installer if the Mac's IP changes.

## Clone and run

The private repo carries everything a build needs: `secrets.properties` (all API keys),
the Firebase config files, and the Android release signing key (`android/key.properties`
+ `android/app/guidy-release-key.jks`). None of that goes to the public CI mirror.

1. Install **Xcode** (App Store), open it once, accept the license and let it install the iOS platform. Then in Terminal:
   `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch`
2. Install **Homebrew**: https://brew.sh (run the two "Next steps" lines it prints).
3. Android only: `brew install --cask android-studio`, open it once and finish the setup wizard.
4. Clone the app (it asks for your GitHub login once; `brew install gh && gh auth login` is the easy way):
   ```
   mkdir -p ~/Guidy && cd ~/Guidy
   git clone https://github.com/youssefezat/guidy-app.git guidy-app-main
   ```
5. Double-click **Guidy - 1 Setup Mac.command** in `~/Guidy/guidy-app-main`. It installs the tools and
   clones the backend next to it as `guidy-backend-main` if it isn't there yet.
6. Double-click **Guidy - 3 Install on iPhone.command** or **Guidy - 4 Install on Android.command**.
   Pick backend option 1 and it starts the backend on this Mac for you.

If you copy the folders from a zip/AirDrop instead of cloning, first run
`xattr -dr com.apple.quarantine ~/Guidy && chmod +x ~/Guidy/*/*.command ~/Guidy/*/*.sh ~/Guidy/guidy-app-main/tool/mac/*.sh`.
If macOS says a `.command` file "cannot be opened": right-click it > Open > Open (once per file).
When macOS asks whether Python may accept incoming network connections: **Allow**.

The only thing a clone cannot carry is your Apple signing identity: the first iPhone
install opens Xcode once so you can pick your Apple ID team (see below).

## iPhone

- Plug in, unlock, **Trust This Computer**; Settings > Privacy & Security > **Developer Mode** on.
- The first run opens Xcode for signing: Runner > Signing & Capabilities > Automatically manage signing > Team (a free Apple ID works). If the bundle id is taken, change it locally (don't commit), press Cmd+S.
- After install: Settings > General > VPN & Device Management > trust your Apple ID. Allow Local Network when asked.
- Free Apple ID builds expire after 7 days; run the installer again.

## Android

- Phone: Settings > About phone > tap Build number 7 times; Developer options > **USB debugging** on; plug in, Allow.
- Builds are signed with the same release key as the Windows PC as the Windows PC's release builds.
- `android/gradle.properties` pins a Windows JDK path; the installer overrides it once in `~/.gradle/gradle.properties`.
- A debug build installed from Android Studio has a different signature; the installer offers to uninstall it first.
