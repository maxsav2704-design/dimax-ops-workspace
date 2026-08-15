param(
    [ValidateSet("start", "smoke", "self-test")]
    [string]$Action = "start",
    [string]$ApiBaseUrl = "http://localhost:8000",
    [ValidateRange(1, 65535)]
    [int]$Port = 8081,
    [ValidateSet("localhost", "lan")]
    [string]$HostMode = "localhost",
    [ValidateRange(1, 64)]
    [int]$MaxWorkers = 1,
    [ValidateRange(30, 3600)]
    [int]$SmokeTimeoutSec = 900,
    [switch]$ClearCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$MobileDir = Join-Path $WorkspaceRoot "mobile"
$ExpoCli = Join-Path $MobileDir "node_modules\expo\bin\cli"
$ExpoCliRelative = "node_modules\expo\bin\cli"
$MinimumNodeVersion = [version]"20.18.0"

if (-not (Test-Path -LiteralPath $ExpoCli)) {
    throw "Expo CLI not found at $ExpoCli"
}

function Get-NodeVersion {
    param([Parameter(Mandatory = $true)][string]$NodePath)

    try {
        $raw = (& $NodePath -p "process.versions.node" 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return [version]$raw
    }
    catch {
        return $null
    }
}

function Test-SupportedNodeVersion {
    param([Parameter(Mandatory = $true)][version]$Version)

    return $Version.Major -eq 20 -and $Version -ge $MinimumNodeVersion
}

function Resolve-PreferredNodePath {
    if (-not [string]::IsNullOrWhiteSpace($env:DIMAX_NODE_LTS)) {
        if (-not (Test-Path -LiteralPath $env:DIMAX_NODE_LTS -PathType Leaf)) {
            throw "DIMAX_NODE_LTS does not point to a Node executable: $($env:DIMAX_NODE_LTS)"
        }
        $explicitVersion = Get-NodeVersion -NodePath $env:DIMAX_NODE_LTS
        if ($null -eq $explicitVersion -or -not (Test-SupportedNodeVersion -Version $explicitVersion)) {
            throw "DIMAX_NODE_LTS must use Node >=20.18 <21 for Expo SDK 52."
        }
        return $env:DIMAX_NODE_LTS
    }

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    $localDimaxNode = Join-Path $env:LOCALAPPDATA "DIMAX\node20\node_modules\node\bin\node.exe"
    if (Test-Path -LiteralPath $localDimaxNode -PathType Leaf) {
        [void]$candidatePaths.Add($localDimaxNode)
    }

    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe"
    if (Test-Path -LiteralPath $wingetRoot -PathType Container) {
        Get-ChildItem -Path $wingetRoot -Filter "node.exe" -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            ForEach-Object { [void]$candidatePaths.Add($_.FullName) }
    }

    $defaultNode = Get-Command node -ErrorAction SilentlyContinue
    if ($defaultNode) {
        [void]$candidatePaths.Add($defaultNode.Source)
    }

    $reviewed = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in @($candidatePaths | Select-Object -Unique)) {
        $version = Get-NodeVersion -NodePath $candidate
        if ($null -eq $version) {
            continue
        }
        [void]$reviewed.Add("$candidate ($version)")
        if (Test-SupportedNodeVersion -Version $version) {
            return $candidate
        }
    }

    $details = if ($reviewed.Count -gt 0) { $reviewed -join "; " } else { "none found" }
    throw "Expo SDK 52 requires Node >=20.18 <21. Reviewed Node runtimes: $details"
}

function Get-MetroArguments {
    $arguments = @(
        $ExpoCliRelative,
        "start",
        "--dev-client",
        "--$HostMode",
        "--port", "$Port",
        "--max-workers", "$MaxWorkers"
    )
    if ($ClearCache) {
        $arguments += "--clear"
    }
    return $arguments
}

function Get-BundleUrl {
    return "http://127.0.0.1:$Port/.expo/.virtual-metro-entry.bundle?platform=android&dev=true&lazy=false&minify=false&app=com.dimax.operations.installer&modulesOnly=false&runModule=true&excludeSource=true&sourcePaths=url-server"
}

function Convert-ResponseContentToString {
    param($Content)

    if ($Content -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($Content)
    }
    return [string]$Content
}

function Read-FilePrefix {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(1, 65536)][int]$MaxCharacters = 4096
    )

    $reader = [System.IO.StreamReader]::new($Path, [System.Text.Encoding]::UTF8, $true)
    try {
        $buffer = New-Object char[] $MaxCharacters
        $count = $reader.Read($buffer, 0, $buffer.Length)
        return -join $buffer[0..([math]::Max(0, $count - 1))]
    }
    finally {
        $reader.Dispose()
    }
}

