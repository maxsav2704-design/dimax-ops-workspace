param(
    [switch]$NoWrite,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $WorkspaceRoot "artifacts\release"

function Invoke-CapturedStep {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string[]]$CommandArgs,
        [switch]$AllowFailure
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell promotes native stderr to NativeCommandError when
        # ErrorActionPreference is Stop. Release decisions must use exit codes;
        # tools such as pip legitimately emit update notices on stderr.
        $ErrorActionPreference = "Continue"
        $output = & powershell.exe @CommandArgs 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $status = if ($exitCode -eq 0) { "PASS" } elseif ($AllowFailure) { "BLOCKED" } else { "FAIL" }

    [pscustomobject]@{
        Label = $Label
        Status = $status
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Get-FirstMatchingLine {
    param(
        [object[]]$Output,
        [string]$Pattern
    )

    $line = @($Output | Where-Object { [string]$_ -like $Pattern } | Select-Object -First 1)
    if ($line.Count -eq 0) {
        return ""
    }
    return [string]$line[0]
}

function Get-ExternalBlockerLines {
    param([object[]]$ReleaseStatusOutput)

    $blockers = [System.Collections.Generic.List[string]]::new()
    foreach ($label in @('Production env', 'Android signing environment', 'Android QA')) {
        $statusLine = Get-FirstMatchingLine -Output $ReleaseStatusOutput -Pattern "- $label`:*"
        if (-not [string]::IsNullOrWhiteSpace($statusLine) -and $statusLine -match '`BLOCKED:') {
            $normalized = $statusLine.Trim().TrimStart('-').Trim() -replace '`', ''
            $blockers.Add("- $normalized") | Out-Null
        }
    }
    return @($blockers)
}

function Get-InternalBlockerLines {
    param([object[]]$ReleaseStatusOutput)

    $statusLine = Get-FirstMatchingLine -Output $ReleaseStatusOutput -Pattern "- Release source`:*"
    if ([string]::IsNullOrWhiteSpace($statusLine) -or $statusLine -notmatch '`BLOCKED:') {
        return @()
    }

    return @("- " + ($statusLine.Trim().TrimStart('-').Trim() -replace '`', ''))
}

function Invoke-ReleaseHandoffSelfTest {
    $stderrSuccess = Invoke-CapturedStep -Label "stderr-success" -CommandArgs @(
        "-NoProfile",
        "-Command",
        "[Console]::Error.WriteLine('expected stderr notice'); exit 0"
    )
    if ($stderrSuccess.Status -ne "PASS" -or $stderrSuccess.ExitCode -ne 0) {
        throw "A successful native command that writes to stderr must remain PASS"
    }

    $blocked = @(Get-ExternalBlockerLines -ReleaseStatusOutput @(
        '- Production env: `BLOCKED: production env files are missing: backend, admin, mobile`',
        '- Android signing environment: `BLOCKED: signing variables are missing`',
        '- Android QA: `PASS: Android device proof is complete`'
    ))
    if ($blocked.Count -ne 2) {
        throw "Expected 2 external blockers, got $($blocked.Count)"
    }
    if ($blocked[0] -notmatch 'backend, admin, mobile' -or $blocked[1] -notmatch 'signing variables') {
        throw 'External blocker details were not preserved'
    }

    $clear = @(Get-ExternalBlockerLines -ReleaseStatusOutput @(
        '- Production env: `PASS: production env files are valid`',
        '- Android signing environment: `PASS: signing is configured`',
        '- Android QA: `PASS: Android device proof is complete`'
    ))
    if ($clear.Count -ne 0) {
        throw "Expected no external blockers, got $($clear.Count)"
    }

    $internal = @(Get-InternalBlockerLines -ReleaseStatusOutput @(
        '- Release source: `BLOCKED: release source is not immutable: 5 changed paths`'
    ))
    if ($internal.Count -ne 1 -or $internal[0] -notmatch '5 changed paths') {
        throw 'Internal release blocker details were not preserved'
    }

    Write-Output 'Release handoff self-test passed (4 cases).'
}

function Get-ArtifactStatus {
    param([string]$RelativePath)

    $path = Join-Path $WorkspaceRoot $RelativePath
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        return "PRESENT ($($item.LastWriteTime))"
    }
    return "MISSING"
}

function Get-LatestArtifactDirectoryStatus {
    param([string]$RelativePath)

    $path = Join-Path $WorkspaceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return "MISSING"
    }

    $latest = Get-ChildItem -LiteralPath $path -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        return "MISSING"
    }

    return "PRESENT ($($latest.LastWriteTime))"
}

