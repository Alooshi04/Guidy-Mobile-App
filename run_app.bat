@echo off
REM Double-click this file to run the Guidy app on a connected phone.
REM (PowerShell .ps1 files can't be double-clicked directly on Windows --
REM the default execution policy blocks it -- so this .bat is the real
REM entry point, and it launches the .ps1 with that policy bypassed just
REM for this one run.)
REM
REM For the Android emulator, run this from a terminal instead:
REM   .\run_app.ps1 -Emulator

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_app.ps1" %*
