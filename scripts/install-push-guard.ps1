param(
    [switch]$ReportOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$HooksPath = Join-Path $WorkspaceRoot ".githooks"
$Repos = @(
    @{ Name = "workspace"; Path = $WorkspaceRoot },
    @{ Name = "backend"; Path = (Join-Path $WorkspaceRoot "backend") },
    @{ Name = "frontend"; Path = (Join-Path $WorkspaceRoot "dimax-operations-suite-main") }
)

if (-not (Test-Path (Join-Path $HooksPath "pre-push"))) {
    throw "Missing hook file: $HooksPath\\pre-push"
}

$HooksPathForGit = $HooksPath -replace '\\', '/'

foreach ($repo in $Repos) {
    if (-not (Test-Path (Join-Path $repo.Path ".git"))) {
        continue
    }

    Push-Location $repo.Path
    try {
        $current = (& git config --local --get core.hooksPath | Out-String).Trim()
        Write-Host "$($repo.Name): hooksPath=$current"

        if ($ReportOnly) {
            continue
        }

        & git config --local core.hooksPath $HooksPathForGit
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to configure core.hooksPath for $($repo.Name)."
        }

        Write-Host "$($repo.Name): installed pre-push guard"
    }
    finally {
        Pop-Location
    }
}

if ($ReportOnly) {
    Write-Host "Push guard report complete."
}
else {
    Write-Host "Push guard installed for workspace/backend/frontend."
}
