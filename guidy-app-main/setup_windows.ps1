# Guidy - one-time Windows setup for a fresh PC.
#
# Installs everything needed to build the Flutter app, run it on a phone or
# the Android emulator, and run the Python backend -- then checks that it
# all works. Safe to re-run: every step skips itself if already done.
#
# Run via setup_windows.bat (double-click). It asks for Administrator once,
# because the JDK, the firewall rule and the emulator's hypervisor
# feature need it.
#
#   setup_windows.bat                 full setup + test build
#   setup_windows.bat -SkipBuild      skip the (slow) test APK build
#   setup_windows.bat -SkipEmulator   don't download the emulator image
#
# Everything printed is also saved to setup_windows_log.txt next to this file.

param(
    [switch]$SkipBuild,
    [switch]$SkipEmulator,
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest ~10x faster
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Self-elevate ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Asking for Administrator rights...' -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated')
    if ($SkipBuild)    { $argList += '-SkipBuild' }
    if ($SkipEmulator) { $argList += '-SkipEmulator' }
    Start-Process powershell -Verb RunAs -ArgumentList $argList -Wait
    exit
}

# Works both from the folder that holds the two repos (D:\guidy) and from
# inside the app repo itself (where a copy of this script is committed).
$Root = $PSScriptRoot
if (Test-Path (Join-Path $Root 'pubspec.yaml')) {
    $App  = $Root
    $Root = Split-Path $Root
} else {
    $App  = Join-Path $Root 'guidy-app-main'
}
$Backend = @('guidy-backend-main', 'guidy-backend') | ForEach-Object { Join-Path $Root $_ } |
    Where-Object { Test-Path (Join-Path $_ 'main.py') } | Select-Object -First 1
if (-not $Backend) { $Backend = Join-Path $Root 'guidy-backend-main' }
$LogFile = Join-Path $Root 'setup_windows_log.txt'
Start-Transcript -Path $LogFile -Force | Out-Null

$warnings = New-Object System.Collections.Generic.List[string]
$needsReboot = $false

# --- Helpers ----------------------------------------------------------------
function Step([string]$msg) {
    Write-Host ''
    Write-Host "==> $msg" -ForegroundColor Cyan
}
function Ok([string]$msg)   { Write-Host "    [ok] $msg" -ForegroundColor Green }
function Warn([string]$msg) { Write-Host "    [!] $msg" -ForegroundColor Yellow; $script:warnings.Add($msg) }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Add-UserPath([string]$dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if ($userPath) { $parts = $userPath.Split(';') | Where-Object { $_ -ne '' } }
    if ($parts -notcontains $dir) {
        [Environment]::SetEnvironmentVariable('Path', (@($dir) + $parts) -join ';', 'User')
        Write-Host "    added to PATH: $dir"
    }
    Refresh-Path
}

# Runs a native program, streams its output, and throws on a non-zero exit
# code unless -AllowFail. (Native stderr must not trip $ErrorActionPreference.)
function Run {
    param([string]$Exe, [string[]]$ArgList = @(), [switch]$AllowFail, [string]$StdIn)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($PSBoundParameters.ContainsKey('StdIn')) {
        $StdIn | & $Exe @ArgList 2>&1 | ForEach-Object { "$_" } | Out-Host
    } else {
        & $Exe @ArgList 2>&1 | ForEach-Object { "$_" } | Out-Host
    }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0 -and -not $AllowFail) {
        throw "'$Exe $($ArgList -join ' ')' failed (exit code $code)"
    }
    return $code
}

function Winget-Install([string]$id, [scriptblock]$isInstalled, [string[]]$extra = @()) {
    if (& $isInstalled) { Ok "$id already installed"; return }
    for ($attempt = 1; $attempt -le 3 -and -not (& $isInstalled); $attempt++) {
        Write-Host "    installing $id (attempt $attempt of 3, can take a few minutes)..."
        $null = Run winget (@('install', '--id', $id, '-e', '--silent',
            '--accept-source-agreements', '--accept-package-agreements') + $extra) -AllowFail
        Refresh-Path
        if (-not (& $isInstalled) -and $attempt -lt 3) { Start-Sleep -Seconds 10 }
    }
    if (-not (& $isInstalled)) { throw "$id did not install. See the winget output above." }
    Ok "$id installed"
}

