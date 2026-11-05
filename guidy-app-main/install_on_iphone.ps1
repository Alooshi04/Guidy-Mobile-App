<#
.SYNOPSIS
  Install the latest Guidy iOS build on an iPhone from Windows.

.DESCRIPTION
  Windows cannot build or sign iOS apps, and Apple only lets a phone run
  an app signed for it. So this script:

    1. downloads the latest UNSIGNED Guidy IPA that CI builds on every push
       to the public guidy-app-ci-mirror repo (release "ios-latest"),
    2. checks the pieces Windows needs to talk to an iPhone,
    3. hands the IPA to Sideloadly, which signs it with YOUR Apple ID and
       installs it over USB/Wi-Fi.

  A free Apple ID works; apps signed that way expire after 7 days (re-run
  this script to refresh) and at most 3 sideloaded apps can be active.
  With a paid Apple Developer account, use TestFlight instead.

  If you already have an IPA signed for your phone (ad-hoc/development),
  pass -SignedIpa and the script installs it directly with ideviceinstaller
  (libimobiledevice) when that tool is on PATH.

.PARAMETER Ipa
  Use this local IPA instead of downloading.
.PARAMETER SignedIpa
  The IPA is already signed for this phone; install it with ideviceinstaller.
.PARAMETER NoPatch
  Don't rewrite the backend address inside the IPA (see Set-IpaBackendUrl).
#>
[CmdletBinding()]
param(
    [string]$Ipa,
    [switch]$SignedIpa,
    [switch]$NoPatch
)

$ReleaseUrl = 'https://github.com/youssefezat/guidy-app-ci-mirror/releases/download/ios-latest/Guidy-unsigned.ipa'
$ReleasePage = 'https://github.com/youssefezat/guidy-app-ci-mirror/releases/tag/ios-latest'
# The address a build without API_BASE_URL talks to first
# (lib/services/api_service.dart, defaultCandidates).
$DefaultBackendUrl = 'http://192.168.1.9:8000/api'

function Test-GuidyIpa {
    <# True when Path is a zip containing Payload/Runner.app/. #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
    } catch {
        return $false   # not a zip at all (e.g. an HTML error page)
    }
    try {
        return [bool]($zip.Entries | Where-Object { $_.FullName -like 'Payload/Runner.app/*' } |
            Select-Object -First 1)
    } finally {
        $zip.Dispose()
    }
}

function Find-Sideloadly {
    <# First existing path among Candidates, or $null. #>
    param([string[]]$Candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Sideloadly\sideloadly.exe'),
        (Join-Path $env:ProgramFiles 'Sideloadly\sideloadly.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Sideloadly\sideloadly.exe')
    ))
    foreach ($c in $Candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c }
    }
    return $null
}

function Get-BackendHostWarning {
    <# A warning string when BaseUrl points at a LAN IP this PC does not own. #>
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string[]]$LocalAddresses
    )
    $hostPart = ([Uri]$BaseUrl).Host
    $ip = $null
    if (-not [System.Net.IPAddress]::TryParse($hostPart, [ref]$ip)) { return $null }
    if ($LocalAddresses -contains $hostPart) { return $null }
    return ("The app looks for the Guidy backend at $hostPart, but this PC's " +
            "addresses are: $($LocalAddresses -join ', '). Routes will fail on the " +
            "iPhone unless run_backend.bat runs on the machine at $hostPart, or the " +
            "IPA is built with an API_BASE_URL secret.")
}

