param(
    [switch]$NoWrite,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $WorkspaceRoot "backend"
$AdminDir = Join-Path $WorkspaceRoot "dimax-operations-suite-main"
$MobileDir = Join-Path $WorkspaceRoot "mobile"
$ReleaseDir = Join-Path $WorkspaceRoot "artifacts\release"
$FinalPackagePath = Join-Path $WorkspaceRoot "FINAL_GO_NO_GO_PACKAGE.md"
$ProductionMaturityPath = Join-Path $WorkspaceRoot "FINAL_PRODUCTION_MATURITY_READINESS.md"

function Find-FirstExistingPath {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    return $null
}

function ConvertTo-EvidenceTimestamp {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [datetimeoffset]) {
        return [datetimeoffset]$Value
    }
    if ($Value -is [datetime]) {
        return [datetimeoffset]([datetime]$Value)
    }

    $parsed = [datetimeoffset]::MinValue
    $parsedSuccessfully = [datetimeoffset]::TryParse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
    if ($parsedSuccessfully) {
        return $parsed
    }
    return $null
}

function Get-SourceSnapshotDecision {
    param([Parameter(Mandatory = $true)][object[]]$Repositories)

    $invalid = @($Repositories | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Head) })
    if ($invalid.Count -gt 0) {
        return "BLOCKED: release source has no commit identity for: $((@($invalid | ForEach-Object { $_.Name })) -join ', ')"
    }

    $dirty = @($Repositories | Where-Object { [int]$_.ChangedCount -gt 0 })
    if ($dirty.Count -gt 0) {
        $total = [int](($dirty | Measure-Object -Property ChangedCount -Sum).Sum)
        $details = @($dirty | ForEach-Object { "$($_.Name)=$($_.ChangedCount)" }) -join ', '
        return "BLOCKED: release source is not immutable: $total changed paths across $($dirty.Count) repositories ($details)"
    }

    $withoutUpstream = @($Repositories | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Upstream) })
    if ($withoutUpstream.Count -gt 0) {
        return "BLOCKED: release source has no upstream for: $((@($withoutUpstream | ForEach-Object { $_.Name })) -join ', ')"
    }

    $behind = @($Repositories | Where-Object { [int]$_.BehindCount -gt 0 })
    if ($behind.Count -gt 0) {
        $details = @($behind | ForEach-Object { "$($_.Name)=$($_.BehindCount)" }) -join ', '
        return "BLOCKED: release source is behind upstream ($details)"
    }

    $ahead = @($Repositories | Where-Object { [int]$_.AheadCount -gt 0 })
    if ($ahead.Count -gt 0) {
        $details = @($ahead | ForEach-Object { "$($_.Name)=$($_.AheadCount)" }) -join ', '
        return "BLOCKED: release source has unpushed commits ($details)"
    }

    $heads = @($Repositories | ForEach-Object { "$($_.Name)=$(([string]$_.Head).Substring(0, 12))" }) -join ', '
    return "PASS: clean release source ($heads)"
}

function Get-ReleaseSourceStatus {
    $definitions = @(
        @{ Name = 'workspace'; Path = $WorkspaceRoot },
        @{ Name = 'backend'; Path = $BackendDir },
        @{ Name = 'admin'; Path = $AdminDir },
        @{ Name = 'mobile'; Path = $MobileDir }
    )
    $states = [System.Collections.Generic.List[object]]::new()

    foreach ($definition in $definitions) {
        if (-not (Test-Path -LiteralPath (Join-Path $definition.Path '.git'))) {
            return "BLOCKED: release repository is missing: $($definition.Name)"
        }

        $headOutput = @(& git -C $definition.Path rev-parse --verify HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or $headOutput.Count -eq 0) {
            return "BLOCKED: release repository has no valid HEAD: $($definition.Name)"
        }

        $changes = @(
            & git -C $definition.Path status --short --untracked-files=all 2>$null |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )
        if ($LASTEXITCODE -ne 0) {
            return "BLOCKED: git status failed for release repository: $($definition.Name)"
        }

        $upstreamOutput = @(
            & git -C $definition.Path rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null
        )
        $upstream = if ($LASTEXITCODE -eq 0 -and $upstreamOutput.Count -gt 0) {
            ([string]$upstreamOutput[0]).Trim()
        }
        else {
            ""
        }
        $aheadCount = 0
        $behindCount = 0
        if (-not [string]::IsNullOrWhiteSpace($upstream)) {
            $divergenceOutput = @(
                & git -C $definition.Path rev-list --left-right --count "HEAD...$upstream" 2>$null
            )
            if ($LASTEXITCODE -ne 0 -or $divergenceOutput.Count -eq 0) {
                return "BLOCKED: upstream divergence check failed for: $($definition.Name)"
            }
            $divergence = ([string]$divergenceOutput[0]).Trim() -split '\s+'
            if ($divergence.Count -ne 2) {
                return "BLOCKED: upstream divergence output is invalid for: $($definition.Name)"
            }
            $aheadCount = [int]$divergence[0]
            $behindCount = [int]$divergence[1]
        }

        $states.Add([pscustomobject]@{
            Name = $definition.Name
            Head = ([string]$headOutput[0]).Trim()
            ChangedCount = $changes.Count
            Upstream = $upstream
            AheadCount = $aheadCount
            BehindCount = $behindCount
        }) | Out-Null
    }

    return Get-SourceSnapshotDecision -Repositories @($states)
}