function Stop-MetroProcesses {
    param([int]$RootProcessId)

    $portPattern = "--port\s+$Port(?:\s|$)"
    $mobilePattern = [regex]::Escape($MobileDir)
    $processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -eq $RootProcessId -or
        $_.ParentProcessId -eq $RootProcessId -or
        (
            $_.CommandLine -and
            $_.CommandLine -match $portPattern -and
            ($_.CommandLine -match $mobilePattern -or $_.CommandLine -match "expo")
        )
    } | Sort-Object ProcessId -Descending)

    foreach ($process in $processes) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Write-SmokeLogs {
    param(
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)][string]$ErrorPath
    )

    if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
        Get-Content -LiteralPath $LogPath -ErrorAction SilentlyContinue | Select-Object -Last 120
    }
    if (Test-Path -LiteralPath $ErrorPath -PathType Leaf) {
        Get-Content -LiteralPath $ErrorPath -ErrorAction SilentlyContinue | Select-Object -Last 120
    }
}

function Remove-SmokeDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd("\")
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if (-not $resolved.StartsWith($tempRoot + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove mobile smoke files outside Temp: $resolved"
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Remove-Item -LiteralPath $resolved -Recurse -Force
            return
        }
        catch {
            if ($attempt -eq 3) {
                throw
            }
            Start-Sleep -Seconds 1
        }
    }
}

function Invoke-SelfTest {
    $cases = @(
        @{ Version = [version]"20.18.0"; Expected = $true },
        @{ Version = [version]"20.20.2"; Expected = $true },
        @{ Version = [version]"20.17.9"; Expected = $false },
        @{ Version = [version]"22.0.0"; Expected = $false },
        @{ Version = [version]"25.5.0"; Expected = $false }
    )
    foreach ($case in $cases) {
        $actual = Test-SupportedNodeVersion -Version $case.Version
        if ($actual -ne $case.Expected) {
            throw "Node support self-test failed for $($case.Version)."
        }
    }

    $bundleUrl = Get-BundleUrl
    foreach ($requiredPart in @("platform=android", "lazy=false", "app=com.dimax.operations.installer")) {
        if (-not $bundleUrl.Contains($requiredPart)) {
            throw "Bundle URL self-test is missing '$requiredPart'."
        }
    }

    Write-Output "Mobile Metro self-test passed (8 cases)."
}

