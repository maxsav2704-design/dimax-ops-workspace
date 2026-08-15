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
$ProductionComposeFile = Join-Path $BackendDir "docker-compose.production.yml"
$ProductionApiImage = "dimax-backend:contract-000000000000"
$AdminDir = Join-Path $WorkspaceRoot "dimax-operations-suite-main"
$MobileDir = Join-Path $WorkspaceRoot "mobile"
$TestJwtSecret = "dimax-test-only-jwt-secret-2026-minimum-32-bytes"

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

function Reset-TestInfra {
    Run-ExternalStep -Exe "docker" -Args @("compose", "-f", $TestComposeFile, "down", "-v", "--remove-orphans")
    Ensure-TestInfraRunning
}

function Remove-TestInfra {
    Run-ExternalStep -Exe "docker" -Args @("compose", "-f", $TestComposeFile, "down", "-v", "--remove-orphans")
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
        "-e", "PYTEST_ADDOPTS=-p no:cacheprovider",
        "-e", "DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax",
        "-e", "JWT_SECRET=$TestJwtSecret",
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

function Assert-BackendPytestCoverage {
    param(
        [Parameter(Mandatory = $true)][array]$Groups
    )

    $testsRoot = Join-Path $BackendDir "tests"
    $covered = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($group in $Groups) {
        $matches = [regex]::Matches(
            [string]$group.Cmd,
            "(?<!\S)(tests(?:/[A-Za-z0-9_.-]+)+)"
        )
        foreach ($match in $matches) {
            $relative = $match.Groups[1].Value.TrimEnd("/")
            $absolute = Join-Path $BackendDir ($relative.Replace("/", "\"))
            if (Test-Path -LiteralPath $absolute -PathType Container) {
                Get-ChildItem -LiteralPath $absolute -Recurse -File -Filter "test_*.py" |
                    ForEach-Object {
                        $path = "tests/" + $_.FullName.Substring($testsRoot.Length + 1).Replace("\", "/")
                        [void]$covered.Add($path)
                    }
            }
            elseif (Test-Path -LiteralPath $absolute -PathType Leaf) {
                [void]$covered.Add($relative)
            }
            else {
                throw "Backend pytest group references a missing path: $relative"
            }
        }
    }

    $allTests = @(
        Get-ChildItem -LiteralPath $testsRoot -Recurse -File -Filter "test_*.py" |
            ForEach-Object {
                "tests/" + $_.FullName.Substring($testsRoot.Length + 1).Replace("\", "/")
            }
    )
    $missing = @($allTests | Where-Object { -not $covered.Contains($_) } | Sort-Object)
    if ($missing.Count -gt 0) {
        throw "Backend quality gate omits test files: $($missing -join ', ')"
    }
    Write-Host "Backend pytest coverage contract passed ($($allTests.Count) files)."
}

function Invoke-BackendPytestGroups {
    $groups = @(
        @{
            Label = "architecture"
            Cmd = "timeout 600s pytest -q tests/architecture"
        },
        @{
            Label = "auth-access-rbac"
            Cmd = "timeout 900s pytest -q tests/integration/test_auth_api.py tests/integration/test_auth_guards_api.py tests/integration/test_rbac_matrix_api.py tests/integration/test_admin_access_and_validation.py tests/integration/test_production_seed.py"
        },
        @{
            Label = "admin-catalogs-calendar-dashboard"
            Cmd = "timeout 1200s pytest -q tests/integration/test_addons_api.py tests/integration/test_admin_list_contracts.py tests/integration/test_audit_coverage_api.py tests/integration/test_calendar_api.py tests/integration/test_catalogs_and_settings_api.py tests/integration/test_catalogs_bulk_import_and_audit_report_api.py tests/integration/test_cors_api.py tests/integration/test_dashboard_api.py"
        },
        @{
            Label = "projects-installers-sync"
            Cmd = "timeout 900s pytest -q tests/integration/test_installer_phase2_api.py tests/integration/test_installer_rates_api.py tests/integration/test_installers_api.py tests/integration/test_installers_link_user_api.py tests/integration/test_projects_admin_api.py tests/integration/test_projects_installer_api.py tests/integration/test_sync_admin_api.py tests/integration/test_sync_admin_health_api.py tests/integration/test_sync_batch_api.py tests/integration/test_sync_installer_snapshot_api.py"
        },
        @{
            Label = "earnings-reports-journal-outbox-platform"
            Cmd = "timeout 1500s pytest -q tests/integration/test_earnings_corrections_api.py tests/integration/test_reports_api.py tests/integration/test_journal_api.py tests/integration/test_journal_delivery_api.py tests/integration/test_files_api.py tests/integration/test_outbox_api.py tests/integration/test_outbox_webhooks_api.py tests/integration/test_platform_companies_api.py tests/integration/test_observability_api.py tests/integration/test_openapi_contract.py tests/integration/test_storage_service_bucket_bootstrap.py tests/integration/test_e2e_core_flow.py tests/integration/test_issues_admin_api.py tests/integration/test_multi_tenant_isolation.py"
        },
        @{
            Label = "project-file-import"
            Cmd = "timeout 900s pytest -q tests/integration/test_project_file_import_api.py"
        },
        @{
            Label = "security-documents-financial-integrity"
            Cmd = "timeout 900s pytest -q tests/test_security_hashes.py tests/integration/test_documents_api.py tests/integration/test_documents_docx_rendering.py tests/integration/test_financial_integrity_constraints.py"
        }
    )

    Assert-BackendPytestCoverage -Groups $groups
    foreach ($group in $groups) {
        Write-Host ""
        Write-Host "== backend pytest group: $($group.Label) =="
        Invoke-TestApiContainer -InnerCmd $group.Cmd
    }
}

function Test-ProductionComposeContract {
    $hadPreviousEnvFile = Test-Path Env:DIMAX_BACKEND_ENV_FILE
    $previousEnvFile = $env:DIMAX_BACKEND_ENV_FILE
    $hadPreviousImage = Test-Path Env:DIMAX_BACKEND_IMAGE
    $previousImage = $env:DIMAX_BACKEND_IMAGE
    try {
        $env:DIMAX_BACKEND_ENV_FILE = ".env.production.example"
        $env:DIMAX_BACKEND_IMAGE = $ProductionApiImage
        Run-ExternalStep -Exe "docker" -Args @(
            "compose", "-f", $ProductionComposeFile, "config", "--quiet"
        ) -WorkDir $BackendDir
    }
    finally {
        if ($hadPreviousEnvFile) {
            $env:DIMAX_BACKEND_ENV_FILE = $previousEnvFile
        }
        else {
            Remove-Item Env:DIMAX_BACKEND_ENV_FILE -ErrorAction SilentlyContinue
        }
        if ($hadPreviousImage) {
            $env:DIMAX_BACKEND_IMAGE = $previousImage
        }
        else {
            Remove-Item Env:DIMAX_BACKEND_IMAGE -ErrorAction SilentlyContinue
        }
    }
}

function Test-ProductionImageContract {
    $hadPreviousEnvFile = Test-Path Env:DIMAX_BACKEND_ENV_FILE
    $previousEnvFile = $env:DIMAX_BACKEND_ENV_FILE
    $hadPreviousImage = Test-Path Env:DIMAX_BACKEND_IMAGE
    $previousImage = $env:DIMAX_BACKEND_IMAGE
    try {
        $env:DIMAX_BACKEND_ENV_FILE = ".env.production.example"
        $env:DIMAX_BACKEND_IMAGE = $ProductionApiImage
        Run-ExternalStep -Exe "docker" -Args @(
            "compose", "-f", $ProductionComposeFile, "build", "api"
        ) -WorkDir $BackendDir
    }
    finally {
        if ($hadPreviousEnvFile) {
            $env:DIMAX_BACKEND_ENV_FILE = $previousEnvFile
        }
        else {
            Remove-Item Env:DIMAX_BACKEND_ENV_FILE -ErrorAction SilentlyContinue
        }
        if ($hadPreviousImage) {
            $env:DIMAX_BACKEND_IMAGE = $previousImage
        }
        else {
            Remove-Item Env:DIMAX_BACKEND_IMAGE -ErrorAction SilentlyContinue
        }
    }

    $imageUser = Invoke-ExternalCapture -Exe "docker" -Args @(
        "image", "inspect", $ProductionApiImage, "--format", "{{.Config.User}}"
    )
    if ($imageUser.Trim() -ne "10001:10001") {
        throw "Production image must run as 10001:10001, got '$imageUser'."
    }

    $secureRunArgs = @(
        "run", "--rm",
        "--cap-drop", "ALL",
        "--security-opt", "no-new-privileges:true"
    )

    Write-Host ">> verify production image rejects an incomplete runtime environment"
    $previousErrorActionPreference = $ErrorActionPreference
    $failClosedArgs = $secureRunArgs + @(
        "-e", "APP_ENV=production",
        $ProductionApiImage,
        "python", "-c", "raise SystemExit('production entrypoint validation was bypassed')"
    )
    try {
        $ErrorActionPreference = "Continue"
        $failClosedOutput = & docker @failClosedArgs 2>&1
        $failClosedExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($failClosedExitCode -eq 0) {
        throw "Production image accepted an incomplete runtime environment."
    }
    if (($failClosedOutput -join "`n") -notmatch "Production env validation failed") {
        throw "Production image failed for an unexpected reason instead of runtime env validation."
    }

    Write-Host ">> verify production image accepts a complete runtime environment"
    $runtimeDatabaseUrl = (
        "postgresql+psycopg2://dimax_app:" +
        ("d" * 24) +
        "@db.dimax.invalid:5432/dimax?sslmode=require"
    )
    $validRuntimeArgs = $secureRunArgs + @(
        "-e", "APP_ENV=production",
        "-e", ("DATABASE_URL=" + $runtimeDatabaseUrl),
        "-e", ("JWT_SECRET=" + ("a" * 64)),
        "-e", "PUBLIC_BASE_URL=https://api.dimax.invalid",
        "-e", "CORS_ALLOW_ORIGINS=https://ops.dimax.invalid",
        "-e", "MINIO_ENDPOINT=s3.dimax.invalid:443",
        "-e", "MINIO_ACCESS_KEY=DIMAXRUNTIME",
        "-e", ("MINIO_SECRET_KEY=" + ("s" * 32)),
        "-e", "MINIO_BUCKET=dimax-production",
        "-e", "MINIO_SECURE=true",
        "-e", "EMAIL_ENABLED=false",
        "-e", "WHATSAPP_ENABLED=false",
        "-e", "WHATSAPP_FALLBACK_TO_EMAIL=false",
        "-e", "TWILIO_WEBHOOK_VALIDATE=false",
        $ProductionApiImage,
        "python", "-c", "print('production runtime contract passed')"
    )
    Run-ExternalStep -Exe "docker" -Args $validRuntimeArgs

    $runtimeUid = Invoke-ExternalCapture -Exe "docker" -Args (
        $secureRunArgs + @($ProductionApiImage, "id", "-u")
    )
    $runtimeGid = Invoke-ExternalCapture -Exe "docker" -Args (
        $secureRunArgs + @($ProductionApiImage, "id", "-g")
    )
    if ($runtimeUid.Trim() -ne "10001" -or $runtimeGid.Trim() -ne "10001") {
        throw "Production runtime must use UID/GID 10001, got $runtimeUid/$runtimeGid."
    }

    Run-ExternalStep -Exe "docker" -Args (
        $secureRunArgs + @($ProductionApiImage, "test", "!", "-e", "/app/.env")
    )
    Run-ExternalStep -Exe "docker" -Args (
        $secureRunArgs + @($ProductionApiImage, "test", "!", "-d", "/app/tests")
    )
    Run-ExternalStep -Exe "docker" -Args (
        $secureRunArgs + @(
            $ProductionApiImage,
            "python", "-c",
            "import importlib.util; import httpx2; from app.main import app; assert app.title == 'DIMAX Operations Suite'; assert importlib.util.find_spec('passlib') is None"
        )
    )
    Run-ExternalStep -Exe "docker" -Args (
        $secureRunArgs + @(
            "-e", "PIP_NO_CACHE_DIR=1",
            $ProductionApiImage, "pip", "check"
        )
    )

    $languageOutput = Invoke-ExternalCapture -Exe "docker" -Args (
        $secureRunArgs + @($ProductionApiImage, "tesseract", "--list-langs")
    )
    $languages = @($languageOutput -split "`r?`n" | ForEach-Object { $_.Trim() })
    foreach ($language in @("eng", "heb", "osd", "rus")) {
        if ($language -notin $languages) {
            throw "Production image is missing Tesseract language '$language'."
        }
    }
}

function Test-Backend {
    Ensure-TestInfraRunning
    Invoke-TestApiContainer -InnerCmd "alembic upgrade head"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_cors_api.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_openapi_contract.py tests/integration/test_reports_api.py -k 'risk_concentration or executive_export'"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_catalogs_bulk_import_and_audit_report_api.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_project_file_import_api.py"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_rbac_matrix_api.py"
    Clear-BackendRuntimeArtifacts
}

function Test-BackendQualityGate {
    Clear-BackendRuntimeArtifacts
    Reset-TestInfra
    try {
        Test-ProductionComposeContract
        Invoke-TestApiContainer -InnerCmd "alembic upgrade head"
        Run-Step -Cmd "python scripts/verify_repo_boundary.py" -WorkDir $BackendDir
        Run-Step -Cmd "python scripts/db_backup_restore_smoke.py --compose-file `"$TestComposeFile`" --project-name `"$TestComposeProject`"" -WorkDir $BackendDir
        Invoke-TestApiContainer -InnerCmd "python -m compileall -q app tests"
        Invoke-BackendPytestGroups
        Invoke-TestApiContainer -InnerCmd "DIMAX_LEGACY_MIGRATION_SMOKE=1 python scripts/db_legacy_product_library_migration_smoke.py"
    }
    finally {
        try {
            Clear-BackendRuntimeArtifacts
        }
        finally {
            Remove-TestInfra
        }
    }
}

function Smoke-TestBackend {
    Ensure-TestInfraRunning
    Invoke-TestApiContainer -InnerCmd "alembic upgrade head"
    Invoke-TestApiContainer -InnerCmd "pytest -q tests/integration/test_openapi_contract.py tests/integration/test_reports_api.py -k 'risk_concentration or executive_export'"
    Clear-BackendRuntimeArtifacts
}

function Test-Frontend {
    Run-Step -Cmd "npm.cmd run quality-gate" -WorkDir $AdminDir
    Clear-AdminRuntimeArtifacts
}

function Test-Mobile {
    Run-Step -Cmd "npm.cmd run quality-gate" -WorkDir $MobileDir
}

function Test-DependencySecurity {
    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "dependency-audit.ps1")
    )
}

function Test-SourceReadiness {
    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "source-readiness.ps1")
    )
}

function Test-ReleaseGate {
    Run-Step -Cmd "python scripts/verify_storage_privacy.py" -WorkDir $WorkspaceRoot
    Test-SourceReadiness
    Test-DependencySecurity
    Test-BackendQualityGate
    Test-ProductionImageContract
    Test-Frontend
    Test-Mobile
    Test-MobileNativeBuild
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
        $(if ($env:USERPROFILE) {
            Get-ChildItem -Path (Join-Path $env:USERPROFILE ".gradle\jdks\*\bin\java.exe") -File -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        }),
        $(if ($env:USERPROFILE) {
            Get-ChildItem -Path (Join-Path $env:USERPROFILE ".gradle-dimax\jdks\*\bin\java.exe") -File -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        }),
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

function Get-MobileGradleUserHome {
    $candidates = @(@(
        $env:DIMAX_GRADLE_USER_HOME,
        $env:GRADLE_USER_HOME,
        $(if ($env:USERPROFILE) { Join-Path $env:USERPROFILE ".gradle-dimax" }),
        $(if ($env:USERPROFILE) { Join-Path $env:USERPROFILE ".gradle" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $existing = Find-FirstExistingPath -Candidates $candidates
    if ($existing) {
        return (Resolve-Path -LiteralPath $existing).Path
    }
    if ($env:USERPROFILE) {
        return (Join-Path $env:USERPROFILE ".gradle-dimax")
    }
    throw "Unable to resolve a Gradle user home for the mobile build."
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

function Preflight-MobileNativeBuild {
    $toolchain = Get-MobileAndroidToolchain
    $gradleUserHome = Get-MobileGradleUserHome
    Write-Host ">> mobile native build preflight"
    Write-Host "SDK root: $($toolchain.SdkRoot)"
    Write-Host "adb: $($toolchain.AdbPath)"
    Write-Host "emulator: $($toolchain.EmulatorPath)"
    Write-Host "java: $($toolchain.JavaPath)"
    Write-Host "Gradle user home: $gradleUserHome"

    $missing = @()
    if (-not $toolchain.SdkRoot) { $missing += "Android SDK root" }
    if (-not $toolchain.AdbPath) { $missing += "adb" }
    if (-not $toolchain.EmulatorPath) { $missing += "emulator" }
    if (-not $toolchain.JavaPath) { $missing += "java" }

    if ($missing.Count -gt 0) {
        throw "Mobile native build preflight failed. Missing: $($missing -join ', ')."
    }

    $javaHome = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { Split-Path -Parent (Split-Path -Parent $toolchain.JavaPath) }
    Write-Host "JAVA_HOME candidate: $javaHome"

    $gradleDistRoot = Join-Path $gradleUserHome "wrapper\dists\gradle-8.10.2-all"
    $gradleReady = $false
    if (Test-Path $gradleDistRoot) {
        $gradleReady = @(Get-ChildItem -Path $gradleDistRoot -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -eq "gradle-8.10.2"
        }).Count -gt 0
    }

    if ($gradleReady) {
        Write-Host "Gradle cache: ready"
    }
    else {
        $partialFiles = @()
        if (Test-Path $gradleDistRoot) {
            $partialFiles = @(Get-ChildItem -Path $gradleDistRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -in @(".part", ".lck")
            } | Select-Object -ExpandProperty Name)
        }
        Write-Host "Gradle cache: missing gradle-8.10.2 distribution"
        if ($partialFiles.Count -gt 0) {
            Write-Host "Partial cache files: $($partialFiles -join ', ')"
        }
        throw "Native Android build requires a cached Gradle 8.10.2 distribution or internet access to services.gradle.org."
    }

    Run-ExternalStep -Exe $toolchain.JavaPath -Args @("-version")
    Run-ExternalStep -Exe $toolchain.AdbPath -Args @("devices")
}

function Test-MobileNativeBuild {
    $toolchain = Get-MobileAndroidToolchain
    $gradleUserHome = Get-MobileGradleUserHome
    Preflight-MobileNativeBuild

    $androidDir = Join-Path $MobileDir "android"
    $gradleWrapper = Join-Path $androidDir "gradlew.bat"
    $apkPath = Join-Path $androidDir "app\build\outputs\apk\debug\app-debug.apk"
    $artifactDir = Join-Path $MobileDir "artifacts\android"
    $artifactPath = Join-Path $artifactDir "dimax-installer-debug.apk"
    $metadataPath = Join-Path $artifactDir "native-build-latest.json"

    $buildToolsRoot = Join-Path $toolchain.SdkRoot "build-tools"
    $buildTools = @(
        Get-ChildItem -LiteralPath $buildToolsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                (Test-Path -LiteralPath (Join-Path $_.FullName "aapt.exe")) -and
                (Test-Path -LiteralPath (Join-Path $_.FullName "apksigner.bat"))
            } |
            Sort-Object { [version]$_.Name } -Descending
    )
    if ($buildTools.Count -eq 0) {
        throw "Android build-tools with aapt and apksigner were not found."
    }

    $aapt = Join-Path $buildTools[0].FullName "aapt.exe"
    $apkSigner = Join-Path $buildTools[0].FullName "apksigner.bat"
    $previousNodeEnv = $env:NODE_ENV
    $previousJavaHome = $env:JAVA_HOME
    $previousAndroidHome = $env:ANDROID_HOME
    $previousAndroidSdkRoot = $env:ANDROID_SDK_ROOT
    $previousGradleUserHome = $env:GRADLE_USER_HOME
    $previousPath = $env:Path

    try {
        $env:NODE_ENV = "development"
        $env:JAVA_HOME = Split-Path -Parent (Split-Path -Parent $toolchain.JavaPath)
        $env:ANDROID_HOME = $toolchain.SdkRoot
        $env:ANDROID_SDK_ROOT = $toolchain.SdkRoot
        $env:GRADLE_USER_HOME = $gradleUserHome
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"

        Run-ExternalStep -Exe $gradleWrapper -Args @(
            ":app:assembleDebug",
            "--no-daemon",
            "--console=plain"
        ) -WorkDir $androidDir

        if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
            throw "Android native build completed without the expected APK: $apkPath"
        }

        $badging = Invoke-ExternalCapture -Exe $aapt -Args @(
            "dump", "badging", $apkPath
        ) -WorkDir $androidDir
        if ($badging -notmatch "package: name='com\.dimax\.operations\.installer'") {
            throw "Android APK package contract failed."
        }
        if ($badging -notmatch "sdkVersion:'24'") {
            throw "Android APK minSdk contract failed."
        }
        if ($badging -notmatch "targetSdkVersion:'34'") {
            throw "Android APK targetSdk contract failed."
        }

        $signing = Invoke-ExternalCapture -Exe $apkSigner -Args @(
            "verify", "--verbose", "--print-certs", $apkPath
        ) -WorkDir $androidDir
        if ($signing -notmatch "(?m)^Verifies\s*$") {
            throw "Android APK signature verification failed."
        }
        if ($signing -notmatch "Signer #1 certificate DN: CN=Android Debug") {
            throw "Debug native build is not signed with the expected Android debug certificate."
        }

        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
        Copy-Item -LiteralPath $apkPath -Destination $artifactPath -Force
        $artifact = Get-Item -LiteralPath $artifactPath
        $hash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash
        $sourceHead = Invoke-ExternalCapture -Exe "git" -Args @(
            "rev-parse", "HEAD"
        ) -WorkDir $MobileDir
        $sourceDirty = -not [string]::IsNullOrWhiteSpace(
            (Invoke-ExternalCapture -Exe "git" -Args @(
                "status", "--porcelain"
            ) -WorkDir $MobileDir)
        )
        [ordered]@{
            generated_at = [datetimeoffset]::Now.ToString("o")
            variant = "debug"
            package = "com.dimax.operations.installer"
            min_sdk = 24
            target_sdk = 34
            apk = "artifacts/android/dimax-installer-debug.apk"
            size_bytes = $artifact.Length
            sha256 = $hash
            signer = "Android Debug"
            source_head = $sourceHead
            source_dirty = $sourceDirty
        } |
            ConvertTo-Json |
            Set-Content -LiteralPath $metadataPath -Encoding UTF8

        Write-Host "Android native build passed."
        Write-Host "APK: $artifactPath"
        Write-Host "SHA-256: $hash"
        Write-Host "Package: com.dimax.operations.installer (minSdk 24, targetSdk 34)"
    }
    finally {
        $env:NODE_ENV = $previousNodeEnv
        $env:JAVA_HOME = $previousJavaHome
        $env:ANDROID_HOME = $previousAndroidHome
        $env:ANDROID_SDK_ROOT = $previousAndroidSdkRoot
        $env:GRADLE_USER_HOME = $previousGradleUserHome
        $env:Path = $previousPath

        foreach ($relativePath in @(
            "android\.gradle",
            "android\build",
            "android\app\build"
        )) {
            Remove-WorkspaceGeneratedPath -Path (Join-Path $MobileDir $relativePath)
        }
        Get-ChildItem -LiteralPath $androidDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^(hs_err|replay)_pid\d+\.log$" } |
            ForEach-Object {
                Remove-WorkspaceGeneratedPath -Path $_.FullName
            }
    }
}

function Run-MobileAndroid {
    $toolchain = Get-MobileAndroidToolchain
    $gradleUserHome = Get-MobileGradleUserHome
    Preflight-MobileNativeBuild

    $previousJavaHome = $env:JAVA_HOME
    $previousAndroidHome = $env:ANDROID_HOME
    $previousAndroidSdkRoot = $env:ANDROID_SDK_ROOT
    $previousGradleUserHome = $env:GRADLE_USER_HOME
    $previousPath = $env:Path
    $localPropertiesPath = Join-Path $MobileDir "android\local.properties"
    $localPropertiesBackup = $null
    if (Test-Path $localPropertiesPath) {
        $localPropertiesBackup = Get-Content -Path $localPropertiesPath -Raw
    }
    $env:JAVA_HOME = Split-Path -Parent (Split-Path -Parent $toolchain.JavaPath)
    $env:ANDROID_HOME = $toolchain.SdkRoot
    $env:ANDROID_SDK_ROOT = $toolchain.SdkRoot
    $env:GRADLE_USER_HOME = $gradleUserHome
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
    try {
        if (-not [string]::IsNullOrWhiteSpace($toolchain.SdkRoot)) {
            $sdkPathForGradle = $toolchain.SdkRoot -replace "\\", "\\\\"
            "sdk.dir=$sdkPathForGradle" | Set-Content -Path $localPropertiesPath
        }
        Run-Step -Cmd "npm.cmd run android" -WorkDir $MobileDir
    }
    finally {
        $env:JAVA_HOME = $previousJavaHome
        $env:ANDROID_HOME = $previousAndroidHome
        $env:ANDROID_SDK_ROOT = $previousAndroidSdkRoot
        $env:GRADLE_USER_HOME = $previousGradleUserHome
        $env:Path = $previousPath
        if ($null -eq $localPropertiesBackup) {
            Remove-Item $localPropertiesPath -Force -ErrorAction SilentlyContinue
        }
        else {
            Set-Content -Path $localPropertiesPath -Value $localPropertiesBackup
        }
    }
}

function Smoke-Mobile {
    $portListener = [System.Net.Sockets.TcpListener]::Create(0)
    $portListener.Start()
    $smokePort = ($portListener.LocalEndpoint).Port
    $portListener.Stop()

    $smokeTimeoutSec = 900
    if (-not [string]::IsNullOrWhiteSpace($env:DIMAX_METRO_SMOKE_TIMEOUT_SEC)) {
        $parsedTimeout = 0
        if (
            -not [int]::TryParse($env:DIMAX_METRO_SMOKE_TIMEOUT_SEC, [ref]$parsedTimeout) -or
            $parsedTimeout -lt 30 -or
            $parsedTimeout -gt 3600
        ) {
            throw "DIMAX_METRO_SMOKE_TIMEOUT_SEC must be an integer from 30 to 3600."
        }
        $smokeTimeoutSec = $parsedTimeout
    }

    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "mobile-metro.ps1"),
        "-Action", "smoke",
        "-ApiBaseUrl", "http://127.0.0.1:8000",
        "-Port", "$smokePort",
        "-HostMode", "localhost",
        "-MaxWorkers", "1",
        "-SmokeTimeoutSec", "$smokeTimeoutSec"
    )
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
    $backendEnvCandidates = @(
        (Join-Path $BackendDir ".env.production.local"),
        (Join-Path $BackendDir ".env.production")
    )
    $backendEnvFile = Find-FirstExistingPath -Candidates $backendEnvCandidates
    if (-not $backendEnvFile) {
        throw "Missing backend production env file. Create backend\\.env.production.local (or .env.production) before running this check."
    }

    $frontendEnvCandidates = @(
        (Join-Path $AdminDir ".env.production.local"),
        (Join-Path $AdminDir ".env.production")
    )
    $frontendEnvFile = Find-FirstExistingPath -Candidates $frontendEnvCandidates
    if (-not $frontendEnvFile) {
        throw "Missing frontend production env file. Create dimax-operations-suite-main\\.env.production.local (or .env.production) before running this check."
    }

    $mobileEnvCandidates = @(
        (Join-Path $MobileDir ".env.production.local"),
        (Join-Path $MobileDir ".env.production")
    )
    $mobileEnvFile = Find-FirstExistingPath -Candidates $mobileEnvCandidates
    if (-not $mobileEnvFile) {
        throw "Missing mobile production env file. Create mobile\\.env.production.local (or .env.production) before running this check."
    }

    Run-Step -Cmd "python scripts/validate_production_env.py --env-file `"$backendEnvFile`"" -WorkDir $BackendDir
    Run-Step -Cmd "npm.cmd run check:env:production -- --env-file `"$frontendEnvFile`" --backend-env-file `"$backendEnvFile`"" -WorkDir $AdminDir
    Run-Step -Cmd "npm.cmd run production-config-check -- --env-file `"$mobileEnvFile`"" -WorkDir $MobileDir
}

function Show-ProductionEnvReport {
    $backendEnvForCrossCheck = Find-FirstExistingPath -Candidates @(
        (Join-Path $BackendDir ".env.production.local"),
        (Join-Path $BackendDir ".env.production")
    )
    $checks = @(
        @{
            Name = "backend"
            WorkDir = $BackendDir
            Candidates = @(
                (Join-Path $BackendDir ".env.production.local"),
                (Join-Path $BackendDir ".env.production")
            )
            Example = Join-Path $BackendDir ".env.production.example"
            ValidatorExe = "python"
            ValidatorArgs = @("scripts/validate_production_env.py", "--env-file")
        },
        @{
            Name = "admin"
            WorkDir = $AdminDir
            Candidates = @(
                (Join-Path $AdminDir ".env.production.local"),
                (Join-Path $AdminDir ".env.production")
            )
            Example = Join-Path $AdminDir ".env.production.example"
            ValidatorExe = "npm.cmd"
            ValidatorArgs = @("run", "check:env:production", "--", "--env-file")
        },
        @{
            Name = "mobile"
            WorkDir = $MobileDir
            Candidates = @(
                (Join-Path $MobileDir ".env.production.local"),
                (Join-Path $MobileDir ".env.production")
            )
            Example = Join-Path $MobileDir ".env.production.example"
            ValidatorExe = "npm.cmd"
            ValidatorArgs = @("run", "production-config-check", "--", "--env-file")
        }
    )

    Write-Host "DIMAX production env report"
    Write-Host ""

    foreach ($check in $checks) {
        $envFile = Find-FirstExistingPath -Candidates $check.Candidates
        $exampleExists = Test-Path -LiteralPath $check.Example
        Write-Host "== $($check.Name) =="
        Write-Host "Example: $(if ($exampleExists) { $check.Example } else { 'MISSING' })"
        Write-Host "Env file: $(if ($envFile) { $envFile } else { 'MISSING' })"

        if (-not $envFile) {
            if ($exampleExists) {
                $targetPath = Join-Path $check.WorkDir ".env.production.local"
                Write-Host "Next step: copy example to $targetPath and replace all placeholders with real production values."
            }
            else {
                Write-Host "Next step: add a production env example and real production env file."
            }
            Write-Host "Status: BLOCKED"
            Write-Host ""
            continue
        }

        Push-Location $check.WorkDir
        try {
            $validatorArgs = @($check.ValidatorArgs) + @($envFile)
            if ($check.Name -eq "admin" -and $backendEnvForCrossCheck) {
                $validatorArgs += @("--backend-env-file", $backendEnvForCrossCheck)
            }
            $output = & $check.ValidatorExe @validatorArgs 2>&1
            $exitCode = $LASTEXITCODE
            if ($output) {
                $output | ForEach-Object { Write-Host $_ }
            }
            if ($exitCode -eq 0) {
                Write-Host "Status: PASS"
            }
            else {
                Write-Host "Status: FAIL"
            }
        }
        finally {
            Pop-Location
        }
        Write-Host ""
    }

    Write-Host "Production deploy remains blocked until backend, admin, and mobile env statuses are PASS."
}

function Smoke-Business {
    Run-Step -Cmd "python scripts/dimax_business_smoke.py" -WorkDir $WorkspaceRoot
}

function Invoke-DockerClean {
    $projects = @(
        "dimaxoperationssuite",
        "dimaxoperationssuite_test",
        "backend"
    )

    $containerIds = @()
    foreach ($project in $projects) {
        $ids = & docker ps -a `
            --filter "status=exited" `
            --filter "label=com.docker.compose.project=$project" `
            -q
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to inspect stopped Docker containers for compose project '$project'."
        }
        $containerIds += @($ids | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $containerIds = @($containerIds | Select-Object -Unique)
    if ($containerIds.Count -eq 0) {
        Write-Host "No stopped DIMAX containers to remove."
        return
    }

    Write-Host "Stopped DIMAX containers:"
    foreach ($id in $containerIds) {
        $name = (& docker inspect --format "{{.Name}}" $id).TrimStart("/")
        Write-Host "  - $name ($id)"
    }

    if ($Arg -in @("dry-run", "report")) {
        Write-Host "Dry run only. No containers were removed."
        return
    }

    Write-Host "Removing stopped DIMAX containers only. Volumes, images, and running containers are not touched."
    & docker rm @containerIds
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove stopped DIMAX containers."
    }
}

function Test-WorkspaceHygiene {
    $checks = @(
        @{
            Area = "workspace"
            Root = $WorkspaceRoot
            Exact = @(".claude", "CLAUDE.md", "login-preview.png")
            RecursiveDirs = @()
            RecursiveFiles = @("*.log", "hs_err_pid*.log")
        },
        @{
            Area = "backend"
            Root = $BackendDir
            Exact = @(".pytest_cache", ".mypy_cache", ".ruff_cache", ".coverage", "htmlcov")
            RecursiveDirs = @("__pycache__")
            RecursiveFiles = @("*.pyc", "*.pyo", "*.log")
        },
        @{
            Area = "admin"
            Root = $AdminDir
            Exact = @(".next", ".next-dev", "test-results", "playwright-report", "visual-audit", "artifacts", "dist", "dist-ssr", "tsconfig.tsbuildinfo")
            RecursiveDirs = @()
            RecursiveFiles = @("*.log", "next-*.log", "tmp-*.cjs", "installer-*-preview.png")
        },
        @{
            Area = "mobile"
            Root = $MobileDir
            Exact = @(".expo", ".expo-shared", ".tmp-expo-go", ".expo-dev.pid", "android\.gradle", "android\build", "android\app\build", "android\local.properties")
            RecursiveDirs = @()
            RecursiveFiles = @("*.log", "*.err.log", "*.out.log", "*.pid", "*.png")
        }
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($check in $checks) {
        foreach ($relativePath in $check.Exact) {
            $path = Join-Path $check.Root $relativePath
            if (Test-Path -LiteralPath $path) {
                $findings.Add([pscustomobject]@{
                    Area = $check.Area
                    Path = Resolve-Path -LiteralPath $path | Select-Object -ExpandProperty Path
                    Kind = "exact"
                }) | Out-Null
            }
        }

        foreach ($dirName in $check.RecursiveDirs) {
            if (Test-Path -LiteralPath $check.Root) {
                Get-ChildItem -Path $check.Root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -eq $dirName } |
                    ForEach-Object {
                        $findings.Add([pscustomobject]@{
                            Area = $check.Area
                            Path = $_.FullName
                            Kind = "directory"
                        }) | Out-Null
                    }
            }
        }

        foreach ($pattern in $check.RecursiveFiles) {
            if (Test-Path -LiteralPath $check.Root) {
                $searchArgs = @{
                    Path = $check.Root
                    File = $true
                    Force = $true
                    Filter = $pattern
                    ErrorAction = "SilentlyContinue"
                }
                if ($check.Area -eq "backend") {
                    $searchArgs["Recurse"] = $true
                }
                Get-ChildItem @searchArgs |
                    Where-Object {
                        $_.FullName -notlike "*\node_modules\*" -and
                        $_.FullName -notlike "*\.git\*" -and
                        $_.FullName -notlike "*\artifacts\release\*"
                    } |
                    ForEach-Object {
                        $findings.Add([pscustomobject]@{
                            Area = $check.Area
                            Path = $_.FullName
                            Kind = "file"
                        }) | Out-Null
                    }
            }
        }
    }

    if ($findings.Count -eq 0) {
        Write-Host "Workspace hygiene check passed. No generated build/test artifacts found."
        return
    }

    Write-Host "Workspace hygiene check found generated artifacts:"
    $findings | Sort-Object Area, Path | Format-Table -AutoSize

    if ($Arg -in @("report", "dry-run")) {
        Write-Host "Report mode only."
        return
    }

    throw "Workspace hygiene check failed. Remove generated artifacts before commit/release handoff."
}

function Test-AndroidQaProof {
    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "android-qa-report.ps1"),
        "-NoWrite",
        "-RequirePass"
    )
}