function Get-SourceControlEvidenceInputs {
    $definitions = @(
        @{ Name = 'workspace'; Path = $WorkspaceRoot },
        @{ Name = 'backend'; Path = $BackendDir },
        @{ Name = 'admin'; Path = $AdminDir },
        @{ Name = 'mobile'; Path = $MobileDir }
    )
    $changedPathCount = 0
    $sourcePaths = [System.Collections.Generic.List[string]]::new()

    foreach ($definition in $definitions) {
        $statusLines = @(
            & git -C $definition.Path status --short --untracked-files=all 2>$null |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )
        if ($LASTEXITCODE -ne 0) {
            throw "git status failed for source readiness evidence: $($definition.Name)"
        }
        $changedPathCount += $statusLines.Count

        $changedFiles = @(
            & git -C $definition.Path -c core.quotePath=false `
                ls-files --modified --others --exclude-standard 2>$null |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        )
        if ($LASTEXITCODE -ne 0) {
            throw "git ls-files failed for source readiness evidence: $($definition.Name)"
        }
        foreach ($relativePath in $changedFiles) {
            $fullPath = Join-Path $definition.Path ([string]$relativePath)
            if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
                $sourcePaths.Add([System.IO.Path]::GetFullPath($fullPath)) | Out-Null
            }
        }
    }

    [pscustomobject]@{
        ChangedPathCount = $changedPathCount
        SourcePaths = @($sourcePaths)
    }
}

function Get-FinalPackageContractStatus {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 'BLOCKED: FINAL_GO_NO_GO_PACKAGE.md is missing'
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $requiredTokens = @(
        '<!-- dimax-release-index:v1 -->',
        'artifacts/release/release-status-latest.md',
        'artifacts/release/source-readiness-latest.md',
        'artifacts/release/dependency-audit-latest.md',
        '.\workspace.cmd release-status',
        '.\workspace.cmd source-readiness',
        'POST_DEPLOY_SMOKE.md'
    )
    $missingTokens = @($requiredTokens | Where-Object { -not $content.Contains($_) })
    if ($missingTokens.Count -gt 0) {
        return "BLOCKED: final package index is incomplete: $($missingTokens -join ', ')"
    }

    if ($content -match '(?<![A-Za-z0-9])\d{1,3}%') {
        return 'BLOCKED: final package duplicates a dynamic readiness percentage'
    }

    return 'PASS: static index points to the generated release decision'
}

function Get-ProductionMaturityContractStatus {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 'BLOCKED: FINAL_PRODUCTION_MATURITY_READINESS.md is missing'
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $requiredTokens = @(
        '<!-- dimax-production-maturity-index:v1 -->',
        'artifacts/release/release-status-latest.md',
        'artifacts/release/source-readiness-latest.md',
        'artifacts/release/dependency-audit-latest.md',
        'FINAL_GO_NO_GO_PACKAGE.md',
        'PRODUCTION_ENV_REQUIRED_VALUES.md',
        'POST_DEPLOY_SMOKE.md'
    )
    $missingTokens = @($requiredTokens | Where-Object { -not $content.Contains($_) })
    if ($missingTokens.Count -gt 0) {
        return "BLOCKED: production maturity index is incomplete: $($missingTokens -join ', ')"
    }

    if ($content -match '(?<![A-Za-z0-9])\d{1,3}%') {
        return 'BLOCKED: production maturity index duplicates a dynamic readiness percentage'
    }
    if ($content -match '(?<![A-Fa-f0-9])[A-Fa-f0-9]{40,64}(?![A-Fa-f0-9])') {
        return 'BLOCKED: production maturity index duplicates a source or artifact digest'
    }
    if ($content -match '(?i)(?<![A-Za-z0-9])\d+\s+(tests?|test files|routes)(?![A-Za-z0-9])') {
        return 'BLOCKED: production maturity index duplicates a dynamic verification count'
    }

    return 'PASS: static maturity index points to generated release evidence'
}

function Invoke-ReleaseStatusSelfTest {
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("dimax-release-status-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    try {
        $validPath = Join-Path $tempDir 'valid.md'
        @(
            '<!-- dimax-release-index:v1 -->',
            'artifacts/release/release-status-latest.md',
            'artifacts/release/source-readiness-latest.md',
            'artifacts/release/dependency-audit-latest.md',
            '.\workspace.cmd release-status',
            '.\workspace.cmd source-readiness',
            'POST_DEPLOY_SMOKE.md'
        ) | Set-Content -LiteralPath $validPath -Encoding UTF8
        $validStatus = Get-FinalPackageContractStatus -Path $validPath
        if ($validStatus -notlike 'PASS:*') {
            throw "Valid final package contract was rejected: $validStatus"
        }

        $stalePath = Join-Path $tempDir 'stale.md'
        (Get-Content -LiteralPath $validPath -Raw) + "`nProduction readiness: 99%" |
            Set-Content -LiteralPath $stalePath -Encoding UTF8
        $staleStatus = Get-FinalPackageContractStatus -Path $stalePath
        if ($staleStatus -notlike 'BLOCKED:*') {
            throw "Stale final package contract was accepted: $staleStatus"
        }

        $missingStatus = Get-FinalPackageContractStatus -Path (Join-Path $tempDir 'missing.md')
        if ($missingStatus -notlike 'BLOCKED:*') {
            throw "Missing final package contract was accepted: $missingStatus"
        }

        $validMaturityPath = Join-Path $tempDir 'valid-maturity.md'
        @(
            '<!-- dimax-production-maturity-index:v1 -->',
            'artifacts/release/release-status-latest.md',
            'artifacts/release/source-readiness-latest.md',
            'artifacts/release/dependency-audit-latest.md',
            'FINAL_GO_NO_GO_PACKAGE.md',
            'PRODUCTION_ENV_REQUIRED_VALUES.md',
            'POST_DEPLOY_SMOKE.md'
        ) | Set-Content -LiteralPath $validMaturityPath -Encoding UTF8
        $validMaturityStatus = Get-ProductionMaturityContractStatus -Path $validMaturityPath
        if ($validMaturityStatus -notlike 'PASS:*') {
            throw "Valid production maturity contract was rejected: $validMaturityStatus"
        }

        $staleMaturitySamples = @(
            'Production readiness: 95%',
            ('Source: ' + ('a' * 40)),
            'Mobile quality gate: 162 tests'
        )
        foreach ($sample in $staleMaturitySamples) {
            $staleMaturityPath = Join-Path $tempDir (([guid]::NewGuid().ToString('N')) + '.md')
            (Get-Content -LiteralPath $validMaturityPath -Raw) + "`n$sample" |
                Set-Content -LiteralPath $staleMaturityPath -Encoding UTF8
            $staleMaturityStatus = Get-ProductionMaturityContractStatus -Path $staleMaturityPath
            if ($staleMaturityStatus -notlike 'BLOCKED:*') {
                throw "Stale production maturity contract was accepted: $sample"
            }
        }

        $missingMaturityStatus = Get-ProductionMaturityContractStatus `
            -Path (Join-Path $tempDir 'missing-maturity.md')
        if ($missingMaturityStatus -notlike 'BLOCKED:*') {
            throw "Missing production maturity contract was accepted: $missingMaturityStatus"
        }

        $cleanSourceStatus = Get-SourceSnapshotDecision -Repositories @(
            [pscustomobject]@{
                Name = 'workspace'; Head = ('a' * 40); ChangedCount = 0
                Upstream = 'origin/feature'; AheadCount = 0; BehindCount = 0
            },
            [pscustomobject]@{
                Name = 'backend'; Head = ('b' * 40); ChangedCount = 0
                Upstream = 'origin/feature'; AheadCount = 0; BehindCount = 0
            }
        )
        if ($cleanSourceStatus -notlike 'PASS:*') {
            throw "Clean release source was rejected: $cleanSourceStatus"
        }

        $dirtySourceStatus = Get-SourceSnapshotDecision -Repositories @(
            [pscustomobject]@{
                Name = 'workspace'; Head = ('a' * 40); ChangedCount = 2
                Upstream = 'origin/feature'; AheadCount = 0; BehindCount = 0
            },
            [pscustomobject]@{
                Name = 'backend'; Head = ('b' * 40); ChangedCount = 3
                Upstream = 'origin/feature'; AheadCount = 0; BehindCount = 0
            }
        )
        if ($dirtySourceStatus -notlike 'BLOCKED:*5 changed paths*') {
            throw "Dirty release source was accepted: $dirtySourceStatus"
        }

        $unpushedSourceStatus = Get-SourceSnapshotDecision -Repositories @(
            [pscustomobject]@{
                Name = 'workspace'; Head = ('a' * 40); ChangedCount = 0
                Upstream = 'origin/feature'; AheadCount = 1; BehindCount = 0
            }
        )
        if ($unpushedSourceStatus -notlike 'BLOCKED:*unpushed*') {
            throw "Unpushed release source was accepted: $unpushedSourceStatus"
        }

        $now = [datetimeoffset]::Parse('2026-07-23T12:00:00+00:00')
        $offsetTimestamp = ConvertTo-EvidenceTimestamp -Value '2026-07-23T14:00:00+03:00'
        if ($null -eq $offsetTimestamp -or $offsetTimestamp.ToUniversalTime() -ne $now.AddHours(-1)) {
            throw "Offset evidence timestamp was parsed incorrectly"
        }
        if ($null -ne (ConvertTo-EvidenceTimestamp -Value 'not-a-timestamp')) {
            throw "Invalid evidence timestamp was accepted"
        }
        $sourcePath = Join-Path $tempDir 'source.py'
        'source' | Set-Content -LiteralPath $sourcePath -Encoding UTF8
        (Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc = $now.AddHours(-2).UtcDateTime

        $businessPath = Join-Path $tempDir 'business.json'
        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath $businessPath -Encoding UTF8
        $businessStatus = Get-BusinessSmokeEvidenceStatus `
            -JsonPath $businessPath `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($businessStatus -notlike 'PASS:*') {
            throw "Fresh business evidence was rejected: $businessStatus"
        }

        @{
            status = 'ok'
            checked_at = $now.AddHours(-48).ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath $businessPath -Encoding UTF8
        $staleBusinessStatus = Get-BusinessSmokeEvidenceStatus `
            -JsonPath $businessPath `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($staleBusinessStatus -notlike 'BLOCKED:*stale*') {
            throw "Stale business evidence was accepted: $staleBusinessStatus"
        }

        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath $businessPath -Encoding UTF8
        (Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc = $now.AddMinutes(-30).UtcDateTime
        $olderThanSourceStatus = Get-BusinessSmokeEvidenceStatus `
            -JsonPath $businessPath `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($olderThanSourceStatus -notlike 'BLOCKED:*predates*') {
            throw "Business evidence older than source was accepted: $olderThanSourceStatus"
        }

        (Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc = $now.AddHours(-2).UtcDateTime
        $dependencyPath = Join-Path $tempDir 'dependency-audit.json'
        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
            backend = @{ known_vulnerabilities = 0 }
            admin = @{ critical = 0; high = 0 }
            mobile = @{ critical = 0; high = 0 }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $dependencyPath -Encoding UTF8
        $dependencyStatus = Get-DependencyAuditEvidenceStatus `
            -JsonPath $dependencyPath `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($dependencyStatus -notlike 'PASS:*') {
            throw "Fresh dependency evidence was rejected: $dependencyStatus"
        }

        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
            backend = @{ known_vulnerabilities = 0 }
            admin = @{ critical = 0; high = 0; unmitigated_high_or_critical = 0 }
            mobile = @{
                critical = 0
                high = 6
                unmitigated_high_or_critical = 0
                locally_patched_packages = @('image-size', 'metro')
            }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $dependencyPath -Encoding UTF8
        $locallyPatchedDependencyStatus = Get-DependencyAuditEvidenceStatus `
            -JsonPath $dependencyPath `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($locallyPatchedDependencyStatus -notlike 'PASS:*') {
            throw "Verified locally patched dependency evidence was rejected: $locallyPatchedDependencyStatus"
        }

        $locallyPatchedEvidence = Get-Content -LiteralPath $dependencyPath -Raw | ConvertFrom-Json
        $locallyPatchedEvidence.mobile.unmitigated_high_or_critical = 1
        $locallyPatchedEvidence | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $dependencyPath -Encoding UTF8
        $unmitigatedDependencyStatus = Get-DependencyAuditEvidenceStatus `
            -JsonPath $dependencyPath `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($unmitigatedDependencyStatus -notlike 'BLOCKED:*vulnerabilities*') {
            throw "Unmitigated dependency evidence was accepted: $unmitigatedDependencyStatus"
        }

        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
            backend = @{ known_vulnerabilities = 0 }
            admin = @{ critical = 0; high = 1 }
            mobile = @{ critical = 0; high = 0 }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $dependencyPath -Encoding UTF8
        $vulnerableDependencyStatus = Get-DependencyAuditEvidenceStatus `
            -JsonPath $dependencyPath `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($vulnerableDependencyStatus -notlike 'BLOCKED:*vulnerabilities*') {
            throw "Vulnerable dependency evidence was accepted: $vulnerableDependencyStatus"
        }

        $sourceReadinessPath = Join-Path $tempDir 'source-readiness.json'
        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
            total_changed_paths = 1
            source_fingerprint = ('a' * 64)
            large_files = @()
            risky_paths = @()
            issues = @()
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sourceReadinessPath -Encoding UTF8
        $sourceReadinessStatus = Get-SourceReadinessEvidenceStatus `
            -JsonPath $sourceReadinessPath `
            -SourcePaths @($sourcePath) `
            -CurrentChangedPathCount 1 `
            -Now $now
        if ($sourceReadinessStatus -notlike 'PASS:*') {
            throw "Fresh source readiness evidence was rejected: $sourceReadinessStatus"
        }

        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
            total_changed_paths = 0
            source_fingerprint = ('d' * 64)
            large_files = @()
            risky_paths = @()
            issues = @()
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sourceReadinessPath -Encoding UTF8
        $cleanTreeReadinessStatus = Get-SourceReadinessEvidenceStatus `
            -JsonPath $sourceReadinessPath `
            -SourcePaths @() `
            -CurrentChangedPathCount 0 `
            -Now $now
        if ($cleanTreeReadinessStatus -notlike 'PASS:*') {
            throw "Clean-tree source readiness evidence was rejected: $cleanTreeReadinessStatus"
        }

        $invalidFingerprintEvidence = Get-Content -LiteralPath $sourceReadinessPath -Raw | ConvertFrom-Json
        $invalidFingerprintEvidence.source_fingerprint = 'not-a-sha256'
        $invalidFingerprintEvidence | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sourceReadinessPath -Encoding UTF8
        $invalidFingerprintStatus = Get-SourceReadinessEvidenceStatus `
            -JsonPath $sourceReadinessPath `
            -SourcePaths @($sourcePath) `
            -CurrentChangedPathCount 1 `
            -Now $now
        if ($invalidFingerprintStatus -notlike 'BLOCKED:*fingerprint*') {
            throw "Invalid source fingerprint was accepted: $invalidFingerprintStatus"
        }

        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
            total_changed_paths = 1
            source_fingerprint = ('b' * 64)
            large_files = @()
            risky_paths = @(@{ repository = 'mobile'; path = 'release.jks' })
            issues = @('risky path')
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sourceReadinessPath -Encoding UTF8
        $unsafeSourceReadinessStatus = Get-SourceReadinessEvidenceStatus `
            -JsonPath $sourceReadinessPath `
            -SourcePaths @($sourcePath) `
            -CurrentChangedPathCount 1 `
            -Now $now
        if ($unsafeSourceReadinessStatus -notlike 'BLOCKED:*unsafe*') {
            throw "Unsafe source readiness evidence was accepted: $unsafeSourceReadinessStatus"
        }

        @{
            status = 'ok'
            checked_at = $now.AddHours(-1).ToString('o')
            total_changed_paths = 1
            source_fingerprint = ('c' * 64)
            large_files = @()
            risky_paths = @()
            issues = @()
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sourceReadinessPath -Encoding UTF8
        (Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc = $now.AddMinutes(-30).UtcDateTime
        $staleSourceReadinessStatus = Get-SourceReadinessEvidenceStatus `
            -JsonPath $sourceReadinessPath `
            -SourcePaths @($sourcePath) `
            -CurrentChangedPathCount 1 `
            -Now $now
        if ($staleSourceReadinessStatus -notlike 'BLOCKED:*predates*') {
            throw "Stale source readiness evidence was accepted: $staleSourceReadinessStatus"
        }
        (Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc = $now.AddHours(-2).UtcDateTime

        $visualRoot = Join-Path $tempDir 'visual'
        $visualRun = Join-Path $visualRoot 'run'
        New-Item -ItemType Directory -Path $visualRun -Force | Out-Null
        $requiredScreenshots = @(Get-RequiredVisualBrandScreenshotNames)
        foreach ($name in $requiredScreenshots) {
            $screenPath = Join-Path $visualRun $name
            'png' | Set-Content -LiteralPath $screenPath -Encoding UTF8
            (Get-Item -LiteralPath $screenPath).LastWriteTimeUtc = $now.AddHours(-1).UtcDateTime
        }
        $visualStatus = Get-VisualBrandEvidenceStatus `
            -RootPath $visualRoot `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($visualStatus -notlike 'PASS:*') {
            throw "Complete visual evidence was rejected: $visualStatus"
        }

        Remove-Item -LiteralPath (Join-Path $visualRun 'login-desktop.png') -Force
        $incompleteVisualStatus = Get-VisualBrandEvidenceStatus `
            -RootPath $visualRoot `
            -SourcePaths @($sourcePath) `
            -Now $now
        if ($incompleteVisualStatus -notlike 'BLOCKED:*incomplete*') {
            throw "Incomplete visual evidence was accepted: $incompleteVisualStatus"
        }

        $cleanHandoffContainers = @(Get-UnexpectedStoppedContainers `
            -Containers @(
                'dimaxoperationssuite-admin-1|Exited (143) 10 seconds ago',
                'dimaxoperationssuite-minio_init-1|Exited (0) 10 seconds ago',
                'unrelated-project-api-1|Exited (1) 10 seconds ago'
            ) `
            -AdminBuildExists $false)
        if ($cleanHandoffContainers.Count -ne 0) {
            throw "Clean handoff containers were treated as unexpected: $($cleanHandoffContainers -join ', ')"
        }

        $stoppedBuiltAdmin = @(Get-UnexpectedStoppedContainers `
            -Containers @('dimaxoperationssuite-admin-1|Exited (143) 10 seconds ago') `
            -AdminBuildExists $true)
        if ($stoppedBuiltAdmin.Count -ne 1) {
            throw 'Stopped admin with an available build was not reported.'
        }

        $stoppedApi = @(Get-UnexpectedStoppedContainers `
            -Containers @('dimaxoperationssuite-api-1|Exited (1) 10 seconds ago') `
            -AdminBuildExists $false)
        if ($stoppedApi.Count -ne 1) {
            throw 'Stopped DIMAX API was not reported.'
        }

        Write-Output 'Release status self-test passed (22 cases).'
    }
    finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-HttpHealth {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8000/health" -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            return "PASS: $($response.Content)"
        }
        return "FAIL: HTTP $($response.StatusCode)"
    }
    catch {
        return "FAIL: $($_.Exception.Message)"
    }
}

