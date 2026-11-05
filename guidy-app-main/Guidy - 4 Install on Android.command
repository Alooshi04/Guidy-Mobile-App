#!/bin/bash
# Double-click in Finder. Builds Guidy and installs it on a connected Android phone.
cd "$(dirname "$0")" || exit 1
exec bash tool/mac/install_android.sh
