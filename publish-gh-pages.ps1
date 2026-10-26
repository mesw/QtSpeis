#Requires -Version 5.1
<#
.SYNOPSIS
    Publishes the local WebAssembly Release build of QtSpeis directly to the
    'gh-pages' branch on GitHub Pages without pushing C++ source code.
#>

$ErrorActionPreference = "Stop"

$repoRoot  = $PSScriptRoot
$wasmBuild = Join-Path $repoRoot "build\WebAssembly_Qt_6_8_3_single_threaded-Release"
$stageDir  = Join-Path $env:TEMP "qtspeis-gh-pages"
$remoteUrl = "https://github.com/mesw/QtSpeis.git"

# 0. Verify WebAssembly build artifacts exist
$requiredFiles = @("appQtSpeis.html", "appQtSpeis.js", "appQtSpeis.wasm", "qtloader.js")
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $wasmBuild $file
    if (-not (Test-Path $fullPath)) {
        Write-Error "Missing build artifact: $fullPath`nPlease build the WebAssembly Release target first."
        exit 1
    }
}

Write-Host "==> Preparing clean staging directory: $stageDir" -ForegroundColor Cyan
if (Test-Path $stageDir) {
    Remove-Item -Recurse -Force $stageDir
}
New-Item -ItemType Directory -Path $stageDir | Out-Null

# 1. Copy WebAssembly build artifacts
foreach ($file in $requiredFiles) {
    Copy-Item (Join-Path $wasmBuild $file) (Join-Path $stageDir $file)
}
$logoPath = Join-Path $wasmBuild "qtlogo.svg"
if (Test-Path $logoPath) {
    Copy-Item $logoPath (Join-Path $stageDir "qtlogo.svg")
}

# 2. Copy landing page as pure UTF-8 (without BOM) and point redirect/links to appQtSpeis.html
$indexSourcePath = Join-Path $repoRoot "index.html"
$indexDestPath   = Join-Path $stageDir "index.html"
$utf8NoBom       = New-Object System.Text.UTF8Encoding($false)
$htmlContent     = [System.IO.File]::ReadAllText($indexSourcePath, $utf8NoBom)
$htmlContent     = $htmlContent.Replace(
    "build/WebAssembly_Qt_6_8_3_single_threaded-Release/index.html",
    "appQtSpeis.html"
)
[System.IO.File]::WriteAllText($indexDestPath, $htmlContent, $utf8NoBom)

# 3. Create .nojekyll so GitHub Pages serves all assets directly
New-Item -ItemType File -Path (Join-Path $stageDir ".nojekyll") | Out-Null

# 4. Commit and force-push ONLY the staging folder to the gh-pages branch
Write-Host "==> Deploying to $remoteUrl (branch: gh-pages)..." -ForegroundColor Cyan
Push-Location $stageDir
try {
    git init
    git checkout -b gh-pages
    git add .
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    git commit -m "Deploy WebAssembly build ($timestamp)"
    git push -f $remoteUrl gh-pages
    Write-Host "==> Successfully published to https://mesw.github.io/QtSpeis/" -ForegroundColor Green
} finally {
    Pop-Location
}
