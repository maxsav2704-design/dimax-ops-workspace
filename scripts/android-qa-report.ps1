param(
    [switch]$NoWrite,
    [switch]$RequirePass,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$ResultsPath = Join-Path $WorkspaceRoot "ANDROID_QA_RESULTS.md"
$ScreensDir = Join-Path $WorkspaceRoot "artifacts\screens"
$DeviceDir = Join-Path $WorkspaceRoot "artifacts\device"
$ReleaseDir = Join-Path $WorkspaceRoot "artifacts\release"

function Get-BacktickValue {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $escapedLabel = [regex]::Escape($Label)
    $pattern = '(?m)^\s*-\s*`?' + $escapedLabel + '`?\s*:\s*`([^`]+)`'
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ""
}

function Test-ConcreteValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    if ($Value -match "____|PASS\s*/\s*FAIL|YES\s*/\s*NO|GO\s*/\s*NO-GO|Local preview\s*/\s*staging\s*/\s*other") {
        return $false
    }
    return $true
}

function Get-FileCount {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    return @(Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue).Count
}

function Get-Sha256FileHash {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
}

function Get-RegressionSection {
    param([Parameter(Mandatory = $true)][string]$Content)

    $match = [regex]::Match(
        $Content,
        '(?ms)^## Regression Device Smoke (?<date>\d{4}-\d{2}-\d{2})\s*\r?\n(?<body>.*?)(?=^## |\z)'
    )
    if (-not $match.Success) {
        return $null
    }

    return [pscustomobject]@{
        Date = $match.Groups['date'].Value
        Body = $match.Groups['body'].Value
    }
}

function Get-AndroidArtifactBindingIssues {
    param(
        [Parameter(Mandatory = $true)][string]$SectionBody,
        [Parameter(Mandatory = $true)][string]$ApkDirectory
    )

    $result = [System.Collections.Generic.List[string]]::new()
    $recordedHash = (Get-BacktickValue -Content $SectionBody -Label 'APK SHA-256').ToUpperInvariant()
    if ($recordedHash -notmatch '^[0-9A-F]{64}$') {
        $result.Add('Regression APK SHA-256 is missing or invalid.') | Out-Null
    }
    elseif (-not (Test-Path -LiteralPath $ApkDirectory -PathType Container)) {
        $result.Add('Saved Android APK directory is missing.') | Out-Null
    }
    else {
        $apkFiles = @(Get-ChildItem -LiteralPath $ApkDirectory -File -Filter '*.apk')
        if ($apkFiles.Count -eq 0) {
            $result.Add('No saved APK artifact was found for the regression proof.') | Out-Null
        }
        else {
            $matchingApk = @($apkFiles | Where-Object {
                (Get-Sha256FileHash -Path $_.FullName) -eq $recordedHash
            })
            if ($matchingApk.Count -eq 0) {
                $result.Add('Recorded regression APK SHA-256 does not match any saved APK artifact.') | Out-Null
            }
        }
    }

    return @($result)
}

function Get-AndroidRegressionIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$ApkDirectory,
        [datetimeoffset]$Now = [datetimeoffset]::Now,
        [timespan]$MaxAge = [timespan]::FromDays(7)
    )

    $result = [System.Collections.Generic.List[string]]::new()
    $section = Get-RegressionSection -Content $Content
    if ($null -eq $section) {
        $result.Add('Regression Device Smoke section is missing.') | Out-Null
        return @($result)
    }

    $regressionDate = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse($section.Date, [ref]$regressionDate)) {
        $result.Add('Regression device smoke date is invalid.') | Out-Null
    }
    else {
        $age = $Now.Date - $regressionDate.Date
        if ($age -lt [timespan]::FromDays(-1)) {
            $result.Add('Regression device smoke date is in the future.') | Out-Null
        }
        elseif ($age -gt $MaxAge) {
            $result.Add("Regression device smoke is stale ($([math]::Floor($age.TotalDays)) days old).") | Out-Null
        }
    }

    $packageName = Get-BacktickValue -Content $section.Body -Label 'Package'
    if ($packageName -ne 'com.dimax.operations.installer') {
        $result.Add('Regression package must be com.dimax.operations.installer.') | Out-Null
    }

    foreach ($check in @(
        @{ Label = 'Installer auto-login'; Expected = 'PASS' },
        @{ Label = 'Assigned project list and sync timestamp'; Expected = 'PASS' },
        @{ Label = 'Assigned project detail navigation'; Expected = 'PASS' },
        @{ Label = 'Fatal Android or JavaScript runtime errors'; Expected = 'NONE' }
    )) {
        $actual = Get-BacktickValue -Content $section.Body -Label $check.Label
        if ($actual -ne $check.Expected) {
            $result.Add("$($check.Label) must be $($check.Expected).") | Out-Null
        }
    }

    foreach ($issue in @(Get-AndroidArtifactBindingIssues `
        -SectionBody $section.Body `
        -ApkDirectory $ApkDirectory)) {
        $result.Add($issue) | Out-Null
    }

    $evidenceMatches = [regex]::Matches(
        $section.Body,
        '`(?<path>artifacts/device/[^`]+)`'
    )
    $evidencePaths = @($evidenceMatches | ForEach-Object {
        $_.Groups['path'].Value.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    } | Select-Object -Unique)
    if ($evidencePaths.Count -lt 3) {
        $result.Add('Regression proof must reference at least three device evidence files.') | Out-Null
    }
    foreach ($relativePath in $evidencePaths) {
        $fullPath = Join-Path $RootPath $relativePath
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            $result.Add("Regression evidence file is missing: $relativePath") | Out-Null
        }
    }

    return @($result)
}

