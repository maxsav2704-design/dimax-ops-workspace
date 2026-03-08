param(
    [Parameter(Position = 0)]
    [string]$Command = "help",
    [Parameter(Position = 1)]
    [string]$Arg = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $WorkspaceRoot "docker-compose.workspace.yml"
$TestComposeFile = Join-Path $WorkspaceRoot "docker-compose.workspace.test.yml"
$TestComposeProject = "dimaxoperationssuite_test"
$TestComposeNetwork = "${TestComposeProject}_default"
$TestApiImage = "dimaxoperationssuite-api"
$BackendDir = Join-Path $WorkspaceRoot "backend"
$AdminDir = Join-Path $WorkspaceRoot "dimax-operations-suite-main"
$MobileDir = Join-Path $WorkspaceRoot "mobile"

function Find-FirstExistingPath {
    param(
        [Parameter(Mandatory = $true)][string[]]$Candidates
    )
    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    return $null
}

function Run-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Cmd,
        [string]$WorkDir = $WorkspaceRoot
    )
    Push-Location $WorkDir
    try {
        Write-Host ">> $Cmd"
        Invoke-Expression $Cmd
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $Cmd"
        }
    }
    finally {
        Pop-Location
    }
}

function Run-ExternalStep {
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [Parameter(Mandatory = $true)][string[]]$Args,
        [string]$WorkDir = $WorkspaceRoot
    )
    Push-Location $WorkDir
    try {
        $rendered = ($Args | ForEach-Object {
            if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
        }) -join ' '
        Write-Host ">> $Exe $rendered"
        & $Exe @Args
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $Exe $rendered"
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-ExternalCapture {
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [Parameter(Mandatory = $true)][string[]]$Args,
        [string]$WorkDir = $WorkspaceRoot
    )
    Push-Location $WorkDir
    try {
        $rendered = ($Args | ForEach-Object {
            if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
        }) -join ' '
        Write-Host ">> $Exe $rendered"
        $output = & $Exe @Args
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $Exe $rendered"
        }
        return ($output | Out-String).Trim()
    }
    finally {
        Pop-Location
    }
}

function Ensure-ApiRunning {
    $cmd = "docker compose -f `"$ComposeFile`" ps -q api"
    $containerId = Invoke-Expression $cmd
    if ([string]::IsNullOrWhiteSpace(($containerId | Out-String))) {
        Run-Step -Cmd "docker compose -f `"$ComposeFile`" up -d db minio minio_init api"
    }
}

function Ensure-TestInfraRunning {
    $containerId = & docker compose -f $TestComposeFile ps -q db
    if ([string]::IsNullOrWhiteSpace(($containerId | Out-String))) {
        Run-ExternalStep -Exe "docker" -Args @("compose", "-f", $TestComposeFile, "up", "-d", "db", "minio", "minio_init")
    }
    else {
        Run-ExternalStep -Exe "docker" -Args @("compose", "-f", $TestComposeFile, "up", "-d", "db", "minio", "minio_init")
    }
}

function Invoke-TestApiContainer {
    param(
        [Parameter(Mandatory = $true)][string]$InnerCmd
    )
    $backendMount = "${BackendDir}:/app"
    $envFile = Join-Path $BackendDir ".env"
    $args = @(
        "run",
        "--rm",
        "--network", $TestComposeNetwork,
        "--env-file", $envFile,
        "-e", "PYTEST_DISABLE_PLUGIN_AUTOLOAD=1",
        "-e", "DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax",
        "-e", "PUBLIC_BASE_URL=http://localhost:8000",
        "-e", "CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173",
        "-e", "MINIO_ENDPOINT=minio:9000",
        "-e", "MINIO_ACCESS_KEY=minioadmin",
        "-e", "MINIO_SECRET_KEY=minioadmin",
        "-e", "MINIO_BUCKET=dimax",
        "-e", "MINIO_SECURE=false",
        "-v", $backendMount,
        "-w", "/app",
        $TestApiImage,
        "sh", "-lc", $InnerCmd
    )
    Run-ExternalStep -Exe "docker" -Args $args
}

function Test-Backend {
    Ensure-TestInfraRunning
    Invoke-TestApiContainer -InnerCmd "alembic upgrade head"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_cors_api.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_openapi_contract.py tests/integration/test_reports_api.py -k 'risk_concentration or executive_export'"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_catalogs_bulk_import_and_audit_report_api.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_project_file_import_api.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_rbac_matrix_api.py"
}

