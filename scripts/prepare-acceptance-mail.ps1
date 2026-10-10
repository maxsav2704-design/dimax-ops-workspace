#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$folder = Join-Path $root 'acceptance\.factory-mail'
$file = Join-Path $folder 'shared.env'

function Assert-PlainPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Refusing secret provisioning through a reparse point.'
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

if (!(Test-Path -LiteralPath (Join-Path $root 'docker-compose.acceptance.yml') -PathType Leaf)) {
    throw 'Run this script from a DIMAX acceptance workspace.'
}
Assert-PlainPath $file
if (![IO.Path]::GetFullPath($file).StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Secret destination is outside the workspace.'
}
[IO.Directory]::CreateDirectory($folder) | Out-Null

# Restrict only this dedicated local-secret directory, never the workspace ACL.
$owner = [Security.Principal.WindowsIdentity]::GetCurrent().User
$system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$directory = [IO.DirectoryInfo]::new($folder)
$acl = [IO.FileSystemAclExtensions]::GetAccessControl($directory, [Security.AccessControl.AccessControlSections]::Access)
$acl.SetAccessRuleProtection($true, $false)
foreach ($rule in @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) {
    $acl.RemoveAccessRuleSpecific($rule)
}
foreach ($sid in @($owner, $system)) {
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
[IO.FileSystemAclExtensions]::SetAccessControl($directory, $acl)

function Protect-SecretFile {
    $info = [IO.FileInfo]::new($file)
    $fileAcl = [IO.FileSystemAclExtensions]::GetAccessControl($info, [Security.AccessControl.AccessControlSections]::Access)
    $fileAcl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($fileAcl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))) {
        $fileAcl.RemoveAccessRuleSpecific($rule)
    }
    foreach ($sid in @($owner, $system)) {
        $fileAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'Allow'))
    }
    [IO.FileSystemAclExtensions]::SetAccessControl($info, $fileAcl)
}

if (Test-Path -LiteralPath $file) {
    Protect-SecretFile
    $content = [IO.File]::ReadAllText($file)
    if ($content -notmatch '\AFACTORY_APPROVAL_EMAIL_KEY=([A-Za-z0-9+/]{43}=)\r?\n?\z') {
        throw 'Existing mail secret is invalid; refusing automatic replacement.'
    }
    if ([Convert]::FromBase64String($Matches[1]).Length -ne 32) { throw 'Invalid mail secret length.' }
    Write-Output '{"status":"reused","rotated":false}'
    exit 0
}

$random = [byte[]]::new(32)
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($random) } finally { $rng.Dispose() }
$data = [Text.Encoding]::ASCII.GetBytes("FACTORY_APPROVAL_EMAIL_KEY=$([Convert]::ToBase64String($random))`n")
$stream = [IO.File]::Open($file, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $stream.Write($data, 0, $data.Length) } finally {
    $stream.Dispose()
    [Array]::Clear($random, 0, $random.Length)
    [Array]::Clear($data, 0, $data.Length)
}
Protect-SecretFile
Write-Output '{"status":"created","rotated":false}'