function Invoke-AndroidQaSelfTest {
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("dimax-android-qa-" + [guid]::NewGuid().ToString('N'))
    $apkDir = Join-Path $tempDir 'mobile\artifacts\android'
    $deviceDir = Join-Path $tempDir 'artifacts\device'
    New-Item -ItemType Directory -Path $apkDir -Force | Out-Null
    New-Item -ItemType Directory -Path $deviceDir -Force | Out-Null
    try {
        $apkPath = Join-Path $apkDir 'proof.apk'
        'apk-proof' | Set-Content -LiteralPath $apkPath -Encoding UTF8
        $apkHash = Get-Sha256FileHash -Path $apkPath
        foreach ($name in @('screen.png', 'screen-2.png', 'device.log')) {
            'proof' | Set-Content -LiteralPath (Join-Path $deviceDir $name) -Encoding UTF8
        }

        $content = @"
## Regression Device Smoke 2026-07-23

- Package: ``com.dimax.operations.installer``
- APK SHA-256: ``$apkHash``
- Installer auto-login: ``PASS``
- Assigned project list and sync timestamp: ``PASS``
- Assigned project detail navigation: ``PASS``
- Fatal Android or JavaScript runtime errors: ``NONE``
- Evidence:
  - ``artifacts/device/screen.png``
  - ``artifacts/device/screen-2.png``
  - ``artifacts/device/device.log``

## Final Recommendation
"@
        $validIssues = @(Get-AndroidRegressionIssues `
            -Content $content `
            -RootPath $tempDir `
            -ApkDirectory $apkDir `
            -Now ([datetimeoffset]::Parse('2026-07-23T12:00:00Z')))
        if ($validIssues.Count -ne 0) {
            throw "Valid regression proof was rejected: $($validIssues -join '; ')"
        }

        $badHashIssues = @(Get-AndroidRegressionIssues `
            -Content ($content.Replace($apkHash, ('0' * 64))) `
            -RootPath $tempDir `
            -ApkDirectory $apkDir `
            -Now ([datetimeoffset]::Parse('2026-07-23T12:00:00Z')))
        if (-not ($badHashIssues -match 'does not match')) {
            throw 'Mismatched APK hash was accepted.'
        }

        $staleIssues = @(Get-AndroidRegressionIssues `
            -Content ($content.Replace('2026-07-23', '2026-07-01')) `
            -RootPath $tempDir `
            -ApkDirectory $apkDir `
            -Now ([datetimeoffset]::Parse('2026-07-23T12:00:00Z')))
        if (-not ($staleIssues -match 'stale')) {
            throw 'Stale regression proof was accepted.'
        }

        $incompleteNavigationContent = $content.Replace(
            'Assigned project detail navigation: `PASS`',
            'Assigned project detail navigation: `NOT RUN`'
        )
        $incompleteNavigationIssues = @(Get-AndroidRegressionIssues `
            -Content $incompleteNavigationContent `
            -RootPath $tempDir `
            -ApkDirectory $apkDir `
            -Now ([datetimeoffset]::Parse('2026-07-23T12:00:00Z')))
        if (-not ($incompleteNavigationIssues -match 'Assigned project detail navigation')) {
            throw 'Incomplete project navigation regression was accepted.'
        }
        $artifactIssues = @(Get-AndroidArtifactBindingIssues `
            -SectionBody (Get-RegressionSection -Content $incompleteNavigationContent).Body `
            -ApkDirectory $apkDir)
        if ($artifactIssues.Count -ne 0) {
            throw 'A valid APK binding was rejected because an unrelated device check was incomplete.'
        }

        Write-Output 'Android QA self-test passed (4 cases).'
    }
    finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($SelfTest) {
    Invoke-AndroidQaSelfTest
    return
}

$issues = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $ResultsPath)) {
    $issues.Add("ANDROID_QA_RESULTS.md is missing.") | Out-Null
    $content = ""
}
else {
    $content = Get-Content -Path $ResultsPath -Raw
}