function Invoke-RangeDownload {
    <#
      One attempt at downloading Uri into Path with Windows' own HTTP stack
      (honours the system proxy, like a browser). If Path already has bytes,
      asks the server for the rest (HTTP Range) and appends. Throws
      FileNotFoundException for HTTP 4xx/5xx, anything else for network
      trouble, and "incomplete" when the connection ends early.
    #>
    param([Parameter(Mandatory)][string]$Uri, [Parameter(Mandatory)][string]$Path)
    $have = 0L
    if (Test-Path -LiteralPath $Path) { $have = (Get-Item -LiteralPath $Path).Length }
    $req = [System.Net.HttpWebRequest]::Create($Uri)
    $req.UserAgent = 'guidy-iphone-installer'
    $req.Timeout = 30000
    $req.ReadWriteTimeout = 60000
    $req.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $req.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
    if ($have -gt 0) { $req.AddRange([long]$have) }
    try {
        $resp = $req.GetResponse()
    } catch [System.Net.WebException] {
        $r = $_.Exception.Response
        if ($r) {
            $code = [int]$r.StatusCode
            $r.Dispose()
            if ($code -eq 416 -and $have -gt 0) { return }   # nothing left to fetch
            throw [System.IO.FileNotFoundException]::new("server returned HTTP $code for $Uri")
        }
        throw
    }
    try {
        $status = [int]$resp.StatusCode
        if ($status -eq 206) {
            $mode = [System.IO.FileMode]::Append
            $total = [long](($resp.Headers['Content-Range'] -split '/')[-1])
        } else {
            $mode = [System.IO.FileMode]::Create      # server ignored Range: start over
            $have = 0L
            $total = $resp.ContentLength
        }
        $fs = [System.IO.File]::Open($Path, $mode, [System.IO.FileAccess]::Write)
        try {
            $in = $resp.GetResponseStream()
            $buf = New-Object byte[] 262144
            $done = $have
            $nextReport = 0
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $fs.Write($buf, 0, $n)
                $done += $n
                if ($total -gt 0) {
                    $pct = [int](100 * $done / $total)
                    if ($pct -ge $nextReport) {
                        Write-Host ("    {0,3}%  {1:N1} / {2:N1} MB" -f $pct, ($done / 1MB), ($total / 1MB))
                        $nextReport = $pct - ($pct % 10) + 10
                    }
                }
            }
        } finally { $fs.Dispose() }
        if ($total -gt 0 -and (Get-Item -LiteralPath $Path).Length -lt $total) {
            throw 'connection ended early (incomplete)'
        }
    } finally { $resp.Dispose() }
}

function Save-Download {
    <#
      Downloads Uri to OutFile, surviving dropped connections (phone
      hotspots, flaky Wi-Fi): every retry resumes where the last one
      stopped, and OutFile only appears once the download is complete.
      Attempts alternate between Windows' own HTTP stack (uses the system
      proxy, like a browser) and curl.exe (built into Windows 10 1803+),
      because some networks only let one of them through.
    #>
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile,
        [int]$Attempts = 8,
        [int]$DelaySeconds = 5,
        [string[]]$Methods = @('windows', 'curl'),
        [string]$CurlPath = $(if ($c = Get-Command curl.exe -ErrorAction SilentlyContinue) { $c.Source })
    )
    $Methods = @($Methods | Where-Object { $_ -ne 'curl' -or $CurlPath })
    if (-not $Methods) { $Methods = @('windows') }
    $part = "$OutFile.part"
    Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue   # never resume an older build
    for ($i = 1; $i -le $Attempts; $i++) {
        $method = $Methods[($i - 1) % $Methods.Count]
        try {
            if ($method -eq 'curl') {
                & $CurlPath -L --fail --show-error --progress-bar --connect-timeout 20 -C - -o $part $Uri
                if ($LASTEXITCODE -eq 22) { throw [System.IO.FileNotFoundException]::new("server returned an HTTP error for $Uri") }
                if ($LASTEXITCODE -ne 0) { throw "connection problem (curl exit code $LASTEXITCODE)" }
            } else {
                Invoke-RangeDownload -Uri $Uri -Path $part
            }
            Move-Item -LiteralPath $part -Destination $OutFile -Force
            return
        } catch [System.IO.FileNotFoundException] {
            throw
        } catch {
            $msg = $_.Exception.Message
            if ($_.Exception.InnerException) { $msg = $_.Exception.InnerException.Message }
            if ($i -ge $Attempts) { throw "gave up after $Attempts tries: $msg" }
            $have = if (Test-Path -LiteralPath $part) { '{0:N1} MB so far' -f ((Get-Item -LiteralPath $part).Length / 1MB) } else { 'nothing yet' }
            Write-Host "  [$method] interrupted: $msg ($have) - retry $($i + 1) of $Attempts in ${DelaySeconds}s..." -ForegroundColor Yellow
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Get-PhoneFacingAddress {
    <#
      This PC's address on the network that has internet (the adapter with
      a default gateway) - on an iPhone hotspot that is 172.20.10.x, which
      the iPhone itself can reach. Returns @{ IP; Alias; Category } or $null.
    #>
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and
                       $_.InterfaceAlias -notmatch 'vEthernet|Virtual|WSL|VPN' } |
        Select-Object -First 1
    if (-not $cfg) { return $null }
    $connProfile = Get-NetConnectionProfile -InterfaceAlias $cfg.InterfaceAlias -ErrorAction SilentlyContinue |
        Select-Object -First 1
    return [pscustomobject]@{
        IP       = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
        Alias    = $cfg.InterfaceAlias
        Category = if ($connProfile) { [string]$connProfile.NetworkCategory } else { '' }
    }
}