function Get-StepKeyLine {
    param(
        [Parameter(Mandatory = $true)]$Step
    )

    switch ($Step.Label) {
        "change-report" {
            $keyLine = Get-FirstMatchingLine -Output $Step.Output -Pattern "- Total changed paths across repos:*"
            if (-not [string]::IsNullOrWhiteSpace($keyLine)) {
                return $keyLine
            }
        }
    }

    $keyLine = Get-FirstMatchingLine -Output $Step.Output -Pattern "- Status:*"
    if ([string]::IsNullOrWhiteSpace($keyLine)) {
        $keyLine = Get-FirstMatchingLine -Output $Step.Output -Pattern "*passed*"
    }
    if ([string]::IsNullOrWhiteSpace($keyLine)) {
        $keyLine = Get-FirstMatchingLine -Output $Step.Output -Pattern "*BLOCKED*"
    }
    return $keyLine
}

if ($SelfTest) {
    Invoke-ReleaseHandoffSelfTest
    return
}

$scriptBaseArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File")
$steps = [System.Collections.Generic.List[object]]::new()

$steps.Add((Invoke-CapturedStep -Label "hygiene-check" -CommandArgs ($scriptBaseArgs + @((Join-Path $PSScriptRoot "workspace.ps1"), "hygiene-check")))) | Out-Null

$sourceReadinessArgs = $scriptBaseArgs + @((Join-Path $PSScriptRoot "source-readiness.ps1"))
if ($NoWrite) {
    $sourceReadinessArgs += "-NoWrite"
}
$steps.Add((Invoke-CapturedStep -Label "source-readiness" -CommandArgs $sourceReadinessArgs)) | Out-Null

$steps.Add((Invoke-CapturedStep -Label "production-infra" -CommandArgs ($scriptBaseArgs + @((Join-Path $PSScriptRoot "production-infra-contract.ps1"), "-ConfigOnly")))) | Out-Null

$dependencyAuditArgs = $scriptBaseArgs + @((Join-Path $PSScriptRoot "dependency-audit.ps1"))
if ($NoWrite) {
    $dependencyAuditArgs += "-NoWrite"
}
$steps.Add((Invoke-CapturedStep -Label "dependency-audit" -CommandArgs $dependencyAuditArgs)) | Out-Null

$steps.Add((Invoke-CapturedStep -Label "production-env-report" -CommandArgs ($scriptBaseArgs + @((Join-Path $PSScriptRoot "workspace.ps1"), "production-env-report")) -AllowFailure)) | Out-Null

$changeArgs = $scriptBaseArgs + @((Join-Path $PSScriptRoot "change-report.ps1"))
if ($NoWrite) {
    $changeArgs += "-NoWrite"
}
$steps.Add((Invoke-CapturedStep -Label "change-report" -CommandArgs $changeArgs)) | Out-Null

$androidArgs = $scriptBaseArgs + @((Join-Path $PSScriptRoot "android-qa-report.ps1"))
if ($NoWrite) {
    $androidArgs += "-NoWrite"
}
$steps.Add((Invoke-CapturedStep -Label "android-qa-report" -CommandArgs $androidArgs)) | Out-Null

$releaseStatusArgs = $scriptBaseArgs + @((Join-Path $PSScriptRoot "release-status.ps1"))
if ($NoWrite) {
    $releaseStatusArgs += "-NoWrite"
}
$steps.Add((Invoke-CapturedStep -Label "release-status" -CommandArgs $releaseStatusArgs)) | Out-Null

$releaseStatusStep = @($steps | Where-Object { $_.Label -eq "release-status" } | Select-Object -First 1)
$overallLine = if ($releaseStatusStep.Count -gt 0) { Get-FirstMatchingLine -Output $releaseStatusStep[0].Output -Pattern "- Overall:*" } else { "" }
$readinessLine = if ($releaseStatusStep.Count -gt 0) { Get-FirstMatchingLine -Output $releaseStatusStep[0].Output -Pattern "- Product readiness:*" } else { "" }
$externalBlockers = if ($releaseStatusStep.Count -gt 0) {
    @(Get-ExternalBlockerLines -ReleaseStatusOutput $releaseStatusStep[0].Output)
}
else {
    @('- Release status output is unavailable.')
}
$internalBlockers = @(
    if ($releaseStatusStep.Count -gt 0) {
        Get-InternalBlockerLines -ReleaseStatusOutput $releaseStatusStep[0].Output
    }
    else {
        '- Release status output is unavailable.'
    }
)

$generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# DIMAX Release Handoff Bundle") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Generated at: `{0}`' -f $generatedAt)) | Out-Null
if (-not [string]::IsNullOrWhiteSpace($overallLine)) {
    $lines.Add($overallLine) | Out-Null
}
if (-not [string]::IsNullOrWhiteSpace($readinessLine)) {
    $lines.Add($readinessLine) | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Bundle Steps") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| Step | Status | Exit code | Key line |") | Out-Null
$lines.Add("|---|---|---:|---|") | Out-Null
foreach ($step in $steps) {
    $keyLine = Get-StepKeyLine -Step $step
    $keyLine = $keyLine -replace "\|", "\|"
    $lines.Add(("| `{0}` | `{1}` | `{2}` | {3} |" -f $step.Label, $step.Status, $step.ExitCode, $keyLine)) | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Latest Evidence Files") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Business smoke: `{0}`' -f (Get-ArtifactStatus -RelativePath "artifacts\release\business-smoke-latest.md"))) | Out-Null
$lines.Add(('- Source readiness: `{0}`' -f (Get-ArtifactStatus -RelativePath "artifacts\release\source-readiness-latest.md"))) | Out-Null
$lines.Add(('- Change report: `{0}`' -f (Get-ArtifactStatus -RelativePath "artifacts\release\change-report-latest.md"))) | Out-Null
$lines.Add(('- Android QA report: `{0}`' -f (Get-ArtifactStatus -RelativePath "artifacts\release\android-qa-report-latest.md"))) | Out-Null
$lines.Add(('- Visual brand screenshots: `{0}`' -f (Get-LatestArtifactDirectoryStatus -RelativePath "artifacts\visual-brand"))) | Out-Null
$lines.Add(('- Release status: `{0}`' -f (Get-ArtifactStatus -RelativePath "artifacts\release\release-status-latest.md"))) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Internal Release Blockers") | Out-Null
$lines.Add("") | Out-Null
if ($internalBlockers.Count -eq 0) {
    $lines.Add("- None.") | Out-Null
}
else {
    foreach ($blocker in $internalBlockers) {
        $lines.Add($blocker) | Out-Null
    }
}
$lines.Add("") | Out-Null
$lines.Add("## External Blockers") | Out-Null
$lines.Add("") | Out-Null
if ($externalBlockers.Count -eq 0) {
    $lines.Add("- None.") | Out-Null
}
else {
    foreach ($blocker in $externalBlockers) {
        $lines.Add($blocker) | Out-Null
    }
}
$lines.Add("") | Out-Null
$lines.Add("## Next Commands") | Out-Null
$lines.Add("") | Out-Null
$lines.Add('```powershell') | Out-Null
$lines.Add('.\workspace.cmd production-env-report') | Out-Null
$lines.Add('.\workspace.cmd android-qa-report') | Out-Null
$lines.Add('.\workspace.cmd visual-brand-smoke') | Out-Null
$lines.Add('.\workspace.cmd go-no-go quick') | Out-Null
$lines.Add('```') | Out-Null
$lines.Add("") | Out-Null

$report = $lines -join [Environment]::NewLine
Write-Output $report

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $reportPath = Join-Path $ReleaseDir "release-handoff-$stamp.md"
    $latestPath = Join-Path $ReleaseDir "release-handoff-latest.md"
    $report | Set-Content -Path $reportPath -Encoding UTF8
    $report | Set-Content -Path $latestPath -Encoding UTF8
    Write-Host ""
    Write-Host "Release handoff written:"
    Write-Host "  $reportPath"
    Write-Host "  $latestPath"
}

$failedSteps = @($steps | Where-Object { $_.Status -eq "FAIL" })
if ($failedSteps.Count -gt 0) {
    throw "Release handoff bundle failed. Fix failing read-only steps before handoff."
}
