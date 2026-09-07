param(
    [ValidateSet("start", "stop", "status", "smoke")]
    [string]$Action = "start"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $WorkspaceRoot "docker-compose.workspace.yml"
$BackendDir = Join-Path $WorkspaceRoot "backend"
$AdminDir = Join-Path $WorkspaceRoot "dimax-operations-suite-main"
$PreviewPort = 5174
$PreviewUrl = "http://localhost:$PreviewPort"
$PreviewApiBaseUrl = if ([string]::IsNullOrWhiteSpace($env:DIMAX_PREVIEW_API_BASE_URL)) {
    "http://127.0.0.1:8000"
}
else {
    $env:DIMAX_PREVIEW_API_BASE_URL.Trim()
}
$PreviewPidFile = Join-Path $AdminDir ".preview-web.pid"
$PreviewLogFile = Join-Path $AdminDir ".preview-web.log"
$PreviewErrFile = Join-Path $AdminDir ".preview-web.err.log"
$PreviewSeedFile = Join-Path $AdminDir ".preview-seed.json"
$NextCli = Join-Path $AdminDir "node_modules\.bin\next.cmd"
$PreviewBuildStampFile = Join-Path $AdminDir ".next\.preview-api-base-url"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string]$WorkDir = $WorkspaceRoot
    )
    Push-Location $WorkDir
    try {
        Write-Host ">> $Command"
        Invoke-Expression $Command
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $Command"
        }
    }
    finally {
        Pop-Location
    }
}

function Get-PreviewProcess {
    if (-not (Test-Path $PreviewPidFile)) {
        return $null
    }

    $rawPid = (Get-Content -Path $PreviewPidFile -ErrorAction SilentlyContinue | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($rawPid)) {
        Remove-Item $PreviewPidFile -Force -ErrorAction SilentlyContinue
        return $null
    }

    try {
        $proc = Get-Process -Id ([int]$rawPid) -ErrorAction Stop
        return $proc
    }
    catch {
        Remove-Item $PreviewPidFile -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Get-PreviewPortProcesses {
    try {
        $pattern = "^\s*TCP\s+\S+:$PreviewPort\s+\S+\s+LISTENING\s+(\d+)"
        $processIds = @(
            & netstat.exe -ano -p tcp 2>$null |
                ForEach-Object {
                    if ($_ -match $pattern) {
                        [int]$Matches[1]
                    }
                }
        )
        return $processIds | Select-Object -Unique
    }
    catch {
        return @()
    }
}

function Ensure-FrontendDeps {
    $swcHelpers = Join-Path $AdminDir "node_modules\@swc\helpers\package.json"
    if ((Test-Path $NextCli) -and (Test-Path $swcHelpers)) {
        return
    }

    Invoke-Step -Command "npm.cmd install" -WorkDir $AdminDir
}

function Test-FrontendBuildPresent {
    $buildIdPath = Join-Path $AdminDir ".next\BUILD_ID"
    return (Test-Path $buildIdPath)
}

function Test-PreviewProcessMatchesBuild {
    param(
        [Parameter(Mandatory = $true)]$Process
    )

    $buildIdPath = Join-Path $AdminDir ".next\BUILD_ID"
    if (-not (Test-Path $buildIdPath)) {
        return $false
    }

    try {
        $buildTime = (Get-Item $buildIdPath).LastWriteTime
        return ($Process.StartTime -ge $buildTime.AddSeconds(-2))
    }
    catch {
        return $false
    }
}

function Get-LanPreviewUrl {
    # LAN URL is optional; avoid slow Windows network cmdlets during preview startup.
    return $null
}

function Get-PreviewCorsOrigins {
    $origins = [System.Collections.Generic.List[string]]::new()
    @(
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:5174",
        "http://127.0.0.1:5174",
        "http://localhost:4173",
        "http://127.0.0.1:4173"
    ) | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace($_) -and -not $origins.Contains($_)) {
            [void]$origins.Add($_)
        }
    }

    $lanPreviewUrl = Get-LanPreviewUrl
    if (-not [string]::IsNullOrWhiteSpace($lanPreviewUrl) -and -not $origins.Contains($lanPreviewUrl)) {
        [void]$origins.Add($lanPreviewUrl)
    }

    return ($origins -join ",")
}

