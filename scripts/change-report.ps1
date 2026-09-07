param(
    [switch]$NoWrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot

$Repos = @(
    @{
        Key = "workspace"
        Path = $WorkspaceRoot
        Title = "workspace/release-orchestration"
        Intent = "Release docs, workspace scripts, safe cleanup, go/no-go, evidence and handoff."
        CommitMessage = "chore(release): finalize operations suite handoff and orchestration"
    },
    @{
        Key = "backend"
        Path = Join-Path $WorkspaceRoot "backend"
        Title = "backend/business-security-sync"
        Intent = "Backend business logic, RBAC/auth, migrations, sync, earnings, imports and tests."
        CommitMessage = "feat(backend): finalize production business, security, and sync flows"
    },
    @{
        Key = "admin"
        Path = Join-Path $WorkspaceRoot "dimax-operations-suite-main"
        Title = "admin/brand-and-operations-ui"
        Intent = "Admin/installer web UI, DIMAX brand system, documents, earnings and browser smoke."
        CommitMessage = "feat(admin): finalize DIMAX operations and installer web UI"
    },
    @{
        Key = "mobile"
        Path = Join-Path $WorkspaceRoot "mobile"
        Title = "mobile/offline-installer-app"
        Intent = "Expo installer app, local storage, offline sync, Android baseline and mobile tests."
        CommitMessage = "feat(mobile): finalize offline installer application"
    }
)

function Get-GitStatusLines {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepoPath ".git"))) {
        throw "Not a git repository: $RepoPath"
    }

    $output = & git -C $RepoPath status --short --untracked-files=all
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed for $RepoPath"
    }

    return @($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Convert-StatusLine {
    param(
        [Parameter(Mandatory = $true)][string]$Line
    )

    $status = $Line.Substring(0, [Math]::Min(2, $Line.Length)).Trim()
    if ([string]::IsNullOrWhiteSpace($status)) {
        $status = "M"
    }

    $path = if ($Line.Length -gt 3) { $Line.Substring(3) } else { $Line }
    [pscustomobject]@{
        Status = $status
        Path = $path
    }
}

function Escape-MarkdownCell {
    param([string]$Value)
    return ($Value -replace "\|", "\|")
}

function Get-RepositoryRefState {
    param([Parameter(Mandatory = $true)][string]$RepoPath)

    $branch = [string](& git -C $RepoPath branch --show-current)
    if ($LASTEXITCODE -ne 0) {
        throw "git branch failed for $RepoPath"
    }
    $head = [string](& git -C $RepoPath rev-parse --verify HEAD)
    if ($LASTEXITCODE -ne 0) {
        throw "git rev-parse HEAD failed for $RepoPath"
    }

    $upstreamOutput = @(
        & git -C $RepoPath rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null
    )
    $upstream = if ($LASTEXITCODE -eq 0 -and $upstreamOutput.Count -gt 0) {
        ([string]$upstreamOutput[0]).Trim()
    }
    else {
        ""
    }
    $ahead = 0
    $behind = 0
    if (-not [string]::IsNullOrWhiteSpace($upstream)) {
        $divergenceOutput = @(
            & git -C $RepoPath rev-list --left-right --count "HEAD...$upstream"
        )
        if ($LASTEXITCODE -ne 0 -or $divergenceOutput.Count -eq 0) {
            throw "git rev-list failed for $RepoPath"
        }
        $divergence = ([string]$divergenceOutput[0]).Trim() -split '\s+'
        $ahead = [int]$divergence[0]
        $behind = [int]$divergence[1]
    }

    [pscustomobject]@{
        Branch = $branch.Trim()
        Head = $head.Trim()
        Upstream = $upstream
        Ahead = $ahead
        Behind = $behind
    }
}

$generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$sections = @()
$totalChanged = 0

foreach ($repo in $Repos) {
    $rawItems = Get-GitStatusLines -RepoPath $repo.Path
    $items = @($rawItems | ForEach-Object { Convert-StatusLine -Line $_ })
    $refState = Get-RepositoryRefState -RepoPath $repo.Path
    $totalChanged += $items.Count
    $sections += [pscustomobject]@{
        Repo = $repo
        Items = $items
        RefState = $refState
    }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# DIMAX Change Grouping Report") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Generated at: `{0}`' -f $generatedAt)) | Out-Null
$lines.Add(('- Workspace: `{0}`' -f $WorkspaceRoot)) | Out-Null
$lines.Add(('- Total changed paths across repos: `{0}`' -f $totalChanged)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Commit Execution Order") | Out-Null
$lines.Add("") | Out-Null
$lines.Add('1. `backend`: schema, contracts, business logic, and backend tests.') | Out-Null
$lines.Add('2. `admin`: API consumers, operations UI, browser tests, and brand system.') | Out-Null
$lines.Add('3. `mobile`: offline installer client, native configuration, and device contracts.') | Out-Null
$lines.Add('4. `workspace`: compose orchestration, release gates, and final evidence index.') | Out-Null
$lines.Add("") | Out-Null
$lines.Add("Keep each repository as one reviewed release commit unless a smaller group can pass its own full gate. The current cross-layer changes were verified together, so arbitrary path splitting would create untested intermediate states.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Recommended Commit Groups") | Out-Null
$lines.Add("") | Out-Null

foreach ($section in $sections) {
    $repo = $section.Repo
    $refState = $section.RefState
    $count = $section.Items.Count
    $lines.Add("### $($repo.Title)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add(('- Repo: `{0}`' -f $repo.Key)) | Out-Null
    $lines.Add(('- Path: `{0}`' -f $repo.Path)) | Out-Null
    $lines.Add(('- Branch: `{0}`' -f $refState.Branch)) | Out-Null
    $lines.Add(('- HEAD: `{0}`' -f $refState.Head)) | Out-Null
    $lines.Add(('- Upstream: `{0}`' -f $(if ([string]::IsNullOrWhiteSpace($refState.Upstream)) { "MISSING" } else { $refState.Upstream }))) | Out-Null
    $lines.Add(('- Divergence: ahead `{0}`, behind `{1}`' -f $refState.Ahead, $refState.Behind)) | Out-Null
    $lines.Add("- Intent: $($repo.Intent)") | Out-Null
    $lines.Add(('- Suggested commit: `{0}`' -f $repo.CommitMessage)) | Out-Null
    $lines.Add(('- Changed paths: `{0}`' -f $count)) | Out-Null
    $lines.Add("") | Out-Null

    if ($count -eq 0) {
        $lines.Add("No changes.") | Out-Null
        $lines.Add("") | Out-Null
        continue
    }

    $lines.Add("| Status | Path |") | Out-Null
    $lines.Add("|---|---|") | Out-Null
    foreach ($item in $section.Items) {
        $statusCell = Escape-MarkdownCell $item.Status
        $pathCell = Escape-MarkdownCell $item.Path
        $lines.Add(('| `{0}` | `{1}` |' -f $statusCell, $pathCell)) | Out-Null
    }
    $lines.Add("") | Out-Null
}

$lines.Add("## Notes") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- This report is read-only and does not stage, commit, delete, or rewrite files.") | Out-Null
$lines.Add("- Keep commits split by repository boundary: workspace, backend, admin, mobile.") | Out-Null
$lines.Add("- Push every repository branch after its release commit; local-only commits do not satisfy source immutability.") | Out-Null
$lines.Add('- Run `.\workspace.cmd source-readiness` before staging and again after the last source edit.') | Out-Null
$lines.Add('- Run `.\workspace.cmd hygiene-check` before staging files.') | Out-Null
$lines.Add('- Run `.\workspace.cmd go-no-go quick` after staging-sensitive changes.') | Out-Null
$lines.Add("") | Out-Null

$report = $lines -join [Environment]::NewLine
Write-Output $report

if ($NoWrite) {
    return
}

$evidenceDir = Join-Path $WorkspaceRoot "artifacts\release"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$reportPath = Join-Path $evidenceDir "change-report-$stamp.md"
$latestPath = Join-Path $evidenceDir "change-report-latest.md"
$report | Set-Content -Path $reportPath -Encoding UTF8
$report | Set-Content -Path $latestPath -Encoding UTF8
Write-Host ""
Write-Host "Change report written:"
Write-Host "  $reportPath"
Write-Host "  $latestPath"
