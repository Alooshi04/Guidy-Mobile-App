#!/bin/sh
# Mac/Linux twin of restore_signing_files.bat -- see the comment there.
cd "$(dirname "$0")" || exit 1
[ -f android/key.properties ] || { git show b70e76a418e5fee09b242ac40b3bfa3f487bdf3d:android/key.properties > android/key.properties && echo "Restored android/key.properties"; }
[ -f android/app/guidy-release-key.jks ] || { git cat-file blob b70e76a418e5fee09b242ac40b3bfa3f487bdf3d:android/app/guidy-release-key.jks > android/app/guidy-release-key.jks && echo "Restored android/app/guidy-release-key.jks"; }
