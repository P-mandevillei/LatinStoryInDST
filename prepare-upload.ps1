# Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\prepare-upload.ps1
# Select build\workshop\latinPresentation in the Steam Mod Uploader.
# Select build\workshop\modicon.png separately as the Workshop preview.
# Rerunning this script replaces the generated upload folder.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$buildRoot = Join-Path $projectRoot 'build'
$workshopRoot = Join-Path $buildRoot 'workshop'
$uploadRoot = Join-Path $workshopRoot 'latinPresentation'
$previewPath = Join-Path $workshopRoot 'modicon.png'

# Explicit allowlist: never copy the development folder wholesale.
# Add any future custom runtime assets here; the current mod uses DST's art.
$runtimeFiles = @('modinfo.lua', 'modmain.lua', 'modicon.tex', 'modicon.xml')

function Assert-PlainPath {
    param([string]$LiteralPath)

    if (Test-Path -LiteralPath $LiteralPath) {
        $item = Get-Item -LiteralPath $LiteralPath -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to follow a symbolic link or junction: $LiteralPath"
        }
    }
}

function Get-PlainFiles {
    param([string]$Directory)

    Assert-PlainPath $Directory
    foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
        Assert-PlainPath $item.FullName
        if ($item.PSIsContainer) {
            Get-PlainFiles $item.FullName
        } else {
            $item
        }
    }
}

# Check all sources before replacing a previous upload folder.
foreach ($relativePath in ($runtimeFiles + @('modicon.png'))) {
    $source = Join-Path $projectRoot $relativePath
    Assert-PlainPath $source
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required file is missing: $source"
    }
}
$scriptsRoot = Join-Path $projectRoot 'scripts'
if (-not (Test-Path -LiteralPath $scriptsRoot -PathType Container)) {
    throw "Required scripts directory is missing: $scriptsRoot"
}
$luaFiles = @(Get-PlainFiles $scriptsRoot | Where-Object { $_.Extension -eq '.lua' })
if ($luaFiles.Count -eq 0) {
    throw "No Lua scripts found in: $scriptsRoot"
}

# Keep all generated paths inside this project's dedicated build directory.
$resolvedUploadRoot = [System.IO.Path]::GetFullPath($uploadRoot)
$expectedUploadRoot = $projectRoot + '\build\workshop\latinPresentation'
if (-not [string]::Equals($resolvedUploadRoot, $expectedUploadRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe upload destination: $resolvedUploadRoot"
}
foreach ($path in @($buildRoot, $workshopRoot, $uploadRoot, $previewPath)) {
    Assert-PlainPath $path
}
if (Test-Path -LiteralPath $resolvedUploadRoot) {
    # Refuse linked descendants before any recursive removal.
    $null = @(Get-PlainFiles $resolvedUploadRoot)
    Remove-Item -LiteralPath $resolvedUploadRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $resolvedUploadRoot -Force | Out-Null

foreach ($relativePath in $runtimeFiles) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $relativePath) -Destination (Join-Path $resolvedUploadRoot $relativePath)
}
foreach ($file in $luaFiles) {
    $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
    $destination = Join-Path $resolvedUploadRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
}

# The uploader takes a PNG preview separately; it is not a runtime asset.
Copy-Item -LiteralPath (Join-Path $projectRoot 'modicon.png') -Destination $previewPath -Force
Write-Output ('Prepared {0} runtime files.' -f ($runtimeFiles.Count + $luaFiles.Count))
Write-Output "Upload folder: $resolvedUploadRoot"
Write-Output "Preview image: $previewPath"