function Get-StoppedContainerSummary {
    $containers = @(& docker ps -a --filter "status=exited" --format "{{.Names}}|{{.Status}}")
    if ($LASTEXITCODE -ne 0) {
        return 'UNKNOWN: docker ps failed'
    }
    $adminBuildExists = Test-Path -LiteralPath (Join-Path $AdminDir '.next\BUILD_ID') -PathType Leaf
    $unexpected = @(Get-UnexpectedStoppedContainers `
        -Containers $containers `
        -AdminBuildExists $adminBuildExists)
    if ($unexpected.Count -eq 0) {
        return 'PASS: no unexpected stopped DIMAX containers'
    }
    return "WARN: $($unexpected.Count) unexpected stopped DIMAX container(s): $($unexpected -join ', ')"
}

function Get-UnexpectedStoppedContainers {
    param(
        [string[]]$Containers,
        [bool]$AdminBuildExists
    )

    return @($Containers | Where-Object {
        if ([string]::IsNullOrWhiteSpace($_)) {
            return $false
        }
        if ($_ -notmatch '^(dimaxoperationssuite|dimaxoperationssuite_test|backend)-') {
            return $false
        }
        if ($_ -match '^dimaxoperationssuite-minio_init-1\|Exited \(0\)') {
            return $false
        }
        if (
            -not $AdminBuildExists -and
            $_ -match '^dimaxoperationssuite-admin-1\|Exited \(143\)'
        ) {
            return $false
        }
        return $true
    })
}

