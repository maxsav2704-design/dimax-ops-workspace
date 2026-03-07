param(
    [Parameter(Mandatory = $true)]
    [string]$BackendRemote,

    [Parameter(Mandatory = $true)]
    [string]$FrontendRemote,

    [string]$WorkspaceRemote = "",
    [string]$Branch = "main",
    [switch]$Push
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$BackendPath = Join-Path $WorkspaceRoot "backend"
$FrontendPath = Join-Path $WorkspaceRoot "dimax-operations-suite-main"

function Set-OriginRemote {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$RemoteUrl,
        [Parameter(Mandatory = $true)][string]$BranchName,
        [switch]$DoPush
    )

    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "Git repository not found: $RepoPath"
    }

    Push-Location $RepoPath
    try {
        $existingUrl = ""
        try {
            $existingUrl = (git remote get-url origin 2>$null).Trim()
        }
        catch {
            $existingUrl = ""
        }

        if ([string]::IsNullOrWhiteSpace($existingUrl)) {
            git remote add origin $RemoteUrl
            Write-Host "origin added in $RepoPath"
        }
        elseif ($existingUrl -ne $RemoteUrl) {
            git remote set-url origin $RemoteUrl
            Write-Host "origin updated in $RepoPath"
        }
        else {
            Write-Host "origin already set in $RepoPath"
        }

        git remote -v

        if ($DoPush) {
            git push -u origin $BranchName
        }
    }
    finally {
        Pop-Location
    }
}

Set-OriginRemote -RepoPath $BackendPath -RemoteUrl $BackendRemote -BranchName $Branch -DoPush:$Push
Set-OriginRemote -RepoPath $FrontendPath -RemoteUrl $FrontendRemote -BranchName $Branch -DoPush:$Push

if (-not [string]::IsNullOrWhiteSpace($WorkspaceRemote)) {
    Set-OriginRemote -RepoPath $WorkspaceRoot -RemoteUrl $WorkspaceRemote -BranchName $Branch -DoPush:$Push
}

Write-Host "Done."
