<#
.SYNOPSIS
Builds and analyzes the Hello World PowerShell artifact.

.DESCRIPTION
This script is the authoritative pipeline for the repository. It compiles the C++ source with
MSVC, writes build outputs into build/, derives analysis outputs into analysis/, and optionally
refreshes a local Ghidra project.

.PARAMETER Target
Pipeline target to execute.

.PARAMETER Clean
Removes reproducible outputs before executing the requested target.

.PARAMETER Arch
Architecture passed to VsDevCmd.bat.

.PARAMETER SkipGhidra
Skips Ghidra project generation. Useful for CI environments where Ghidra is not installed.
#>

param(
    [ValidateSet('clean', 'release', 'debug', 'run', 'debug-run', 'dumps')]
    [string]$Target = 'dumps',

    [switch]$Clean,

    [ValidateSet('x64', 'x86')]
    [string]$Arch = 'x64',

    [switch]$SkipGhidra
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent $PSScriptRoot
$srcDir = Join-Path $repoRoot 'src'
$buildDir = Join-Path $repoRoot 'build'
$analysisDir = Join-Path $repoRoot 'analysis'
$objdumpDir = Join-Path $analysisDir 'objdump'
$hexdumpDir = Join-Path $analysisDir 'hexdump'
$ghidraDir = Join-Path $analysisDir 'ghidra'

$sourceFile = Join-Path $srcDir 'test.cpp'
$targetExe = Join-Path $buildDir 'test.exe'
$targetObj = Join-Path $buildDir 'test.obj'
$targetPdb = Join-Path $buildDir 'test.pdb'
$targetIlk = Join-Path $buildDir 'test.ilk'
$runtimePdb = Join-Path $buildDir 'vc140.pdb'

$fullObjdump = Join-Path $objdumpDir 'test.objdump.txt'
$mainObjdump = Join-Path $objdumpDir 'test.main.objdump.txt'
$invokeMainObjdump = Join-Path $objdumpDir 'test.invoke_main.objdump.txt'
$mainCrtObjdump = Join-Path $objdumpDir 'test.mainCRTStartup.objdump.txt'
$hexdump = Join-Path $hexdumpDir 'test.hexdump.txt'
$ghidraProjectName = 'ghidra-test'
$ghidraProjectFile = Join-Path $ghidraDir "$ghidraProjectName.gpr"

function Write-Step {
    param([string]$Message)

    Write-Host "==> $Message"
}

function Test-CommandAvailable {
    param([string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw $Message
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [string]$FailureMessage = 'Native command failed.'
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage Exit code: $LASTEXITCODE"
    }
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Remove-PathIfExists {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force
        }
        catch {
            Write-Warning "Skipping locked path during clean: $Path"
        }
    }
}

function Initialize-Directories {
    Ensure-Directory -Path $buildDir
    Ensure-Directory -Path $analysisDir
    Ensure-Directory -Path $objdumpDir
    Ensure-Directory -Path $hexdumpDir
    Ensure-Directory -Path $ghidraDir
}

function Invoke-CleanLayout {
    Write-Step 'Cleaning generated layout'

    Remove-PathIfExists -Path $buildDir
    Remove-PathIfExists -Path $analysisDir

    $legacyPaths = @(
        (Join-Path $repoRoot 'test.exe'),
        (Join-Path $repoRoot 'test.obj'),
        (Join-Path $repoRoot 'test.pdb'),
        (Join-Path $repoRoot 'test.ilk'),
        (Join-Path $repoRoot 'vc140.pdb'),
        (Join-Path $repoRoot 'test.objdump.txt'),
        (Join-Path $repoRoot 'test.main.objdump.txt'),
        (Join-Path $repoRoot 'test.invoke_main.objdump.txt'),
        (Join-Path $repoRoot 'test.mainCRTStartup.objdump.txt'),
        (Join-Path $repoRoot 'test.hexdump.txt'),
        (Join-Path $repoRoot 'ghidra-test.gpr'),
        (Join-Path $repoRoot 'ghidra-test.lock'),
        (Join-Path $repoRoot 'ghidra-test.lock~'),
        (Join-Path $repoRoot 'ghidra-test.rep')
    )

    foreach ($path in $legacyPaths) {
        Remove-PathIfExists -Path $path
    }
}

function Import-VsDevEnvironment {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        throw 'vswhere.exe was not found. Install Visual Studio Build Tools or Visual Studio with C++ support.'
    }

    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vsPath) {
        throw 'No Visual Studio installation with C++ build tools was found.'
    }

    $vsDevCmd = Join-Path $vsPath 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $vsDevCmd)) {
        throw "VsDevCmd.bat was not found at $vsDevCmd"
    }

    Write-Step "Using Visual Studio tools from: $vsPath"

    $environmentLines = & cmd /c "`"$vsDevCmd`" -arch=$Arch >nul && set"
    foreach ($line in $environmentLines) {
        $separatorIndex = $line.IndexOf('=')
        if ($separatorIndex -le 0) {
            continue
        }

        $name = $line.Substring(0, $separatorIndex)
        $value = $line.Substring($separatorIndex + 1)
        Set-Item -Path "Env:$name" -Value $value
    }
}

function Invoke-ClBuild {
    param([ValidateSet('release', 'debug')] [string]$Configuration)

    Initialize-Directories
    Assert-PathExists -Path $sourceFile -Message "Source file not found: $sourceFile"

    $compileFlags = @('/EHsc', '/nologo', '/Zi')
    if ($Configuration -eq 'release') {
        $compileFlags += '/O2'
    }
    else {
        $compileFlags += '/Od'
    }

    Push-Location $buildDir
    try {
        Write-Step "Building $Configuration artifacts"

        $arguments = @(
            $sourceFile,
            '/Fotest.obj',
            '/Fdtest.pdb',
            '/Fetest.exe'
        ) + $compileFlags + @(
            '/link',
            '/DEBUG',
            '/OUT:test.exe',
            '/PDB:test.pdb',
            '/ILK:test.ilk'
        )

        Invoke-NativeCommand -FilePath 'cl' -Arguments $arguments -FailureMessage 'MSVC compilation failed.'

        Assert-PathExists -Path $targetExe -Message "Expected executable was not produced: $targetExe"
        Assert-PathExists -Path $targetObj -Message "Expected object file was not produced: $targetObj"
        Assert-PathExists -Path $targetPdb -Message "Expected PDB file was not produced: $targetPdb"
    }
    finally {
        Pop-Location
    }
}

function Write-FunctionSlice {
    param(
        [string]$InputPath,
        [string]$Label,
        [string]$OutputPath
    )

    $lines = Get-Content -LiteralPath $InputPath
    $start = [Array]::IndexOf($lines, "${Label}:")
    if ($start -lt 0) {
        throw "$Label symbol not found in objdump output"
    }

    $end = $start + 1
    while ($end -lt $lines.Length) {
        if ($end -gt $start -and $lines[$end] -match '^[^ ].*:$') {
            break
        }
        $end++
    }

    $lines[$start..($end - 1)] | Set-Content -LiteralPath $OutputPath -Encoding ascii
}

function Find-GhidraHeadless {
    $candidates = @(
        'C:\Program Files\Ghidra\ghidra_*\support\analyzeHeadless.bat',
        'C:\Program Files\ghidra\ghidra_*\support\analyzeHeadless.bat',
        'C:\Tools\Ghidra\ghidra_*\support\analyzeHeadless.bat',
        'C:\Tools\ghidra\ghidra_*\support\analyzeHeadless.bat',
        "$env:USERPROFILE\Downloads\ghidra_*\support\analyzeHeadless.bat"
    )

    $match = Get-ChildItem -Path $candidates -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if ($match) {
        return $match.FullName
    }

    return $null
}

function Import-GhidraProject {
    Initialize-Directories

    if ($SkipGhidra) {
        Write-Step 'Skipping Ghidra project generation'
        return
    }

    $headless = Find-GhidraHeadless
    if (-not $headless) {
        Write-Warning 'Ghidra analyzeHeadless.bat was not found. Skipping Ghidra project generation.'
        return
    }

    Write-Step 'Refreshing Ghidra project'

    Invoke-NativeCommand -FilePath $headless -Arguments @($ghidraDir, $ghidraProjectName, '-import', $targetExe, '-overwrite') -FailureMessage 'Ghidra headless import failed.'
    Assert-PathExists -Path $ghidraProjectFile -Message "Expected Ghidra project file was not produced: $ghidraProjectFile"
}

function Invoke-AnalysisPipeline {
    Initialize-Directories

    if (-not (Test-CommandAvailable -Name 'dumpbin')) {
        throw 'dumpbin is not available on PATH. Ensure the Visual Studio developer environment is loaded.'
    }

    if (-not (Test-CommandAvailable -Name 'Format-Hex')) {
        throw 'Format-Hex is not available in the current PowerShell session.'
    }

    Write-Step 'Generating disassembly and inspection outputs'

    & dumpbin /DISASM /RAWDATA:NONE $targetExe | Out-File -FilePath $fullObjdump -Encoding ascii
    if ($LASTEXITCODE -ne 0) {
        throw "dumpbin failed with exit code $LASTEXITCODE"
    }

    Write-FunctionSlice -InputPath $fullObjdump -Label 'main' -OutputPath $mainObjdump
    Write-FunctionSlice -InputPath $fullObjdump -Label 'invoke_main' -OutputPath $invokeMainObjdump
    Write-FunctionSlice -InputPath $fullObjdump -Label 'mainCRTStartup' -OutputPath $mainCrtObjdump

    Format-Hex -Path $targetExe | Out-File -FilePath $hexdump -Encoding ascii

    Assert-PathExists -Path $fullObjdump -Message "Expected objdump output was not produced: $fullObjdump"
    Assert-PathExists -Path $mainObjdump -Message "Expected main slice was not produced: $mainObjdump"
    Assert-PathExists -Path $invokeMainObjdump -Message "Expected invoke_main slice was not produced: $invokeMainObjdump"
    Assert-PathExists -Path $mainCrtObjdump -Message "Expected mainCRTStartup slice was not produced: $mainCrtObjdump"
    Assert-PathExists -Path $hexdump -Message "Expected hexdump was not produced: $hexdump"

    Import-GhidraProject
}

function Invoke-Binary {
    if (-not (Test-Path -LiteralPath $targetExe)) {
        throw "Built executable not found at $targetExe"
    }

    Write-Step 'Running built executable'
    Invoke-NativeCommand -FilePath $targetExe -FailureMessage 'Built executable returned a failure exit code.'
}

if ($Clean) {
    Write-Step 'Running clean first'
    Invoke-CleanLayout
}

Write-Step "Running target: $Target"

if ($Target -eq 'clean') {
    Invoke-CleanLayout
    exit 0
}

Import-VsDevEnvironment

switch ($Target) {
    'release' {
        Invoke-ClBuild -Configuration 'release'
    }
    'debug' {
        Invoke-ClBuild -Configuration 'debug'
    }
    'run' {
        Invoke-ClBuild -Configuration 'release'
        Invoke-Binary
    }
    'debug-run' {
        Invoke-ClBuild -Configuration 'debug'
        Invoke-Binary
    }
    'dumps' {
        Invoke-ClBuild -Configuration 'debug'
        Invoke-AnalysisPipeline
    }
}