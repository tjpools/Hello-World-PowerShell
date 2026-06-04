# Hello World PowerShell

## Project Overview

This repository is a complete C++ to binary to analysis pipeline for a deliberately simple `Hello World!` program.

The source code is small. The artifact is not. The point of the repository is to show the full path from:

- source code in `src/`
- compiled outputs in `build/`
- inspection outputs in `analysis/`
- automation in `scripts/` and `.github/workflows/`

## Why This Repo Exists

The tool is not the executable.
The tool is the entire directory.

This repository is structured as a teaching artifact and a reference implementation for a repeatable Windows-native reverse-engineering workflow:

- write or change C++ in `src/`
- build with MSVC from PowerShell
- capture the produced binary and debug metadata in `build/`
- derive objdump, hexdump, and Ghidra project outputs in `analysis/`
- reproduce the full pipeline with one command

## Directory Layout

```text
/
├── .github/
│   └── workflows/
│       └── windows-build.yml
├── analysis/
│   ├── ghidra/
│   │   ├── ghidra-test.gpr
│   │   └── ghidra-test.rep/
│   ├── hexdump/
│   │   └── test.hexdump.txt
│   └── objdump/
│       ├── test.objdump.txt
│       ├── test.main.objdump.txt
│       ├── test.invoke_main.objdump.txt
│       └── test.mainCRTStartup.objdump.txt
├── build/
│   ├── test.exe
│   ├── test.obj
│   ├── test.pdb
│   ├── test.ilk
│   └── vc140.pdb
├── scripts/
│   └── build.ps1
├── src/
│   └── test.cpp
├── .gitignore
├── LICENSE
├── Makefile
└── README.md
```

### Layout Notes

- `src/` contains authored source code.
- `scripts/` contains the primary PowerShell pipeline.
- `build/` contains compiler and linker outputs.
- `analysis/objdump/` contains disassembly slices derived from `build/test.exe`.
- `analysis/hexdump/` contains the byte-level dump.
- `analysis/ghidra/` contains the local Ghidra project created from the built binary.
- `Makefile` is a thin command-line entrypoint that delegates to the PowerShell pipeline.

## Build Instructions

### PowerShell (MSVC)

This is the primary workflow for the repository.

Requirements:

- Windows
- Visual Studio Build Tools or Visual Studio with the C++ workload installed
- PowerShell 7 or newer

Common commands:

```powershell
.\scripts\build.ps1 -Target release
.\scripts\build.ps1 -Target run
.\scripts\build.ps1 -Target debug
.\scripts\build.ps1 -Target debug-run
.\scripts\build.ps1 -Target dumps -Clean
.\scripts\build.ps1 -Target clean
```

What the script does:

- detects the latest MSVC toolchain automatically with `vswhere`
- imports the Visual Studio developer environment into the PowerShell session
- creates the `build/` and `analysis/` directories on demand
- compiles with MSVC using `/EHsc /Zi /nologo`
- emits compiled artifacts into `build/`
- emits objdump, hexdump, and Ghidra outputs into `analysis/`

### Makefile

The root `Makefile` is a convenience entrypoint for the same pipeline. It delegates to `scripts/build.ps1` rather than owning separate build logic.

Use it from a Visual Studio Developer Command Prompt, or from any shell where `nmake` is already available on `PATH`.

Examples:

```powershell
nmake release
nmake run
nmake debug
nmake dumps
nmake clean
```

## Analysis Pipeline

### Objdump

The pipeline uses `dumpbin /DISASM /RAWDATA:NONE` from the Visual Studio toolchain and writes the results to `analysis/objdump/`.

Produced files:

- `analysis/objdump/test.objdump.txt` - full disassembly
- `analysis/objdump/test.main.objdump.txt` - extracted `main`
- `analysis/objdump/test.invoke_main.objdump.txt` - extracted CRT bridge into `main`
- `analysis/objdump/test.mainCRTStartup.objdump.txt` - extracted runtime entry point

### Hexdump

The pipeline uses PowerShell `Format-Hex` and writes the output to `analysis/hexdump/test.hexdump.txt`.

### Ghidra Project

If Ghidra is installed locally, the pipeline runs `analyzeHeadless.bat` and imports the built executable into `analysis/ghidra/ghidra-test.gpr`.

This gives the repository a stable handoff point between build artifacts and interactive reverse engineering.

### How To Reproduce The Analysis

Run:

```powershell
.\scripts\build.ps1 -Target dumps -Clean
```

That command:

1. cleans the previous generated layout
2. rebuilds the binary in debug mode
3. writes disassembly and hexdump outputs into `analysis/`
4. generates or refreshes the local Ghidra project when Ghidra is available

## Reproducibility

This repository is designed so every intermediate artifact has a canonical location and can be regenerated from source with one PowerShell command.

The working tree is intentionally split between:

- stable source and automation files in the repository root, `src/`, `scripts/`, and `.github/`
- reproducible outputs in `build/` and `analysis/`

That separation makes the project easy to inspect, easy to teach from, and easy to rebuild.

## Extending The Artifact

To extend the repository:

1. add new source files under `src/`
2. update `scripts/build.ps1` if the compilation or analysis pipeline needs to include them
3. add new analysis stages under `analysis/` with a dedicated subdirectory when appropriate
4. update this README so the artifact stays legible to the next engineer

Examples:

- add a `strings/` stage under `analysis/` for printable-string extraction
- add additional function-slice extraction to the objdump stage
- add another Ghidra export or post-processing step to `scripts/build.ps1`

## Continuous Integration

GitHub Actions runs `.github/workflows/windows-build.yml` on pushes to `main` and on pull requests.

The workflow:

- builds the release artifact on a Windows runner
- runs the analysis pipeline through `scripts/build.ps1`
- uploads build and analysis outputs as workflow artifacts

## License

This project is licensed under the MIT License. See `LICENSE` for the full text.