function Get-FrontendSourceTimestampUtc {
    $pathsToWatch = [System.Collections.Generic.List[string]]::new()
    $rg = Get-Command "rg" -ErrorAction SilentlyContinue
    if ($rg) {
        Push-Location $AdminDir
        try {
            foreach ($root in @("app", "src", "public")) {
                if (-not (Test-Path $root)) {
                    continue
                }
                $files = & rg --files $root 2>$null
                if ($LASTEXITCODE -le 1) {
                    foreach ($file in $files) {
                        if (-not [string]::IsNullOrWhiteSpace($file)) {
                            [void]$pathsToWatch.Add((Join-Path $AdminDir $file))
                        }
                    }
                }
            }
        }
        finally {
            Pop-Location
        }
    }

    foreach ($file in @(
        "package.json",
        "package-lock.json",
        "next.config.js",
        "next.config.mjs",
        "next.config.ts",
        "tsconfig.json"
    )) {
        [void]$pathsToWatch.Add((Join-Path $AdminDir $file))
    }

    $latest = [datetime]::MinValue
    foreach ($path in $pathsToWatch) {
        if (-not (Test-Path $path)) {
            continue
        }

        $item = Get-Item $path -ErrorAction SilentlyContinue
        if ($null -ne $item -and $item.LastWriteTimeUtc -gt $latest) {
            $latest = $item.LastWriteTimeUtc
        }
    }

    return $latest
}

function Test-FrontendBuildFresh {
    $buildIdPath = Join-Path $AdminDir ".next\BUILD_ID"
    if (-not (Test-Path $buildIdPath)) {
        return $false
    }

    if (-not (Test-Path $PreviewBuildStampFile)) {
        return $false
    }

    $buildTimestamp = (Get-Item $buildIdPath).LastWriteTimeUtc
    $sourceTimestamp = Get-FrontendSourceTimestampUtc
    $buildApiBaseUrl = ((Get-Content -Path $PreviewBuildStampFile -ErrorAction SilentlyContinue | Out-String).Trim())
    return ($buildTimestamp -ge $sourceTimestamp) -and ($buildApiBaseUrl -eq $PreviewApiBaseUrl)
}

function Ensure-FrontendBuild {
    if (Test-FrontendBuildFresh) {
        return
    }

    if (Test-FrontendBuildPresent) {
        Write-Host "Frontend sources changed; rebuilding preview bundle..."
    }
    else {
        Write-Host "Frontend build is missing; creating preview bundle..."
    }

    $previousApiBaseUrl = $env:NEXT_PUBLIC_API_BASE_URL
    $previousNodeOptions = $env:NODE_OPTIONS
    try {
        $env:NEXT_PUBLIC_API_BASE_URL = $PreviewApiBaseUrl
        if ([string]::IsNullOrWhiteSpace($previousNodeOptions)) {
            $env:NODE_OPTIONS = "--max-old-space-size=4096"
        }
        elseif ($previousNodeOptions -notmatch "--max-old-space-size=") {
            $env:NODE_OPTIONS = "$previousNodeOptions --max-old-space-size=4096"
        }
        Push-Location $AdminDir
        try {
            Write-Host ">> npm.cmd run build"
            & npm.cmd run build
            if ($LASTEXITCODE -ne 0) {
                throw "Command failed with exit code ${LASTEXITCODE}: npm.cmd run build"
            }
        }
        finally {
            Pop-Location
        }
        Set-Content -Path $PreviewBuildStampFile -Value $PreviewApiBaseUrl
    }
    finally {
        if ($null -eq $previousApiBaseUrl) {
            Remove-Item Env:NEXT_PUBLIC_API_BASE_URL -ErrorAction SilentlyContinue
        }
        else {
            $env:NEXT_PUBLIC_API_BASE_URL = $previousApiBaseUrl
        }

        if ($null -eq $previousNodeOptions) {
            Remove-Item Env:NODE_OPTIONS -ErrorAction SilentlyContinue
        }
        else {
            $env:NODE_OPTIONS = $previousNodeOptions
        }
    }
}

