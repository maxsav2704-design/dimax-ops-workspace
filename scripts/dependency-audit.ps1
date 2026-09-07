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
$LatestJsonPath = Join-Path $ReleaseDir "dependency-audit-latest.json"
$LatestMarkdownPath = Join-Path $ReleaseDir "dependency-audit-latest.md"
$PipAuditVersion = "2.10.1"
$MinimumNodeVersion = [version]"20.18.0"
$NpmFetchTimeoutMilliseconds = 60000
$NpmFetchRetries = 2
$BackendAuditTimeoutSeconds = 600
$MobileImageSizeAdvisoryUrls = @(
    "https://github.com/advisories/GHSA-5p2g-fcmc-qvqq",
    "https://github.com/advisories/GHSA-w3rx-r6r6-pgpr"
)

function Get-NodeVersion {
    param([Parameter(Mandatory = $true)][string]$NodePath)

    try {
        $raw = (& $NodePath -p "process.versions.node" 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return [version]$raw
    }
    catch {
        return $null
    }
}

function Test-SupportedNodeVersion {
    param([Parameter(Mandatory = $true)][version]$Version)

    return $Version.Major -eq 20 -and $Version -ge $MinimumNodeVersion
}

function Resolve-Node20Path {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($env:DIMAX_NODE_LTS)) {
        [void]$candidates.Add($env:DIMAX_NODE_LTS)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        [void]$candidates.Add(
            (Join-Path $env:LOCALAPPDATA "DIMAX\node20\node_modules\node\bin\node.exe")
        )
    }
    $defaultNode = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($defaultNode) {
        [void]$candidates.Add($defaultNode.Source)
    }

    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }
        $version = Get-NodeVersion -NodePath $candidate
        if ($null -ne $version -and (Test-SupportedNodeVersion -Version $version)) {
            return $candidate
        }
    }

    throw "Dependency audit requires Node >=20.18 <21."
}

function Resolve-NpmCliPath {
    $npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $npmCommand) {
        throw "npm.cmd was not found."
    }

    $npmCliPath = Join-Path (Split-Path -Parent $npmCommand.Source) "node_modules\npm\bin\npm-cli.js"
    if (-not (Test-Path -LiteralPath $npmCliPath -PathType Leaf)) {
        throw "npm CLI entrypoint was not found at $npmCliPath"
    }
    return $npmCliPath
}

function Test-NpmPolicyPass {
    param(
        [int]$High,
        [int]$Critical
    )

    return $High -eq 0 -and $Critical -eq 0
}

