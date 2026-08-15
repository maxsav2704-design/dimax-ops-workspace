param(
    [switch]$NoWrite,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $WorkspaceRoot "artifacts\release"
$GitleaksImage = "zricethezav/gitleaks@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"
$MaximumSourceFileBytes = 5MB

$Repositories = @(
    @{ Name = "workspace"; Path = $WorkspaceRoot },
    @{ Name = "backend"; Path = (Join-Path $WorkspaceRoot "backend") },
    @{ Name = "admin"; Path = (Join-Path $WorkspaceRoot "dimax-operations-suite-main") },
    @{ Name = "mobile"; Path = (Join-Path $WorkspaceRoot "mobile") }
)

function Get-RiskyPathReason {
    param([Parameter(Mandatory = $true)][string]$Path)

    $normalized = ($Path -replace "\\", "/").ToLowerInvariant()
    $name = [System.IO.Path]::GetFileName($normalized)
    $extension = [System.IO.Path]::GetExtension($normalized)

    if ($name -like ".env*" -and $name -notlike "*.example") {
        return "environment file"
    }

    $blockedExtensions = @(
        ".pem", ".key", ".p12", ".pfx", ".jks", ".keystore",
        ".apk", ".aab", ".ipa",
        ".sqlite", ".sqlite3", ".db",
        ".bak", ".dump",
        ".zip", ".7z", ".rar"
    )
    if ($extension -in $blockedExtensions) {
        return "release/source artifact ($extension)"
    }

    if ($name -in @("id_rsa", "id_dsa", "credentials.json", "service-account.json")) {
        return "credential file"
    }

    return $null
}

function Get-GitleaksIssue {
    param(
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [string]$Output = ""
    )

    if ($ExitCode -eq 0) {
        return $null
    }
    if ($Output -match '(?i)permission denied while trying to connect to the docker API|cannot connect to the docker daemon|error during connect') {
        return "Gitleaks scanner could not run because the Docker API is unavailable or denied"
    }
    if ($Output -match '(?im)^\s*(Finding|Secret|RuleID|Fingerprint):|leaks found') {
        return "Gitleaks reported potential secrets"
    }

    $firstLine = @(
        $Output -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -First 1
    )
    $detail = if ($firstLine.Count -gt 0) { $firstLine[0] } else { "no diagnostic output" }
    if ($detail.Length -gt 200) {
        $detail = $detail.Substring(0, 200)
    }
    return "Gitleaks scanner failed with exit code ${ExitCode}: $detail"
}

function Get-Sha256HexForText {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes)) `
            -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-Sha256HexForFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($stream)) `
            -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
}

function Get-SourceStateFingerprint {
    param([Parameter(Mandatory = $true)][object[]]$Records)

    $canonicalRecords = @(
        $Records |
            ForEach-Object { [string]$_ } |
            Sort-Object -CaseSensitive
    )
    return Get-Sha256HexForText -Value ($canonicalRecords -join "`n")
}