function Ensure-ApiAndSeed {
    $previousCorsOrigins = $env:DIMAX_PREVIEW_CORS_ORIGINS
    try {
        $env:DIMAX_PREVIEW_CORS_ORIGINS = Get-PreviewCorsOrigins
        Invoke-Step -Command "docker compose -f `"$ComposeFile`" up -d db minio minio_init" -WorkDir $WorkspaceRoot
        Invoke-Step -Command "docker compose -f `"$ComposeFile`" up -d api" -WorkDir $WorkspaceRoot
        Wait-ApiReady
        $summaryRaw = & docker compose -f $ComposeFile exec -T api python -m app.scripts.seed_dev --emit-json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to seed demo users for preview."
        }
        $summary = (($summaryRaw | Out-String).Trim() | ConvertFrom-Json)
    }
    finally {
        if ($null -eq $previousCorsOrigins) {
            Remove-Item Env:DIMAX_PREVIEW_CORS_ORIGINS -ErrorAction SilentlyContinue
        }
        else {
            $env:DIMAX_PREVIEW_CORS_ORIGINS = $previousCorsOrigins
        }
    }

    $previewSeed = [pscustomobject]@{
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        company_id = $summary.company_id
        api_base_url = $PreviewApiBaseUrl
        preview_url = "http://127.0.0.1:$PreviewPort"
        admin = [pscustomobject]@{
            email = "admin@dimax.dev"
            password = "admin12345"
        }
        installer = [pscustomobject]@{
            email = $summary.primary_installer.email
            password = $summary.primary_installer.password
        }
    }
    $previewSeed | ConvertTo-Json -Depth 4 | Set-Content -Path $PreviewSeedFile
    return $summary
}

function Wait-ApiReady {
    $ready = $false
    for ($i = 0; $i -lt 420; $i++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8000/health" -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                $ready = $true
                break
            }
        }
        catch {
            if ($i -gt 0 -and ($i % 15) -eq 0) {
                Write-Host "Waiting for API on http://localhost:8000/health ... (${i}s)"
            }
            Start-Sleep -Seconds 1
        }
    }

    if (-not $ready) {
        throw "API did not become ready on http://localhost:8000/health within 7 minutes."
    }
}

function Wait-PreviewReady {
    $ready = $false
    for ($i = 0; $i -lt 180; $i++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "$PreviewUrl/login" -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }

    if (-not $ready) {
        throw "Preview UI did not become ready on $PreviewUrl/login"
    }
}

function Get-HttpStatusCode {
    param([Parameter(Mandatory = $true)][string]$Url)

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 5
        return [string]$response.StatusCode
    }
    catch {
        return $null
    }
}

