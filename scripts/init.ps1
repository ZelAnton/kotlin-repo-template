#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initializes this template into a concrete Kotlin (Gradle) project.

.DESCRIPTION
    POSIX counterpart: scripts/init.sh — use whichever matches your shell.

    Replaces the placeholder tokens (__ProjectName__, __PackageName__, __Group__,
    __Author__, __GitHubOwner__, __Description__, __Year__) in file contents,
    moves the token-named Kotlin source package
    (src/{main,test}/kotlin/__PackageName__) into the real dotted-package
    directory tree, then removes the template-only files (TEMPLATE.md,
    docs/AGENT-INIT-GUIDE.md, and — unless -KeepScript — both initializers,
    init.ps1 and init.sh).

    Run it once, right after creating a repository from the template:

        pwsh ./scripts/init.ps1 -ProjectName acme-widgets -PackageName com.acme.widgets

    Omitted optional values fall back to sensible defaults so the result always
    builds; edit LICENSE / build.gradle.kts afterwards if you need to refine them.

.PARAMETER ProjectName
    Gradle project / artifact name (rootProject.name). Required. Letters, digits,
    '-' and '_' (kebab-case recommended, e.g. acme-widgets).

.PARAMETER PackageName
    Kotlin package (dotted, lowercase, e.g. com.acme.widgets). Defaults to the
    group plus a sanitized project name.

.PARAMETER Group
    Maven group id (e.g. com.acme). Defaults to "io.github.<github-owner>".

.PARAMETER Author
    Author for LICENSE / POM. Defaults to `git config user.name`, else "Your Name".

.PARAMETER GitHubOwner
    GitHub owner/org used in repository URLs. Defaults to "your-org".

.PARAMETER Description
    Short project description. Defaults to "TODO: project description".

.PARAMETER Year
    Copyright year. Defaults to the current year.

.PARAMETER KeepScript
    Keep both initializers (init.ps1 and init.sh) after running. TEMPLATE.md and
    docs/AGENT-INIT-GUIDE.md are removed either way.

.EXAMPLE
    pwsh ./scripts/init.ps1 -ProjectName acme-widgets -PackageName com.acme.widgets -Author "Jane Doe" -GitHubOwner acme -Description "Widget toolkit"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    [string]$PackageName,
    [string]$Group,
    [string]$Author,
    [string]$GitHubOwner,
    [string]$Description,
    [int]$Year = (Get-Date).Year,
    [switch]$KeepScript
)

$ErrorActionPreference = 'Stop'

# Gradle artifact names: letters, digits, '-' and '_'; start with a letter.
if ($ProjectName -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
    throw "Invalid -ProjectName '$ProjectName'. Use letters, digits, '-' or '_'; start with a letter (e.g. acme-widgets)."
}

if (-not $Author) {
    $Author = (& git config user.name 2>$null)
    if (-not $Author) { $Author = 'Your Name' }
}
if (-not $GitHubOwner) { $GitHubOwner = 'your-org' }
if (-not $Description) { $Description = 'TODO: project description' }

# Sanitize a string into a single legal lowercase package segment.
function ConvertTo-PackageSegment([string]$value) {
    $seg = ($value.ToLowerInvariant() -replace '[^a-z0-9]', '')
    if (-not $seg) { $seg = 'app' }
    if ($seg -match '^[0-9]') { $seg = "_$seg" }
    return $seg
}

if (-not $Group) { $Group = "io.github.$(ConvertTo-PackageSegment $GitHubOwner)" }
if (-not $PackageName) { $PackageName = "$Group.$(ConvertTo-PackageSegment $ProjectName)" }