function Set-IpaBackendUrl {
    <#
      Copies SourceIpa to DestIpa with every occurrence of OldUrl in the
      Flutter AOT binary (App.framework/App) replaced by NewUrl.

      API_BASE_URL is compiled into the app, and the CI build carries the
      old PC's address. A Dart AOT snapshot stores string literals as plain
      bytes, so an address of the SAME LENGTH can be swapped in place
      without rebuilding (e.g. 192.168.1.9 -> 172.20.10.2). The IPA is
      unsigned; Sideloadly signs the patched binary. Returns the number of
      replacements (0 = the build doesn't contain OldUrl; DestIpa is then
      not created).
    #>
    param(
        [Parameter(Mandatory)][string]$SourceIpa,
        [Parameter(Mandatory)][string]$DestIpa,
        [Parameter(Mandatory)][string]$OldUrl,
        [Parameter(Mandatory)][string]$NewUrl
    )
    if ($OldUrl.Length -ne $NewUrl.Length) {
        throw "Can't patch: '$NewUrl' is not the same length as '$OldUrl'."
    }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $latin1 = [System.Text.Encoding]::GetEncoding(28591)   # 1 byte <-> 1 char
    $tmp = "$DestIpa.tmp"
    Copy-Item -LiteralPath $SourceIpa -Destination $tmp -Force
    $count = 0
    $zip = [System.IO.Compression.ZipFile]::Open($tmp, 'Update')
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -like 'Payload/*.app/Frameworks/App.framework/App' } |
            Select-Object -First 1
        if (-not $entry) { throw 'App.framework/App not found in the IPA.' }
        $buf = New-Object System.IO.MemoryStream
        $in = $entry.Open(); try { $in.CopyTo($buf) } finally { $in.Dispose() }
        $bytes = $buf.ToArray()
        $text = $latin1.GetString($bytes)
        $new = $latin1.GetBytes($NewUrl)
        $i = $text.IndexOf($OldUrl, [System.StringComparison]::Ordinal)
        while ($i -ge 0) {
            [Array]::Copy($new, 0, $bytes, $i, $new.Length)
            $count++
            $i = $text.IndexOf($OldUrl, $i + $OldUrl.Length, [System.StringComparison]::Ordinal)
        }
        if ($count -gt 0) {
            $name = $entry.FullName
            $attrs = $entry.ExternalAttributes
            $entry.Delete()
            $replacement = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
            $replacement.ExternalAttributes = $attrs
            $out = $replacement.Open(); try { $out.Write($bytes, 0, $bytes.Length) } finally { $out.Dispose() }
        }
    } finally {
        $zip.Dispose()
    }
    if ($count -gt 0) { Move-Item -LiteralPath $tmp -Destination $DestIpa -Force }
    else { Remove-Item -LiteralPath $tmp -Force }
    return $count
}

