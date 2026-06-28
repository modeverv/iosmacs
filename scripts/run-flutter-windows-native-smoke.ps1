#!/usr/bin/env pwsh
#Requires -Version 5.1
<#
.SYNOPSIS
    Build, launch, and smoke-test the Flutter Windows app with the native Emacs bridge.

.DESCRIPTION
    Builds the Flutter Windows debug bundle, launches the app with autostart
    smoke flags, holds it for a configurable duration, and checks the log for
    native Emacs bridge evidence.

    Prerequisites:
      - Flutter SDK on PATH (or under %USERPROFILE%\work\flutter\bin)
      - Windows Emacs runtime built: .\scripts\build-emacs-windows-runtime.ps1

    Usage:
      .\scripts\run-flutter-windows-native-smoke.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDir    = Split-Path -Parent $scriptDir

$holdSeconds = if ($env:IOSMACS_FLUTTER_WINDOWS_NATIVE_HOLD_SECONDS) {
    [int]$env:IOSMACS_FLUTTER_WINDOWS_NATIVE_HOLD_SECONDS
} else { 8 }

$logPath = Join-Path $env:TEMP 'iosmacs-flutter-windows-native-smoke.log'

# ---------------------------------------------------------------------------
# Locate Flutter
# ---------------------------------------------------------------------------
$flutterBin = ''
$candidateDirs = @(
    (Join-Path $env:USERPROFILE 'work\flutter\bin'),
    'C:\flutter\bin',
    'C:\tools\flutter\bin'
)
foreach ($d in $candidateDirs) {
    $f = Join-Path $d 'flutter.bat'
    if (Test-Path $f) { $flutterBin = $f; break }
}
if (-not $flutterBin) {
    $found = Get-Command 'flutter' -ErrorAction SilentlyContinue
    if ($found) { $flutterBin = $found.Source }
}
if (-not $flutterBin) {
    Write-Error "error: flutter not found; install Flutter SDK or add it to PATH"
    exit 1
}

# ---------------------------------------------------------------------------
# Verify Emacs runtime
# ---------------------------------------------------------------------------
$emacsRuntime = Join-Path $appDir 'build\emacs-windows\runtime'
if (-not (Test-Path (Join-Path $emacsRuntime 'bin\emacs.exe'))) {
    Write-Error "error: Windows Emacs runtime not built; run: .\scripts\build-emacs-windows-runtime.ps1"
    exit 1
}

