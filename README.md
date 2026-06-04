# Hello World PowerShell

## Project Overview

This repository is a complete, reproducible C++ to binary to analysis pipeline for a deliberately small `Hello World!` program.

The program is minimal. The artifact is not.

The repository exists to make the entire path legible:

- authored source in `src/`
- compiler and linker outputs in `build/`
- reverse-engineering outputs in `analysis/`
- automation in `scripts/` and `.github/workflows/`

## Philosophy Of The Artifact

The tool is not the executable.
The tool is the entire directory.

This repository treats a binary not as an endpoint, but as one stage in a larger artifact pipeline:

- source code describes intent
- build outputs capture execution reality
- analysis outputs reconstruct semantics from the produced binary

That is why the repository keeps these layers separate. The point is not just to compile `test.cpp`. The point is to preserve a complete, inspectable chain from notation to execution to interpretation.

As a result, the repository is both:

- a teaching artifact for reverse-engineering workflow design
- a reference implementation for reproducible Windows-native binary analysis

## Directory Layout

```text
/
├── .github/
│   └── workflows/
│       └── windows-build.yml        # GitHub Actions CI for the Windows MSVC pipeline
│
├── analysis/                        # Reverse-engineering and inspection outputs
│   ├── ghidra/
│   │   ├── ghidra-test.gpr          # Ghidra project file
│   │   └── ghidra-test.rep/         # Ghidra internal representation directory
│   │
│   ├── hexdump/
│   │   └── test.hexdump.txt         # Raw hex dump of the compiled binary
│   │
│   └── objdump/
│       ├── test.objdump.txt         # Full PE/COFF disassembly output
│       ├── test.main.objdump.txt    # Disassembly of main()
│       ├── test.invoke_main.objdump.txt
│       └── test.mainCRTStartup.objdump.txt
│
├── build/                           # Compiler and linker artifacts
│   ├── test.exe
│   ├── test.obj
│   ├── test.pdb
│   ├── test.ilk
│   └── vc140.pdb
│
├── scripts/
│   └── build.ps1                    # Full build and analysis pipeline (MSVC)
│
├── src/
│   └── test.cpp                     # Minimal C++ source probe
│
├── .gitignore
├── LICENSE
├── Makefile                         # Convenience entrypoint for the PowerShell pipeline
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

## Why This Layout Is Correct

### 1. It separates the three conceptual layers cleanly

- `src/` is the mathematical description.
- `build/` is the compiled artifact.
- `analysis/` is the semantic reconstruction.

That separation keeps authorship, execution, and interpretation distinct.

### 2. It makes the repository reproducible

Anyone can:

- build the binary
- inspect the binary
- reproduce the analysis

from one documented pipeline with stable output locations.

### 3. It communicates professionalism

The layout signals that this repository is not just a trivial executable. It is a complete toolchain artifact with explicit automation, generated outputs, and analysis products.

### 4. It scales

The structure leaves room for:

- additional source files in `src/`
- additional binaries in `build/`
- additional analysis stages under `analysis/`
- future tooling integrations without collapsing the root directory

## Tooling Model

This project is operated from PowerShell and command-line tools, not from the Visual Studio IDE.

- PowerShell is the orchestration shell.
- Visual Studio provides the MSVC toolchain: `cl`, `link`, `dumpbin`, and the developer environment.
- `scripts/build.ps1` is the authoritative pipeline.
- GitHub Actions reproduces the same pipeline on a Windows runner.

## Build Instructions

### PowerShell (MSVC)

This is the primary workflow for the repository and the canonical way to reproduce the artifact.

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

### Production Build Script

The PowerShell pipeline is intentionally written as a real tool rather than a wrapper around ad hoc commands.

It provides:

- automatic MSVC detection
- reproducible directory creation
- explicit target selection
- deterministic output locations
- artifact validation after each major stage
- optional Ghidra project refresh when Ghidra is installed locally

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
- verifies that the expected outputs were actually produced
- uploads build and analysis outputs as workflow artifacts

CI treats Ghidra as optional. The workflow runs the analysis pipeline with `-SkipGhidra` so a clean Windows runner does not need a local Ghidra installation. Local runs still import into Ghidra automatically when `analyzeHeadless.bat` is available.

This keeps the repository aligned with its core promise: the full artifact can be rebuilt and inspected in a fresh environment.

## License

This project is licensed under the MIT License. See `LICENSE` for the full text.