function Test-BackendQualityGate {
    Ensure-TestInfraRunning
    Invoke-TestApiContainer -InnerCmd "alembic upgrade head"
    Run-Step -Cmd "python scripts/verify_repo_boundary.py" -WorkDir $BackendDir
    Run-Step -Cmd "python scripts/db_backup_restore_smoke.py --compose-file `"$TestComposeFile`" --project-name `"$TestComposeProject`"" -WorkDir $BackendDir
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/architecture/test_module_structure.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_openapi_contract.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_auth_guards_api.py tests/integration/test_admin_access_and_validation.py tests/integration/test_installers_link_user_api.py tests/integration/test_installer_rates_api.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration"
}

function Smoke-TestBackend {
    Ensure-TestInfraRunning
    Invoke-TestApiContainer -InnerCmd "alembic upgrade head"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_openapi_contract.py tests/integration/test_reports_api.py -k 'risk_concentration or executive_export'"
}

function Test-Frontend {
    Run-Step -Cmd "npm.cmd run quality-gate" -WorkDir $AdminDir
}

function Test-Mobile {
    Run-Step -Cmd "npm.cmd run quality-gate" -WorkDir $MobileDir
}

function Test-ReleaseGate {
    Test-BackendQualityGate
    Test-Frontend
    Test-Mobile
}

function Test-InstallerGate {
    Run-Step -Cmd "docker compose up -d" -WorkDir $BackendDir
    $seedJson = Invoke-ExternalCapture -Exe "docker" -Args @(
        "compose", "exec", "-T", "-e", "APP_ENV=dev", "api",
        "python", "-m", "app.scripts.seed_dev", "--emit-json"
    ) -WorkDir $BackendDir
    $seed = $seedJson | ConvertFrom-Json
    $e2eEnvPath = Join-Path $AdminDir ".env.e2e.local"
    @(
        "# Auto-generated by workspace.cmd installer-gate"
        "E2E_COMPANY_ID=$($seed.company_id)"
        "E2E_INSTALLER_EMAIL=$($seed.primary_installer.email)"
        "E2E_INSTALLER_PASSWORD=$($seed.primary_installer.password)"
        "NEXT_PUBLIC_API_BASE_URL=http://127.0.0.1:8001"
    ) | Set-Content -Path $e2eEnvPath
    Run-Step -Cmd "npm.cmd run test:e2e:installer:strict:local" -WorkDir $AdminDir
}

