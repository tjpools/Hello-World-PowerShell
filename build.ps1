param(
    [ValidateSet('release', 'debug', 'run', 'debug-run', 'dumps')]
    [string]$Target = 'dumps',

    [switch]$Clean,

    [ValidateSet('x64', 'x86')]
    [string]$Arch = 'x64'
)

$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'

if (-not (Test-Path $vswhere)) {
    throw 'vswhere.exe was not found. Install Visual Studio Build Tools or Visual Studio with C++ support.'
}

$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath

if (-not $vsPath) {
    throw 'No Visual Studio installation with C++ build tools was found.'
}

$vsDevCmd = Join-Path $vsPath 'Common7\Tools\VsDevCmd.bat'

if (-not (Test-Path $vsDevCmd)) {
    throw "VsDevCmd.bat was not found at $vsDevCmd"
}

$commands = @()
if ($Clean) {
    $commands += 'nmake clean'
}
$commands += "nmake $Target"

$commandChain = $commands -join ' && '
$cmd = "cd /d `"$projectDir`" && `"$vsDevCmd`" -arch=$Arch && $commandChain"

Write-Host "Using Visual Studio tools from: $vsPath"
Write-Host "Running target: $Target"
if ($Clean) {
    Write-Host 'Running clean first: yes'
}

& cmd /c $cmd

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}