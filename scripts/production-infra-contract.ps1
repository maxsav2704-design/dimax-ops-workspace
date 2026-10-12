param(
    [switch]$ConfigOnly,
    [switch]$BuildInsideDocker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$WorkspaceRoot = Split-Path -Parent $PSScriptRoot
$BackendCompose = Join-Path $WorkspaceRoot "backend\docker-compose.production.yml"
$EdgeCompose = Join-Path $WorkspaceRoot "infra\production\docker-compose.edge.yml"
$CaddyFile = Join-Path $WorkspaceRoot "infra\production\Caddyfile"
$BackendExample = Join-Path $WorkspaceRoot "backend\.env.production.example"
$AdminDir = Join-Path $WorkspaceRoot "dimax-operations-suite-main"
$AdminDockerfile = Join-Path $AdminDir "Dockerfile"
$AdminDockerignore = Join-Path $AdminDir ".dockerignore"
$AdminArtifactDockerfile = Join-Path $AdminDir "Dockerfile.artifact"
$AdminArtifactDockerignore = Join-Path $AdminDir "Dockerfile.artifact.dockerignore"
$AdminNextConfig = Join-Path $AdminDir "next.config.mjs"
$ContractId = [Guid]::NewGuid().ToString('N')
$ContractLabel = "dimax.acceptance.infra=$ContractId"
$AdminImage = "dimax-admin:infra-contract-$ContractId"
$AdminContainer = "dimax-admin-infra-contract-$ContractId"
$KeepaliveContainer = "dimax-infra-build-keepalive-$ContractId"
$CreatedContainers = [System.Collections.Generic.List[string]]::new()
$ImageBuildStarted = $false
$OwnsNextDirectory = $false
$CaddyImage = "caddy:2.11.4-alpine"

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = $WorkspaceRoot
    )

    Push-Location $WorkingDirectory
    try {
        Write-Host ">> $Executable $($Arguments -join ' ')"
        & $Executable @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE`: $Executable"
        }
    }
    finally {
        Pop-Location
    }
}

function Save-EnvironmentValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    [pscustomobject]@{
        Name = $Name
        Exists = Test-Path "Env:$Name"
        Value = [Environment]::GetEnvironmentVariable($Name)
    }
}

function Restore-EnvironmentValue {
    param([Parameter(Mandatory = $true)]$Snapshot)

    if ($Snapshot.Exists) {
        [Environment]::SetEnvironmentVariable($Snapshot.Name, $Snapshot.Value)
    }
    else {
        Remove-Item "Env:$($Snapshot.Name)" -ErrorAction SilentlyContinue
    }
}

function Remove-ContractDockerResources {
    param([switch]$KeepImage)

    foreach ($name in @($CreatedContainers)) {
        $label = & docker inspect --format '{{index .Config.Labels "dimax.acceptance.infra"}}' $name 2>$null
        if ($LASTEXITCODE -eq 0 -and "$label".Trim() -eq $ContractId) {
            & docker rm -f $name | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Could not clean owned contract container." }
            $CreatedContainers.Remove($name) | Out-Null
        }
    }
    if (-not $KeepImage -and $ImageBuildStarted) {
        $label = & docker image inspect --format '{{index .Config.Labels "dimax.acceptance.infra"}}' $AdminImage 2>$null
        if ($LASTEXITCODE -eq 0 -and "$label".Trim() -eq $ContractId) {
            & docker image rm $AdminImage | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Could not clean owned contract image." }
        }
    }
}

function Remove-OwnedNextDirectory {
    if (-not $OwnsNextDirectory) { return }
    $target = [IO.Path]::GetFullPath((Join-Path $AdminDir '.next'))
    $root = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\', '/')
    if (-not $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the workspace.'
    }
    $cursor = $target
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Refusing cleanup through a reparse point.'
            }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    if (Test-Path -LiteralPath $target) {
        $links = @(Get-ChildItem -LiteralPath $target -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
        if ($links.Count) { throw 'Refusing cleanup containing reparse points.' }
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

$requiredFiles = @(
    $BackendCompose,
    $EdgeCompose,
    $CaddyFile,
    $BackendExample,
    $AdminDockerfile,
    $AdminDockerignore,
    $AdminArtifactDockerfile,
    $AdminArtifactDockerignore,
    $AdminNextConfig,
    (Join-Path $WorkspaceRoot "infra\production\deploy.sh"),
    (Join-Path $WorkspaceRoot "infra\production\README.md")
)
foreach ($path in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Production infrastructure file is missing: $path"
    }
}

$dockerfileText = Get-Content -LiteralPath $AdminDockerfile -Raw
foreach ($token in @(
    "node scripts/validate-production-env.mjs",
    "/app/.next/standalone",
    "USER 10001:10001",
    'CMD ["node", "server.cjs"]'
)) {
    if (-not $dockerfileText.Contains($token)) {
        throw "Admin production Dockerfile contract is missing: $token"
    }
}

$artifactDockerfileText = Get-Content -LiteralPath $AdminArtifactDockerfile -Raw
foreach ($token in @(
    ".next/standalone",
    "USER 10001:10001",
    'CMD ["node", "server.cjs"]'
)) {
    if (-not $artifactDockerfileText.Contains($token)) {
        throw "Admin artifact Dockerfile contract is missing: $token"
    }
}

if (-not (Get-Content -LiteralPath $AdminNextConfig -Raw).Contains('output: "standalone"')) {
    throw "Next production config must enable standalone output."
}

$dockerignoreText = Get-Content -LiteralPath $AdminDockerignore -Raw
foreach ($token in @("node_modules", ".next", ".env*", "src/test")) {
    if (-not $dockerignoreText.Contains($token)) {
        throw "Admin .dockerignore contract is missing: $token"
    }
}

$environmentNames = @(
    "COMPOSE_PROJECT_NAME",
    "DIMAX_BACKEND_IMAGE",
    "DIMAX_ADMIN_IMAGE",
    "DIMAX_BACKEND_ENV_FILE",
    "DIMAX_CADDYFILE",
    "DIMAX_API_HOST",
    "DIMAX_ADMIN_HOST",
    "DIMAX_TLS_EMAIL",
    "DIMAX_API_BIND",
    "DIMAX_WEB_CONCURRENCY",
    "NEXT_PUBLIC_API_BASE_URL",
    "NEXT_DIST_DIR"
)
$environmentSnapshot = @($environmentNames | ForEach-Object { Save-EnvironmentValue $_ })

try {
    $env:COMPOSE_PROJECT_NAME = "dimax-infra-contract"
    $env:DIMAX_BACKEND_IMAGE = "registry.dimax.invalid/dimax/backend:git-000000000000"
    $env:DIMAX_ADMIN_IMAGE = "registry.dimax.invalid/dimax/admin:git-000000000000"
    $env:DIMAX_BACKEND_ENV_FILE = $BackendExample
    $env:DIMAX_CADDYFILE = $CaddyFile
    $env:DIMAX_API_HOST = "api.dimax.invalid"
    $env:DIMAX_ADMIN_HOST = "ops.dimax.invalid"
    $env:DIMAX_TLS_EMAIL = "owner@dimax.invalid"
    $env:DIMAX_API_BIND = "127.0.0.1:8000"
    $env:DIMAX_WEB_CONCURRENCY = "2"

    Invoke-Native -Executable "docker" -Arguments @(
        "compose",
        "-f", $BackendCompose,
        "-f", $EdgeCompose,
        "config", "--quiet"
    )

    $caddyMount = "${CaddyFile}:/etc/caddy/Caddyfile:ro"
    Invoke-Native -Executable "docker" -Arguments @(
        "run", "--rm", "--pull", "never", "--network", "none",
        "-e", "DIMAX_API_HOST=api.dimax.invalid",
        "-e", "DIMAX_ADMIN_HOST=ops.dimax.invalid",
        "-e", "DIMAX_TLS_EMAIL=owner@dimax.invalid",
        "-v", $caddyMount,
        $CaddyImage,
        "caddy", "validate", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"
    )

    if (-not $ConfigOnly) {
        if (-not $BuildInsideDocker -and (Test-Path -LiteralPath (Join-Path $AdminDir '.next'))) {
            throw 'Existing .next is preserved. Use -BuildInsideDocker or a separate checkout for the host build.'
        }
        $CreatedContainers.Add($KeepaliveContainer)
        Invoke-Native -Executable "docker" -Arguments @(
            "run", "-d",
            "--name", $KeepaliveContainer, "--label", $ContractLabel,
            $CaddyImage,
            "sleep", "45m"
        )

        $env:NEXT_PUBLIC_API_BASE_URL = "https://api.dimax.invalid"
        if ($BuildInsideDocker) {
            $dockerfileName = "Dockerfile"
        }
        else {
            $OwnsNextDirectory = $true
            $env:NEXT_DIST_DIR = '.next'
            Invoke-Native -Executable "npm.cmd" -Arguments @("run", "build") -WorkingDirectory $AdminDir
            $dockerfileName = "Dockerfile.artifact"
        }

        $ImageBuildStarted = $true
        Invoke-Native -Executable "docker" -Arguments @(
            "build",
            "-f", $dockerfileName,
            "--label", $ContractLabel,
            "--build-arg", "NEXT_PUBLIC_API_BASE_URL=https://api.dimax.invalid",
            "-t", $AdminImage,
            "."
        ) -WorkingDirectory $AdminDir

        $imageUser = (& docker image inspect $AdminImage --format "{{.Config.User}}").Trim()
        if ($LASTEXITCODE -ne 0 -or $imageUser -ne "10001:10001") {
            throw "Admin production image must run as 10001:10001, got '$imageUser'."
        }

        Invoke-Native -Executable "docker" -Arguments @(
            "run", "--rm", "--entrypoint", "sh", $AdminImage,
            "-c", "test ! -e /app/.env && test ! -d /app/src && test ! -d /app/e2e"
        )

        Remove-ContractDockerResources -KeepImage
        $runArguments = @(
            "run", "-d",
            "--name", $AdminContainer, "--label", $ContractLabel,
            "--read-only",
            "--tmpfs", "/tmp",
            "--tmpfs", "/app/.next/cache:uid=10001,gid=10001",
            "-p", "127.0.0.1::5173",
            $AdminImage
        )
        $CreatedContainers.Add($AdminContainer)
        $containerId = (& docker @runArguments).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($containerId)) {
            throw "Admin production image did not start."
        }

        $portLine = (& docker port $AdminContainer "5173/tcp").Trim()
        if ($LASTEXITCODE -ne 0 -or $portLine -notmatch ':(\d+)$') {
            throw "Could not resolve the admin contract port."
        }
        $port = $Matches[1]
        $deadline = [DateTime]::UtcNow.AddMinutes(3)
        $ready = $false
        do {
            try {
                $response = Invoke-WebRequest `
                    -Uri "http://127.0.0.1:$port/login" `
                    -UseBasicParsing `
                    -TimeoutSec 10
                $ready = $response.StatusCode -eq 200
            }
            catch {
                Start-Sleep -Seconds 3
            }
        } while (-not $ready -and [DateTime]::UtcNow -lt $deadline)

        if (-not $ready) {
            & docker logs $AdminContainer
            throw "Admin production image did not serve /login within three minutes."
        }
    }

    Write-Host "- Status: PASS"
    Write-Host "DIMAX production infrastructure contract passed."
}
finally {
    try {
        if (-not $ConfigOnly) {
            Remove-ContractDockerResources
            Remove-OwnedNextDirectory
        }
    }
    finally {
        foreach ($snapshot in $environmentSnapshot) {
            Restore-EnvironmentValue $snapshot
        }
    }
}
