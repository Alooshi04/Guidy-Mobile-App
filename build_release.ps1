# Guidy release build: signed APK + App Bundle with every runtime value
# baked in, and optionally installed on a USB-connected Android phone.
#
#   .\build_release.ps1                      Play Store build with Google's TEST
#                                            ad units (the default for now: safe
#                                            to tap, earns nothing)
#   .\build_release.ps1 -RealAds             Play Store build with the real
#                                            AdMob units from secrets.properties
#   .\build_release.ps1 -Install             also install it on a USB phone
#   .\build_release.ps1 -NoBump              do not raise the build number first
#
# Every run raises the build number in pubspec.yaml by 1 (Google Play accepts
# each build number only once, across all tracks). Commit pubspec.yaml after
# a build you upload, so the next one starts from the right number. The
# version name (1.0.11) stays manual.
#
# Why a separate script: release values reach Dart only through
# --dart-define (see run_app.ps1). `flutter build` without them ships a
# build with no Places key (search silently empty), test ads, and the
# compiled-in default backend. The GitHub release workflow can't run on the
# private repo (Actions billing), so this is the release path.
#
# Output (and a log) goes to build\release\.

param(
    [switch]$RealAds,
    # Explicit opt-in to Google's test ad units.
    [switch]$TestAds,
    # Store build with no ads at all (no consent flow, no ads SDK start, no
    # advertising ID permission). This is the default; the switch is kept for
    # older callers.
    [switch]$NoAds,
    [switch]$Install,
    # Skip the automatic build number bump (build_both.bat bumps once itself).
    [switch]$NoBump
)
if ($RealAds -and $TestAds) { throw "Pass only one of -RealAds / -TestAds." }
if (-not $RealAds -and -not $TestAds) { $NoAds = [switch]$true }
if ($NoAds -and ($RealAds -or $TestAds)) { throw "-NoAds cannot be combined with -RealAds / -TestAds." }

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# Ensure PUB_CACHE resides on the same drive letter as the project to prevent
# Android/Kotlin Gradle plugin "this and base files have different roots" failure on Windows.
$projDrive = (Get-Item $PSScriptRoot).PSDrive.Name
if ($projDrive -and $projDrive -ne "C" -and (-not $env:PUB_CACHE -or -not $env:PUB_CACHE.StartsWith($projDrive))) {
    $env:PUB_CACHE = "$($projDrive):\pub_cache"
}

$flutter = "flutter"
if (Test-Path "C:\Users\Joey\FLUTTE~1\flutter\bin\flutter.bat") {
    $flutter = "C:\Users\Joey\FLUTTE~1\flutter\bin\flutter.bat"
}

$outDir = Join-Path $PSScriptRoot "build\release"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$log = Join-Path $outDir "build_release_log.txt"
Start-Transcript -Path $log -Force | Out-Null