function Resolve-NpmAdvisoryUrls {
    param(
        [Parameter(Mandatory = $true)]$Vulnerabilities,
        [Parameter(Mandatory = $true)][string]$PackageName,
        [string[]]$VisitedPackages = @()
    )

    if ($PackageName -in $VisitedPackages) {
        return @()
    }
    $property = @(
        $Vulnerabilities.PSObject.Properties |
            Where-Object { $_.Name -eq $PackageName }
    ) | Select-Object -First 1
    if ($null -eq $property) {
        return @()
    }

    $nextVisited = @($VisitedPackages) + $PackageName
    $urls = [System.Collections.Generic.List[string]]::new()
    foreach ($via in @($property.Value.via)) {
        if ($via -is [string]) {
            foreach ($url in @(Resolve-NpmAdvisoryUrls `
                -Vulnerabilities $Vulnerabilities `
                -PackageName $via `
                -VisitedPackages $nextVisited)) {
                [void]$urls.Add($url)
            }
            continue
        }
        if ($null -ne $via.url -and -not [string]::IsNullOrWhiteSpace([string]$via.url)) {
            [void]$urls.Add([string]$via.url)
        }
    }
    return @($urls | Select-Object -Unique)
}

function Get-NpmPolicyEvaluation {
    param(
        [Parameter(Mandatory = $true)]$Audit,
        [string[]]$AllowedHighAdvisoryUrls = @()
    )

    $mitigatedPackages = [System.Collections.Generic.List[string]]::new()
    $unmitigatedPackages = [System.Collections.Generic.List[string]]::new()
    $usedAdvisoryUrls = [System.Collections.Generic.List[string]]::new()

    foreach ($property in $Audit.vulnerabilities.PSObject.Properties) {
        $severity = [string]$property.Value.severity
        if ($severity -notin @("critical", "high")) {
            continue
        }

        $urls = @(Resolve-NpmAdvisoryUrls `
            -Vulnerabilities $Audit.vulnerabilities `
            -PackageName $property.Name)
        $hasOnlyAllowedHighAdvisories = $severity -eq "high" -and $urls.Count -gt 0
        foreach ($url in $urls) {
            if ($url -notin $AllowedHighAdvisoryUrls) {
                $hasOnlyAllowedHighAdvisories = $false
                break
            }
        }

        if ($hasOnlyAllowedHighAdvisories) {
            [void]$mitigatedPackages.Add($property.Name)
            foreach ($url in $urls) {
                if ($url -notin $usedAdvisoryUrls) {
                    [void]$usedAdvisoryUrls.Add($url)
                }
            }
        }
        else {
            [void]$unmitigatedPackages.Add($property.Name)
        }
    }

    return [ordered]@{
        mitigated_packages = @($mitigatedPackages)
        unmitigated_packages = @($unmitigatedPackages)
        advisory_urls = @($usedAdvisoryUrls | Sort-Object)
    }
}

function Invoke-MobileImageSizePatchVerification {
    param([Parameter(Mandatory = $true)][string]$NodePath)

    $patchScript = Join-Path $MobileDir "scripts\patch-image-size.mjs"
    if (-not (Test-Path -LiteralPath $patchScript -PathType Leaf)) {
        throw "Mobile image-size security patch verifier is missing: $patchScript"
    }

    $output = & $NodePath $patchScript --self-test 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Mobile image-size security patch verification failed: $($output -join ' ')"
    }
    return ($output | Out-String).Trim()
}

function Get-NpmAuditVulnerabilityCounts {
    param(
        [Parameter(Mandatory = $true)]$Audit,
        [Parameter(Mandatory = $true)][string]$Area,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )

    if (
        $null -eq $Audit.PSObject.Properties['metadata'] -or
        $null -eq $Audit.metadata.PSObject.Properties['vulnerabilities']
    ) {
        $detail = if ($null -ne $Audit.PSObject.Properties['error']) {
            [string]$Audit.error.summary
        }
        else {
            "advisory response has no vulnerability metadata"
        }
        if ([string]::IsNullOrWhiteSpace($detail)) {
            $detail = "advisory endpoint returned no vulnerability metadata"
        }
        throw "$Area npm audit could not retrieve advisory data (exit code $ExitCode): $detail"
    }
    return $Audit.metadata.vulnerabilities
}

function Invoke-NpmAudit {
    param(
        [Parameter(Mandatory = $true)][string]$Area,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$NpmCliPath,
        [string[]]$AllowedHighAdvisoryUrls = @(),
        [string]$Mitigation = ""
    )

    $npmCachePath = Join-Path (
        [System.IO.Path]::GetTempPath()
    ) ("dimax-npm-audit-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $npmCachePath -Force | Out-Null
    Push-Location $WorkingDirectory
    try {
        Write-Host "Auditing $Area npm dependency tree..."
        $output = & $NodePath $NpmCliPath audit `
            --json `
            --audit-level=high `
            --cache $npmCachePath `
            "--fetch-timeout=$NpmFetchTimeoutMilliseconds" `
            "--fetch-retries=$NpmFetchRetries" `
            --fetch-retry-mintimeout=1000 `
            --fetch-retry-maxtimeout=10000
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
        Remove-Item -LiteralPath $npmCachePath -Recurse -Force -ErrorAction SilentlyContinue
    }

    $raw = ($output | Out-String).Trim()
    try {
        $audit = $raw | ConvertFrom-Json
    }
    catch {
        throw "$Area npm audit did not return valid JSON (exit code $exitCode)."
    }
    $counts = Get-NpmAuditVulnerabilityCounts -Audit $audit -Area $Area -ExitCode $exitCode
    $critical = [int]$counts.critical
    $high = [int]$counts.high
    $moderate = [int]$counts.moderate
    $low = [int]$counts.low
    $evaluation = Get-NpmPolicyEvaluation `
        -Audit $audit `
        -AllowedHighAdvisoryUrls $AllowedHighAdvisoryUrls
    $unmitigatedPackages = @($evaluation.unmitigated_packages)
    $mitigatedPackages = @($evaluation.mitigated_packages)
    if ($exitCode -notin @(0, 1) -or $unmitigatedPackages.Count -gt 0) {
        $blocking = if ($unmitigatedPackages.Count -gt 0) {
            $unmitigatedPackages -join ", "
        }
        else {
            "npm audit execution error"
        }
        throw "$Area dependency audit failed: critical=$critical, high=$high, moderate=$moderate, low=$low; blocking=$blocking."
    }

    return [ordered]@{
        status = if ($mitigatedPackages.Count -gt 0) { "PASS_WITH_LOCAL_PATCH" } else { "PASS" }
        critical = $critical
        high = $high
        unmitigated_high_or_critical = $unmitigatedPackages.Count
        locally_patched_packages = $mitigatedPackages
        locally_patched_advisories = @($evaluation.advisory_urls)
        mitigation = if ($mitigatedPackages.Count -gt 0) { $Mitigation } else { "" }
        moderate = $moderate
        low = $low
        total = [int]$counts.total
    }
}

function Invoke-BackendAudit {
    $requirementsPath = Join-Path $BackendDir "requirements-audit.txt"
    if (-not (Test-Path -LiteralPath $requirementsPath -PathType Leaf)) {
        throw "Backend audit requirements file is missing: $requirementsPath"
    }

    Write-Host "Auditing backend Python dependency tree..."
    $backendMount = "${BackendDir}:/workspace:ro"
    $auditCommand = @(
        "python -m pip install --quiet --root-user-action=ignore pip-audit==$PipAuditVersion >/dev/null",
        "pip-audit --requirement requirements-audit.txt --strict --format json"
    ) -join " && "
    $output = & docker run --rm `
        --user 0 `
        -v $backendMount `
        -w /workspace `
        python:3.12-slim `
        timeout --signal=TERM --kill-after=15s "${BackendAuditTimeoutSeconds}s" `
        sh -lc $auditCommand
    $exitCode = $LASTEXITCODE
    $raw = ($output | Out-String).Trim()

    if ($exitCode -eq 124) {
        throw "Backend dependency audit timed out after $BackendAuditTimeoutSeconds seconds."
    }

    try {
        $audit = $raw | ConvertFrom-Json
    }
    catch {
        throw "Backend pip-audit did not return valid JSON (exit code $exitCode)."
    }

    $vulnerabilityCount = 0
    foreach ($dependency in @($audit.dependencies)) {
        $vulnerabilityCount += @($dependency.vulns).Count
    }
    if ($exitCode -ne 0 -or $vulnerabilityCount -ne 0) {
        throw "Backend dependency audit failed: known vulnerabilities=$vulnerabilityCount."
    }

    return [ordered]@{
        status = "PASS"
        known_vulnerabilities = $vulnerabilityCount
        audited_packages = @($audit.dependencies).Count
        pip_audit_version = $PipAuditVersion
    }
}

function Invoke-SelfTest {
    $cases = @(
        @{ High = 0; Critical = 0; Expected = $true },
        @{ High = 1; Critical = 0; Expected = $false },
        @{ High = 0; Critical = 1; Expected = $false },
        @{ High = 2; Critical = 3; Expected = $false }
    )
    foreach ($case in $cases) {
        $actual = Test-NpmPolicyPass -High $case.High -Critical $case.Critical
        if ($actual -ne $case.Expected) {
            throw "Dependency audit policy self-test failed."
        }
    }

    $syntheticAudit = @'
{
  "vulnerabilities": {
    "image-size": {
      "severity": "high",
      "via": [
        {"url": "https://github.com/advisories/GHSA-w3rx-r6r6-pgpr"},
        {"url": "https://github.com/advisories/GHSA-5p2g-fcmc-qvqq"}
      ]
    },
    "metro": {"severity": "high", "via": ["image-size"]}
  }
}
'@ | ConvertFrom-Json
    $allowed = Get-NpmPolicyEvaluation `
        -Audit $syntheticAudit `
        -AllowedHighAdvisoryUrls $MobileImageSizeAdvisoryUrls
    if (@($allowed.mitigated_packages).Count -ne 2 -or @($allowed.unmitigated_packages).Count -ne 0) {
        throw "Dependency audit local-patch policy self-test failed."
    }
    $blocked = Get-NpmPolicyEvaluation -Audit $syntheticAudit
    if (@($blocked.unmitigated_packages).Count -ne 2) {
        throw "Dependency audit blocking policy self-test failed."
    }
    $syntheticAudit.vulnerabilities.metro.severity = "critical"
    $critical = Get-NpmPolicyEvaluation `
        -Audit $syntheticAudit `
        -AllowedHighAdvisoryUrls $MobileImageSizeAdvisoryUrls
    if ("metro" -notin @($critical.unmitigated_packages)) {
        throw "Dependency audit critical policy self-test failed."
    }
    $networkError = '{"error":{"summary":"audit endpoint returned an error"}}' | ConvertFrom-Json
    try {
        Get-NpmAuditVulnerabilityCounts -Audit $networkError -Area "test" -ExitCode 1 | Out-Null
        throw "Dependency audit invalid-response self-test failed."
    }
    catch {
        if ($_.Exception.Message -notlike "test npm audit could not retrieve advisory data*") {
            throw
        }
    }
    Write-Output "Dependency audit self-test passed (8 cases)."
}

if ($SelfTest) {
    Invoke-SelfTest
    return
}

if (-not $NoWrite) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

$nodePath = Resolve-Node20Path
$npmCliPath = Resolve-NpmCliPath
$nodeVersion = Get-NodeVersion -NodePath $nodePath
$mobileImageSizePatch = Invoke-MobileImageSizePatchVerification -NodePath $nodePath
$admin = Invoke-NpmAudit `
    -Area "admin" `
    -WorkingDirectory $AdminDir `
    -NodePath $nodePath `
    -NpmCliPath $npmCliPath
$mobile = Invoke-NpmAudit `
    -Area "mobile" `
    -WorkingDirectory $MobileDir `
    -NodePath $nodePath `
    -NpmCliPath $npmCliPath `
    -AllowedHighAdvisoryUrls $MobileImageSizeAdvisoryUrls `
    -Mitigation $mobileImageSizePatch
$backend = Invoke-BackendAudit

$checkedAt = (Get-Date).ToUniversalTime().ToString("o")
$result = [ordered]@{
    status = "ok"
    checked_at = $checkedAt
    node_version = $nodeVersion.ToString()
    policy = [ordered]@{
        npm = "fail on unmitigated high or critical; two image-size advisories require the verified local patch"
        python = "fail on any known vulnerability"
    }
    backend = $backend
    admin = $admin
    mobile = $mobile
}

$markdown = @(
    "# DIMAX Dependency Audit"
    ""
    '- Status: `PASS`'
    ('- Checked at: `{0}`' -f $checkedAt)
    ('- Node: `{0}`' -f $nodeVersion)
    ('- Backend: `0 known vulnerabilities across {0} packages`' -f $backend.audited_packages)
    ('- Admin: `critical={0}, high={1}, moderate={2}, low={3}`' -f $admin.critical, $admin.high, $admin.moderate, $admin.low)
    ('- Mobile: `critical={0}, high={1}, locally patched packages={2}, unmitigated high/critical={3}, moderate={4}, low={5}`' -f $mobile.critical, $mobile.high, @($mobile.locally_patched_packages).Count, $mobile.unmitigated_high_or_critical, $mobile.moderate, $mobile.low)
    ('- Mobile mitigation: `{0}`' -f $mobile.mitigation)
    ""
    "The npm release policy fails on every unmitigated High or Critical finding. The two unpatched upstream image-size advisories pass only when the pinned local security patch succeeds. Python fails on any known vulnerability."
) -join [Environment]::NewLine

if (-not $NoWrite) {
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $LatestJsonPath -Encoding UTF8
    $markdown | Set-Content -LiteralPath $LatestMarkdownPath -Encoding UTF8
}

Write-Output $markdown
