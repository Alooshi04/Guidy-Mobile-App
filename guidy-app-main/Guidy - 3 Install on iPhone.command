#!/bin/bash
# Double-click in Finder. Builds Guidy and installs it on a connected iPhone.
cd "$(dirname "$0")" || exit 1
exec bash tool/mac/install_iphone.sh