function Get-ProductionEnvStatus {
    $backendEnv = Find-FirstExistingPath -Candidates @(
        (Join-Path $BackendDir ".env.production.local"),
        (Join-Path $BackendDir ".env.production")
    )
    $adminEnv = Find-FirstExistingPath -Candidates @(
        (Join-Path $AdminDir ".env.production.local"),
        (Join-Path $AdminDir ".env.production")
    )
    $mobileEnv = Find-FirstExistingPath -Candidates @(
        (Join-Path $MobileDir ".env.production.local"),
        (Join-Path $MobileDir ".env.production")
    )

    $missingAreas = @()
    if (-not $backendEnv) { $missingAreas += "backend" }
    if (-not $adminEnv) { $missingAreas += "admin" }
    if (-not $mobileEnv) { $missingAreas += "mobile" }
    if ($missingAreas.Count -gt 0) {
        return "BLOCKED: production env files are missing: $($missingAreas -join ', ')"
    }

    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "workspace.ps1") check-production-env 2>&1
    if ($LASTEXITCODE -eq 0) {
        return "PASS: backend/admin/mobile production env files are valid"
    }

    $message = (($output | Out-String).Trim() -split "\r?\n" | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = "validation failed"
    }
    return "BLOCKED: $message"
}

function Get-AndroidReleaseConfigStatus {
    $appConfigPath = Join-Path $MobileDir 'app.json'
    $buildGradlePath = Join-Path $MobileDir 'android\app\build.gradle'
    $runtimeConfigPath = Join-Path $MobileDir 'src\lib\config.ts'
    $validatorPath = Join-Path $MobileDir 'scripts\validate-production-config.mjs'
    $packageRoot = Join-Path $MobileDir 'android\app\src\main\java\com\dimax\operations\installer'

    if (
        -not (Test-Path -LiteralPath $appConfigPath) -or
        -not (Test-Path -LiteralPath $buildGradlePath) -or
        -not (Test-Path -LiteralPath $runtimeConfigPath) -or
        -not (Test-Path -LiteralPath $validatorPath)
    ) {
        return 'BLOCKED: Android release configuration files are missing'
    }

    try {
        $appConfig = Get-Content -LiteralPath $appConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        return 'BLOCKED: mobile/app.json is not valid JSON'
    }

    if ([string]$appConfig.expo.android.package -ne 'com.dimax.operations.installer') {
        return 'BLOCKED: Android application ID must be com.dimax.operations.installer'
    }

    $extraProperty = $appConfig.expo.PSObject.Properties['extra']
    if ($null -ne $extraProperty) {
        $apiBaseProperty = $extraProperty.Value.PSObject.Properties['apiBaseUrl']
        if ($null -ne $apiBaseProperty -and [string]$apiBaseProperty.Value -match '(?i)localhost|127\.0\.0\.1|0\.0\.0\.0') {
            return 'BLOCKED: mobile/app.json contains a local release API fallback'
        }
    }

    $buildGradle = Get-Content -LiteralPath $buildGradlePath -Raw
    if ($buildGradle -match '(?ms)^\s{4}buildTypes\s*\{.*?^\s{8}release\s*\{(?:(?!^\s{8}\}).)*signingConfig\s+signingConfigs\.debug') {
        return 'BLOCKED: Android release build still uses debug signing'
    }

    $requiredTokens = @(
        'signingConfig signingConfigs.release',
        'DIMAX_ANDROID_KEYSTORE_FILE',
        'DIMAX_ANDROID_KEYSTORE_PASSWORD',
        'DIMAX_ANDROID_KEY_ALIAS',
        'DIMAX_ANDROID_KEY_PASSWORD',
        'EXPO_PUBLIC_API_BASE_URL'
    )
    $missingTokens = @($requiredTokens | Where-Object { -not $buildGradle.Contains($_) })
    if ($missingTokens.Count -gt 0) {
        return "BLOCKED: Android release guard is incomplete: $($missingTokens -join ', ')"
    }

    $runtimeConfig = Get-Content -LiteralPath $runtimeConfigPath -Raw
    if (-not $runtimeConfig.Contains('resolveApiBaseUrl(process.env.EXPO_PUBLIC_API_BASE_URL')) {
        return 'BLOCKED: mobile runtime API URL is not resolved through the production guard'
    }

    foreach ($sourceName in @('MainActivity.kt', 'MainApplication.kt')) {
        $sourcePath = Join-Path $packageRoot $sourceName
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            return "BLOCKED: Android package source is missing: $sourceName"
        }
        if ((Get-Content -LiteralPath $sourcePath -Raw) -notmatch '^package com\.dimax\.operations\.installer') {
            return "BLOCKED: Android package declaration is invalid: $sourceName"
        }
    }

    return 'PASS: application ID, release signing, and production API guards are configured'
}