function Invoke-GoNoGo {
    $mode = if ([string]::IsNullOrWhiteSpace($Arg)) { "quick" } else { $Arg.ToLowerInvariant() }
    if ($mode -notin @("quick", "full")) {
        throw "Unsupported go-no-go mode '$Arg'. Use quick or full."
    }

    $results = [System.Collections.Generic.List[object]]::new()

    function Invoke-GoNoGoStep {
        param(
            [Parameter(Mandatory = $true)][string]$Label,
            [Parameter(Mandatory = $true)][scriptblock]$Action,
            [ValidateSet("required", "external")][string]$Scope = "required"
        )

        Write-Host ""
        Write-Host "== $Label =="
        try {
            & $Action
            Write-Host "[PASS] $Label"
            $results.Add([pscustomobject]@{
                Label = $Label
                Scope = $Scope
                Status = "PASS"
            }) | Out-Null
        }
        catch {
            $status = if ($Scope -eq "external") { "BLOCKED" } else { "FAIL" }
            Write-Host "[$status] $Label"
            Write-Host $_.Exception.Message
            $results.Add([pscustomobject]@{
                Label = $Label
                Scope = $Scope
                Status = $status
            }) | Out-Null
        }
    }

    Write-Host "DIMAX go/no-go mode: $mode"

    if ($mode -eq "quick") {
        Invoke-GoNoGoStep -Label "Workspace compose config" -Action {
            Run-ExternalStep -Exe "docker" -Args @("compose", "-f", $ComposeFile, "config", "-q")
        }
        Invoke-GoNoGoStep -Label "Production compose config" -Action {
            Test-ProductionComposeContract
        }
        Invoke-GoNoGoStep -Label "Source readiness" -Action {
            Test-SourceReadiness
        }
        Invoke-GoNoGoStep -Label "Dependency security audit" -Action {
            Test-DependencySecurity
        }
        Invoke-GoNoGoStep -Label "Backend health" -Action {
            Ensure-ApiRunning
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8000/health" -TimeoutSec 20
            if ($response.StatusCode -ne 200) {
                throw "Expected HTTP 200 from /health, got $($response.StatusCode)."
            }
            Write-Host $response.Content
        }
        Invoke-GoNoGoStep -Label "Backend sync/openapi smoke" -Action {
            Run-ExternalStep -Exe "docker" -Args @(
                "compose", "-f", $ComposeFile, "exec", "-T", "api",
                "sh", "-lc",
                "timeout 600s pytest -q tests/integration/test_openapi_contract.py tests/integration/test_sync_admin_api.py tests/integration/test_sync_admin_health_api.py"
            )
            Clear-BackendRuntimeArtifacts
        }
        Invoke-GoNoGoStep -Label "Admin production build" -Action {
            Run-ExternalStep -Exe "npm.cmd" -Args @("run", "build") -WorkDir $AdminDir
            Clear-AdminRuntimeArtifacts
        }
        Invoke-GoNoGoStep -Label "Mobile quality gate" -Action {
            Run-ExternalStep -Exe "npm.cmd" -Args @("run", "quality-gate") -WorkDir $MobileDir
        }
        Invoke-GoNoGoStep -Label "Production env validation" -Scope "external" -Action {
            Check-ProductionEnv
        }
        Invoke-GoNoGoStep -Label "Android device proof" -Scope "external" -Action {
            Test-AndroidQaProof
        }
    }
    else {
        Invoke-GoNoGoStep -Label "Production env validation" -Action {
            Check-ProductionEnv
        }
        Invoke-GoNoGoStep -Label "Full release gate" -Action {
            Test-ReleaseGate
        }
        Invoke-GoNoGoStep -Label "DIMAX business smoke" -Action {
            Smoke-Business
        }
        Invoke-GoNoGoStep -Label "Web preview smoke" -Action {
            Run-ExternalStep -Exe "powershell.exe" -Args @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", (Join-Path $PSScriptRoot "web-preview.ps1"),
                "-Action", "start"
            )
            Run-ExternalStep -Exe "powershell.exe" -Args @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", (Join-Path $PSScriptRoot "web-preview.ps1"),
                "-Action", "smoke"
            )
        }
        Invoke-GoNoGoStep -Label "Admin browser release smoke" -Action {
            Smoke-BrowserRelease
        }
        Invoke-GoNoGoStep -Label "Mobile device preflight" -Action {
            Preflight-MobileDevice
        }
        Invoke-GoNoGoStep -Label "Mobile native build preflight" -Action {
            Preflight-MobileNativeBuild
        }
        Invoke-GoNoGoStep -Label "Mobile Expo smoke" -Action {
            Smoke-Mobile
        }
        Invoke-GoNoGoStep -Label "Android device proof" -Scope "external" -Action {
            Test-AndroidQaProof
        }
    }

    Write-Host ""
    Write-Host "== Go/no-go summary =="
    $results | Format-Table -AutoSize

    $requiredFailures = @($results | Where-Object { $_.Scope -eq "required" -and $_.Status -ne "PASS" })
    $externalBlockers = @($results | Where-Object { $_.Scope -eq "external" -and $_.Status -ne "PASS" })

    if ($requiredFailures.Count -gt 0) {
        throw "GO/NO-GO result: CODE NO-GO. Fix required gate failures before release."
    }

    if ($externalBlockers.Count -gt 0) {
        Write-Host "GO/NO-GO result: CODE GO / PRODUCTION NO-GO. External blockers remain."
        return
    }

    Write-Host "GO/NO-GO result: AUTOMATED GATES GO. Confirm post-deploy smoke before declaring production complete."
}