# ---------------------------------------------------------------------------
# Build Flutter Windows debug bundle
# ---------------------------------------------------------------------------
Push-Location $appDir
try {
    & $flutterBin build windows --debug `
        '--dart-define=IOSMACS_FLUTTER_AUTOSTART_NATIVE=true' `
        '--dart-define=IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT=true' `
        '--dart-define=IOSMACS_FLUTTER_CAPABILITIES_SMOKE=true' `
        '--dart-define=IOSMACS_FLUTTER_INPUT_SMOKE=true' `
        '--dart-define=IOSMACS_FLUTTER_RESIZE_SMOKE=true' `
        '--dart-define=IOSMACS_FLUTTER_REDRAW_SMOKE=true' `
        '--dart-define=IOSMACS_FLUTTER_STATUS_SMOKE=true' `
        '--dart-define=IOSMACS_FLUTTER_STOP_SMOKE=true' `
        '--dart-define=IOSMACS_FLUTTER_WORKSPACE_SMOKE=true'
    if ($LASTEXITCODE -ne 0) {
        Write-Error "error: flutter build windows failed (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

# ---------------------------------------------------------------------------
# Locate built executable
# ---------------------------------------------------------------------------
$bundleDir = Join-Path $appDir 'build\windows\x64\runner\Debug'
$appExe    = Join-Path $bundleDir 'fluttmacs.exe'
if (-not (Test-Path $appExe)) {
    Write-Error "error: missing Flutter Windows executable: $appExe"
    exit 1
}

$bundledEmacs = Join-Path $bundleDir 'data\iosmacs-emacs\bin\emacs.exe'
if (-not (Test-Path $bundledEmacs)) {
    Write-Error "error: missing bundled Emacs in Flutter Windows bundle: $bundledEmacs"
    exit 1
}

# ---------------------------------------------------------------------------
# Launch app
# ---------------------------------------------------------------------------
if (Test-Path $logPath) { Remove-Item $logPath -Force }

Write-Host "Launching Flutter Windows app (hold ${holdSeconds}s)..."
$proc = Start-Process -FilePath $appExe `
    -RedirectStandardOutput $logPath `
    -RedirectStandardError  ($logPath + '.err') `
    -PassThru -WindowStyle Hidden

Start-Sleep -Seconds $holdSeconds

# ---------------------------------------------------------------------------
# Check log
# ---------------------------------------------------------------------------
$log = ''
if (Test-Path $logPath) { $log = Get-Content $logPath -Raw -ErrorAction SilentlyContinue }
$errLog = ''
if (Test-Path ($logPath + '.err')) {
    $errLog = Get-Content ($logPath + '.err') -Raw -ErrorAction SilentlyContinue
}
$combined = $log + "`n" + $errLog

function Check-Pattern([string]$pattern, [string]$msg) {
    if ($combined -notmatch $pattern) {
        Write-Error "error: $msg"
        Write-Host "--- log ---"
        Write-Host $combined
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
        exit 1
    }
}

Check-Pattern 'Windows Emacs process candidates' `
    'Windows process backend did not enumerate Emacs candidates'

Check-Pattern 'Windows interactive GNU Emacs process started:.*iosmacs-emacs.bin.emacs' `
    'Windows native smoke did not start the bundled GNU Emacs process'

if ($combined -match 'Windows Emacs process exited during startup') {
    Write-Error "error: Windows native smoke selected an Emacs process that exited during startup"
    Write-Host "--- log ---"
    Write-Host $combined
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    exit 1
}

Check-Pattern 'iosmacs-capabilities-smoke: id=platform-native-channel' `
    'Windows native smoke did not report selected backend capabilities'

Check-Pattern 'iosmacs-capabilities-smoke: .*supported=[1-9]\d* .*unsupported=[1-9]\d*' `
    'Windows native smoke did not report capability counts'

Check-Pattern 'iosmacs-status-smoke: id=platform-native-channel' `
    'Windows native smoke did not report status smoke backend id'

Check-Pattern 'iosmacs-status-smoke: .* lifecycle=\S+ .*geometry=[1-9]\d*x[1-9]\d*' `
    'Windows native smoke did not report status smoke lifecycle/geometry'

Check-Pattern 'iosmacs-input-smoke: committed [1-9]\d* byte\(s\); backend input total [1-9]\d*' `
    'Windows native smoke did not report input smoke evidence'

Check-Pattern 'iosmacs-resize-smoke: requested [1-9]\d*x[1-9]\d*; backend geometry [1-9]\d*x[1-9]\d*' `
    'Windows native smoke did not report resize smoke evidence'

Check-Pattern 'iosmacs-redraw-smoke: message="[^"]+"' `
    'Windows native smoke did not report redraw smoke evidence'

Check-Pattern 'iosmacs-stop-smoke: lifecycle=stopped' `
    'Windows native smoke did not report stop smoke evidence'

Check-Pattern 'iosmacs-workspace-smoke: workspace listed' `
    'Windows workspace smoke did not list workspace entries'

if ($combined -notmatch 'iosmacs-workspace-smoke: workspace export candidate\(s\):') {
    Write-Error "error: Windows workspace smoke did not report export candidates"
    Write-Host "--- log ---"
    Write-Host $combined
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    exit 1
}

if ($combined -notmatch 'iosmacs-workspace-smoke: workspace imported 1 item\(s\)') {
    Write-Error "error: Windows workspace smoke did not import the smoke file"
    Write-Host "--- log ---"
    Write-Host $combined
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    exit 1
}

Check-Pattern 'iosmacs-workspace-smoke: workspace listed after import' `
    'Windows workspace smoke did not list workspace after import'

Check-Pattern 'iosmacs-workspace-smoke: workspace open requested: .+ \([1-9]\d* byte\(s\)\); backend input total [1-9]\d*' `
    'Windows workspace smoke did not report workspace open evidence'

# ---------------------------------------------------------------------------
# Terminate
# ---------------------------------------------------------------------------
if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $proc.WaitForExit(3000) | Out-Null
}

Write-Host "flutter Windows native smoke ok: $logPath"
