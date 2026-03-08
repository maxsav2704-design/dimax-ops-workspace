param(
    [switch]$ReportOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot

$repos = @(
    @{ Name = "workspace"; Path = $WorkspaceRoot },
    @{ Name = "backend"; Path = (Join-Path $WorkspaceRoot "backend") },
    @{ Name = "frontend"; Path = (Join-Path $WorkspaceRoot "dimax-operations-suite-main") }
)

$violations = @()

foreach ($repo in $repos) {
    if (-not (Test-Path (Join-Path $repo.Path ".git"))) {
        continue
    }

    Push-Location $repo.Path
    try {
        $branch = (& git rev-parse --abbrev-ref HEAD | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($branch)) {
            throw "Could not determine current branch for $($repo.Name)"
        }

        Write-Host "$($repo.Name): $branch"

        if ($branch -eq "HEAD") {
            $violations += "$($repo.Name) is in detached HEAD state"
            continue
        }

        if ($branch -eq "main") {
            $violations += "$($repo.Name) is on main"
        }
    }
    finally {
        Pop-Location
    }
}

if ($ReportOnly) {
    if ($violations.Count -gt 0) {
        Write-Host ""
        Write-Host "Violations:"
        $violations | ForEach-Object { Write-Host "- $_" }
    }
    exit 0
}

if ($violations.Count -gt 0) {
    throw "PR branch guard failed: $($violations -join '; '). Create a feature branch before continuing."
}

Write-Host "PR branch guard passed."