function Smoke-VisualBrand {
    try {
        Run-Step -Cmd "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'web-preview.ps1')`" -Action start"
        Run-Step -Cmd "npm.cmd run test:e2e:visual-brand" -WorkDir $AdminDir
    }
    finally {
        Run-Step -Cmd "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'web-preview.ps1')`" -Action stop"
        Clear-AdminRuntimeArtifacts
    }
}

function Smoke-BrowserRelease {
    try {
        Run-Step -Cmd "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'web-preview.ps1')`" -Action start"
        Run-Step -Cmd "npm.cmd run test:e2e:release" -WorkDir $AdminDir
    }
    finally {
        Run-Step -Cmd "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'web-preview.ps1')`" -Action stop"
        Clear-AdminRuntimeArtifacts
    }
}

function Remove-WorkspaceGeneratedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $workspaceResolved = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if (-not ($resolved.StartsWith($workspaceResolved, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Refusing to remove generated artifact outside workspace: $resolved"
    }

    Remove-Item -LiteralPath $resolved -Recurse -Force
}

function Clear-AdminRuntimeArtifacts {
    $targets = @(
        (Join-Path $AdminDir ".next"),
        (Join-Path $AdminDir "test-results"),
        (Join-Path $AdminDir "playwright-report"),
        (Join-Path $AdminDir ".preview-web.log"),
        (Join-Path $AdminDir ".preview-web.err.log"),
        (Join-Path $AdminDir ".preview-web.pid")
    )

    foreach ($target in $targets) {
        Remove-WorkspaceGeneratedPath -Path $target
    }
}

function Clear-BackendRuntimeArtifacts {
    $targets = @(
        (Join-Path $BackendDir ".pytest_cache"),
        (Join-Path $BackendDir ".mypy_cache"),
        (Join-Path $BackendDir ".ruff_cache"),
        (Join-Path $BackendDir ".coverage"),
        (Join-Path $BackendDir "htmlcov")
    )

    foreach ($target in $targets) {
        Remove-WorkspaceGeneratedPath -Path $target
    }

    if (-not (Test-Path -LiteralPath $BackendDir)) {
        return
    }

    Get-ChildItem -Path $BackendDir -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "__pycache__" } |
        ForEach-Object {
            Remove-WorkspaceGeneratedPath -Path $_.FullName
        }
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

function Show-ChangeReport {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "change-report.ps1")
    )
    if ($Arg -eq "self-test") {
        $args += "-SelfTest"
    }
    elseif ($Arg -in @("report", "dry-run", "no-write")) {
        $args += "-NoWrite"
    }
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Show-SourceReadiness {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "source-readiness.ps1")
    )
    if ($Arg -eq "self-test") {
        $args += "-SelfTest"
    }
    elseif ($Arg -in @("report", "dry-run", "no-write")) {
        $args += "-NoWrite"
    }
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Show-AndroidQaReport {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "android-qa-report.ps1")
    )
    if ($Arg -eq "self-test") {
        $args += "-SelfTest"
    }
    elseif ($Arg -in @("report", "dry-run", "no-write")) {
        $args += "-NoWrite"
    }
    if ($Arg -eq "require-pass") {
        $args += "-RequirePass"
    }
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Show-ReleaseStatus {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "release-status.ps1")
    )
    if ($Arg -eq "self-test") {
        $args += "-SelfTest"
    }
    elseif ($Arg -in @("report", "dry-run", "no-write")) {
        $args += "-NoWrite"
    }
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Show-ReleaseHandoff {
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "release-handoff.ps1")
    )
    if ($Arg -eq "self-test") {
        $args += "-SelfTest"
    }
    elseif ($Arg -in @("report", "dry-run", "no-write")) {
        $args += "-NoWrite"
    }
    Run-ExternalStep -Exe "powershell.exe" -Args $args
}

