@echo off
REM Double-click to install the latest Guidy iOS build on an iPhone.
REM Downloads the unsigned IPA that CI publishes on the public
REM guidy-app-ci-mirror repo and hands it to Sideloadly, which signs it
REM with your Apple ID. See install_on_iphone.ps1 for details.
REM   install_on_iphone.bat -Ipa C:\path\app.ipa     use a local IPA
REM   install_on_iphone.bat -Ipa x.ipa -SignedIpa    already-signed IPA, via ideviceinstaller
setlocal
set "SCRIPT=%~dp0install_on_iphone.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0guidy-app-main\install_on_iphone.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
echo.
pause
