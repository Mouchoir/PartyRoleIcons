$ErrorActionPreference = 'Stop'

$addonName = 'PartyRoleIcons'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$source = Join-Path $projectRoot "addon\$addonName"
$dist = Join-Path $projectRoot 'dist'
$zip = Join-Path $dist "$addonName.zip"

New-Item -ItemType Directory -Force -Path $dist | Out-Null
if (Test-Path -LiteralPath $zip) {
    Remove-Item -LiteralPath $zip -Force
}

Compress-Archive -LiteralPath $source -DestinationPath $zip -Force
Write-Host "Package created: $zip"