# A package is dot-separated identifiers: [a-z_][a-z0-9_]* per segment.
foreach ($seg in ($PackageName -split '\.')) {
    if ($seg -notmatch '^[a-z_][a-z0-9_]*$') {
        throw "Invalid -PackageName '$PackageName'. Each segment must be lowercase letters/digits/underscore and start with a letter or underscore (e.g. com.acme.widgets)."
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$selfPath = $PSCommandPath
$siblingSh = Join-Path $PSScriptRoot 'init.sh'

$replacements = [ordered]@{
    '__ProjectName__' = $ProjectName
    '__PackageName__' = $PackageName
    '__Group__'       = $Group
    '__Author__'      = $Author
    '__GitHubOwner__' = $GitHubOwner
    '__Description__'  = $Description
    '__Year__'        = "$Year"
}

# Values written into Kotlin-script / TOML files sit inside double-quoted strings
# (rootProject.name, group, the POM fields). A literal " or \ would break the
# script, so escape them for those targets.
$escapedReplacements = [ordered]@{}
foreach ($key in $replacements.Keys) {
    $escapedReplacements[$key] = $replacements[$key].Replace('\', '\\').Replace('"', '\"')
}
$escapedFileExtensions = @('.kts', '.toml')

$excludedDirs = @('.git', '.jj', 'build', '.gradle', '.idea')

function Test-Excluded([string]$fullPath) {
    $rel = $fullPath.Substring($repoRoot.Length).TrimStart('\', '/')
    foreach ($seg in ($rel -split '[\\/]')) {
        if ($excludedDirs -contains $seg) { return $true }
    }
    return $false
}

Write-Host "==> Initializing template as '$ProjectName' (package $PackageName)" -ForegroundColor Cyan

# 1) Replace tokens in file contents. Both initializers are skipped: they carry
#    the literal token strings as search keys, so substituting inside them would
#    corrupt the sibling script.
$files = Get-ChildItem -Path $repoRoot -File -Recurse | Where-Object {
    -not (Test-Excluded $_.FullName) -and $_.FullName -ne $selfPath -and $_.FullName -ne $siblingSh
}
# Binary extensions are skipped: they carry no tokens, and reading them as text
# (then rewriting) would corrupt them — notably gradle/wrapper/gradle-wrapper.jar.
$binaryExtensions = @('.jar', '.png', '.jpg', '.gif', '.ico', '.zip')
$contentChanged = 0
foreach ($file in $files) {
    if ($binaryExtensions -contains $file.Extension) { continue }
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $new = $text
    $map = if ($escapedFileExtensions -contains $file.Extension) { $escapedReplacements } else { $replacements }
    foreach ($key in $map.Keys) {
        $new = $new.Replace($key, $map[$key])
    }
    if ($new -ne $text) {
        # UTF-8 without BOM, LF preserved — matches .gitattributes (eol=lf).
        [System.IO.File]::WriteAllText($file.FullName, $new, (New-Object System.Text.UTF8Encoding($false)))
        $contentChanged++
    }
}
Write-Host "    Updated contents in $contentChanged file(s)." -ForegroundColor DarkGray

# 2) Move the token-named Kotlin package directory into the real dotted-package
#    tree (e.g. src/main/kotlin/__PackageName__ -> src/main/kotlin/com/acme/widgets).
#    This is the Kotlin-specific step: a JVM source file must live in a directory
#    path matching its `package` declaration.
$pkgRelPath = $PackageName.Replace('.', [IO.Path]::DirectorySeparatorChar)
$srcRoot = Join-Path $repoRoot 'src'
if (Test-Path $srcRoot) {
    $tokenDirs = Get-ChildItem -Path $srcRoot -Directory -Recurse | Where-Object { $_.Name -eq '__PackageName__' }
    foreach ($dir in $tokenDirs) {
        $dest = Join-Path $dir.Parent.FullName $pkgRelPath
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Get-ChildItem -LiteralPath $dir.FullName -File | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
        Remove-Item -LiteralPath $dir.FullName -Recurse -Force
        $relParent = $dir.Parent.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
        Write-Host "    Moved $relParent/__PackageName__ -> $relParent/$($PackageName.Replace('.', '/'))" -ForegroundColor DarkGray
    }
}

# 3) Activate Claude Code shared settings if shipped as a .template.
$claudeTemplate = Join-Path $repoRoot '.claude/settings.json.template'
if (Test-Path $claudeTemplate) {
    Move-Item -LiteralPath $claudeTemplate -Destination (Join-Path $repoRoot '.claude/settings.json') -Force
    Write-Host "    Activated .claude/settings.json" -ForegroundColor DarkGray
}

# 4) Remove template-only files. The agent guide is template meta — pitfalls are
#    logged back to the *template's* copy, so the downstream repo doesn't keep it.
$templateOnly = @('TEMPLATE.md', 'docs/AGENT-INIT-GUIDE.md')
foreach ($rel in $templateOnly) {
    $p = Join-Path $repoRoot $rel
    if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
}
# Drop docs/ if it's now empty.
$docsDir = Join-Path $repoRoot 'docs'
if ((Test-Path $docsDir) -and -not (Get-ChildItem -LiteralPath $docsDir -Force)) {
    Remove-Item -LiteralPath $docsDir -Force
}

# Strip the template-only ktlint exemption from .editorconfig. It disables the
# package-name rule for the placeholder package directory, which no longer exists
# after the move in step 2, so the rule now applies to the real package.
$editorConfig = Join-Path $repoRoot '.editorconfig'
if (Test-Path $editorConfig) {
    $ecText = [System.IO.File]::ReadAllText($editorConfig)
    $ecNew = [regex]::Replace($ecText, '(?s)\r?\n# >>> template-only:ktlint-placeholder.*?# <<< template-only:ktlint-placeholder\r?\n', '')
    if ($ecNew -ne $ecText) {
        [System.IO.File]::WriteAllText($editorConfig, $ecNew, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "    Removed template-only ktlint exemption from .editorconfig" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Green
Write-Host "  1. ./gradlew build"
Write-Host "  2. ./gradlew ktlintFormat   # auto-fix style, then re-run build"
Write-Host "  3. Review LICENSE (author/year) and build.gradle.kts POM metadata."
Write-Host "  4. Replace src/main/kotlin/.../Greeter.kt with your real API and"
Write-Host "     update the sample test."
Write-Host "  5. Fill the Architecture section of CLAUDE.md, then commit."

# Remove both initializers unless asked to keep them.
if (-not $KeepScript) {
    if (Test-Path $siblingSh) { Remove-Item -LiteralPath $siblingSh -Force }
    Remove-Item -LiteralPath $selfPath -Force
}
