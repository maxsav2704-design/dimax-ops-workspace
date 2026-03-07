param(
    [string]$Branch = "main",
    [string]$Token = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $WorkspaceRoot "backend"
$FrontendDir = Join-Path $WorkspaceRoot "dimax-operations-suite-main"
$BackendScript = Join-Path $BackendDir "scripts\setup_branch_protection.py"

if (-not (Test-Path $BackendScript)) {
    throw "Missing script: $BackendScript"
}

function Invoke-BranchProtection {
    param(
        [Parameter(Mandatory = $true)][string]$RepoDir,
        [Parameter(Mandatory = $true)][string[]]$RequiredChecks
    )

    $args = @(
        $BackendScript,
        "--branch", $Branch
    )

    foreach ($check in $RequiredChecks) {
        $args += @("--required-check", $check)
    }

    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $args += @("--token", $Token)
    }

    if ($DryRun.IsPresent) {
        $args += "--dry-run"
    }

    Push-Location $RepoDir
    try {
        Write-Host ">> python $($args -join ' ')"
        python @args
        if ($LASTEXITCODE -ne 0) {
            throw "Branch protection command failed in $RepoDir"
        }
    }
    finally {
        Pop-Location
    }
}

Invoke-BranchProtection -RepoDir $BackendDir -RequiredChecks @(
    "Backend Tests / quality-gate"
)

Invoke-BranchProtection -RepoDir $FrontendDir -RequiredChecks @(
    "Frontend Quality Gate / quality-gate",
    "Installer Quality Gate / quality-gate"
)
