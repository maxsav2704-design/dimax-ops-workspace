Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$repos = @(
    @{ Name = "workspace"; Path = $WorkspaceRoot },
    @{ Name = "backend"; Path = (Join-Path $WorkspaceRoot "backend") },
    @{ Name = "frontend"; Path = (Join-Path $WorkspaceRoot "dimax-operations-suite-main") }
)

function Normalize-RemoteUrl {
    param([Parameter(Mandatory = $true)][string]$Url)

    $normalized = $Url.Trim()
    if ($normalized.EndsWith(".git")) {
        $normalized = $normalized.Substring(0, $normalized.Length - 4)
    }
    if ($normalized.StartsWith("git@github.com:")) {
        $normalized = "https://github.com/" + $normalized.Substring("git@github.com:".Length)
    }
    return $normalized
}

foreach ($repo in $repos) {
    if (-not (Test-Path (Join-Path $repo.Path ".git"))) {
        continue
    }

    Push-Location $repo.Path
    try {
        $branch = (& git branch --show-current | Out-String).Trim()
        $remote = Normalize-RemoteUrl -Url ((& git remote get-url origin | Out-String).Trim())

        if ([string]::IsNullOrWhiteSpace($branch)) {
            throw "Could not determine branch for $($repo.Name)."
        }
        if ($branch -eq "main") {
            throw "$($repo.Name) is still on main. Switch to a feature branch before creating a PR."
        }

        $compareUrl = "$remote/compare/main...${branch}?expand=1"
        Write-Host "$($repo.Name): $compareUrl"
    }
    finally {
        Pop-Location
    }
}
