# Pester 5+ tests for install_on_iphone.ps1's pure helpers.
#   pwsh -c "Invoke-Pester ./install_on_iphone.Tests.ps1"
BeforeAll {
    . (Join-Path $PSScriptRoot 'install_on_iphone.ps1')
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function New-TestZip([string]$Path, [string[]]$Entries) {
        $zip = [System.IO.Compression.ZipFile]::Open($Path, 'Create')
        try {
            foreach ($e in $Entries) {
                $w = New-Object System.IO.StreamWriter ($zip.CreateEntry($e).Open())
                $w.Write('x'); $w.Dispose()
            }
        } finally { $zip.Dispose() }
    }
}

Describe 'Test-GuidyIpa' {
    It 'accepts an IPA with Payload/Runner.app' {
        $p = Join-Path $TestDrive 'good.ipa'
        New-TestZip $p @('Payload/Runner.app/Info.plist', 'Payload/Runner.app/Runner')
        Test-GuidyIpa -Path $p | Should -BeTrue
    }
    It 'rejects a download that is really an HTML error page' {
        $p = Join-Path $TestDrive 'notfound.ipa'
        Set-Content -Path $p -Value '<!DOCTYPE html><title>Not Found</title>'
        Test-GuidyIpa -Path $p | Should -BeFalse
    }
    It 'rejects a zip without the app bundle' {
        $p = Join-Path $TestDrive 'other.ipa'
        New-TestZip $p @('Payload/Other.app/Info.plist')
        Test-GuidyIpa -Path $p | Should -BeFalse
    }
    It 'rejects a missing file' {
        Test-GuidyIpa -Path (Join-Path $TestDrive 'nope.ipa') | Should -BeFalse
    }
}

Describe 'Find-Sideloadly' {
    It 'returns the first candidate that exists' {
        $a = Join-Path $TestDrive 'a\sideloadly.exe'
        $b = Join-Path $TestDrive 'b\sideloadly.exe'
        New-Item -ItemType File -Force -Path $b | Out-Null
        Find-Sideloadly -Candidates @($a, $b) | Should -Be $b
    }
    It 'returns null when none exist' {
        Find-Sideloadly -Candidates @((Join-Path $TestDrive 'x.exe')) | Should -BeNullOrEmpty
    }
}

Describe 'Get-BackendHostWarning' {
    It 'is silent when this PC owns the backend address' {
        Get-BackendHostWarning -BaseUrl 'http://192.168.1.9:8000/api' -LocalAddresses @('10.0.0.2', '192.168.1.9') |
            Should -BeNullOrEmpty
    }
    It 'warns when this PC has a different address' {
        $w = Get-BackendHostWarning -BaseUrl 'http://192.168.1.9:8000/api' -LocalAddresses @('192.168.1.20')
        $w | Should -Match '192\.168\.1\.9'
        $w | Should -Match '192\.168\.1\.20'
    }
    It 'is silent for a hostname backend (a hosted server)' {
        Get-BackendHostWarning -BaseUrl 'https://api.example.com/api' -LocalAddresses @('192.168.1.20') |
            Should -BeNullOrEmpty
    }
}

Describe 'Save-Download' {
    BeforeAll {
        # Fake curl: fails (exit 56) the first N calls after appending some
        # bytes to the -o file, then appends the rest and exits 0.
        $script:fake = Join-Path $TestDrive 'fakecurl.ps1'
        Set-Content -Path $script:fake -Value @'
$out = $args[[array]::IndexOf($args, '-o') + 1]
$state = Join-Path (Split-Path $out) 'calls.txt'
$n = if (Test-Path $state) { [int](Get-Content $state) } else { 0 }
Set-Content $state ($n + 1)
if ($env:FAKE_MODE -eq '404') { exit 22 }
Add-Content -Path $out -Value "chunk$n" -NoNewline
if ($n -lt [int]$env:FAKE_FAILS) { exit 56 }
exit 0
'@
        function script:Invoke-Fake {
            param($Uri, $OutFile, $Fails, $Mode = '', $Attempts = 6)
            $env:FAKE_FAILS = $Fails; $env:FAKE_MODE = $Mode
            Save-Download -Uri $Uri -OutFile $OutFile -Attempts $Attempts -DelaySeconds 0 -Methods @('curl') -CurlPath $script:fake
        }
    }
    BeforeEach {
        Remove-Item (Join-Path $TestDrive 'calls.txt'), (Join-Path $TestDrive 'dl.ipa*') -ErrorAction SilentlyContinue
    }
    It 'resumes after dropped connections and keeps the partial bytes' {
        $out = Join-Path $TestDrive 'dl.ipa'
        Invoke-Fake -Uri 'https://x/y.ipa' -OutFile $out -Fails 2
        Get-Content $out -Raw | Should -Be 'chunk0chunk1chunk2'
        Test-Path "$out.part" | Should -BeFalse
    }
    It 'gives up after the attempt limit and leaves no finished file' {
        $out = Join-Path $TestDrive 'dl.ipa'
        { Invoke-Fake -Uri 'https://x/y.ipa' -OutFile $out -Fails 99 -Attempts 3 } | Should -Throw '*gave up after 3 tries*'
        Test-Path $out | Should -BeFalse
        [int](Get-Content (Join-Path $TestDrive 'calls.txt')) | Should -Be 3
    }
    It 'does not retry an HTTP error such as 404' {
        $out = Join-Path $TestDrive 'dl.ipa'
        { Invoke-Fake -Uri 'https://x/y.ipa' -OutFile $out -Fails 0 -Mode '404' } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
        [int](Get-Content (Join-Path $TestDrive 'calls.txt')) | Should -Be 1
    }
    It 'discards a stale .part from an earlier run' {
        $out = Join-Path $TestDrive 'dl.ipa'
        Set-Content -Path "$out.part" -Value 'OLD' -NoNewline
        Invoke-Fake -Uri 'https://x/y.ipa' -OutFile $out -Fails 0
        Get-Content $out -Raw | Should -Be 'chunk0'
    }
}