$sessionDate = Get-BacktickValue -Content $content -Label "Date"
$tester = Get-BacktickValue -Content $content -Label "Tester"
$device = Get-BacktickValue -Content $content -Label "Device"
$androidVersion = Get-BacktickValue -Content $content -Label "Android version"
$wazeVersion = Get-BacktickValue -Content $content -Label "Waze version"
$whatsappVersion = Get-BacktickValue -Content $content -Label "WhatsApp version"
$buildEnv = Get-BacktickValue -Content $content -Label "Build / environment"

$projectWaze = Get-BacktickValue -Content $content -Label "Project -> Waze"
$projectWhatsapp = Get-BacktickValue -Content $content -Label "Project -> WhatsApp"
$localePrefill = Get-BacktickValue -Content $content -Label "Locale-specific prefill"
$crashObserved = Get-BacktickValue -Content $content -Label "Crash observed"
$decision = Get-BacktickValue -Content $content -Label "Decision"
$screenshotsSaved = Get-BacktickValue -Content $content -Label 'Screenshots saved in `artifacts/screens/`'
$deviceFilesSaved = Get-BacktickValue -Content $content -Label 'Device files saved in `artifacts/device/`'
$videoSaved = Get-BacktickValue -Content $content -Label "Video saved if needed"

if (-not (Test-ConcreteValue -Value $sessionDate)) { $issues.Add("Session date is not filled.") | Out-Null }
if (-not (Test-ConcreteValue -Value $tester)) { $issues.Add("Tester is not filled.") | Out-Null }
if (-not (Test-ConcreteValue -Value $device)) { $issues.Add("Device is not filled.") | Out-Null }
if (-not (Test-ConcreteValue -Value $androidVersion)) { $issues.Add("Android version is not filled.") | Out-Null }
if (-not (Test-ConcreteValue -Value $wazeVersion)) { $issues.Add("Waze version is not filled.") | Out-Null }
if (-not (Test-ConcreteValue -Value $whatsappVersion)) { $issues.Add("WhatsApp version is not filled.") | Out-Null }
if (-not (Test-ConcreteValue -Value $buildEnv)) { $issues.Add("Build/environment is not filled.") | Out-Null }

if ($projectWaze -ne "PASS") { $issues.Add("Critical gate Project -> Waze is not PASS.") | Out-Null }
if ($projectWhatsapp -ne "PASS") { $issues.Add("Critical gate Project -> WhatsApp is not PASS.") | Out-Null }
if ($localePrefill -ne "PASS") { $issues.Add("Critical gate Locale-specific prefill is not PASS.") | Out-Null }
if ($crashObserved -ne "NO") { $issues.Add("Crash observed must be NO.") | Out-Null }
if ($decision -ne "GO") { $issues.Add("Final recommendation Decision must be GO.") | Out-Null }

$screenCount = Get-FileCount -Path $ScreensDir
$deviceCount = Get-FileCount -Path $DeviceDir
$evidenceCount = $screenCount + $deviceCount

if ($screenshotsSaved -ne "YES") {
    $issues.Add("Screenshots saved checklist must be YES.") | Out-Null
}
if ($evidenceCount -eq 0) {
    $issues.Add("No Android QA evidence files found in artifacts/screens or artifacts/device.") | Out-Null
}
if ($deviceFilesSaved -eq "YES" -and $deviceCount -eq 0) {
    $issues.Add("Device files checklist is YES but artifacts/device is empty.") | Out-Null
}

