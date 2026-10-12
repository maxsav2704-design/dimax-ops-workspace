# Test-only Docker/git/npm substitutes. No real services or builds are invoked.
$ErrorActionPreference = 'Stop'
$global:DimaxInfraTestLabels = @{}
function global:docker {
    ConvertTo-Json -InputObject @($args) -Compress | Add-Content -LiteralPath $env:DIMAX_INFRA_TEST_LOG
    $global:LASTEXITCODE = 0
    if ($env:DIMAX_INFRA_TEST_FAIL -eq 'config' -and $args -contains 'config') {
        $global:LASTEXITCODE = 1
    }
    if ($args -contains '--label') {
        $name = $args[[Array]::IndexOf($args, '--name') + 1]
        $label = $args[[Array]::IndexOf($args, '--label') + 1]
        $global:DimaxInfraTestLabels[$name] = $label.Split('=', 2)[1]
    }
    if ($args[0] -eq 'inspect') { $global:DimaxInfraTestLabels[$args[-1]] }
}
function global:git { throw 'Infrastructure check attempted a Git mutation.' }
function global:npm.cmd {
    if ($env:DIMAX_INFRA_TEST_MODE -ne 'build-failure') { throw 'Infrastructure config check attempted an npm build.' }
    if ($env:NEXT_DIST_DIR -ne '.next') { throw 'Host build did not isolate its output directory.' }
    New-Item -ItemType Directory -Path '.next' | Out-Null
    Set-Content -LiteralPath '.next/partial-build' -Value 'disposable output'
    throw 'Synthetic host build failure.'
}

$previousDist = $env:NEXT_DIST_DIR
try {
    if ($env:DIMAX_INFRA_TEST_MODE -in @('host', 'build-failure')) {
        & $env:DIMAX_INFRA_TEST_SCRIPT
    } else {
        & $env:DIMAX_INFRA_TEST_SCRIPT -ConfigOnly
    }
} finally {
    if ($env:NEXT_DIST_DIR -ne $previousDist) { throw 'Caller build environment was not restored.' }
}