function Get-AndroidSigningEnvStatus {
    $requiredNames = @(
        'DIMAX_ANDROID_KEYSTORE_FILE',
        'DIMAX_ANDROID_KEYSTORE_PASSWORD',
        'DIMAX_ANDROID_KEY_ALIAS',
        'DIMAX_ANDROID_KEY_PASSWORD'
    )
    $missingNames = @($requiredNames | Where-Object {
        [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
    })
    if ($missingNames.Count -gt 0) {
        return "BLOCKED: Android signing environment is missing: $($missingNames -join ', ')"
    }

    $keystorePath = [Environment]::GetEnvironmentVariable('DIMAX_ANDROID_KEYSTORE_FILE')
    if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
        return 'BLOCKED: DIMAX_ANDROID_KEYSTORE_FILE is not a readable file'
    }

    return 'PASS: Android signing environment and keystore are available'
}

function Get-AndroidQaStatus {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "android-qa-report.ps1") -NoWrite
    if ($LASTEXITCODE -ne 0) {
        return "BLOCKED: android-qa-report failed"
    }

    $statusLine = @($output | Where-Object { $_ -like "- Status:*" } | Select-Object -First 1)
    if ($statusLine.Count -eq 0) {
        return "UNKNOWN: Android QA status line was not found"
    }
    if ($statusLine[0] -match '`PASS`') {
        return "PASS: Android device proof is complete"
    }
    return "BLOCKED: Android device proof is not complete"
}

function Get-LatestArtifactStatus {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $path = Join-Path $WorkspaceRoot $RelativePath
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        return "$Label`: PRESENT ($($item.LastWriteTime))"
    }
    return "$Label`: MISSING"
}

function Get-LatestArtifactDirectoryStatus {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $path = Join-Path $WorkspaceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return "$Label`: MISSING"
    }

    $latest = Get-ChildItem -LiteralPath $path -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        return "$Label`: MISSING"
    }

    return "$Label`: PRESENT ($($latest.LastWriteTime))"
}

function Get-LatestSourceWriteTime {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Paths
    )

    $latest = [datetime]::MinValue
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $item = Get-Item -LiteralPath $path
        $candidates = if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -File -Recurse -ErrorAction SilentlyContinue
        }
        else {
            @($item)
        }
        foreach ($candidate in $candidates) {
            if ($candidate.LastWriteTimeUtc -gt $latest) {
                $latest = $candidate.LastWriteTimeUtc
            }
        }
    }
    return $latest
}

