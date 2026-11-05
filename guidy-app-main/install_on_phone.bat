@echo off
setlocal enabledelayedexpansion

title Guidy - Quick Phone Installer
color 0B

echo ============================================================
echo            GUIDY - 1-CLICK PHONE INSTALLER
echo ============================================================
echo.

:: 1. Navigate to the Flutter project directory
set "PROJECT_DIR=%~dp0"
if exist "%PROJECT_DIR%guidy-app-main\pubspec.yaml" (
    set "PROJECT_DIR=%PROJECT_DIR%guidy-app-main\"
)
cd /d "%PROJECT_DIR%"

:: 2. Locate adb.exe
set "ADB_CMD=adb"
where adb >nul 2>&1
if %ERRORLEVEL% EQU 0 goto ADB_FOUND

if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_CMD=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
    goto ADB_FOUND
)
if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
    set "ADB_CMD=%ANDROID_HOME%\platform-tools\adb.exe"
    goto ADB_FOUND
)
if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
    set "ADB_CMD=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
    goto ADB_FOUND
)
if exist "C:\Android\platform-tools\adb.exe" (
    set "ADB_CMD=C:\Android\platform-tools\adb.exe"
    goto ADB_FOUND
)

color 0C
echo [ERROR] ADB - Android Debug Bridge - could not be found!
echo Please ensure Android SDK Platform-Tools or Flutter is installed.
echo.
pause
exit /b 1

:ADB_FOUND

:: 3. Check for Connected Android Device
:CHECK_DEVICE
echo [*] Checking for connected Android phone...
set "DEVICE_FOUND=0"
set "DEVICE_UNAUTHORIZED=0"

for /f "tokens=1,2" %%A in ('"%ADB_CMD%" devices') do (
    if "%%B"=="device" (
        set "DEVICE_ID=%%A"
        set "DEVICE_FOUND=1"
    )
    if "%%B"=="unauthorized" (
        set "DEVICE_UNAUTHORIZED=1"
    )
)

if "!DEVICE_FOUND!"=="1" goto DEVICE_READY

color 0E
echo.
if "!DEVICE_UNAUTHORIZED!"=="1" (
    echo [!] Device detected but UNAUTHORIZED!
    echo     Please unlock your phone and tap "Allow USB debugging".
) else (
    echo [!] No Android phone detected!
    echo     1. Connect your phone to your computer via USB cable.
    echo     2. Ensure "USB Debugging" is enabled in Developer Options.
    echo     3. If prompted on your phone, choose "File Transfer" mode.
)
echo.
echo Press any key to retry connection, or close this window...
pause >nul
color 0B
cls
echo ============================================================
echo            GUIDY - 1-CLICK PHONE INSTALLER
echo ============================================================
echo.
goto CHECK_DEVICE

:DEVICE_READY
:: Get Phone Info
for /f "usebackq delims=" %%M in (`"%ADB_CMD%" -s !DEVICE_ID! shell getprop ro.product.model 2^>nul`) do set "PHONE_MODEL=%%M"
for /f "usebackq delims=" %%V in (`"%ADB_CMD%" -s !DEVICE_ID! shell getprop ro.build.version.release 2^>nul`) do set "ANDROID_VER=%%V"
for /f "usebackq delims=" %%B in (`"%ADB_CMD%" -s !DEVICE_ID! shell getprop ro.product.brand 2^>nul`) do set "PHONE_BRAND=%%B"

echo [OK] Phone Connected: !PHONE_BRAND! !PHONE_MODEL! (Android !ANDROID_VER!) [!DEVICE_ID!]
echo.

:: 4. Check for APK
set "APK_PATH=build\app\outputs\flutter-apk\app-debug.apk"
if not exist "%APK_PATH%" (
    set "APK_PATH=build\app\outputs\apk\debug\app-debug.apk"
)

if not exist "%APK_PATH%" (
    echo [*] No APK build found. Initiating first build...
    goto BUILD_APK
)

for %%F in ("%APK_PATH%") do (
    set "APK_SIZE=%%~zF"
    set "APK_DATE=%%~tF"
)
set /a APK_SIZE_MB=!APK_SIZE! / 1048576
echo [*] Found existing build: !APK_PATH!
echo     Size: !APK_SIZE_MB! MB ^| Built on: !APK_DATE!
echo.
echo Choose an option:
echo   [I] Install existing build now (Fast - approx 5 seconds)
echo   [B] Rebuild fresh APK first (Approx 1 to 2 minutes)
echo.
choice /c IB /t 4 /d I /m "Auto-installing existing build in 4s (or press B to rebuild)"
if !ERRORLEVEL! EQU 2 goto BUILD_APK
goto DO_INSTALL

:BUILD_APK
echo.
echo [*] Building Flutter APK (Debug)...
call flutter build apk --debug
if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo.
    echo [ERROR] Flutter build failed! Please inspect the output above.
    echo.
    pause
    exit /b 1
)
set "APK_PATH=build\app\outputs\flutter-apk\app-debug.apk"

:DO_INSTALL
echo.
echo [*] Installing Guidy onto !PHONE_MODEL!...
"%ADB_CMD%" -s !DEVICE_ID! install -r -d "%APK_PATH%" > "%TEMP%\guidy_install.log" 2>&1
findstr /C:"Success" "%TEMP%\guidy_install.log" >nul 2>&1
if %ERRORLEVEL% EQU 0 goto INSTALL_SUCCESS

findstr /C:"INSTALL_FAILED_UPDATE_INCOMPATIBLE" "%TEMP%\guidy_install.log" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo [!] Previous install has incompatible signature.
    echo     Uninstalling previous version to perform clean install...
    "%ADB_CMD%" -s !DEVICE_ID! uninstall com.guidy.guidy_app >nul 2>&1
    "%ADB_CMD%" -s !DEVICE_ID! install -r "%APK_PATH%" > "%TEMP%\guidy_install.log" 2>&1
    findstr /C:"Success" "%TEMP%\guidy_install.log" >nul 2>&1
    if !ERRORLEVEL! EQU 0 goto INSTALL_SUCCESS
)

color 0C
echo.
echo [ERROR] Installation failed!
type "%TEMP%\guidy_install.log"
echo.
pause
exit /b 1

:INSTALL_SUCCESS
color 0A
echo.
echo ============================================================
echo       [SUCCESS] Guidy was installed successfully!
echo ============================================================
echo.
echo [*] Setting up reverse port forward for backend (tcp:8000)...
"%ADB_CMD%" -s !DEVICE_ID! reverse tcp:8000 tcp:8000 >nul 2>&1

echo [*] Launching Guidy on your phone...
"%ADB_CMD%" -s !DEVICE_ID! shell am start -n com.guidy.guidy_app/com.guidy.guidy_app.MainActivity >nul 2>&1
echo [OK] App is now open and running on your phone!
echo.
echo You can close this window now.
pause
exit /b 0
