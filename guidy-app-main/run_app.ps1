# Guidy app launcher.
#
# WHY THIS EXISTS
#
# Four values the app needs at RUNTIME come from --dart-define, not from
# secrets.properties:
#
#   MAPS_API_KEY_ANDROID   places_service.dart (destination search)
#   ANDROID_CERT_SHA1      places_service.dart (identifies this build to
#                          Google when the key has an "Android apps"
#                          restriction)
#   API_BASE_URL           api_service.dart
#   ADMOB_*                ad_service.dart
#
# android/app/build.gradle.kts reads secrets.properties and injects some of
# these as MANIFEST placeholders, which covers the native Maps SDK and the
# AdMob app id. It does NOT reach Dart. `String.fromEnvironment` is
# resolved by the Dart compiler at build time and can only be fed by
# --dart-define, so a plain `flutter run` leaves all four empty -- and an
# empty Places key fails silently: you type in the destination field and
# simply get no suggestions, with no error anywhere.
#
# This script reads the same secrets.properties and passes them through.
#
# USAGE
#
#   .\run_app.ps1                 physical phone on the same Wi-Fi
#   .\run_app.ps1 -Emulator       Android emulator on this machine
#   .\run_app.ps1 -RealAds        serve real ad units instead of test ones
#   .\run_app.ps1 -Release        release build
#   .\run_app.ps1 -Device <id>    pick a specific device

param(
    [switch]$Emulator,
    [switch]$RealAds,
    [switch]$Release,
    [string]$Device
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$secretsPath = Join-Path $PSScriptRoot "secrets.properties"
if (-not (Test-Path $secretsPath)) {
    Write-Host "secrets.properties not found next to this script." -ForegroundColor Red
    Write-Host "Copy secrets.properties.example to secrets.properties and fill it in."
    exit 1
}

# Parse the .properties file: KEY=VALUE, ignoring blanks and # comments.
# Values are taken verbatim after the FIRST '=' so a URL's own characters
# survive intact.
$secrets = @{}
foreach ($line in Get-Content $secretsPath) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
    $i = $trimmed.IndexOf("=")
    if ($i -lt 1) { continue }
    $secrets[$trimmed.Substring(0, $i).Trim()] = $trimmed.Substring($i + 1).Trim()
}

function Secret([string]$key) {
    if ($secrets.ContainsKey($key)) { return $secrets[$key] }
    return ""
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Guidy App" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# --- Backend URL --------------------------------------------------------
# An Android emulator is a virtual machine: its own 127.0.0.1 is itself,
# not this PC. 10.0.2.2 is the emulator's fixed alias for the host's
# loopback, so it works without knowing the LAN IP and without the
# firewall rule a physical phone needs.
$apiBaseUrl = Secret "API_BASE_URL"
if ($Emulator) {
    $apiBaseUrl = "http://10.0.2.2:8000/api"
    Write-Host "Emulator mode: backend at $apiBaseUrl" -ForegroundColor Green
} elseif ($apiBaseUrl -eq "") {
    Write-Host "API_BASE_URL is not set in secrets.properties." -ForegroundColor Red
    Write-Host "Run run_backend.bat once -- it prints the exact line to paste."
    exit 1
} else {
    Write-Host "Backend at $apiBaseUrl" -ForegroundColor Green
}

$defines = @(
    "--dart-define=API_BASE_URL=$apiBaseUrl"
)

# --- Places ------------------------------------------------------------
$mapsKey = Secret "MAPS_API_KEY_ANDROID"
$certSha1 = Secret "ANDROID_CERT_SHA1"

if ($mapsKey -eq "") {
    Write-Host "WARNING: MAPS_API_KEY_ANDROID is empty. Destination search will" -ForegroundColor Yellow
    Write-Host "         return no results, silently." -ForegroundColor Yellow
} else {
    $defines += "--dart-define=MAPS_API_KEY_ANDROID=$mapsKey"
}

if ($certSha1 -eq "") {
    Write-Host "WARNING: ANDROID_CERT_SHA1 is empty. If the Maps key has an" -ForegroundColor Yellow
    Write-Host "         'Android apps' restriction, Google will reject every" -ForegroundColor Yellow
    Write-Host "         Places call from this build." -ForegroundColor Yellow
} else {
    $defines += "--dart-define=ANDROID_CERT_SHA1=$certSha1"
}

$iosKey = Secret "MAPS_API_KEY_IOS"
if ($iosKey -ne "") { $defines += "--dart-define=MAPS_API_KEY_IOS=$iosKey" }

# --- Ads ---------------------------------------------------------------
# Test ad units by default, ON PURPOSE. AdService falls back to Google's
# public test IDs when these aren't defined, and a development build that
# serves REAL ads is how an AdMob account gets flagged for invalid traffic:
# every hot reload is an impression, and one curious tap on your own live
# ad is a policy violation. Pass -RealAds only when deliberately checking
# that the real units are wired up, and don't click them.
if ($RealAds) {
    Write-Host "REAL ad units -- do not click the ads." -ForegroundColor Yellow
    foreach ($key in @(
        "ADMOB_BANNER_AD_UNIT_ID_ANDROID",
        "ADMOB_BANNER_AD_UNIT_ID_IOS",
        "ADMOB_APP_OPEN_AD_UNIT_ID_ANDROID",
        "ADMOB_APP_OPEN_AD_UNIT_ID_IOS",
        "ADMOB_NATIVE_AD_UNIT_ID_ANDROID",
        "ADMOB_NATIVE_AD_UNIT_ID_IOS",
        "ADMOB_INTERSTITIAL_AD_UNIT_ID_ANDROID",
        "ADMOB_INTERSTITIAL_AD_UNIT_ID_IOS",
        "ADMOB_REWARDED_AD_UNIT_ID_ANDROID",
        "ADMOB_REWARDED_AD_UNIT_ID_IOS"
    )) {
        $value = Secret $key
        if ($value -ne "") { $defines += "--dart-define=$key=$value" }
    }
    # AdService ignores the unit IDs above without this (see ad_service.dart).
    $defines += "--dart-define=GUIDY_REAL_ADS=true"
} else {
    Write-Host "Test ad units (pass -RealAds to override)." -ForegroundColor Gray
}

# --- Build the command --------------------------------------------------
$flutterArgs = @("run") + $defines
if ($Release) { $flutterArgs += "--release" }
if ($Device -ne "") { $flutterArgs += @("-d", $Device) }

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Starting... (press q in this window to stop)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

& flutter @flutterArgs
