param(
    [Parameter(Mandatory = $true)]
    [string]$Branch,
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

if ($Branch -notmatch '^[A-Za-z0-9._/-]+$') {
    throw "Invalid branch name '$Branch'. Use letters, numbers, '.', '_', '-', or '/'."
}

if ($Branch -eq "main") {
    throw "Feature branch name cannot be 'main'."
}

foreach ($repo in $repos) {
    if (-not (Test-Path (Join-Path $repo.Path ".git"))) {
        continue
    }

    Push-Location $repo.Path
    try {
        $status = (& git status --short | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($status)) {
            if ($ReportOnly) {
                Write-Host "$($repo.Name): dirty -> cannot switch branches until committed or stashed"
                continue
            }
            throw "$($repo.Name) has uncommitted changes. Commit or stash before switching branches."
        }

        $currentBranch = (& git branch --show-current | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($currentBranch)) {
            throw "Could not determine current branch for $($repo.Name)."
        }

        $existingBranch = (& git branch --list $Branch | Out-String).Trim()
        $action = if ($currentBranch -eq $Branch) {
            "already-on-branch"
        } elseif (-not [string]::IsNullOrWhiteSpace($existingBranch)) {
            "checkout-existing"
        } else {
            "create-and-checkout"
        }

        Write-Host "$($repo.Name): $currentBranch -> $Branch ($action)"

        if ($ReportOnly) {
            continue
        }

        if ($currentBranch -eq $Branch) {
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($existingBranch)) {
            & git checkout $Branch
        }
        else {
            & git checkout -b $Branch
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to switch $($repo.Name) to branch '$Branch'."
        }
    }
    finally {
        Pop-Location
    }
}

if ($ReportOnly) {
    Write-Host "Feature branch plan generated."
}
else {
    Write-Host "Feature branch '$Branch' is active in workspace/backend/frontend."
}