function Fail([string]$msg) {
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# --- Build number ---------------------------------------------------------
# Google Play accepts each build number (versionCode) only once, across all
# tracks, so every build raises it by 1 in pubspec.yaml unless -NoBump is given.
if (-not $NoBump) {
    $pubspec = Join-Path $PSScriptRoot "pubspec.yaml"
    $text = [IO.File]::ReadAllText($pubspec)
    $m = [regex]::Match($text, '(?m)^version: (\S+)\+(\d+)')
    if (-not $m.Success) { Fail "Could not find 'version: x.y.z+N' in pubspec.yaml." }
    $old = [int]$m.Groups[2].Value
    $new = $old + 1
    $text = $text.Substring(0, $m.Index) + "version: $($m.Groups[1].Value)+$new" + $text.Substring($m.Index + $m.Length)
    [IO.File]::WriteAllText($pubspec, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Build number $old -> $new (version $($m.Groups[1].Value)+$new). Commit pubspec.yaml after uploading."
}

# --- Signing -------------------------------------------------------------
if (-not (Test-Path "android\key.properties") -or -not (Test-Path "android\app\guidy-release-key.jks")) {
    Fail "Release signing files are missing. Run restore_signing_files.bat first."
}

# --- secrets.properties -> dart-defines ---------------------------------
if (-not (Test-Path "secrets.properties")) { Fail "secrets.properties not found." }
$secrets = @{}
foreach ($line in Get-Content "secrets.properties") {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $i = $t.IndexOf("=")
    if ($i -lt 1) { continue }
    $secrets[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim()
}
function Secret([string]$k) { if ($secrets.ContainsKey($k)) { $secrets[$k] } else { "" } }

$api = Secret "API_BASE_URL"
if (-not $api.StartsWith("https://")) {
    Fail "API_BASE_URL in secrets.properties must be the public https:// server for a release build (it is '$api')."
}
$maps = Secret "MAPS_API_KEY_ANDROID"
if ($maps -eq "") { Fail "MAPS_API_KEY_ANDROID is empty." }

$defines = @(
    "--dart-define=API_BASE_URL=$api",
    "--dart-define=MAPS_API_KEY_ANDROID=$maps"
    # ANDROID_CERT_SHA1 deliberately not passed: that entry is this PC's
    # DEBUG fingerprint. Release builds send the release fingerprint
    # built into places_service.dart.
)
$iosMaps = Secret "MAPS_API_KEY_IOS"
if ($iosMaps -ne "") { $defines += "--dart-define=MAPS_API_KEY_IOS=$iosMaps" }

if ($NoAds) {
    $defines += "--dart-define=GUIDY_NO_ADS=true"
    Write-Host "NO ads in this build." -ForegroundColor Yellow
} elseif ($TestAds) {
    Write-Host "TEST ad units (safe to tap)." -ForegroundColor Yellow
} else {
    foreach ($k in @("ADMOB_BANNER_AD_UNIT_ID_ANDROID", "ADMOB_APP_OPEN_AD_UNIT_ID_ANDROID")) {
        $v = Secret $k
        if ($v -eq "" -or $v.StartsWith("ca-app-pub-3940256099942544")) {
            Fail "$k is missing or still Google's test unit; a Play Store build needs the real one."
        }
        $defines += "--dart-define=$k=$v"
    }
    # Optional: without a native unit the in-content ad cards stay hidden.
    $native = Secret "ADMOB_NATIVE_AD_UNIT_ID_ANDROID"
    if ($native -ne "" -and -not $native.StartsWith("ca-app-pub-3940256099942544")) {
        $defines += "--dart-define=ADMOB_NATIVE_AD_UNIT_ID_ANDROID=$native"
    } else {
        Write-Host "No ADMOB_NATIVE_AD_UNIT_ID_ANDROID: native ad cards hidden in this build." -ForegroundColor Yellow
    }
    # Optional: without these units the trip-end interstitial and the "hide the
    # banner" rewarded option are off in this build.
    foreach ($k in @("ADMOB_INTERSTITIAL_AD_UNIT_ID_ANDROID", "ADMOB_REWARDED_AD_UNIT_ID_ANDROID")) {
        $v = Secret $k
        if ($v -ne "" -and -not $v.StartsWith("ca-app-pub-3940256099942544")) {
            $defines += "--dart-define=$k=$v"
        } else {
            Write-Host "No ${k}: that ad format is off in this build." -ForegroundColor Yellow
        }
    }
    # AdService ignores the unit IDs above without this (see ad_service.dart).
    $defines += "--dart-define=GUIDY_REAL_ADS=true"
    Write-Host "REAL ad units. Don't tap ads on your own phone." -ForegroundColor Yellow
}

Write-Host "Backend: $api"
Write-Host ""

# --- Build ---------------------------------------------------------------
& $flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get failed." }

# AGP 9.0+ built-in Kotlin compatibility for transitive plugins in pub cache
if ($env:PUB_CACHE -and (Test-Path $env:PUB_CACHE)) {
    Get-ChildItem -Path (Join-Path $env:PUB_CACHE "hosted\pub.dev") -Recurse -Filter "build.gradle.kts" -ErrorAction SilentlyContinue | ForEach-Object {
        $c = [System.IO.File]::ReadAllText($_.FullName)
        if ($c.Contains('id("kotlin-android")')) {
            [System.IO.File]::WriteAllText($_.FullName, $c.Replace('id("kotlin-android")', '// id("kotlin-android")'))
        }
    }
}

& $flutter build apk --release @defines
if ($LASTEXITCODE -ne 0) { Fail "APK build failed." }
$suffix = if ($NoAds) { "noads" } elseif ($TestAds) { "testads" } else { "release" }
& $flutter build appbundle --release @defines
if ($LASTEXITCODE -ne 0) { Fail "App Bundle build failed." }
Copy-Item "build\app\outputs\bundle\release\app-release.aab" (Join-Path $outDir "guidy-$suffix.aab") -Force
$apk = Join-Path $outDir "guidy-$suffix.apk"
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $apk -Force
Write-Host ""
Write-Host "Built: $apk" -ForegroundColor Green

# --- Install -------------------------------------------------------------
if ($Install) {
    $adb = "adb"
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        $adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
        if (-not (Test-Path $adb)) { Fail "adb not found." }
    }
    $devices = & $adb devices | Select-String "\tdevice$"
    if (-not $devices) { Fail "No phone found. Plug it in with USB debugging on and accept the prompt on the phone." }
    # A debug build (different signature) can't be upgraded in place, and a
    # stale saved backend URL survives upgrades -- start clean.
    & $adb uninstall com.guidy.guidy_app | Out-Null
    & $adb install $apk
    if ($LASTEXITCODE -ne 0) { Fail "adb install failed." }
    & $adb shell monkey -p com.guidy.guidy_app -c android.intent.category.LAUNCHER 1 | Out-Null
    Write-Host "Installed and launched on the phone." -ForegroundColor Green
}

Stop-Transcript | Out-Null
