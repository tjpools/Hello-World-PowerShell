# Hello World C++ Test Program

This project contains a simple C++ program that prints `Hello World!` to the console.

## Project Layout

| File or Path | Type | Role |
| --- | --- | --- |
| `.gitignore` | tracked project file | Excludes generated binaries, dump outputs, and Ghidra local project files from version control. |
| `Makefile` | tracked project file | Defines the `nmake` build, run, clean, and dump-generation workflows. |
| `README.md` | tracked project file | Documents the project structure and common commands. |
| `test.cpp` | tracked project file | Contains the C++ source code for the `Hello World!` program. |
| `test.exe` | generated build output | The compiled Windows executable produced from `test.cpp`. |
| `test.obj` | generated build output | Intermediate object file emitted by the compiler before linking. |
| `test.pdb` | generated build output | Debug symbol database used by debuggers and by Ghidra during analysis. |
| `test.ilk` | generated build output | Incremental linker state file used by Visual Studio debug builds. |
| `vc140.pdb` | generated toolchain artifact | Additional Microsoft runtime or linker symbol information emitted by the toolchain. |
| `test.objdump.txt` | generated analysis output | Full `dumpbin` disassembly of `test.exe`. |
| `test.main.objdump.txt` | generated analysis output | Extracted disassembly for `main()`. |
| `test.invoke_main.objdump.txt` | generated analysis output | Extracted disassembly for the CRT helper that prepares arguments and jumps to `main()`. |
| `test.mainCRTStartup.objdump.txt` | generated analysis output | Extracted disassembly for the Windows CRT startup entry point. |
| `test.hexdump.txt` | generated analysis output | Hexadecimal byte dump of `test.exe`. |
| `ghidra-test.gpr` | generated Ghidra project file | Main Ghidra project descriptor for reverse-engineering this executable. |
| `ghidra-test.rep/` | generated Ghidra project data | Stores the imported program database and analysis results used by Ghidra. |
| `ghidra-test.lock` | generated Ghidra lock file | Prevents conflicting access while the Ghidra project is open. |
| `ghidra-test.lock~` | generated Ghidra lock file | Backup or temporary lock metadata created by Ghidra. |

## Tracked Files

These files define the project and are the ones you would normally keep in version control:

- `test.cpp` - the program source; defines `main()` and prints `Hello World!`
- `Makefile` - the Windows `nmake` build script; builds release and debug binaries, runs the program, and generates analysis dumps
- `.gitignore` - prevents generated artifacts from cluttering the repository
- `README.md` - project documentation and command reference

## Generated Files

These files are created after building, analyzing, or opening the project in Ghidra:

- `test.exe`, `test.obj`, `test.pdb`, `test.ilk`, and `vc140.pdb` - compiler, linker, and debug outputs
- `test.objdump.txt`, `test.main.objdump.txt`, `test.invoke_main.objdump.txt`, `test.mainCRTStartup.objdump.txt`, and `test.hexdump.txt` - reverse-engineering and inspection outputs
- `ghidra-test.gpr`, `ghidra-test.rep/`, `ghidra-test.lock`, and `ghidra-test.lock~` - local Ghidra project data

## Requirements

- Windows
- Visual Studio with C++ build tools installed

## Tooling Model

This project is operated from PowerShell and command-line tools, not from the Visual Studio IDE.

- PowerShell is the shell used to run the workflow.
- Visual Studio provides the compiler and build tools such as `cl`, `link`, `nmake`, and `dumpbin`.
- `VsDevCmd.bat` sets the environment so those tools work correctly from the shell.

You do not need to open the Visual Studio GUI to build, run, dump, or analyze this project.

## PowerShell Entry Point

To run the project workflow from PowerShell without manually invoking `VsDevCmd.bat`, use:

```powershell
.\build.ps1 -Target dumps -Clean
```

Common examples:

- `./build.ps1 -Target release` - build a release executable
- `./build.ps1 -Target run` - build and run the release target
- `./build.ps1 -Target debug` - build a debug executable with symbols
- `./build.ps1 -Target debug-run` - build and run the debug target
- `./build.ps1 -Target dumps -Clean` - clean first, then rebuild debug artifacts and regenerate all dump files

## Build

Open PowerShell in this folder and run:

```powershell
.\build.ps1 -Target release
```

If you prefer to call the build tools manually, open a Visual Studio Developer Command Prompt and run:

```powershell
nmake release
```

This builds `test.exe` from `test.cpp`.

`nmake` also defaults to the `release` target.

## Debug Build

To build with Visual Studio debug symbols and disabled optimizations, run:

```powershell
.\build.ps1 -Target debug
```

Or, from a Developer Command Prompt:

```powershell
nmake debug
```

This produces `test.exe` and `test.pdb` for debugging.

## Run

```powershell
.\build.ps1 -Target run
```

Or, from a Developer Command Prompt:

```powershell
nmake run
```

This builds the release target and runs it.

To build and run the debug target instead:

```powershell
.\build.ps1 -Target debug-run
```

Or, from a Developer Command Prompt:

```powershell
nmake debug-run
```

Or run the executable directly:

```powershell
.\test.exe
```

## Typical Workflow

For a normal development and analysis pass, use this order:

1. Build the executable with `./build.ps1 -Target release` if you just want a runnable binary.
2. Run the program with `./build.ps1 -Target run` to confirm the behavior is still correct.
3. Build the debug version with `./build.ps1 -Target debug` when you want symbols for debugging or reverse engineering.
4. Generate analysis artifacts with `./build.ps1 -Target dumps -Clean` to produce the disassembly slices and hexdump files.
5. Open `ghidra-test.gpr` in Ghidra to inspect the imported binary together with the generated dump files.

## Disassembly And Hexdump

To generate a symbol-rich disassembly, startup-function slices, and a hexdump, run:

```powershell
.\build.ps1 -Target dumps -Clean
```

Or, from a Developer Command Prompt:

```powershell
nmake dumps
```

This uses the debug build so `main` is easier to identify in the disassembly output.

Generated files:

- `test.objdump.txt` - full `dumpbin` disassembly
- `test.main.objdump.txt` - extracted `main` function disassembly
- `test.invoke_main.objdump.txt` - extracted `invoke_main` function disassembly
- `test.mainCRTStartup.objdump.txt` - extracted `mainCRTStartup` function disassembly
- `test.hexdump.txt` - hexadecimal dump of `test.exe`

## Reverse Engineering Notes

The extracted disassembly files show the basic control flow from the Windows runtime startup code into your program logic.

- `mainCRTStartup` is the process entry point provided by the C runtime. In this binary, it initializes the security cookie and then jumps into the CRT startup routine that prepares the process before user code runs.
- `invoke_main` is the CRT bridge between startup code and your program. It gathers the initial environment, loads `argv` and `argc`, and then transfers control to `main`.
- `main` is the actual program logic from `test.cpp`. In this binary, it loads the address of the string data, writes it to `std::cout`, applies `std::endl`, clears `eax` to return `0`, and exits.

In practical terms, the execution path is:

`mainCRTStartup` -> CRT initialization -> `invoke_main` -> `main`

## Clean

```powershell
nmake clean
```

This removes the generated `.obj` file and executable.

It also removes the generated `.pdb` debug symbols file.

It also removes the generated dump files.