function Get-BusinessSmokeEvidenceStatus {
    param(
        [Parameter(Mandatory = $true)][string]$JsonPath,
        [Parameter(Mandatory = $true)][string[]]$SourcePaths,
        [datetimeoffset]$Now = [datetimeoffset]::Now,
        [timespan]$MaxAge = [timespan]::FromHours(24)
    )

    if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) {
        return 'BLOCKED: business smoke evidence is missing'
    }

    try {
        $evidence = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
    }
    catch {
        return 'BLOCKED: business smoke evidence is not valid JSON'
    }

    if ([string]$evidence.status -notin @('ok', 'PASS')) {
        return "BLOCKED: business smoke status is '$($evidence.status)'"
    }

    $checkedAt = ConvertTo-EvidenceTimestamp -Value $evidence.checked_at
    if ($null -eq $checkedAt) {
        return 'BLOCKED: business smoke checked_at is invalid'
    }
    $age = $Now.ToUniversalTime() - $checkedAt.ToUniversalTime()
    if ($age -lt [timespan]::FromMinutes(-5)) {
        return 'BLOCKED: business smoke evidence timestamp is in the future'
    }
    if ($age -gt $MaxAge) {
        return "BLOCKED: business smoke evidence is stale ($([math]::Floor($age.TotalHours))h old)"
    }

    $latestSourceWrite = Get-LatestSourceWriteTime -Paths $SourcePaths
    if (
        $latestSourceWrite -ne [datetime]::MinValue -and
        $checkedAt.UtcDateTime -lt $latestSourceWrite
    ) {
        return 'BLOCKED: business smoke evidence predates backend or smoke-source changes'
    }

    return "PASS: business smoke status ok at $($checkedAt.ToString('u'))"
}

function Get-NpmReleaseBlockingCount {
    param([Parameter(Mandatory = $true)]$Area)

    $unmitigatedProperty = $Area.PSObject.Properties['unmitigated_high_or_critical']
    if ($null -ne $unmitigatedProperty) {
        return [int]$unmitigatedProperty.Value
    }
    return [int]$Area.critical + [int]$Area.high
}

function Get-DependencyAuditEvidenceStatus {
    param(
        [Parameter(Mandatory = $true)][string]$JsonPath,
        [Parameter(Mandatory = $true)][string[]]$SourcePaths,
        [datetimeoffset]$Now = [datetimeoffset]::Now,
        [timespan]$MaxAge = [timespan]::FromHours(24)
    )

    if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) {
        return 'BLOCKED: dependency audit evidence is missing'
    }

    try {
        $evidence = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
        $backendVulnerabilities = [int]$evidence.backend.known_vulnerabilities
        $adminCritical = [int]$evidence.admin.critical
        $adminHigh = [int]$evidence.admin.high
        $mobileCritical = [int]$evidence.mobile.critical
        $mobileHigh = [int]$evidence.mobile.high
        $adminBlocking = Get-NpmReleaseBlockingCount -Area $evidence.admin
        $mobileBlocking = Get-NpmReleaseBlockingCount -Area $evidence.mobile
    }
    catch {
        return 'BLOCKED: dependency audit evidence is not valid JSON'
    }

    if ([string]$evidence.status -ne 'ok') {
        return "BLOCKED: dependency audit status is '$($evidence.status)'"
    }
    if (
        $backendVulnerabilities -ne 0 -or
        $adminBlocking -ne 0 -or
        $mobileBlocking -ne 0
    ) {
        return 'BLOCKED: dependency audit reports release-blocking vulnerabilities'
    }

    $checkedAt = ConvertTo-EvidenceTimestamp -Value $evidence.checked_at
    if ($null -eq $checkedAt) {
        return 'BLOCKED: dependency audit checked_at is invalid'
    }
    $age = $Now.ToUniversalTime() - $checkedAt.ToUniversalTime()
    if ($age -lt [timespan]::FromMinutes(-5)) {
        return 'BLOCKED: dependency audit evidence timestamp is in the future'
    }
    if ($age -gt $MaxAge) {
        return "BLOCKED: dependency audit evidence is stale ($([math]::Floor($age.TotalHours))h old)"
    }

    $latestSourceWrite = Get-LatestSourceWriteTime -Paths $SourcePaths
    if (
        $latestSourceWrite -ne [datetime]::MinValue -and
        $checkedAt.UtcDateTime -lt $latestSourceWrite
    ) {
        return 'BLOCKED: dependency audit evidence predates dependency manifest changes'
    }

    return "PASS: backend/admin/mobile release dependency policy passed at $($checkedAt.ToString('u'))"
}

function Get-SourceReadinessEvidenceStatus {
    param(
        [Parameter(Mandatory = $true)][string]$JsonPath,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$SourcePaths,
        [Parameter(Mandatory = $true)][int]$CurrentChangedPathCount,
        [datetimeoffset]$Now = [datetimeoffset]::Now,
        [timespan]$MaxAge = [timespan]::FromHours(24)
    )

    if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) {
        return 'BLOCKED: source readiness evidence is missing'
    }

    try {
        $evidence = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
        $evidenceChangedPathCount = [int]$evidence.total_changed_paths
        $fingerprintProperty = $evidence.PSObject.Properties['source_fingerprint']
        $sourceFingerprint = if ($null -ne $fingerprintProperty) {
            ([string]$fingerprintProperty.Value).ToLowerInvariant()
        }
        else {
            ''
        }
        $largeFileCount = @($evidence.large_files).Count
        $riskyPathCount = @($evidence.risky_paths).Count
        $issueCount = @($evidence.issues).Count
    }
    catch {
        return 'BLOCKED: source readiness evidence is not valid JSON'
    }

    if ([string]$evidence.status -ne 'ok') {
        return "BLOCKED: source readiness status is '$($evidence.status)'"
    }
    if ($sourceFingerprint -notmatch '^[0-9a-f]{64}$') {
        return 'BLOCKED: source readiness fingerprint is missing or invalid'
    }
    if ($largeFileCount -ne 0 -or $riskyPathCount -ne 0 -or $issueCount -ne 0) {
        return 'BLOCKED: source readiness reports unsafe changed files'
    }
    if ($evidenceChangedPathCount -ne $CurrentChangedPathCount) {
        return "BLOCKED: source readiness changed-path count is stale ($evidenceChangedPathCount vs $CurrentChangedPathCount)"
    }

    $checkedAt = ConvertTo-EvidenceTimestamp -Value $evidence.checked_at
    if ($null -eq $checkedAt) {
        return 'BLOCKED: source readiness checked_at is invalid'
    }
    $age = $Now.ToUniversalTime() - $checkedAt.ToUniversalTime()
    if ($age -lt [timespan]::FromMinutes(-5)) {
        return 'BLOCKED: source readiness evidence timestamp is in the future'
    }
    if ($age -gt $MaxAge) {
        return "BLOCKED: source readiness evidence is stale ($([math]::Floor($age.TotalHours))h old)"
    }

    $latestSourceWrite = Get-LatestSourceWriteTime -Paths $SourcePaths
    if (
        $latestSourceWrite -ne [datetime]::MinValue -and
        $checkedAt.UtcDateTime -lt $latestSourceWrite
    ) {
        return 'BLOCKED: source readiness evidence predates changed source files'
    }

    return "PASS: changed source snapshot $($sourceFingerprint.Substring(0, 12)) passed boundary, size, path, whitespace, and secret checks at $($checkedAt.ToString('u'))"
}

