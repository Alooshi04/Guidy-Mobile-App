@echo off
rem Builds BOTH release flavours into build\release\ :
rem   guidy-testads.aab / .apk   Google test ads  (internal / closed testing)
rem   guidy-release.aab / .apk   real AdMob ads   (production)
rem Raises the build number in pubspec.yaml by 1 first: Google Play accepts
rem each build number (versionCode) only once, across all tracks. Skip that
rem with "build_both.bat -NoBump". Both flavours share the new number, so
rem upload only one of them per build number.
setlocal
cd /d "%~dp0"

for /f "tokens=2" %%v in ('findstr /b "version:" pubspec.yaml') do set "CUR=%%v"
echo Current version: %CUR%
if /i not "%~1"=="-NoBump" (
  powershell -NoProfile -Command "$p='pubspec.yaml'; $t=[IO.File]::ReadAllText($p); $m=[regex]::Match($t,'(?m)^version: (\S+)\+(\d+)'); $n=[int]$m.Groups[2].Value+1; $t=$t.Substring(0,$m.Index)+'version: '+$m.Groups[1].Value+'+'+$n+$t.Substring($m.Index+$m.Length); [IO.File]::WriteAllText($p,$t); Write-Host ('Now: version '+$m.Groups[1].Value+'+'+$n)"
  if errorlevel 1 goto fail
)

echo.
echo [1/2] Test-ads build...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release.ps1" -NoBump -TestAds
if errorlevel 1 goto fail
echo.
echo [2/2] Real-ads build...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release.ps1" -NoBump -RealAds
if errorlevel 1 goto fail

echo.
echo ALL DONE. Files are in build\release\
dir /b build\release\*.aab build\release\*.apk
pause
exit /b 0

:fail
echo SOMETHING FAILED - see build\release\build_release_log.txt
pause
exit /b 1
