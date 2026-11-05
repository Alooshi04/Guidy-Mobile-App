#!/bin/bash
# Double-click in Finder. One-time Mac setup (Xcode check, Flutter, CocoaPods, Android, backend).
cd "$(dirname "$0")" || exit 1
exec bash ./setup_mac.sh