Describe 'Set-IpaBackendUrl' {
    BeforeEach {
        $script:src = Join-Path $TestDrive 'src.ipa'
        $script:dst = Join-Path $TestDrive 'dst.ipa'
        Remove-Item $script:src, $script:dst -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::Open($script:src, 'Create')
        try {
            $e = $zip.CreateEntry('Payload/Runner.app/Frameworks/App.framework/App')
            $s = $e.Open()
            $b = [System.Text.Encoding]::GetEncoding(28591).GetBytes("`0`xFFhead http://192.168.1.9:8000/api mid http://192.168.1.9:8000/api tail`0")
            $s.Write($b, 0, $b.Length); $s.Dispose()
            $w = New-Object System.IO.StreamWriter ($zip.CreateEntry('Payload/Runner.app/Info.plist').Open())
            $w.Write('plist'); $w.Dispose()
        } finally { $zip.Dispose() }
    }
    function script:Read-AppBinary([string]$Path) {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $e = $zip.Entries | Where-Object FullName -like '*App.framework/App'
            $ms = New-Object System.IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Dispose()
            return [System.Text.Encoding]::GetEncoding(28591).GetString($ms.ToArray())
        } finally { $zip.Dispose() }
    }
    It 'replaces every occurrence and keeps other bytes and entries' {
        $n = Set-IpaBackendUrl -SourceIpa $script:src -DestIpa $script:dst -OldUrl 'http://192.168.1.9:8000/api' -NewUrl 'http://172.20.10.2:8000/api'
        $n | Should -Be 2
        Read-AppBinary $script:dst | Should -Be "`0`xFFhead http://172.20.10.2:8000/api mid http://172.20.10.2:8000/api tail`0"
        Test-GuidyIpa -Path $script:dst | Should -BeTrue
        Read-AppBinary $script:src | Should -Match '192\.168\.1\.9'   # source untouched
    }
    It 'refuses a different-length address' {
        { Set-IpaBackendUrl -SourceIpa $script:src -DestIpa $script:dst -OldUrl 'http://192.168.1.9:8000/api' -NewUrl 'http://172.20.10.12:8000/api' } |
            Should -Throw '*same length*'
        Test-Path $script:dst | Should -BeFalse
    }
    It 'returns 0 and writes nothing when the address is absent' {
        Set-IpaBackendUrl -SourceIpa $script:src -DestIpa $script:dst -OldUrl 'http://10.10.10.10:8000/api' -NewUrl 'http://10.10.10.11:8000/api' |
            Should -Be 0
        Test-Path $script:dst | Should -BeFalse
        Test-Path "$($script:dst).tmp" | Should -BeFalse
    }
}

Describe 'Test-FirewallAllows' {
    It 'covers every profile with Any' { Test-FirewallAllows -RuleProfile 'Any' -Category 'Public' | Should -BeTrue }
    It 'blocks Public for a Private+Domain rule' { Test-FirewallAllows -RuleProfile 'Domain, Private' -Category 'Public' | Should -BeFalse }
    It 'allows Private for a Private+Domain rule' { Test-FirewallAllows -RuleProfile 'Domain, Private' -Category 'Private' | Should -BeTrue }
    It 'maps DomainAuthenticated to Domain' { Test-FirewallAllows -RuleProfile 'Domain' -Category 'DomainAuthenticated' | Should -BeTrue }
    It 'is false with no rule' { Test-FirewallAllows -RuleProfile '' -Category 'Private' | Should -BeFalse }
}

Describe 'Get-SameLengthBackendUrl' {
    BeforeAll { $script:old = 'http://192.168.1.9:8000/api' }
    It 'keeps 8000 for an 11-character IP' {
        (Get-SameLengthBackendUrl -Ip '172.20.10.2' -OldUrl $old).Url | Should -Be 'http://172.20.10.2:8000/api'
    }
    It 'uses port 80 for a 13-character IP' {
        $r = Get-SameLengthBackendUrl -Ip '10.19.225.192' -OldUrl $old
        $r.Url | Should -Be 'http://10.19.225.192:80/api'
        $r.Port | Should -Be 80
        $r.Url.Length | Should -Be $old.Length
    }
    It 'skips a busy port' {
        (Get-SameLengthBackendUrl -Ip '10.19.225.192' -OldUrl $old -BusyPorts @(80)).Port | Should -Be 88
    }
    It 'uses a 3-digit port for a 12-character IP' {
        $r = Get-SameLengthBackendUrl -Ip '172.20.10.12' -OldUrl $old
        $r.Port | Should -Be 800
        $r.Url.Length | Should -Be $old.Length
    }
    It 'uses a 5-digit port for a 10-character IP' {
        $r = Get-SameLengthBackendUrl -Ip '10.0.0.150' -OldUrl $old
        $r.Port | Should -Be 18000
        $r.Url.Length | Should -Be $old.Length
    }
    It 'gives up when no port length fits' {
        Get-SameLengthBackendUrl -Ip '192.168.100.200' -OldUrl $old | Should -BeNullOrEmpty
        Get-SameLengthBackendUrl -Ip '10.0.0.15' -OldUrl $old | Should -BeNullOrEmpty
    }
}