function Get-RequiredVisualBrandScreenshotNames {
    $routes = @(
        'login',
        'admin-dashboard',
        'admin-projects',
        'admin-installers',
        'admin-documents',
        'admin-operations',
        'admin-reports',
        'admin-door-types',
        'admin-reasons',
        'installer-workspace',
        'installer-earnings',
        'installer-issues',
        'installer-sync-queue'
    )

    foreach ($route in $routes) {
        foreach ($viewport in @('desktop', 'mobile')) {
            Write-Output "$route-$viewport.png"
        }
    }
}

function Get-VisualBrandEvidenceStatus {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string[]]$SourcePaths,
        [datetimeoffset]$Now = [datetimeoffset]::Now,
        [timespan]$MaxAge = [timespan]::FromHours(24)
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return 'BLOCKED: visual brand evidence directory is missing'
    }

    $latest = Get-ChildItem -LiteralPath $RootPath -Directory |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        return 'BLOCKED: visual brand evidence is missing'
    }

    $requiredFiles = @(Get-RequiredVisualBrandScreenshotNames)
    $missingFiles = @($requiredFiles | Where-Object {
        $candidate = Join-Path $latest.FullName $_
        -not (Test-Path -LiteralPath $candidate -PathType Leaf) -or
        (Get-Item -LiteralPath $candidate).Length -eq 0
    })
    if ($missingFiles.Count -gt 0) {
        return "BLOCKED: visual brand evidence is incomplete: $($missingFiles -join ', ')"
    }

    $latestEvidenceWrite = (
        Get-ChildItem -LiteralPath $latest.FullName -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    ).LastWriteTimeUtc
    $age = $Now.ToUniversalTime().UtcDateTime - $latestEvidenceWrite
    if ($age -lt [timespan]::FromMinutes(-5)) {
        return 'BLOCKED: visual brand evidence timestamp is in the future'
    }
    if ($age -gt $MaxAge) {
        return "BLOCKED: visual brand evidence is stale ($([math]::Floor($age.TotalHours))h old)"
    }

    $latestSourceWrite = Get-LatestSourceWriteTime -Paths $SourcePaths
    if (
        $latestSourceWrite -ne [datetime]::MinValue -and
        $latestEvidenceWrite -lt $latestSourceWrite
    ) {
        return 'BLOCKED: visual brand evidence predates admin UI or browser-test changes'
    }

    return "PASS: $($requiredFiles.Count) required screenshots captured at $($latestEvidenceWrite.ToString('u'))"
}

function Get-HygieneStatus {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "workspace.ps1") hygiene-check report
    if ($LASTEXITCODE -ne 0) {
        return "FAIL: hygiene-check failed"
    }
    if (($output | Out-String) -match "passed") {
        return "PASS: no generated build/test artifacts found"
    }
    return "WARN: review hygiene-check output"
}

if ($SelfTest) {
    Invoke-ReleaseStatusSelfTest
    return
}

$generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$healthStatus = Get-HttpHealth
$dockerStatus = Get-StoppedContainerSummary
$hygieneStatus = Get-HygieneStatus
$releaseSourceStatus = Get-ReleaseSourceStatus
$sourceReadinessStatus = try {
    $sourceControlEvidenceInputs = Get-SourceControlEvidenceInputs
    Get-SourceReadinessEvidenceStatus `
        -JsonPath (Join-Path $ReleaseDir 'source-readiness-latest.json') `
        -SourcePaths @($sourceControlEvidenceInputs.SourcePaths) `
        -CurrentChangedPathCount $sourceControlEvidenceInputs.ChangedPathCount
}
catch {
    "BLOCKED: source readiness state could not be evaluated: $($_.Exception.Message)"
}
$finalPackageStatus = Get-FinalPackageContractStatus -Path $FinalPackagePath
$productionMaturityStatus = Get-ProductionMaturityContractStatus -Path $ProductionMaturityPath
$productionEnvStatus = Get-ProductionEnvStatus
$androidReleaseConfigStatus = Get-AndroidReleaseConfigStatus
$androidSigningEnvStatus = Get-AndroidSigningEnvStatus
$androidQaStatus = Get-AndroidQaStatus
$businessSmokeStatus = Get-BusinessSmokeEvidenceStatus `
    -JsonPath (Join-Path $ReleaseDir 'business-smoke-latest.json') `
    -SourcePaths @(
        (Join-Path $BackendDir 'app'),
        (Join-Path $BackendDir 'alembic'),
        (Join-Path $PSScriptRoot 'dimax_business_smoke.py'),
        (Join-Path $WorkspaceRoot 'docker-compose.workspace.yml')
    )
$dependencyAuditStatus = Get-DependencyAuditEvidenceStatus `
    -JsonPath (Join-Path $ReleaseDir 'dependency-audit-latest.json') `
    -SourcePaths @(
        (Join-Path $BackendDir 'requirements.txt'),
        (Join-Path $BackendDir 'constraints.txt'),
        (Join-Path $BackendDir 'requirements-audit.txt'),
        (Join-Path $BackendDir 'Dockerfile'),
        (Join-Path $AdminDir 'package.json'),
        (Join-Path $AdminDir 'package-lock.json'),
        (Join-Path $MobileDir 'package.json'),
        (Join-Path $MobileDir 'package-lock.json'),
        (Join-Path $MobileDir 'scripts\patch-image-size.mjs'),
        (Join-Path $PSScriptRoot 'dependency-audit.ps1')
    )
$changeReportStatus = Get-LatestArtifactStatus -RelativePath "artifacts\release\change-report-latest.md" -Label "Change report"
$androidReportStatus = Get-LatestArtifactStatus -RelativePath "artifacts\release\android-qa-report-latest.md" -Label "Android QA report"
$visualBrandStatus = Get-VisualBrandEvidenceStatus `
    -RootPath (Join-Path $WorkspaceRoot 'artifacts\visual-brand') `
    -SourcePaths @(
        (Join-Path $AdminDir 'app'),
        (Join-Path $AdminDir 'src'),
        (Join-Path $AdminDir 'e2e'),
        (Join-Path $AdminDir 'scripts\visual-brand-smoke.mjs'),
        (Join-Path $AdminDir 'package.json'),
        (Join-Path $AdminDir 'next.config.mjs'),
        (Join-Path $AdminDir 'tailwind.config.ts')
    )

$productionBlocked = $productionEnvStatus -like "BLOCKED:*" -or
    $androidSigningEnvStatus -like "BLOCKED:*" -or
    $androidQaStatus -like "BLOCKED:*"
$releaseSourceBlocked = $releaseSourceStatus -like "BLOCKED:*"
$codeBlocked = $healthStatus -like "FAIL:*" -or
    $hygieneStatus -like "FAIL:*" -or
    $sourceReadinessStatus -like "BLOCKED:*" -or
    $finalPackageStatus -like "BLOCKED:*" -or
    $productionMaturityStatus -like "BLOCKED:*" -or
    $androidReleaseConfigStatus -like "BLOCKED:*" -or
    $dependencyAuditStatus -like "BLOCKED:*" -or
    $businessSmokeStatus -like "BLOCKED:*" -or
    $visualBrandStatus -like "BLOCKED:*"
$overall = if ($codeBlocked) {
    "CODE NO-GO"
}
elseif ($releaseSourceBlocked) {
    "CODE GO / RELEASE SOURCE NO-GO / PRODUCTION NO-GO"
}
elseif ($productionBlocked) {
    "CODE GO / STAGING GO / PRODUCTION NO-GO"
}
else {
    "AUTOMATED GATES GO / WAIT FOR POST-DEPLOY SMOKE"
}
$codeReadiness = if ($codeBlocked) { "BLOCKED" } else { "100%" }
$productionReadiness = if ($codeBlocked) {
    'BLOCKED'
}
elseif ($releaseSourceBlocked) {
    '90%'
}
elseif ($productionBlocked) {
    '95%'
}
else {
    '99%'
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# DIMAX Release Status") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Generated at: `{0}`' -f $generatedAt)) | Out-Null
$lines.Add(('- Overall: `{0}`' -f $overall)) | Out-Null
$lines.Add(('- Verified code/staging readiness: `{0}`' -f $codeReadiness)) | Out-Null
$lines.Add(('- Production deployment readiness: `{0}`' -f $productionReadiness)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Automated Status") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Backend health: `{0}`' -f $healthStatus)) | Out-Null
$lines.Add(('- Docker stopped containers: `{0}`' -f $dockerStatus)) | Out-Null
$lines.Add(('- Hygiene: `{0}`' -f $hygieneStatus)) | Out-Null
$lines.Add(('- Source safety: `{0}`' -f $sourceReadinessStatus)) | Out-Null
$lines.Add(('- Release source: `{0}`' -f $releaseSourceStatus)) | Out-Null
$lines.Add(('- Final package contract: `{0}`' -f $finalPackageStatus)) | Out-Null
$lines.Add(('- Production maturity contract: `{0}`' -f $productionMaturityStatus)) | Out-Null
$lines.Add(('- Dependency security: `{0}`' -f $dependencyAuditStatus)) | Out-Null
$lines.Add(('- Production env: `{0}`' -f $productionEnvStatus)) | Out-Null
$lines.Add(('- Android release config: `{0}`' -f $androidReleaseConfigStatus)) | Out-Null
$lines.Add(('- Android signing environment: `{0}`' -f $androidSigningEnvStatus)) | Out-Null
$lines.Add(('- Android QA: `{0}`' -f $androidQaStatus)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Evidence") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Business smoke evidence: `{0}`' -f $businessSmokeStatus)) | Out-Null
$lines.Add(('- {0}' -f $changeReportStatus)) | Out-Null
$lines.Add(('- {0}' -f $androidReportStatus)) | Out-Null
$lines.Add(('- Visual brand screenshots: `{0}`' -f $visualBrandStatus)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Next Required Actions") | Out-Null
$lines.Add("") | Out-Null
if ($productionEnvStatus -like "BLOCKED:*") {
    $lines.Add('- Create real backend/admin/mobile production env files and run `.\workspace.cmd check-production-env`.') | Out-Null
}
if ($sourceReadinessStatus -like "BLOCKED:*") {
    $lines.Add('- Run `.\workspace.cmd source-readiness` and resolve any changed-source safety findings.') | Out-Null
}
if ($releaseSourceBlocked) {
    $lines.Add('- Review `change-report-latest.md`, create intentional commits, push all four upstream branches, and rerun release status against synchronized commit SHA values.') | Out-Null
}
if ($finalPackageStatus -like "BLOCKED:*") {
    $lines.Add('- Restore the static final package index and point it to `artifacts/release/release-status-latest.md`.') | Out-Null
}
if ($productionMaturityStatus -like "BLOCKED:*") {
    $lines.Add('- Restore the static production maturity index and remove duplicated percentages, digests, and verification counts.') | Out-Null
}
if ($androidReleaseConfigStatus -like "BLOCKED:*") {
    $lines.Add('- Fix the stable Android application ID, signing, and production API guards.') | Out-Null
}
if ($androidSigningEnvStatus -like "BLOCKED:*") {
    $lines.Add('- Provision the Android release keystore and four `DIMAX_ANDROID_*` signing variables in the release environment.') | Out-Null
}
if ($androidQaStatus -like "BLOCKED:*") {
    $lines.Add('- Run Android device/emulator QA, fill `ANDROID_QA_RESULTS.md`, save evidence, then run `.\workspace.cmd android-qa-report require-pass`.') | Out-Null
}
if ($dependencyAuditStatus -like "BLOCKED:*") {
    $lines.Add('- Fix release-blocking dependency findings and run `.\workspace.cmd dependency-audit`.') | Out-Null
}
if ($businessSmokeStatus -like "BLOCKED:*") {
    $lines.Add('- Run `.\workspace.cmd business-smoke` after the latest backend changes.') | Out-Null
}
if ($visualBrandStatus -like "BLOCKED:*") {
    $lines.Add('- Run `.\workspace.cmd browser-release-smoke` after the latest admin UI changes.') | Out-Null
}
if (-not $productionBlocked -and -not $codeBlocked) {
    $lines.Add("- Run post-deploy smoke on the target environment before declaring production complete.") | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Useful Commands") | Out-Null
$lines.Add("") | Out-Null
$lines.Add('```powershell') | Out-Null
$lines.Add(".\workspace.cmd go-no-go quick") | Out-Null
$lines.Add(".\workspace.cmd source-readiness") | Out-Null
$lines.Add(".\workspace.cmd dependency-audit") | Out-Null
$lines.Add(".\workspace.cmd production-env-report") | Out-Null
$lines.Add(".\workspace.cmd android-qa-report") | Out-Null
$lines.Add(".\workspace.cmd visual-brand-smoke") | Out-Null
$lines.Add(".\workspace.cmd business-smoke") | Out-Null
$lines.Add(".\workspace.cmd change-report") | Out-Null
$lines.Add(".\workspace.cmd hygiene-check") | Out-Null
$lines.Add('```') | Out-Null
$lines.Add("") | Out-Null

$report = $lines -join [Environment]::NewLine
Write-Output $report

if ($NoWrite) {
    return
}

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$reportPath = Join-Path $ReleaseDir "release-status-$stamp.md"
$latestPath = Join-Path $ReleaseDir "release-status-latest.md"
$report | Set-Content -Path $reportPath -Encoding UTF8
$report | Set-Content -Path $latestPath -Encoding UTF8
Write-Host ""
Write-Host "Release status written:"
Write-Host "  $reportPath"
Write-Host "  $latestPath"
