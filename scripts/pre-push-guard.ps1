param(
    [string]$RemoteName = "",
    [string]$RemoteUrl = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$currentBranch = (& git branch --show-current | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    throw "pre-push guard: could not determine current branch."
}

$blockedRefs = @()
$stdinLines = @()

while (($line = [Console]::In.ReadLine()) -ne $null) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    $stdinLines += $line
    $parts = $line -split '\s+'
    if ($parts.Length -lt 4) {
        continue
    }
    $localRef = $parts[0]
    $remoteRef = $parts[2]

    if ($localRef -eq "refs/heads/main" -or $remoteRef -eq "refs/heads/main") {
        $blockedRefs += "$localRef -> $remoteRef"
    }
}

if ($currentBranch -eq "main") {
    throw "pre-push guard blocked push from local branch 'main'. Create or switch to a feature branch first."
}

if ($blockedRefs.Count -gt 0) {
    throw "pre-push guard blocked push targeting 'main': $($blockedRefs -join ', '). Use a PR instead of pushing to main."
}

Write-Host "pre-push guard passed for branch '$currentBranch'." -ForegroundColor DarkGray
