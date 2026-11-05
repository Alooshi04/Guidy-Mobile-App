@echo off
REM Builds the release APK with TEST ads and installs it on the USB phone.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release.ps1" -TestAds -NoBump -Install
pause