function Invoke-Smoke {
    $nodeExe = Resolve-PreferredNodePath
    $nodeVersion = Get-NodeVersion -NodePath $nodeExe
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $smokeDir = Join-Path ([System.IO.Path]::GetTempPath()) ("dimax-mobile-smoke-$stamp-" + [guid]::NewGuid().ToString("N"))
    $logFile = Join-Path $smokeDir "metro.log"
    $errorFile = Join-Path $smokeDir "metro.err.log"
    $bundleFile = Join-Path $smokeDir "index.android.bundle"
    $process = $null
    $previousCi = $env:CI
    $previousApiBaseUrl = $env:EXPO_PUBLIC_API_BASE_URL
    $previousNodeEnv = $env:NODE_ENV

    New-Item -ItemType Directory -Path $smokeDir -Force | Out-Null
    $env:CI = "1"
    $env:EXPO_PUBLIC_API_BASE_URL = $ApiBaseUrl
    $env:NODE_ENV = "development"

    try {
        $portOwner = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($portOwner) {
            throw "Mobile smoke port $Port is already in use by PID $($portOwner.OwningProcess)."
        }

        Write-Host "Starting DIMAX mobile bundle smoke..."
        Write-Host "- node:        $nodeExe ($nodeVersion)"
        Write-Host "- port:        $Port"
        Write-Host "- max workers: $MaxWorkers"
        Write-Host "- timeout:     $SmokeTimeoutSec sec"

        $process = Start-Process -FilePath $nodeExe `
            -ArgumentList (Get-MetroArguments) `
            -WorkingDirectory $MobileDir `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError $errorFile `
            -WindowStyle Hidden `
            -PassThru

        $statusDeadline = (Get-Date).AddSeconds([math]::Min(180, $SmokeTimeoutSec))
        $statusReady = $false
        while ((Get-Date) -lt $statusDeadline) {
            if ($process.HasExited) {
                throw "Expo exited before Metro became ready (exit code $($process.ExitCode))."
            }
            try {
                $statusResponse = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/status" -TimeoutSec 3
                $statusContent = Convert-ResponseContentToString -Content $statusResponse.Content
                if ($statusResponse.StatusCode -eq 200 -and $statusContent -match "packager-status:running") {
                    $statusReady = $true
                    break
                }
            }
            catch {
                Start-Sleep -Seconds 1
            }
        }
        if (-not $statusReady) {
            throw "Metro status did not become ready within the allowed startup window."
        }

        $bundleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $bundleResponse = Invoke-WebRequest `
            -UseBasicParsing `
            -Uri (Get-BundleUrl) `
            -OutFile $bundleFile `
            -PassThru `
            -TimeoutSec $SmokeTimeoutSec
        $bundleStopwatch.Stop()

        if ($bundleResponse.StatusCode -ne 200) {
            throw "Metro bundle request returned HTTP $($bundleResponse.StatusCode)."
        }
        if (-not (Test-Path -LiteralPath $bundleFile -PathType Leaf)) {
            throw "Metro bundle response did not create an output file."
        }

        $bundleSize = (Get-Item -LiteralPath $bundleFile).Length
        if ($bundleSize -lt 500000) {
            throw "Metro bundle is unexpectedly small ($bundleSize bytes)."
        }
        $bundlePrefix = Read-FilePrefix -Path $bundleFile
        if ($bundlePrefix -match '"type"\s*:\s*"InternalError"|Metro has encountered an error') {
            throw "Metro returned an error payload instead of JavaScript."
        }

        Write-Host "Mobile bundle smoke passed:"
        Write-Host "- HTTP:   200"
        Write-Host "- bytes:  $bundleSize"
        Write-Host "- time:   $([math]::Round($bundleStopwatch.Elapsed.TotalSeconds, 1)) sec"
    }
    catch {
        Write-SmokeLogs -LogPath $logFile -ErrorPath $errorFile
        throw
    }
    finally {
        if ($null -ne $process) {
            Stop-MetroProcesses -RootProcessId $process.Id
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
        }

        if ($null -eq $previousCi) {
            Remove-Item Env:CI -ErrorAction SilentlyContinue
        }
        else {
            $env:CI = $previousCi
        }
        if ($null -eq $previousApiBaseUrl) {
            Remove-Item Env:EXPO_PUBLIC_API_BASE_URL -ErrorAction SilentlyContinue
        }
        else {
            $env:EXPO_PUBLIC_API_BASE_URL = $previousApiBaseUrl
        }
        if ($null -eq $previousNodeEnv) {
            Remove-Item Env:NODE_ENV -ErrorAction SilentlyContinue
        }
        else {
            $env:NODE_ENV = $previousNodeEnv
        }

        Start-Sleep -Milliseconds 500
        Remove-SmokeDirectory -Path $smokeDir
    }
}

switch ($Action) {
    "self-test" {
        Invoke-SelfTest
    }
    "smoke" {
        Invoke-Smoke
    }
    "start" {
        $env:EXPO_PUBLIC_API_BASE_URL = $ApiBaseUrl
        $env:NODE_ENV = "development"
        $nodeExe = Resolve-PreferredNodePath
        $nodeVersion = Get-NodeVersion -NodePath $nodeExe
        Write-Host "Starting mobile Metro..."
        Write-Host "- mobile dir:  $MobileDir"
        Write-Host "- api base:    $ApiBaseUrl"
        Write-Host "- port:        $Port"
        Write-Host "- host mode:   $HostMode"
        Write-Host "- max workers: $MaxWorkers"
        Write-Host "- node:        $nodeExe ($nodeVersion)"
        Write-Host "- clear cache: $([bool]$ClearCache)"
        Write-Host ""
        Set-Location $MobileDir
        & $nodeExe @(Get-MetroArguments)
        if ($LASTEXITCODE -ne 0) {
            throw "Expo Metro exited with code $LASTEXITCODE."
        }
    }
}