function Test-FirewallAllows {
    <# True when a rule Profile string ('Any', 'Domain, Private', ...) covers a network category. #>
    param([string]$RuleProfile, [string]$Category)
    if (-not $RuleProfile) { return $false }
    if ($RuleProfile -eq 'Any') { return $true }
    $wanted = switch ($Category) { 'DomainAuthenticated' { 'Domain' } default { $Category } }
    return [bool](($RuleProfile -split ',\s*') -contains $wanted)
}

function Get-SameLengthBackendUrl {
    <#
      The backend URL for this PC's IP that has exactly OldUrl's length, so
      it can be patched into the app. The address length is fixed by the
      network, so the PORT absorbs the difference: an 11-char IP keeps
      :8000, a 13-char IP gets a 2-digit port (:80), a 12-char IP a 3-digit
      one (:800) and so on. Windows then forwards that port to the backend
      on 8000. Returns @{ Url; Port } or $null when no port length fits.
    #>
    param(
        [Parameter(Mandatory)][string]$Ip,
        [Parameter(Mandatory)][string]$OldUrl,
        [int[]]$BusyPorts = @()
    )
    $digits = $OldUrl.Length - ("http://${Ip}:/api").Length
    if ($digits -lt 1 -or $digits -gt 5) { return $null }
    $preferred = switch ($digits) {
        1 { @(8) + (1..9) }
        2 { @(80, 88) + (81..99) }
        3 { @(800, 880, 808) + (801..999) }
        4 { @(8000, 8080, 8888) + (8001..9999) }
        5 { @(18000, 28000) + (18001..18999) }
    }
    foreach ($port in $preferred) {
        if ($port -gt 65535 -or "$port".Length -ne $digits) { continue }
        if ($port -ne 8000 -and $BusyPorts -contains $port) { continue }
        return [pscustomobject]@{ Url = "http://${Ip}:$port/api"; Port = $port }
    }
    return $null
}

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }

function Main {
    $ErrorActionPreference = 'Stop'
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '        GUIDY - iPhone installer (Windows)' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan

    # --- 1. Windows <-> iPhone plumbing -----------------------------------
    Write-Step 'Checking Apple device support'
    $amds = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Apple Mobile Device*' }
    if (-not $amds) {
        Write-Warning ('Apple Mobile Device Support is not installed. Install iTunes and ' +
            'iCloud from apple.com (NOT the Microsoft Store versions) - Sideloadly needs them.')
    } elseif ($amds.Status -ne 'Running') {
        Write-Warning "The '$($amds.DisplayName)' service is $($amds.Status). Start it (or reboot) before installing."
    } else {
        Write-Host "  ok  $($amds.DisplayName) is running"
    }

    $phone = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'Apple iPhone|Apple Mobile Device USB' } |
        Select-Object -First 1
    if ($phone) {
        Write-Host "  ok  iPhone connected: $($phone.FriendlyName)"
    } else {
        Write-Warning ('No iPhone found over USB. Plug it in, unlock it and tap "Trust This Computer". ' +
            '(Sideloadly can also use Wi-Fi once the phone has been paired over USB.)')
    }

    # --- 2. Get the IPA ---------------------------------------------------
    if ($Ipa) {
        $ipaPath = (Resolve-Path -LiteralPath $Ipa).Path
        Write-Step "Using $ipaPath"
    } else {
        $dir = Join-Path $env:LOCALAPPDATA 'Guidy'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $ipaPath = Join-Path $dir 'Guidy-unsigned.ipa'
        Write-Step "Downloading the latest iOS build`n    $ReleaseUrl"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'   # the iwr progress bar makes it ~10x slower
        try {
            Save-Download -Uri $ReleaseUrl -OutFile $ipaPath
        } catch [System.IO.FileNotFoundException] {
            throw "No iOS build found at $ReleaseUrl.`nCheck $ReleasePage - CI may not have published one yet."
        } catch {
            if (Test-GuidyIpa -Path $ipaPath) {
                Write-Warning ("Download failed ($($_.Exception.Message)). Using the IPA downloaded " +
                    "earlier, from $((Get-Item -LiteralPath $ipaPath).LastWriteTime).")
            } else {
                throw ("Download failed: $($_.Exception.Message)`nYour internet connection dropped. " +
                    "Check it and run this again, or download the IPA in a browser from $ReleasePage " +
                    "and run: install_on_iphone.bat -Ipa <path to the .ipa>")
            }
        }
    }
    if (-not (Test-GuidyIpa -Path $ipaPath)) {
        throw "$ipaPath is not a valid Guidy IPA (no Payload/Runner.app inside)."
    }
    $sizeMb = [math]::Round((Get-Item -LiteralPath $ipaPath).Length / 1MB, 1)
    Write-Host "  ok  IPA verified ($sizeMb MB)"

    # --- 3. Point the build at this PC's backend -------------------------
    $net = Get-PhoneFacingAddress
    if (-not $net) {
        Write-Warning 'Could not find this PC''s network address; the app will look for the backend at its built-in address.'
    } elseif ($SignedIpa -or $NoPatch) {
        $warn = Get-BackendHostWarning -BaseUrl $DefaultBackendUrl -LocalAddresses @($net.IP)
        if ($warn) { Write-Warning $warn }
    } else {
        # Ports already forwarded to the backend by an earlier run count as free.
        $ours = @(@(netsh interface portproxy show v4tov4) -match '^\s*0\.0\.0\.0\s+\d+\s+127\.0\.0\.1\s+8000\s*$' |
            ForEach-Object { [int](($_.Trim() -split '\s+')[1]) })
        $busy = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            ForEach-Object LocalPort | Sort-Object -Unique | Where-Object { $ours -notcontains $_ })
        $target = Get-SameLengthBackendUrl -Ip $net.IP -OldUrl $DefaultBackendUrl -BusyPorts $busy
        Write-Step "Backend address for the iPhone (network '$($net.Alias)', $($net.Category))"
        if (-not $target) {
            Write-Warning ("This PC's address ($($net.IP)) can't be fitted into the app's built-in " +
                "address. Routes will fail on the iPhone until the app is rebuilt with API_BASE_URL.")
        } else {
            Write-Host "  $($target.Url)"
            if ($target.Url -ne $DefaultBackendUrl) {
                $patched = Join-Path (Split-Path -LiteralPath $ipaPath) ("Guidy-for-{0}-{1}.ipa" -f $net.IP, $target.Port)
                $n = Set-IpaBackendUrl -SourceIpa $ipaPath -DestIpa $patched -OldUrl $DefaultBackendUrl -NewUrl $target.Url
                if ($n -gt 0) {
                    $ipaPath = $patched
                    Write-Host "  ok  patched the app to use it -> $patched"
                } else {
                    Write-Warning "This build doesn't contain $DefaultBackendUrl, so it was left unchanged."
                }
            }

            # The iPhone connects IN to this PC, so Windows Firewall must allow
            # it on this network (LocalSubnet only), and a port other than 8000
            # must be forwarded to the backend. Needs Administrator, once.
            $ports = @(8000)
            if ($target.Port -ne 8000) { $ports += $target.Port }
            $ruleName = { param($port) if ($port -eq 8000) { 'Guidy Backend' } else { "Guidy Backend (port $port)" } }
            $needFix = $false
            foreach ($port in $ports) {
                $rule = Get-NetFirewallRule -DisplayName (& $ruleName $port) -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not ($rule -and (Test-FirewallAllows -RuleProfile ([string]$rule.Profile) -Category $net.Category))) { $needFix = $true }
            }
            if ($target.Port -ne 8000 -and $ours -notcontains $target.Port) { $needFix = $true }

            if ($needFix) {
                $what = "allow port $($ports -join ' and ') from this local network"
                if ($target.Port -ne 8000) { $what += " and forward port $($target.Port) to the backend (8000)" }
                Write-Host "  Asking for Administrator rights to $what..." -ForegroundColor Yellow
                $fix = @()
                foreach ($port in $ports) {
                    $name = & $ruleName $port
                    $fix += "Remove-NetFirewallRule -DisplayName '$name' -ErrorAction SilentlyContinue"
                    $fix += "New-NetFirewallRule -DisplayName '$name' -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow -Profile Any -RemoteAddress LocalSubnet | Out-Null"
                }
                if ($target.Port -ne 8000) {
                    $fix += 'Set-Service iphlpsvc -StartupType Automatic'
                    $fix += 'Start-Service iphlpsvc'
                    $fix += "netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=$($target.Port) connectaddress=127.0.0.1 connectport=8000 | Out-Null"
                }
                $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($fix -join '; '))
                try {
                    Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList @('-NoProfile', '-EncodedCommand', $encoded)
                    Write-Host '  ok  network access configured'
                } catch {
                    Write-Warning 'Cancelled - the iPhone won''t be able to reach the backend.'
                }
            } else {
                Write-Host '  ok  firewall and port forwarding already set up'
            }

            try {
                $null = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/api/health' -UseBasicParsing -TimeoutSec 3
                try {
                    $null = Invoke-WebRequest -Uri ($target.Url + '/health') -UseBasicParsing -TimeoutSec 5
                    Write-Host "  ok  backend answers at $($target.Url)/health"
                } catch {
                    Write-Warning "The backend runs, but $($target.Url)/health doesn't answer: $($_.Exception.Message)"
                }
            } catch {
                Write-Warning 'The backend is not running. Start run_backend.bat before opening Guidy on the iPhone.'
            }
            Write-Host "  The iPhone must be on the same network as this PC ('$($net.Alias)')." -ForegroundColor Gray
        }
    }

    # --- 4. Install ---------------------------------------------------------
    if ($SignedIpa) {
        $idi = Get-Command ideviceinstaller -ErrorAction SilentlyContinue
        if (-not $idi) { throw 'ideviceinstaller (libimobiledevice) is not on PATH; cannot install a pre-signed IPA directly.' }
        Write-Step 'Installing the signed IPA with ideviceinstaller'
        & $idi.Source install $ipaPath
        if ($LASTEXITCODE -ne 0) { & $idi.Source -i $ipaPath }   # older builds use -i
        if ($LASTEXITCODE -ne 0) { throw "ideviceinstaller failed (exit $LASTEXITCODE)." }
        Write-Host "`nInstalled. Open Guidy on the iPhone." -ForegroundColor Green
        return
    }

    $sideloadly = Find-Sideloadly
    if (-not $sideloadly) {
        Write-Warning 'Sideloadly is not installed. Opening its website - install it, then run this again.'
        Start-Process 'https://sideloadly.io/'
        exit 1
    }

    Write-Step 'Opening Sideloadly'
    Set-Clipboard -Value $ipaPath -ErrorAction SilentlyContinue
    Start-Process -FilePath $sideloadly -ArgumentList "`"$ipaPath`""
    Start-Process explorer.exe -ArgumentList "/select,`"$ipaPath`""

    Write-Host @"

  In Sideloadly:
    1. If the IPA isn't loaded yet, drag $(Split-Path -Leaf $ipaPath) onto the window
       (Explorer is open on it; the path is also on your clipboard).
    2. Pick your iPhone under "iDevice" and enter your Apple ID.
    3. Click Start and enter your Apple ID password / 2FA code when asked.

  Then on the iPhone (first install only):
    4. Settings > General > VPN & Device Management > your Apple ID > Trust.
    5. iOS 16+: Settings > Privacy & Security > Developer Mode > On (phone restarts).

  A free Apple ID signature lasts 7 days - run this script again to refresh.
"@ -ForegroundColor Green
}

# Run only when executed, not when dot-sourced by the tests.
if ($MyInvocation.InvocationName -ne '.') {
    try { Main } catch { Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
}
