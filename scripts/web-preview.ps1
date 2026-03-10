param(
    [ValidateSet("start", "stop", "status")]
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
$PreviewPidFile = Join-Path $AdminDir ".preview-web.pid"
$PreviewLogFile = Join-Path $AdminDir ".preview-web.log"
$PreviewErrFile = Join-Path $AdminDir ".preview-web.err.log"
$PreviewCommand = "npm.cmd run dev -- -p $PreviewPort"

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
        $connections = Get-NetTCPConnection -LocalPort $PreviewPort -State Listen -ErrorAction Stop
        return $connections | Select-Object -ExpandProperty OwningProcess -Unique
    }
    catch {
        return @()
    }
}

function Ensure-FrontendDeps {
    $nextCmd = Join-Path $AdminDir "node_modules\.bin\next.cmd"
    $swcHelpers = Join-Path $AdminDir "node_modules\@swc\helpers\package.json"
    if ((Test-Path $nextCmd) -and (Test-Path $swcHelpers)) {
        return
    }

    Invoke-Step -Command "npm.cmd install" -WorkDir $AdminDir
}

function Reset-NextCache {
    $nextCacheDir = Join-Path $AdminDir ".next"
    if (Test-Path $nextCacheDir) {
        Remove-Item -Path $nextCacheDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-ApiAndSeed {
    Invoke-Step -Command "docker compose -f `"$ComposeFile`" up -d db minio minio_init api" -WorkDir $WorkspaceRoot
    $summaryRaw = & docker compose -f $ComposeFile exec -T api python -m app.scripts.seed_dev --emit-json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to seed demo users for preview."
    }
    return (($summaryRaw | Out-String).Trim() | ConvertFrom-Json)
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

function Get-NodeStatusCode {
    param([Parameter(Mandatory = $true)][string]$Url)

    try {
        $status = & node -e "fetch(process.argv[1]).then((r)=>{console.log(r.status)}).catch(()=>process.exit(1))" $Url
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return (($status | Out-String).Trim())
    }
    catch {
        return $null
    }
}

function Start-Preview {
    $existing = Get-PreviewProcess
    if ($existing) {
        Write-Host "Preview already running at $PreviewUrl (PID $($existing.Id))."
        Show-Status
        return
    }

    $portOwners = @(Get-PreviewPortProcesses)
    if ($portOwners.Count -gt 0) {
        $portOwners | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
    }

    $seed = Ensure-ApiAndSeed
    Ensure-FrontendDeps
    Reset-NextCache

    Remove-Item $PreviewLogFile -Force -ErrorAction SilentlyContinue
    Remove-Item $PreviewErrFile -Force -ErrorAction SilentlyContinue

    $psCommand = "& { `$env:NEXT_PUBLIC_API_BASE_URL = 'http://127.0.0.1:8000'; $PreviewCommand }"
    $proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $psCommand) `
        -WorkingDirectory $AdminDir `
        -RedirectStandardOutput $PreviewLogFile `
        -RedirectStandardError $PreviewErrFile `
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
    $portOwners | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
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

    $previewStatus = Get-NodeStatusCode -Url "$PreviewUrl/login"
    if ($previewStatus) {
        Write-Host "Preview URL: $PreviewUrl/login -> $previewStatus"
    }
    else {
        Write-Host "Preview URL: $PreviewUrl/login -> unavailable"
    }

    $apiStatus = Get-NodeStatusCode -Url "http://localhost:8000/health"
    if ($apiStatus) {
        Write-Host "API health: http://localhost:8000/health -> $apiStatus"
    }
    else {
        Write-Host "API health: http://localhost:8000/health -> unavailable"
    }
}

switch ($Action) {
    "start" { Start-Preview }
    "stop" { Stop-Preview }
    "status" { Show-Status }
}
