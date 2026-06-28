#!/usr/bin/env pwsh
#Requires -Version 5.1
<#
.SYNOPSIS
    Build a headless GNU Emacs runtime for the Flutter Windows app.

.DESCRIPTION
    Calls scripts/build-emacs-windows-runtime.sh via MSYS2 bash
    (MinGW-w64 toolchain).  The resulting runtime lands in
    build/emacs-windows/runtime and is bundled by CMake on the next
    flutter build windows.

    Prerequisites:
      - MSYS2 installed (default: C:\msys64)
      - Inside MSYS2 MinGW64 shell, run once:
          pacman -S --noconfirm mingw-w64-x86_64-toolchain autoconf automake make pkg-config rsync
      - GNU Emacs source at wasmacs/vendor/emacs
        (or set IOSMACS_EMACS_SOURCE)

    Usage:
      powershell.exe -ExecutionPolicy Bypass -File scripts\build-emacs-windows-runtime.ps1

    Environment overrides:
      IOSMACS_EMACS_SOURCE                       Emacs source tree path
      IOSMACS_FLUTTER_WINDOWS_EMACS_BUILD_ROOT   Build root (default: build\emacs-windows)
      IOSMACS_FLUTTER_WINDOWS_EMACS_DEST         Copy runtime here after build
      IOSMACS_FLUTTER_WINDOWS_EMACS_RUNTIME_NAME Runtime dir name (default: iosmacs-emacs)
      MSYS2_PATH                                 MSYS2 install dir (default: C:\msys64)
      JOBS                                       Parallel build jobs
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot    = Split-Path -Parent $scriptDir

$msys2Path   = if ($env:MSYS2_PATH)      { $env:MSYS2_PATH }      else { 'C:\msys64' }
$sourceRoot  = if ($env:IOSMACS_EMACS_SOURCE) { $env:IOSMACS_EMACS_SOURCE } `
               else { Join-Path $repoRoot 'wasmacs\vendor\emacs' }
$buildRoot   = if ($env:IOSMACS_FLUTTER_WINDOWS_EMACS_BUILD_ROOT) `
               { $env:IOSMACS_FLUTTER_WINDOWS_EMACS_BUILD_ROOT } `
               else { Join-Path $repoRoot 'build\emacs-windows' }
$runtimeName = if ($env:IOSMACS_FLUTTER_WINDOWS_EMACS_RUNTIME_NAME) `
               { $env:IOSMACS_FLUTTER_WINDOWS_EMACS_RUNTIME_NAME } else { 'iosmacs-emacs' }
$destination = if ($env:IOSMACS_FLUTTER_WINDOWS_EMACS_DEST) `
               { $env:IOSMACS_FLUTTER_WINDOWS_EMACS_DEST } else { '' }
$jobs        = if ($env:JOBS) { $env:JOBS } else { [Environment]::ProcessorCount }

$sourceCopy   = Join-Path $buildRoot 'source'
$buildDir     = Join-Path $buildRoot 'build'
$runtimeRoot  = Join-Path $buildRoot 'runtime'

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
$bash = Join-Path $msys2Path 'usr\bin\bash.exe'
if (-not (Test-Path $bash)) {
    Write-Error @"
error: MSYS2 bash not found at $bash

  Install MSYS2 from https://www.msys2.org/ or set MSYS2_PATH.

  Example (PowerShell):
    ${'$'}env:MSYS2_PATH = 'C:\msys64'
    powershell.exe -ExecutionPolicy Bypass -File scripts\build-emacs-windows-runtime.ps1
"@
    exit 1
}

# Check Emacs is installed via MSYS2 package (UCRT64 or MINGW64)
$ucrt64Emacs  = Join-Path $msys2Path 'ucrt64\bin\emacs.exe'
$mingw64Emacs = Join-Path $msys2Path 'mingw64\bin\emacs.exe'
if (-not (Test-Path $ucrt64Emacs) -and -not (Test-Path $mingw64Emacs)) {
    Write-Error @"
error: Emacs not found in MSYS2 ($msys2Path).

  Open an MSYS2 UCRT64 shell and run:
    pacman -S --noconfirm mingw-w64-ucrt-x86_64-emacs

  Then re-run this script.
"@
    exit 1
}

# ---------------------------------------------------------------------------
# Check if runtime is already ready
# ---------------------------------------------------------------------------
function Test-RuntimeReady {
    (Test-Path (Join-Path $runtimeRoot 'bin\emacs.exe')) -and
    (Test-Path (Join-Path $runtimeRoot 'lisp\loadup.el')) -and
    (Test-Path (Join-Path $runtimeRoot 'etc\charsets\README'))
}

if (Test-RuntimeReady) {
    Write-Host "flutter Windows Emacs runtime already ready: $runtimeRoot"
    if ($destination) {
        $destTarget = Join-Path $destination $runtimeName
        if (Test-Path $destTarget) { Remove-Item $destTarget -Recurse -Force }
        Copy-Item $runtimeRoot $destTarget -Recurse
    }
    exit 0
}

# ---------------------------------------------------------------------------
# Convert Windows path -> MSYS2 path (e.g. C:\foo -> /c/foo)
# ---------------------------------------------------------------------------
function ConvertTo-MsysPath([string]$winPath) {
    $p = $winPath -replace '\\', '/'
    if ($p -match '^([A-Za-z]):(.*)') {
        return '/' + $Matches[1].ToLower() + $Matches[2]
    }
    return $p
}

$msysSourceRoot  = ConvertTo-MsysPath $sourceRoot
$msysSourceCopy  = ConvertTo-MsysPath $sourceCopy
$msysBuildDir    = ConvertTo-MsysPath $buildDir
$msysRuntimeRoot = ConvertTo-MsysPath $runtimeRoot
$msysBashScript  = ConvertTo-MsysPath (Join-Path $scriptDir 'build-emacs-windows-runtime.sh')

# ---------------------------------------------------------------------------
# Create build directories and run the bash build script
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null

Write-Host "Building Windows Emacs runtime via MSYS2..."
Write-Host "  Source:  $sourceRoot"
Write-Host "  Build:   $buildDir"
Write-Host "  Output:  $runtimeRoot"
Write-Host "  MSYS2:   $msys2Path"
Write-Host ""

$env:IOSMACS_EMACS_SOURCE   = $msysSourceRoot
$env:IOSMACS_WIN_SOURCE_COPY = $msysSourceCopy
$env:IOSMACS_WIN_BUILD_DIR   = $msysBuildDir
$env:IOSMACS_WIN_RUNTIME_ROOT = $msysRuntimeRoot
$env:JOBS = "$jobs"

& $bash --login $msysBashScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "error: Emacs build failed (exit $LASTEXITCODE)"
    exit $LASTEXITCODE
}

if (-not (Test-RuntimeReady)) {
    Write-Error "error: Windows Emacs runtime not complete after build"
    exit 1
}

Write-Host ""
Write-Host "flutter Windows Emacs runtime ready: $runtimeRoot"

if ($destination) {
    $destTarget = Join-Path $destination $runtimeName
    if (Test-Path $destTarget) { Remove-Item $destTarget -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Copy-Item $runtimeRoot $destTarget -Recurse
    Write-Host "flutter Windows Emacs runtime copied to: $destTarget"
}