$regressionSection = Get-RegressionSection -Content $content
$artifactBindingIssues = @()
if ($null -ne $regressionSection) {
    $artifactBindingIssues = @(Get-AndroidArtifactBindingIssues `
        -SectionBody $regressionSection.Body `
        -ApkDirectory (Join-Path $WorkspaceRoot 'mobile\artifacts\android'))
}
$regressionIssues = @(Get-AndroidRegressionIssues `
    -Content $content `
    -RootPath $WorkspaceRoot `
    -ApkDirectory (Join-Path $WorkspaceRoot 'mobile\artifacts\android'))
foreach ($issue in $regressionIssues) {
    $issues.Add($issue) | Out-Null
}

$status = if ($issues.Count -eq 0) { "PASS" } else { "BLOCKED" }
$generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# DIMAX Android QA Report") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Generated at: `{0}`' -f $generatedAt)) | Out-Null
$lines.Add(('- Status: `{0}`' -f $status)) | Out-Null
$lines.Add(('- Results file: `{0}`' -f $ResultsPath)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Session") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Date: `{0}`' -f $sessionDate)) | Out-Null
$lines.Add(('- Tester: `{0}`' -f $tester)) | Out-Null
$lines.Add(('- Device: `{0}`' -f $device)) | Out-Null
$lines.Add(('- Android version: `{0}`' -f $androidVersion)) | Out-Null
$lines.Add(('- Waze version: `{0}`' -f $wazeVersion)) | Out-Null
$lines.Add(('- WhatsApp version: `{0}`' -f $whatsappVersion)) | Out-Null
$lines.Add(('- Build/environment: `{0}`' -f $buildEnv)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Critical Gates") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Project -> Waze: `{0}`' -f $projectWaze)) | Out-Null
$lines.Add(('- Project -> WhatsApp: `{0}`' -f $projectWhatsapp)) | Out-Null
$lines.Add(('- Locale-specific prefill: `{0}`' -f $localePrefill)) | Out-Null
$lines.Add(('- Crash observed: `{0}`' -f $crashObserved)) | Out-Null
$lines.Add(('- Decision: `{0}`' -f $decision)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Evidence") | Out-Null
$lines.Add("") | Out-Null
$lines.Add(('- Screenshots saved checklist: `{0}`' -f $screenshotsSaved)) | Out-Null
$lines.Add(('- Device files saved checklist: `{0}`' -f $deviceFilesSaved)) | Out-Null
$lines.Add(('- Video saved if needed: `{0}`' -f $videoSaved)) | Out-Null
$lines.Add(('- Screenshots found: `{0}`' -f $screenCount)) | Out-Null
$lines.Add(('- Device files found: `{0}`' -f $deviceCount)) | Out-Null
$lines.Add("") | Out-Null
$lines.Add("## Regression Proof") | Out-Null
$lines.Add("") | Out-Null
if ($null -eq $regressionSection) {
    $lines.Add('- Regression section: `MISSING`') | Out-Null
}
else {
    $regressionPackage = Get-BacktickValue -Content $regressionSection.Body -Label 'Package'
    $regressionHash = Get-BacktickValue -Content $regressionSection.Body -Label 'APK SHA-256'
    $lines.Add(('- Date: `{0}`' -f $regressionSection.Date)) | Out-Null
    $lines.Add(('- Package: `{0}`' -f $regressionPackage)) | Out-Null
    $lines.Add(('- APK SHA-256: `{0}`' -f $regressionHash)) | Out-Null
    $lines.Add(('- Artifact binding: `{0}`' -f $(if ($artifactBindingIssues.Count -eq 0) { 'PASS' } else { 'BLOCKED' }))) | Out-Null
}
$lines.Add("") | Out-Null
$lines.Add("## Open Items") | Out-Null
$lines.Add("") | Out-Null
if ($issues.Count -eq 0) {
    $lines.Add("- None.") | Out-Null
}
else {
    foreach ($issue in $issues) {
        $lines.Add(("- {0}" -f $issue)) | Out-Null
    }
}
$lines.Add("") | Out-Null
$lines.Add("## Decision Rule") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Production mobile GO requires filled session metadata, all critical gates PASS, crash observed NO, final Decision GO, a fresh regression device smoke, and an APK hash that matches a saved artifact.") | Out-Null
$lines.Add("- This report is read-only. It does not create Android proof.") | Out-Null
$lines.Add("") | Out-Null

$report = $lines -join [Environment]::NewLine
Write-Output $report

if (-not $NoWrite) {
    New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $reportPath = Join-Path $ReleaseDir "android-qa-report-$stamp.md"
    $latestPath = Join-Path $ReleaseDir "android-qa-report-latest.md"
    $report | Set-Content -Path $reportPath -Encoding UTF8
    $report | Set-Content -Path $latestPath -Encoding UTF8
    Write-Host ""
    Write-Host "Android QA report written:"
    Write-Host "  $reportPath"
    Write-Host "  $latestPath"
}

if ($RequirePass -and $status -ne "PASS") {
    throw "Android QA proof is not closed. See ANDROID_QA_RESULTS.md and artifacts/release/android-qa-report-latest.md."
}
