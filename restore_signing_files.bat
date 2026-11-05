@echo off
REM Restores the Android release-signing files after they stopped being
REM tracked in git (2026-09-22). A pull that includes that change deletes
REM them from this machine's working tree; this puts them back from the
REM last commit that still contained them. They are gitignored now, so
REM they stay local from here on.
cd /d "%~dp0"
if exist android\key.properties (
  echo android\key.properties already present.
) else (
  git show b70e76a418e5fee09b242ac40b3bfa3f487bdf3d:android/key.properties > android\key.properties && echo Restored android\key.properties
)
if exist android\app\guidy-release-key.jks (
  echo android\app\guidy-release-key.jks already present.
) else (
  git cat-file blob b70e76a418e5fee09b242ac40b3bfa3f487bdf3d:android/app/guidy-release-key.jks > android\app\guidy-release-key.jks && echo Restored android\app\guidy-release-key.jks
)
pause
