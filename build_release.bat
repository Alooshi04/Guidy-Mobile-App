@echo off
REM Double-click: Play Store build with NO ads (default). Test ads: "build_release.bat -TestAds". Real ads: "-RealAds".
REM Install on your phone too: "build_release.bat -Install" (or install_release_on_phone.bat).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release.ps1" %*
pause