function Get-RealPython {
    $cmd = Get-Command python -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notlike '*\WindowsApps\*' } | Select-Object -First 1
    if (-not $cmd) { return $null }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $v = & $cmd.Source -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
    $ErrorActionPreference = $old
    if (-not $v) { return $null }
    if ([version]$v -lt [version]'3.10') { return $null }
    return $cmd.Source
}

function Get-LanIp {
    # Prefer the adapter that has a default gateway (the real Wi-Fi/Ethernet),
    # so the Mobile Hotspot / ICS adapter (192.168.137.1) is never picked.
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and
                       $_.InterfaceAlias -notmatch 'vEthernet|Virtual|WSL|VPN' } |
        Select-Object -First 1
    if ($cfg) { return ($cfg.IPv4Address | Select-Object -First 1).IPAddress }
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
            $_.IPAddress -notlike '192.168.137.*' -and
            $_.InterfaceAlias -notmatch 'Loopback|vEthernet|Virtual|WSL|VPN|Local Area Connection\*'
        } | Select-Object -First 1 -ExpandProperty IPAddress
}

function Write-TextNoBom([string]$path, [string]$text) {
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}

try {
    Write-Host ''
    Write-Host '=================================================' -ForegroundColor Cyan
    Write-Host '  Guidy - Windows setup' -ForegroundColor Cyan
    Write-Host '=================================================' -ForegroundColor Cyan

    if (-not (Test-Path (Join-Path $App 'pubspec.yaml'))) { throw "App not found at $App" }
    if (-not (Test-Path (Join-Path $Backend 'main.py')))  { throw "Backend not found at $Backend" }

    # ---------------------------------------------------------------- winget
    Step 'Checking winget'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is missing. Install "App Installer" from the Microsoft Store, then run this again.'
    }
    Ok 'winget found'

    # ------------------------------------------------------------------- Git
    Step 'Git'
    Winget-Install 'Git.Git' { [bool](Get-Command git -ErrorAction SilentlyContinue) }
    # The repos were copied from another PC, so Git would call them
    # "dubious ownership" and refuse to work in them.
    foreach ($repo in @($App, $Backend)) {
        $p = $repo -replace '\\', '/'
        $existing = & git config --global --get-all safe.directory 2>$null
        if ($existing -notcontains $p) { $null = Run git @('config', '--global', '--add', 'safe.directory', $p) }
    }
    Ok 'repos marked as safe for Git'

    # ---------------------------------------------------------------- Python
    Step 'Python'
    Winget-Install 'Python.Python.3.11' { [bool](Get-RealPython) } @(
        '--override', '/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1 Include_test=0')
    $Python = Get-RealPython
    Ok "using $Python"

    # ------------------------------------------------------------------ JDK
    # Gradle needs JDK 17+. Android Studio's bundled one is used if it's
    # already installed; otherwise Microsoft's OpenJDK 21 (smaller, and its
    # download host has been more reliable than Google's here).
    # android/gradle.properties is pointed at whichever one is used, below.
    Step 'Java JDK (for Gradle)'
    function Find-Jdk {
        $as = 'C:\Program Files\Android\Android Studio\jbr'
        if (Test-Path (Join-Path $as 'bin\java.exe')) { return $as }
        $ms = Get-ChildItem 'C:\Program Files\Microsoft' -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($ms) { return $ms.FullName }
        return $null
    }
    Winget-Install 'Microsoft.OpenJDK.21' { [bool](Find-Jdk) }
    $Jbr = Find-Jdk
    Ok "using JDK at $Jbr"
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $Jbr, 'User')
    $env:JAVA_HOME = $Jbr

    # ------------------------------------------------------------ Android SDK
    Step 'Android SDK'
    $Sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    New-Item -ItemType Directory -Force -Path $Sdk | Out-Null
    [Environment]::SetEnvironmentVariable('ANDROID_HOME', $Sdk, 'User')
    $env:ANDROID_HOME = $Sdk
    $SdkManager = Join-Path $Sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
    $AvdManager = Join-Path $Sdk 'cmdline-tools\latest\bin\avdmanager.bat'

    if (-not (Test-Path $SdkManager)) {
        $zipUrl  = 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
        $zipSha  = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'
        $zipPath = Join-Path $env:TEMP 'android-cmdline-tools.zip'
        $unzip   = Join-Path $env:TEMP 'android-cmdline-tools'
        Write-Host '    downloading Android command-line tools (~155 MB)...'
        for ($attempt = 1; ; $attempt++) {
            try { Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing; break }
            catch {
                if ($attempt -ge 3) { throw }
                Write-Host "    download failed ($($_.Exception.Message)); retrying..."
                Start-Sleep -Seconds 10
            }
        }
        $hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
        if ($hash -ne $zipSha) { throw "Checksum mismatch on the Android tools download ($hash)" }
        if (Test-Path $unzip) { Remove-Item $unzip -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $unzip -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $Sdk 'cmdline-tools') | Out-Null
        Move-Item (Join-Path $unzip 'cmdline-tools') (Join-Path $Sdk 'cmdline-tools\latest')
        Remove-Item $zipPath, $unzip -Recurse -Force -ErrorAction SilentlyContinue
        Ok 'command-line tools installed'
    } else {
        Ok 'command-line tools already installed'
    }

    $yes = (1..50 | ForEach-Object { 'y' }) -join "`n"
    Write-Host '    accepting Android SDK licenses...'
    $null = Run $SdkManager @('--licenses', "--sdk_root=$Sdk") -StdIn $yes -AllowFail

    $packages = @('platform-tools', 'platforms;android-36', 'build-tools;36.0.0')
    $SysImage = 'system-images;android-36;google_apis_playstore;x86_64'
    if (-not $SkipEmulator) { $packages += @('emulator', $SysImage) }
    Write-Host '    installing SDK packages (several GB the first time)...'
    $null = Run $SdkManager (@("--sdk_root=$Sdk") + $packages) -StdIn $yes
    Add-UserPath (Join-Path $Sdk 'platform-tools')
    if (-not $SkipEmulator) { Add-UserPath (Join-Path $Sdk 'emulator') }
    Ok 'SDK packages installed'

    # ---------------------------------------------------------------- Flutter
    # pubspec.yaml needs Dart >= 3.11.1, i.e. a current stable Flutter.
    # Full clone on purpose: a --depth 1 clone has no tags, Flutter then
    # reports version 0.0.0-unknown and every SDK constraint fails.
    Step 'Flutter'
    $existing = Get-Command flutter -ErrorAction SilentlyContinue
    if ($existing) {
        $FlutterRoot = Split-Path (Split-Path $existing.Source)
        Ok "Flutter already on PATH at $FlutterRoot"
    } else {
        $FlutterRoot = 'C:\flutter_sdk\flutter'
        if (-not (Test-Path (Join-Path $FlutterRoot 'bin\flutter.bat'))) {
            New-Item -ItemType Directory -Force -Path (Split-Path $FlutterRoot) | Out-Null
            Write-Host '    cloning Flutter stable (~1 GB)...'
            $null = Run git @('clone', '-b', 'stable', 'https://github.com/flutter/flutter.git', $FlutterRoot)
        }
        Add-UserPath (Join-Path $FlutterRoot 'bin')
    }
    $FlutterExe = Join-Path $FlutterRoot 'bin\flutter.bat'
    $null = Run git @('config', '--global', '--add', 'safe.directory', ($FlutterRoot -replace '\\', '/')) -AllowFail

    $null = Run $FlutterExe @('config', '--no-analytics') -AllowFail
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $verJson = (& $FlutterExe --version --machine 2>$null) -join "`n"
    $ErrorActionPreference = $old
    $dartVer = $null
    if ($verJson -match '"dartSdkVersion"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)') { $dartVer = [version]$Matches[1] }
    if (-not $dartVer -or $dartVer -lt [version]'3.11.1') {
        Write-Host "    Dart $dartVer is too old for this app; upgrading Flutter..."
        $null = Run $FlutterExe @('channel', 'stable') -AllowFail
        $null = Run $FlutterExe @('upgrade', '--force')
    }
    $null = Run $FlutterExe @('--version')

    $null = Run $FlutterExe @('config', "--android-sdk=$Sdk", "--jdk-dir=$Jbr")
    Write-Host '    accepting Flutter Android licenses...'
    $null = Run $FlutterExe @('doctor', '--android-licenses') -StdIn $yes -AllowFail

    # --------------------------------------- android/gradle.properties JDK path
    Step 'Gradle JDK path'
    $gp = Join-Path $App 'android\gradle.properties'
    if (Test-Path $gp) {
        $text = [IO.File]::ReadAllText($gp)
        $escaped = ($Jbr -replace '\\', '\\') -replace ':', '\:'
        $newLine = "org.gradle.java.home=$escaped"
        if ($text -match '(?m)^org\.gradle\.java\.home=[^\r\n]*') {
            if ($Matches[0] -ne $newLine) {
                Write-TextNoBom $gp ([regex]::Replace($text, '(?m)^org\.gradle\.java\.home=[^\r\n]*', $newLine))
                Ok 'updated to this PC''s JDK'
            } else { Ok 'already points at this JDK' }
        } else { Ok 'no hardcoded JDK path' }
    }

    # ------------------------------------------------ Flutter project packages
    Step 'App packages (flutter pub get + gen-l10n)'
    Push-Location $App
    try {
        $null = Run $FlutterExe @('pub', 'get')
        $null = Run $FlutterExe @('gen-l10n')
    } finally { Pop-Location }
    Ok 'packages fetched'

    # --------------------------------------------------- debug signing / SHA-1
    # Google Maps / Firebase restrictions are tied to the SHA-1 of the debug
    # keystore, and every PC generates its own.
    Step 'Debug signing key'
    $keytool = Join-Path $Jbr 'bin\keytool.exe'
    $androidDir = Join-Path $env:USERPROFILE '.android'
    $debugKs = Join-Path $androidDir 'debug.keystore'
    New-Item -ItemType Directory -Force -Path $androidDir | Out-Null
    if (-not (Test-Path $debugKs)) {
        $null = Run $keytool @('-genkeypair', '-v', '-keystore', $debugKs, '-storepass', 'android',
            '-alias', 'androiddebugkey', '-keypass', 'android', '-keyalg', 'RSA', '-keysize', '2048',
            '-validity', '10000', '-dname', 'CN=Android Debug,O=Android,C=US')
    }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $ksOut = (& $keytool -list -v -keystore $debugKs -alias androiddebugkey -storepass android 2>$null) -join "`n"
    $ErrorActionPreference = $old
    $sha1 = $null
    if ($ksOut -match 'SHA1:\s*([0-9A-F:]{59})') { $sha1 = $Matches[1] }
    Write-Host "    this PC's debug SHA-1: $sha1"

    $secretsPath = Join-Path $App 'secrets.properties'
    $secretsText = [IO.File]::ReadAllText($secretsPath)
    $configured = $null
    if ($secretsText -match '(?m)^ANDROID_CERT_SHA1=([^\r\n]*)') { $configured = $Matches[1].Trim() }
    $norm = { param($s) if ($s) { ($s -replace '[^0-9A-Fa-f]', '').ToUpper() } }
    if ($sha1 -and (& $norm $configured) -ne (& $norm $sha1)) {
        Warn ("This PC's debug SHA-1 ($sha1) is not the one in secrets.properties. " +
              'Map tiles and Google sign-in in debug builds need it added to the Maps API key ' +
              '(Google Cloud Console) and to the Firebase Android app -- or copy ' +
              '%USERPROFILE%\.android\debug.keystore over from the old PC.')
    } else { Ok 'matches secrets.properties' }

    # ------------------------------------------------ API_BASE_URL for a phone
    Step 'Backend address for a physical phone'
    $ip = Get-LanIp
    if ($ip) {
        $wanted = "API_BASE_URL=http://${ip}:8000/api"
        if ($secretsText -match '(?m)^API_BASE_URL=[^\r\n]*' -and $Matches[0] -ne $wanted) {
            Write-TextNoBom $secretsPath ([regex]::Replace($secretsText, '(?m)^API_BASE_URL=[^\r\n]*', $wanted))
            Ok "secrets.properties now uses $wanted"
        } else { Ok "already $wanted" }
    } else {
        Warn 'Could not detect this PC''s Wi-Fi IP; set API_BASE_URL in secrets.properties by hand (see ipconfig).'
    }

    # --------------------------------------------------------- Firewall rule
    Step 'Windows Firewall (port 8000 for the backend)'
    if (-not (Get-NetFirewallRule -DisplayName 'Guidy Backend' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName 'Guidy Backend' -Direction Inbound -LocalPort 8000 `
            -Protocol TCP -Action Allow -Profile Private,Domain | Out-Null
        Ok 'rule added'
    } else { Ok 'rule already exists' }
    $pub = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.NetworkCategory -eq 'Public' }
    if ($pub) {
        Warn ("Your network '$($pub[0].Name)' is set to Public, so the firewall rule doesn't apply and a phone " +
              "on Wi-Fi can't reach the backend. Set it to Private in Settings > Network, or use install_on_phone.bat (USB).")
    }

    # ------------------------------------------------------ Emulator + AVD
    if (-not $SkipEmulator) {
        Step 'Android emulator'
        $feature = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -ErrorAction SilentlyContinue
        if ($feature -and $feature.State -ne 'Enabled') {
            Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -NoRestart -All | Out-Null
            $needsReboot = $true
            Warn 'Enabled Windows Hypervisor Platform for the emulator -- restart the PC before using the emulator.'
        } else { Ok 'Windows Hypervisor Platform enabled' }

        $avdName = 'Guidy_Phone_API_36'
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $avds = & $AvdManager list avd -c 2>$null
        $ErrorActionPreference = $old
        if ($avds -notcontains $avdName) {
            $null = Run $AvdManager @('create', 'avd', '-n', $avdName, '-k', $SysImage, '-d', 'pixel_7') -StdIn 'no'
            Ok "created emulator '$avdName'"
        } else { Ok "emulator '$avdName' already exists" }
    }

    # ---------------------------------------------------------------- Backend
    Step 'Backend Python packages'
    Push-Location $Backend
    try {
        $null = Run $Python @('-m', 'pip', 'install', '--upgrade', 'pip')
        $null = Run $Python @('-m', 'pip', 'install', '-r', 'requirements.txt', 'pytest')
        $null = Run $Python @('-c', 'import fastapi, uvicorn, slowapi, requests, pydantic; print(''imports ok'')')
    } finally { Pop-Location }
    Ok 'backend dependencies installed'

    Step 'Backend smoke test (start server, call /api/health)'
    $proc = Start-Process -FilePath $Python -ArgumentList 'main.py' -WorkingDirectory $Backend `
        -PassThru -NoNewWindow `
        -RedirectStandardOutput (Join-Path $env:TEMP 'guidy_backend_out.txt') `
        -RedirectStandardError  (Join-Path $env:TEMP 'guidy_backend_err.txt')
    $healthy = $false
    for ($i = 0; $i -lt 90 -and -not $proc.HasExited; $i++) {
        Start-Sleep -Seconds 2
        try {
            $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/health' -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -eq 200) { $healthy = $true; Write-Host "    $($r.Content)"; break }
        } catch { }
    }
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    if ($healthy) { Ok 'backend answered on http://127.0.0.1:8000/api/health' }
    else {
        Get-Content (Join-Path $env:TEMP 'guidy_backend_err.txt') -Tail 30 -ErrorAction SilentlyContinue | Out-Host
        Warn 'Backend did not answer /api/health within 3 minutes -- see the error output above.'
    }

    # ---------------------------------------------------------- flutter doctor
    Step 'flutter doctor'
    $null = Run $FlutterExe @('doctor', '-v') -AllowFail

    # ------------------------------------------------------------ Test build
    if (-not $SkipBuild) {
        Step 'Test build: debug APK (first build downloads Gradle + NDK, 5-15 min)'
        Push-Location $App
        try { $null = Run $FlutterExe @('build', 'apk', '--debug') }
        finally { Pop-Location }
        Ok 'debug APK built: guidy-app-main\build\app\outputs\flutter-apk\app-debug.apk'
    }

    Write-Host ''
    Write-Host '=================================================' -ForegroundColor Green
    Write-Host '  Setup finished' -ForegroundColor Green
    Write-Host '=================================================' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next (open a NEW terminal so PATH changes apply):'
    Write-Host "  1. $(Join-Path $Backend 'run_backend.bat')   start the backend"
    Write-Host "  2. $(Join-Path $App 'install_on_phone.bat')   phone over USB"
    Write-Host '     or  guidy-app-main\run_app.bat                 phone on the same Wi-Fi'
    Write-Host '     or  guidy-app-main\run_app.bat -Emulator       emulator'
    if ($warnings.Count -gt 0) {
        Write-Host ''
        Write-Host 'Needs your attention:' -ForegroundColor Yellow
        foreach ($w in $warnings) { Write-Host "  - $w" -ForegroundColor Yellow }
    }
    if ($needsReboot) { Write-Host ''; Write-Host 'Restart the PC before starting the emulator.' -ForegroundColor Yellow }
}
catch {
    Write-Host ''
    Write-Host "SETUP STOPPED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Fix the problem above and run setup_windows.bat again -- finished steps are skipped.' -ForegroundColor Red
}
finally {
    Stop-Transcript | Out-Null
    Write-Host ''
    Write-Host "Log saved to $LogFile"
    Read-Host 'Press Enter to close this window'
}
