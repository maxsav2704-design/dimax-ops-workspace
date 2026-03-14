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

function Get-RepoSummary {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path
    )

    Push-Location $Path
    try {
        $branch = (& git branch --show-current | Out-String).Trim()
        $remote = Normalize-RemoteUrl -Url ((& git remote get-url origin | Out-String).Trim())
        $status = (& git status --short | Out-String).Trim()
        $isClean = [string]::IsNullOrWhiteSpace($status)
        $compareUrl = if ($branch -and $branch -ne "main") { "$remote/compare/main...${branch}?expand=1" } else { $null }

        return [pscustomobject]@{
            Name = $Name
            Branch = $branch
            Remote = $remote
            CompareUrl = $compareUrl
            IsClean = $isClean
        }
    }
    finally {
        Pop-Location
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

Write-Host "DIMAX staging handoff"
Write-Host ""

$summaries = foreach ($repo in $repos) {
    if (Test-Path (Join-Path $repo.Path ".git")) {
        Get-RepoSummary -Name $repo.Name -Path $repo.Path
    }
}

Write-Host "PR compare links:"
foreach ($summary in $summaries) {
    if ($summary.CompareUrl) {
        Write-Host "- $($summary.Name): $($summary.CompareUrl)"
    }
    else {
        Write-Host "- $($summary.Name): branch=$($summary.Branch)"
    }
}

Write-Host ""
Write-Host "Repo status:"
foreach ($summary in $summaries) {
    $cleanFlag = if ($summary.IsClean) { "clean" } else { "dirty" }
    Write-Host "- $($summary.Name): branch=$($summary.Branch), $cleanFlag"
}

Write-Host ""
$previewStatus = Get-NodeStatusCode -Url "http://localhost:5174/login"
$apiStatus = Get-NodeStatusCode -Url "http://localhost:8000/health"
$previewLabel = if ([string]::IsNullOrWhiteSpace($previewStatus)) { "unavailable" } else { $previewStatus }
$apiLabel = if ([string]::IsNullOrWhiteSpace($apiStatus)) { "unavailable" } else { $apiStatus }
Write-Host "Local preview:"
Write-Host "- login: http://localhost:5174/login ($previewLabel)"
Write-Host "- api:   http://localhost:8000/health ($apiLabel)"

Write-Host ""
Write-Host "Demo deploy:"
Write-Host "- env file: .env.demo"
Write-Host "- compose:  docker-compose.demo.yml"
Write-Host "- docs:     DEMO_DEPLOY.md"
Write-Host "- start:    docker compose --env-file .env.demo -f docker-compose.demo.yml up -d --build"
Write-Host "- seed:     docker compose --env-file .env.demo -f docker-compose.demo.yml exec -T api python -m app.scripts.seed_dev"

Write-Host ""
Write-Host "Review routes:"
Write-Host "- admin:     http://localhost:5174/"
Write-Host "- operations:http://localhost:5174/operations"
Write-Host "- reports:   http://localhost:5174/reports"
Write-Host "- installer: http://localhost:5174/installer"
Write-Host "- calendar:  http://localhost:5174/installer/calendar"

Write-Host ""
Write-Host "Seeded logins:"
Write-Host "- admin:     company_id=1f16d537-5617-4c4b-a944-dafba2bcead9, admin@dimax.dev / admin12345"
Write-Host "- installer: company_id=1f16d537-5617-4c4b-a944-dafba2bcead9, installer1@dimax.dev / installer12345"