function Get-MobileAndroidToolchain {
    $sdkCandidates = @(@(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Android\Sdk" }),
        "C:\Android\Sdk"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $sdkRoot = Find-FirstExistingPath -Candidates $sdkCandidates

    $adbCandidates = @(@(
        $(if ($sdkRoot) { Join-Path $sdkRoot "platform-tools\adb.exe" }),
        (Get-Command adb.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $adbPath = if ($adbCandidates.Count -gt 0) { Find-FirstExistingPath -Candidates $adbCandidates } else { $null }

    $emulatorCandidates = @(@(
        $(if ($sdkRoot) { Join-Path $sdkRoot "emulator\emulator.exe" }),
        (Get-Command emulator.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $emulatorPath = if ($emulatorCandidates.Count -gt 0) { Find-FirstExistingPath -Candidates $emulatorCandidates } else { $null }

    $javaCandidates = @(@(
        $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\java.exe" }),
        "C:\Program Files\Android\Android Studio\jbr\bin\java.exe",
        "C:\Program Files\Android\Android Studio\jre\bin\java.exe",
        (Get-Command java.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $javaPath = if ($javaCandidates.Count -gt 0) { Find-FirstExistingPath -Candidates $javaCandidates } else { $null }

    [pscustomobject]@{
        SdkRoot = $sdkRoot
        AdbPath = $adbPath
        EmulatorPath = $emulatorPath
        JavaPath = $javaPath
    }
}

function Preflight-MobileDevice {
    $toolchain = Get-MobileAndroidToolchain
    Write-Host ">> mobile device preflight"
    Write-Host "SDK root: $($toolchain.SdkRoot)"
    Write-Host "adb: $($toolchain.AdbPath)"
    Write-Host "emulator: $($toolchain.EmulatorPath)"
    Write-Host "java: $($toolchain.JavaPath)"

    $missing = @()
    if (-not $toolchain.SdkRoot) { $missing += "Android SDK root" }
    if (-not $toolchain.AdbPath) { $missing += "adb" }
    if (-not $toolchain.EmulatorPath) { $missing += "emulator" }
    if (-not $toolchain.JavaPath) { $missing += "java" }

    if ($missing.Count -gt 0) {
        throw "Mobile device preflight failed. Missing: $($missing -join ', '). Install Android Studio SDK and expose the toolchain."
    }

    Run-ExternalStep -Exe $toolchain.JavaPath -Args @("-version")
    Run-ExternalStep -Exe $toolchain.AdbPath -Args @("devices")
    Run-ExternalStep -Exe $toolchain.EmulatorPath -Args @("-list-avds")
}

function Smoke-Mobile {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $portListener = [System.Net.Sockets.TcpListener]::Create(0)
    $portListener.Start()
    $smokePort = ($portListener.LocalEndpoint).Port
    $portListener.Stop()
    $logFile = Join-Path $MobileDir ".expo-smoke-$stamp.log"
    $errFile = Join-Path $MobileDir ".expo-smoke-$stamp.err.log"
    $expoCli = Join-Path $MobileDir "node_modules\.bin\expo.cmd"
    $staleExpo = Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -like '*expo start --offline --port *'
    }
    if ($staleExpo) {
        $staleExpo | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
    }
    if (-not (Test-Path $expoCli)) {
        throw "Expo CLI not found at $expoCli"
    }

    Write-Host ">> mobile smoke on port $smokePort"
    $previousCi = $env:CI
    $env:CI = "1"
    try {
        $proc = Start-Process -FilePath $expoCli -ArgumentList @("start", "--offline", "--port", "$smokePort") -WorkingDirectory $MobileDir -RedirectStandardOutput $logFile -RedirectStandardError $errFile -PassThru
        Start-Sleep -Seconds 25
        if ($proc.HasExited) {
            Get-Content $logFile
            if (Test-Path $errFile) { Get-Content $errFile }
            throw "Expo smoke failed to stay up"
        }

        $related = Get-CimInstance Win32_Process | Where-Object {
            $_.ProcessId -eq $proc.Id -or $_.ParentProcessId -eq $proc.Id -or $_.CommandLine -like "*--port $smokePort*"
        } | Sort-Object ProcessId -Descending
        $related | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Wait-Process -Id $proc.Id -Timeout 10 -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Get-Content $logFile
        if (Test-Path $errFile) { Get-Content $errFile }
    }
    finally {
        if ([string]::IsNullOrWhiteSpace($previousCi)) {
            Remove-Item Env:CI -ErrorAction SilentlyContinue
        }
        else {
            $env:CI = $previousCi
        }
    }
}

function Smoke-Workspace {
    Run-Step -Cmd "docker compose -f `"$ComposeFile`" config -q"
    Ensure-ApiRunning
    $healthCheck = @'
$ok = $false
for ($i = 0; $i -lt 180; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8000/health" -TimeoutSec 3
    if ($r.StatusCode -eq 200) { $ok = $true; break }
  } catch {}
  Start-Sleep -Seconds 1
}
if (-not $ok) { throw "API health check failed on http://localhost:8000/health" }
Write-Host "API health check passed"
'@
    Run-Step -Cmd $healthCheck
}

function Setup-Governance {
    if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN) -and [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        throw "Missing GH_TOKEN/GITHUB_TOKEN. Export a GitHub token with repo admin rights, then run workspace.cmd setup-governance."
    }

    $token = if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { $env:GH_TOKEN } else { $env:GITHUB_TOKEN }
    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "setup-governance.ps1"),
        "-Branch", "main",
        "-Token", $token
    )
}

function Check-ProductionEnv {
    $frontendEnvCandidates = @(
        (Join-Path $AdminDir ".env.production.local"),
        (Join-Path $AdminDir ".env.production")
    )
    $frontendEnvFile = Find-FirstExistingPath -Candidates $frontendEnvCandidates
    if (-not $frontendEnvFile) {
        throw "Missing frontend production env file. Create dimax-operations-suite-main\\.env.production.local (or .env.production) before running this check."
    }

    Run-Step -Cmd "python scripts/validate_production_env.py --env-file .env" -WorkDir $BackendDir
    Run-Step -Cmd "npm.cmd run check:env:production -- --env-file `"$frontendEnvFile`"" -WorkDir $AdminDir
}

function Assert-PrBranch {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "assert-pr-branch.ps1")
    )
    if ($Arg -eq "report") {
        $args += "-ReportOnly"
    }
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Start-FeatureBranch {
    if ([string]::IsNullOrWhiteSpace($Arg)) {
        throw "Missing branch name. Example: .\workspace.cmd start-feature-branch feature/ops-cleanup"
    }

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "start-feature-branch.ps1"),
        "-Branch", $Arg
    )
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Install-PushGuard {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "install-push-guard.ps1")
    )
    if ($Arg -eq "report") {
        $args += "-ReportOnly"
    }
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Show-PrLinks {
    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "pr-links.ps1")
    )
}

switch ($Command.ToLowerInvariant()) {
    "up" {
        Run-Step -Cmd "docker compose -f `"$ComposeFile`" up -d --build"
    }
    "down" {
        Run-Step -Cmd "docker compose -f `"$ComposeFile`" down --remove-orphans"
    }
    "restart" {
        Run-Step -Cmd "docker compose -f `"$ComposeFile`" down --remove-orphans"
        Run-Step -Cmd "docker compose -f `"$ComposeFile`" up -d --build"
    }
    "ps" {
        Run-Step -Cmd "docker compose -f `"$ComposeFile`" ps"
    }
    "logs" {
        if ([string]::IsNullOrWhiteSpace($Arg)) {
            Run-Step -Cmd "docker compose -f `"$ComposeFile`" logs -f --tail=150"
        }
        else {
            Run-Step -Cmd "docker compose -f `"$ComposeFile`" logs -f --tail=150 $Arg"
        }
    }
    "test-backend" {
        Test-Backend
    }
    "test-backend-gate" {
        Test-BackendQualityGate
    }
    "smoke-test-backend" {
        Smoke-TestBackend
    }
    "test-frontend" {
        Test-Frontend
    }
    "test-frontend-gate" {
        Test-Frontend
    }
    "test-mobile" {
        Test-Mobile
    }
    "test-mobile-gate" {
        Test-Mobile
    }
    "preflight-mobile-device" {
        Preflight-MobileDevice
    }
    "smoke-mobile" {
        Smoke-Mobile
    }
    "test-release-gate" {
        Test-ReleaseGate
    }
    "installer-gate" {
        Test-InstallerGate
    }
    "setup-governance" {
        Setup-Governance
    }
    "check-production-env" {
        Check-ProductionEnv
    }
    "assert-pr-branch" {
        Assert-PrBranch
    }
    "start-feature-branch" {
        Start-FeatureBranch
    }
    "install-push-guard" {
        Install-PushGuard
    }
    "pr-links" {
        Show-PrLinks
    }
    "test-all" {
        Test-Backend
        Test-Frontend
        Test-Mobile
    }
    "smoke" {
        Smoke-Workspace
    }
    default {
        Write-Host "Usage:"
        Write-Host "  .\scripts\workspace.ps1 up"
        Write-Host "  .\scripts\workspace.ps1 down"
        Write-Host "  .\scripts\workspace.ps1 restart"
        Write-Host "  .\scripts\workspace.ps1 ps"
        Write-Host "  .\scripts\workspace.ps1 logs [service]"
        Write-Host "  .\scripts\workspace.ps1 test-backend"
        Write-Host "  .\scripts\workspace.ps1 test-backend-gate"
        Write-Host "  .\scripts\workspace.ps1 smoke-test-backend"
        Write-Host "  .\scripts\workspace.ps1 test-frontend"
        Write-Host "  .\scripts\workspace.ps1 test-frontend-gate"
        Write-Host "  .\scripts\workspace.ps1 test-mobile"
        Write-Host "  .\scripts\workspace.ps1 test-mobile-gate"
        Write-Host "  .\scripts\workspace.ps1 preflight-mobile-device"
        Write-Host "  .\scripts\workspace.ps1 smoke-mobile"
        Write-Host "  .\scripts\workspace.ps1 test-release-gate"
        Write-Host "  .\scripts\workspace.ps1 installer-gate"
        Write-Host "  .\scripts\workspace.ps1 setup-governance"
        Write-Host "  .\scripts\workspace.ps1 check-production-env"
        Write-Host "  .\scripts\workspace.ps1 assert-pr-branch [report]"
        Write-Host "  .\scripts\workspace.ps1 start-feature-branch <name>"
        Write-Host "  .\scripts\workspace.ps1 install-push-guard [report]"
        Write-Host "  .\scripts\workspace.ps1 pr-links"
        Write-Host "  .\scripts\workspace.ps1 test-all"
        Write-Host "  .\scripts\workspace.ps1 smoke"
    }
}