function Invoke-SourceReadinessSelfTest {
    if ($null -ne (Get-RiskyPathReason -Path "backend/.env.production.example")) {
        throw "Production env example must be allowed"
    }
    if ((Get-RiskyPathReason -Path "backend/.env.production.local") -ne "environment file") {
        throw "Local production env was not blocked"
    }
    if ((Get-RiskyPathReason -Path "mobile/release-key.jks") -notlike "release/source artifact*") {
        throw "Android keystore was not blocked"
    }
    if ($null -ne (Get-RiskyPathReason -Path "admin/src/app.tsx")) {
        throw "Normal source file was blocked"
    }
    if ($null -ne (Get-GitleaksIssue -ExitCode 0)) {
        throw "Successful Gitleaks execution was blocked"
    }
    if ((Get-GitleaksIssue -ExitCode 1 -Output "Finding: test") -ne "Gitleaks reported potential secrets") {
        throw "Gitleaks finding was not classified"
    }
    if ((Get-GitleaksIssue -ExitCode 1 -Output "permission denied while trying to connect to the docker API") -notlike "*Docker API*") {
        throw "Gitleaks Docker failure was not classified"
    }
    if ((Get-GitleaksIssue -ExitCode 2 -Output "unexpected scanner error") -notlike "Gitleaks scanner failed with exit code 2:*") {
        throw "Gitleaks generic failure was not classified"
    }

    $fingerprintA = Get-SourceStateFingerprint -Records @('file|b|hash-b', 'file|a|hash-a')
    $fingerprintB = Get-SourceStateFingerprint -Records @('file|a|hash-a', 'file|b|hash-b')
    if ($fingerprintA -notmatch '^[0-9a-f]{64}$') {
        throw "Source fingerprint is not a lowercase SHA-256 value"
    }
    if ($fingerprintA -ne $fingerprintB) {
        throw "Source fingerprint depends on input enumeration order"
    }
    if ($fingerprintA -eq (Get-SourceStateFingerprint -Records @('file|a|changed', 'file|b|hash-b'))) {
        throw "Source fingerprint did not change with source content"
    }
    if ((Get-Sha256HexForFile -Path $PSCommandPath) -notmatch '^[0-9a-f]{64}$') {
        throw "File fingerprint is not a lowercase SHA-256 value"
    }

    Write-Output "Source readiness self-test passed (12 cases)."
}

function Get-GitLines {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = @(& git -C $RepoPath @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed for $RepoPath"
    }
    return @($output)
}

function Assert-RepositoryBoundary {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RepoPath
    )

    $expected = [System.IO.Path]::GetFullPath($RepoPath).TrimEnd("\", "/")
    $actualLines = @(Get-GitLines -RepoPath $RepoPath -Arguments @("rev-parse", "--show-toplevel"))
    if ($actualLines.Count -eq 0) {
        throw "Git root is unavailable for $Name"
    }
    $actual = [System.IO.Path]::GetFullPath(([string]$actualLines[0])).TrimEnd("\", "/")
    if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Repository boundary mismatch for ${Name}: expected $expected, got $actual"
    }
}

function Invoke-GitDiffCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RepoPath
    )

    & git -c core.safecrlf=false -C $RepoPath diff --check
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check failed for $Name"
    }
}

if ($SelfTest) {
    Invoke-SourceReadinessSelfTest
    return
}

$tempRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $env:TEMP ("dimax-source-readiness-" + [guid]::NewGuid().ToString("N")))
)
$repoResults = [System.Collections.Generic.List[object]]::new()
$largeFiles = [System.Collections.Generic.List[object]]::new()
$riskyPaths = [System.Collections.Generic.List[object]]::new()
$workspaceSnapshotRecords = [System.Collections.Generic.List[string]]::new()
$scannedFiles = 0
$gitleaksExitCode = 1
$gitleaksOutputText = ""

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    foreach ($repository in $Repositories) {
        $name = [string]$repository.Name
        $repoPath = [System.IO.Path]::GetFullPath([string]$repository.Path)
        Assert-RepositoryBoundary -Name $name -RepoPath $repoPath
        Invoke-GitDiffCheck -Name $name -RepoPath $repoPath

        $headLines = @(Get-GitLines -RepoPath $repoPath -Arguments @("rev-parse", "--verify", "HEAD"))
        $branchLines = @(Get-GitLines -RepoPath $repoPath -Arguments @("branch", "--show-current"))
        $statusLines = @(
            Get-GitLines -RepoPath $repoPath -Arguments @("status", "--short", "--untracked-files=all") |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )
        $sourcePaths = @(
            Get-GitLines -RepoPath $repoPath -Arguments @(
                "-c", "core.quotePath=false", "ls-files", "--modified", "--others", "--exclude-standard"
            ) |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
                Sort-Object -CaseSensitive
        )

        $repoSnapshotRecords = [System.Collections.Generic.List[string]]::new()
        $repoSnapshotRecords.Add(('head|{0}' -f [string]$headLines[0])) | Out-Null
        foreach ($statusLineValue in @($statusLines | Sort-Object -CaseSensitive)) {
            $statusLine = [string]$statusLineValue
            $repoSnapshotRecords.Add(('status|{0}|{1}' -f $statusLine.Length, $statusLine)) | Out-Null
        }

        foreach ($relativePathValue in $sourcePaths) {
            $relativePath = [string]$relativePathValue
            $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $repoPath $relativePath))
            if (-not $sourcePath.StartsWith(
                $repoPath + [System.IO.Path]::DirectorySeparatorChar,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                throw "Unsafe changed source path: $sourcePath"
            }
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                continue
            }

            $file = Get-Item -LiteralPath $sourcePath
            $fileHash = Get-Sha256HexForFile -Path $sourcePath
            $repoSnapshotRecords.Add((
                'file|{0}|{1}|{2}|{3}' -f
                $relativePath.Length,
                $relativePath,
                $file.Length,
                $fileHash
            )) | Out-Null
            if ($file.Length -ge $MaximumSourceFileBytes) {
                $largeFiles.Add([pscustomobject]@{
                    repository = $name
                    path = $relativePath
                    bytes = $file.Length
                }) | Out-Null
            }

            $riskReason = Get-RiskyPathReason -Path $relativePath
            if (-not [string]::IsNullOrWhiteSpace($riskReason)) {
                $riskyPaths.Add([pscustomobject]@{
                    repository = $name
                    path = $relativePath
                    reason = $riskReason
                }) | Out-Null
            }

            $targetPath = Join-Path (Join-Path $tempRoot $name) $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
            $scannedFiles++
        }

        $repoFingerprint = Get-SourceStateFingerprint -Records @($repoSnapshotRecords)
        $workspaceSnapshotRecords.Add(('repository|{0}|{1}' -f $name, $repoFingerprint)) | Out-Null

        $repoResults.Add([pscustomobject]@{
            name = $name
            branch = if ($branchLines.Count -gt 0) { [string]$branchLines[0] } else { "(detached)" }
            head = [string]$headLines[0]
            changed = $statusLines.Count
            tracked = @($statusLines | Where-Object { [string]$_ -notmatch "^\?\?" }).Count
            untracked = @($statusLines | Where-Object { [string]$_ -match "^\?\?" }).Count
            source_fingerprint = $repoFingerprint
        }) | Out-Null
    }

    if ($largeFiles.Count -gt 0 -or $riskyPaths.Count -gt 0) {
        $gitleaksExitCode = 0
    }
    else {
        $mountPath = ($tempRoot -replace "\\", "/") + ":/scan:ro"
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            $gitleaksOutput = @(& docker run --rm --volume $mountPath $GitleaksImage `
                dir /scan `
                --redact `
                --no-banner `
                --no-color `
                --max-target-megabytes 5 2>&1)
            $gitleaksExitCode = $LASTEXITCODE
            $gitleaksOutputText = ($gitleaksOutput | Out-String).Trim()
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
        $expectedTempRoot = [System.IO.Path]::GetFullPath($env:TEMP)
        if (-not $resolvedTemp.StartsWith(
            $expectedTempRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Unsafe source readiness cleanup target: $resolvedTemp"
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

$issues = [System.Collections.Generic.List[string]]::new()
if ($largeFiles.Count -gt 0) {
    $issues.Add("$($largeFiles.Count) changed source file(s) are at least 5 MB") | Out-Null
}
if ($riskyPaths.Count -gt 0) {
    $issues.Add("$($riskyPaths.Count) risky source path(s) were found") | Out-Null
}
$gitleaksIssue = Get-GitleaksIssue -ExitCode $gitleaksExitCode -Output $gitleaksOutputText
if ($null -ne $gitleaksIssue) {
    $issues.Add($gitleaksIssue) | Out-Null
}

$status = if ($issues.Count -eq 0) { "ok" } else { "blocked" }
$checkedAt = (Get-Date).ToUniversalTime().ToString("o")
$totalChanged = [int](($repoResults | Measure-Object -Property changed -Sum).Sum)
$sourceFingerprint = Get-SourceStateFingerprint -Records @($workspaceSnapshotRecords)
$result = [ordered]@{
    status = $status
    checked_at = $checkedAt
    gitleaks_image = $GitleaksImage
    gitleaks_exit_code = $gitleaksExitCode
    gitleaks_outcome = if ($gitleaksExitCode -eq 0) { "pass" } elseif ($gitleaksIssue -like "*potential secrets*") { "findings" } else { "scanner_error" }
    scanned_files = $scannedFiles
    total_changed_paths = $totalChanged
    source_fingerprint = $sourceFingerprint
    repositories = @($repoResults)
    large_files = @($largeFiles)
    risky_paths = @($riskyPaths)
    issues = @($issues)
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# DIMAX Source Readiness") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Status: `{0}`' -f $status.ToUpperInvariant())) | Out-Null
$lines.Add(('- Checked at: `{0}`' -f $checkedAt)) | Out-Null
$lines.Add(('- Changed paths: `{0}`' -f $totalChanged)) | Out-Null
$lines.Add(('- Source fingerprint (SHA-256): `{0}`' -f $sourceFingerprint)) | Out-Null
$lines.Add(('- Files scanned by Gitleaks: `{0}`' -f $scannedFiles)) | Out-Null
$lines.Add(('- Large changed source files: `{0}`' -f $largeFiles.Count)) | Out-Null
$lines.Add(('- Risky changed source paths: `{0}`' -f $riskyPaths.Count)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Repositories") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| Repository | Branch | HEAD | Source fingerprint | Changed | Tracked | Untracked |") | Out-Null
$lines.Add("|---|---|---|---|---:|---:|---:|") | Out-Null
foreach ($repository in $repoResults) {
    $lines.Add((
        "| `{0}` | `{1}` | `{2}` | `{3}` | {4} | {5} | {6} |" -f
        $repository.name,
        $repository.branch,
        $repository.head.Substring(0, 12),
        $repository.source_fingerprint.Substring(0, 12),
        $repository.changed,
        $repository.tracked,
        $repository.untracked
    )) | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Policy") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Repository boundaries and `git diff --check` must pass.") | Out-Null
$lines.Add("- Changed source files of 5 MB or more are blocked.") | Out-Null
$lines.Add("- Environment files, keys, signing files, database dumps, archives, and binaries are blocked.") | Out-Null
$lines.Add("- Pinned Gitleaks scans only tracked modifications and non-ignored untracked files.") | Out-Null
$lines.Add("- The SHA-256 source fingerprint binds repository HEAD values, status records, paths, sizes, and changed file contents.") | Out-Null
$lines.Add("- A PASS result validates commit safety; it does not make a dirty working tree immutable.") | Out-Null

if ($issues.Count -gt 0) {
    $lines.Add("") | Out-Null
    $lines.Add("## Blocking Issues") | Out-Null
    $lines.Add("") | Out-Null
    foreach ($issue in $issues) {
        $lines.Add("- $issue") | Out-Null
    }
}

$report = $lines -join [Environment]::NewLine
Write-Output $report

if (-not $NoWrite) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $json = $result | ConvertTo-Json -Depth 6
    $json | Set-Content -LiteralPath (Join-Path $ReleaseDir "source-readiness-$stamp.json") -Encoding UTF8
    $json | Set-Content -LiteralPath (Join-Path $ReleaseDir "source-readiness-latest.json") -Encoding UTF8
    $report | Set-Content -LiteralPath (Join-Path $ReleaseDir "source-readiness-$stamp.md") -Encoding UTF8
    $report | Set-Content -LiteralPath (Join-Path $ReleaseDir "source-readiness-latest.md") -Encoding UTF8
}

if ($issues.Count -gt 0) {
    throw "Source readiness failed. Resolve source-safety findings or scanner infrastructure errors before commit handoff."
}