function Manage-WebPreview {
    $action = if ([string]::IsNullOrWhiteSpace($Arg)) { "start" } else { $Arg.ToLowerInvariant() }
    if ($action -notin @("start", "stop", "status", "smoke")) {
        throw "Unsupported preview-web action '$Arg'. Use start, stop, status, or smoke."
    }

    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "web-preview.ps1"),
        "-Action", $action
    )
}

function Show-StagingHandoff {
    Run-ExternalStep -Exe "powershell.exe" -Args @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "staging-handoff.ps1")
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
    "preflight-mobile-native-build" {
        Preflight-MobileNativeBuild
    }
    "test-mobile-native-build" {
        Test-MobileNativeBuild
    }
    "run-mobile-android" {
        Run-MobileAndroid
    }
    "smoke-mobile" {
        Smoke-Mobile
    }
    "test-release-gate" {
        Test-ReleaseGate
    }
    "test-production-image" {
        Test-ProductionImageContract
    }
    "dependency-audit" {
        Test-DependencySecurity
    }
    "source-readiness" {
        Show-SourceReadiness
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
    "production-env-report" {
        Show-ProductionEnvReport
    }
    "business-smoke" {
        Smoke-Business
    }
    "docker-clean" {
        Invoke-DockerClean
    }
    "go-no-go" {
        Invoke-GoNoGo
    }
    "hygiene-check" {
        Test-WorkspaceHygiene
    }
    "visual-brand-smoke" {
        Smoke-VisualBrand
    }
    "browser-release-smoke" {
        Smoke-BrowserRelease
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
    "change-report" {
        Show-ChangeReport
    }
    "android-qa-report" {
        Show-AndroidQaReport
    }
    "release-status" {
        Show-ReleaseStatus
    }
    "release-handoff" {
        Show-ReleaseHandoff
    }
    "preview-web" {
        Manage-WebPreview
    }
    "staging-handoff" {
        Show-StagingHandoff
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
        Write-Host "  .\scripts\workspace.ps1 preflight-mobile-native-build"
        Write-Host "  .\scripts\workspace.ps1 test-mobile-native-build"
        Write-Host "  .\scripts\workspace.ps1 run-mobile-android"
        Write-Host "  .\scripts\workspace.ps1 smoke-mobile"
        Write-Host "  .\scripts\workspace.ps1 test-release-gate"
        Write-Host "  .\scripts\workspace.ps1 test-production-image"
        Write-Host "  .\scripts\workspace.ps1 dependency-audit"
        Write-Host "  .\scripts\workspace.ps1 source-readiness [report|dry-run|no-write|self-test]"
        Write-Host "  .\scripts\workspace.ps1 installer-gate"
        Write-Host "  .\scripts\workspace.ps1 setup-governance"
        Write-Host "  .\scripts\workspace.ps1 check-production-env"
        Write-Host "  .\scripts\workspace.ps1 production-env-report"
        Write-Host "  .\scripts\workspace.ps1 business-smoke"
        Write-Host "  .\scripts\workspace.ps1 docker-clean [dry-run|report]"
        Write-Host "  .\scripts\workspace.ps1 go-no-go [quick|full]"
        Write-Host "  .\scripts\workspace.ps1 hygiene-check [report|dry-run]"
        Write-Host "  .\scripts\workspace.ps1 visual-brand-smoke"
        Write-Host "  .\scripts\workspace.ps1 browser-release-smoke"
        Write-Host "  .\scripts\workspace.ps1 assert-pr-branch [report]"
        Write-Host "  .\scripts\workspace.ps1 start-feature-branch <name>"
        Write-Host "  .\scripts\workspace.ps1 install-push-guard [report]"
        Write-Host "  .\scripts\workspace.ps1 pr-links"
        Write-Host "  .\scripts\workspace.ps1 change-report [report|dry-run|no-write]"
        Write-Host "  .\scripts\workspace.ps1 android-qa-report [report|dry-run|no-write|self-test|require-pass]"
        Write-Host "  .\scripts\workspace.ps1 release-status [report|dry-run|no-write|self-test]"
        Write-Host "  .\scripts\workspace.ps1 release-handoff [report|dry-run|no-write|self-test]"
        Write-Host "  .\scripts\workspace.ps1 preview-web [start|stop|status|smoke]"
        Write-Host "  .\scripts\workspace.ps1 staging-handoff"
        Write-Host "  .\scripts\workspace.ps1 test-all"
        Write-Host "  .\scripts\workspace.ps1 smoke"
    }
}