function Start-Preview {
    $existing = Get-PreviewProcess
    if ($existing) {
        $apiStatus = Get-HttpStatusCode -Url "http://localhost:8000/health"
        if ((-not $apiStatus) -or (-not (Test-Path $PreviewSeedFile))) {
            Ensure-ApiAndSeed | Out-Null
        }
        if ((Test-FrontendBuildFresh) -and (Test-PreviewProcessMatchesBuild -Process $existing)) {
            Write-Host "Preview already running at $PreviewUrl (PID $($existing.Id))."
            Show-Status
            return
        }

        Write-Host "Preview process is stale for the current build; restarting."
        Stop-Preview
    }

    $portOwners = @(Get-PreviewPortProcesses)
    if ($portOwners.Count -gt 0) {
        $portOwners | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
    }

    Ensure-FrontendDeps
    Ensure-FrontendBuild
    $seed = Ensure-ApiAndSeed

    Remove-Item $PreviewLogFile -Force -ErrorAction SilentlyContinue
    Remove-Item $PreviewErrFile -Force -ErrorAction SilentlyContinue

    $psCommand = "& { Set-Location '$AdminDir'; `$env:NEXT_PUBLIC_API_BASE_URL = '$PreviewApiBaseUrl'; & '$NextCli' start -H 0.0.0.0 -p $PreviewPort }"
    $proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $psCommand) `
        -WorkingDirectory $AdminDir `
        -RedirectStandardOutput $PreviewLogFile `
        -RedirectStandardError $PreviewErrFile `
        -WindowStyle Hidden `
        -PassThru
    Set-Content -Path $PreviewPidFile -Value $proc.Id

    Wait-PreviewReady

    Write-Host ""
    Write-Host "Preview ready:"
    Write-Host "- login:      $PreviewUrl/login"
    Write-Host "- admin root: $PreviewUrl/"
    Write-Host "- operations: $PreviewUrl/operations"
    Write-Host "- reports:    $PreviewUrl/reports"
    Write-Host "- installer:  $PreviewUrl/installer"
    Write-Host "- calendar:   $PreviewUrl/installer/calendar"
    $lanPreviewUrl = Get-LanPreviewUrl
    if ($lanPreviewUrl) {
        Write-Host "- device URL: $lanPreviewUrl/login"
    }
    Write-Host ""
    Write-Host "Admin login:"
    Write-Host "- company_id: $($seed.company_id)"
    Write-Host "- email:      admin@dimax.dev"
    Write-Host "- password:   admin12345"
    Write-Host ""
    Write-Host "Installer login:"
    Write-Host "- company_id: $($seed.company_id)"
    Write-Host "- email:      $($seed.primary_installer.email)"
    Write-Host "- password:   $($seed.primary_installer.password)"
}

function Stop-Preview {
    $proc = Get-PreviewProcess
    $portOwners = @(Get-PreviewPortProcesses)
    if (-not $proc) {
        $portOwners | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
        Write-Host "Preview is not running."
        return
    }

    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $proc.Id -Timeout 10 -ErrorAction SilentlyContinue
    $portOwners | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
    Remove-Item $PreviewPidFile -Force -ErrorAction SilentlyContinue
    Write-Host "Stopped preview process $($proc.Id)."
}

function Show-Status {
    $proc = Get-PreviewProcess
    if ($proc) {
        Write-Host "Preview process: running (PID $($proc.Id))"
    }
    else {
        $portOwners = @(Get-PreviewPortProcesses)
        if ($portOwners.Count -gt 0) {
            Write-Host "Preview process: running (port owner $($portOwners -join ', '), pid file stale or absent)"
        }
        else {
            Write-Host "Preview process: stopped"
        }
    }

    $previewStatus = Get-HttpStatusCode -Url "$PreviewUrl/login"
    if ($previewStatus) {
        Write-Host "Preview URL: $PreviewUrl/login -> $previewStatus"
    }
    else {
        Write-Host "Preview URL: $PreviewUrl/login -> unavailable"
    }

    $apiStatus = Get-HttpStatusCode -Url "http://localhost:8000/health"
    if ($apiStatus) {
        Write-Host "API health: http://localhost:8000/health -> $apiStatus"
    }
    else {
        Write-Host "API health: http://localhost:8000/health -> unavailable"
    }
}

function Invoke-PreviewSmoke {
    Start-Preview

    $checks = @(
        @{ Name = "API health"; Url = "http://localhost:8000/health"; Expected = "200" },
        @{ Name = "Login"; Url = "$PreviewUrl/login"; Expected = "200" },
        @{ Name = "Admin root"; Url = "$PreviewUrl/"; Expected = "200" },
        @{ Name = "Operations"; Url = "$PreviewUrl/operations"; Expected = "200" },
        @{ Name = "Reports"; Url = "$PreviewUrl/reports"; Expected = "200" },
        @{ Name = "Installer"; Url = "$PreviewUrl/installer"; Expected = "200" },
        @{ Name = "Installer calendar"; Url = "$PreviewUrl/installer/calendar"; Expected = "200" }
    )

    Write-Host ""
    Write-Host "Preview smoke check:"

    $failed = @()
    foreach ($check in $checks) {
        $status = Get-HttpStatusCode -Url $check.Url
        if ($status -eq $check.Expected) {
            Write-Host "- $($check.Name): $status"
            continue
        }

        $displayStatus = if ($status) { $status } else { "unavailable" }
        Write-Host "- $($check.Name): $displayStatus"
        $failed += "$($check.Name) ($($check.Url))"
    }

    if ($failed.Count -gt 0) {
        throw "Preview smoke failed for: $($failed -join ', ')"
    }

    Write-Host ""
    Write-Host "Preview smoke passed."
}

switch ($Action) {
    "start" { Start-Preview }
    "stop" { Stop-Preview }
    "status" { Show-Status }
    "smoke" { Invoke-PreviewSmoke }
}
