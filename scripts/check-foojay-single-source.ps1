#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies the template's single-source Foojay settings-plugin contract.

.DESCRIPTION
    Checks that settings.gradle.kts has exactly one Foojay plugin declaration,
    that the declaration contains a version, and that the version catalog has
    no Foojay alias. It then changes the authoritative declaration in memory
    and verifies that the settings declaration changes with it.

    This is a static check; it does not resolve the plugin or require a JDK.
#>
[CmdletBinding()]
param(
    [string]$Root
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Join-Path $PSScriptRoot '..'
}
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$settingsPath = Join-Path $rootPath 'settings.gradle.kts'
$catalogPath = Join-Path $rootPath 'gradle/libs.versions.toml'

foreach ($path in @($settingsPath, $catalogPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file not found: $path"
    }
}

$settings = Get-Content -Raw -LiteralPath $settingsPath
$catalog = Get-Content -Raw -LiteralPath $catalogPath
$pluginPattern = '(?m)^(\s*id\("org\.gradle\.toolchains\.foojay-resolver-convention"\)\s+version\s+")([^"]+)("\s*)$'
$matches = [regex]::Matches($settings, $pluginPattern)

if ($matches.Count -ne 1) {
    throw "Expected exactly one Foojay settings-plugin declaration; found $($matches.Count)."
}

$version = $matches[0].Groups[2].Value
if ([string]::IsNullOrWhiteSpace($version)) {
    throw 'The Foojay settings-plugin declaration has an empty version.'
}

$catalogDuplicates = [regex]::Matches(
    $catalog,
    '(?im)^\s*[A-Za-z0-9_-]*foojay[A-Za-z0-9_-]*\s*='
)
if ($catalogDuplicates.Count -ne 0) {
    throw 'The version catalog contains a Foojay assignment; keep Foojay settings-owned.'
}

$candidateVersion = '99.99.99-contract-test'
$mutatedSettings = [regex]::Replace(
    $settings,
    $pluginPattern,
    '${1}' + $candidateVersion + '${3}'
)
$mutatedMatches = [regex]::Matches($mutatedSettings, $pluginPattern)
if ($mutatedMatches.Count -ne 1 -or $mutatedMatches[0].Groups[2].Value -ne $candidateVersion) {
    throw 'Changing the settings-owned version did not change the applied Foojay declaration.'
}

Write-Host "Foojay single-source contract OK: settings.gradle.kts owns version $version; catalog has no Foojay alias."
