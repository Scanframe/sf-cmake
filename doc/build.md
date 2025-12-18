# Build Script Documentation

## Overview

Script `build.py` is a comprehensive CMake build system helper that provides a unified interface for configuring, building,
testing, and packaging C++ projects across multiple platforms and toolchains. It automates complex build workflows using
`CMakePresets.json` configuration and supports nested execution environments (native, Docker, Wine).

## Key Features

- **Interactive Preset Selection**: Curses-based menu system for selecting build configurations
- **Multi-Toolchain Support**: Configure and use different compilers (GNU, MinGW, MSVC, cross-compilers)
- **Cross-Platform Building**: Build for different target platforms from a single environment
- **Environment Management**: Automated environment variable configuration per toolchain
- **Nested Execution**: Chain execution through Docker and Wine for specialized build environments
- **Package Management**: Install development dependencies (Linux apt, Windows WinGet)
- **Workflow Automation**: Execute complete build, test, and package workflows
- **Colored Logging**: Customizable verbosity with ANSI color-coded output

## Supported Platforms

- **Linux** (x86_64, aarch64 & cross-compiled)
- **Windows** (native)

## Available Commands

### Native Command (Default)

The primary build command that executes CMake operations directly in the current environment.

**Usage**: `./build.py [options] [preset]`

**Key Options**:

- `-i, --info`: Display preset information.
- `-c, --clean`: Clean build (remove CMakeCache.txt).
- `-f, --fresh`: Fresh build (CMake --fresh flag).
- `-C, --wipe`: Wipe entire build directory contents.
- `-m, --make`: Create build directory/makefiles only.
- `-b, --build`: Build the project.
- `-B, --build-only`: Build without running tests.
- `-t, --test`: Run CTest using test preset.
- `-T, --test-select`: Interactive test selection dialog.
- `-R, --test-regex <regex>`: Run tests matching regularexpression pattern.
- `-p, --package`: Create distribution packages.
- `-w, --workflow`: Execute workflow presets.
- `-n, --target <trg>`: Build specific target.
- `-N, --target-select`: Interactive target selection.
- `--no-fancy`: Disable curses-based menu/dialog.

**Examples**:

```bash
# Build and test with GNU toolchain (debug configuration)
./build.py -mbt gnu-debug

# Get preset information
./build.py --info gnu-debug

# Build only (no tests)
./build.py --make --build gnu-debug

# Run specific tests
./build.py --test gnu-debug -r '^t_my-test'

# Create packages
./build.py --package gnu-release
```

### Wine Command

Execute build commands within a Wine environment, enabling Windows toolchains (MSVC, MinGW) to run on Linux.

**Usage**: `./build.py wine [options] -- [native-command-args]`

**Key Options**:

- `-g, --git-server`: Force a start git-server in background for repository access in Wine.

**Examples**:

```bash
# Build with MSVC toolchain in Wine
./build.py wine -- -mbt msvc-debug

# Run MSVC compiled console application
./build.py wine -- run -p msvc-debug -- hello-world.exe

# Run MSVC compiled Qt GUI application
./build.py wine -- run -p msvc-debug -- hello-world-qt.exe
```

### Docker Command

Execute build commands inside a Docker container, providing isolated build environments with pre-configured toolchains.

**Usage**: `./build.py docker [options] -- [command] [args]`

**Key Options**:

- `-q, --qt-ver <version>`: Specify Qt version (default: 6.10.1)
- `-p, --platform <arch>`: Target platform (amd64 or arm64)
- `--no-build-dir`: Don't mount build directory into container

**Examples**:

```bash
# Build with GNU aarch64 cross-compiler in Docker
./build.py docker -- -mbt ga-debug

# Run GNU aarch64 compiled application
./build.py docker -- run -p ga-debug -- ./hello-world.bin

# Build with GNU for Windows (MinGW) in Docker
./build.py docker -- -mbt gw-debug

# Run GNU for Windows application with Wine in Docker
./build.py docker -- run -p gw-debug -- hello-world.exe

# Nested: MSVC in Wine inside Docker
./build.py docker -- wine -- -mbt msvc-debug

# Run MSVC application in Wine inside Docker
./build.py docker -- wine -- run -p msvc-debug -- hello-world.exe
```

### Install Command

Install required development packages and dependencies depending on the OS it is executed.

> See help with: `./build.py install --help`

### Run Command

Execute compiled applications with the proper environment configuration from the `CMakePreset.json` file 
preceeded by an environment configured from `build.ini` file.

**Usage**: `./build.py run -p <preset> -- <executable> [args]`

**Key Options**:

- `-p, --preset <preset>`: Specify the build preset (required)
- `-e, --exec`: Execute without CMake environment setup
- `-v, --verbose`: Verbose output

**Examples**:

```bash
# Run GNU compiled console application
./build.py run -p gnu-debug -- ./hello-world.bin

# Run Qt GUI application
./build.py run -p gnu-debug -- ./hello-world-qt.bin

# Run with custom environment suffix
SF_EXEC_DIR_SUFFIX=-gnu ./build.py run -p gnu-debug -- ./hello-world.bin

# Run MSVC application
SF_EXEC_DIR_SUFFIX=-msvc ./build.py run -p msvc-debug -- hello-world.exe
```

## Toolchain Support Matrix

| Toolchain              | Abbrev. | Linux | Windows | Wine | Dckr | Description                                       |
|------------------------|---------|-------|---------|------|------|---------------------------------------------------|
| **GNU x86_64/aarch64** | `gnu`   | ✓¹    | ✗       | ✗    | ✓    | Native Linux GNU compiler (on x86_64 or aarch64)  |
| **GNU aarch64**        | `ga`    | ✓²    | ✗       | ✗    | ✓    | Linux GNU cross-compiler for aarch64 (on x86_64)  |
| **GNU for Win64**      | `gw`    | ✓     | ✗       | ✓    | ✓    | Linux GNU MinGW cross-compiler for Windows builds |
| **MinGW**              | `mingw` | ✗     | ✓       | ✗    | ✗³   | Windows MinGW-w64 compiler for Windows builds     |
| **MSVC**               | `msvc`  | ✗     | ✓       | ✓    | ✓    | Windows Microsoft Visual C++ compiler builds      |

**Legend**:

- ✓ = Supported and tested.
- ✗ = Not supported.
- `1` = Only available on Linux aarch64.
- `2` = Only available on Linux x86_64.
- `3` = Not useful, a cross-compiler is available on Linux x86_64.

### Toolchain Details

#### GNU (gnu) x86_64, aarch64

- **Environment**: Native Linux (x86_64, aarch64).
- **Compiler**: gcc/g++.
- **Use Case**: Standard Linux development.
- **Configuration**: `env.gnu@` in `build.ini`

#### GNU (ga) aarch64

- **Environment**: Linux x86_64 with cross-compiler for aarch64.
- **Compiler**: aarch64-linux-gnu-gcc/g++.
- **Use Case**: Cross-compile for aarch64 targets.
- **Configuration**: `env.ga.docker@` in `build.ini`.

#### GNU for Windows (gw) x86_64 

- **Environment**: Linux with MinGW cross-compiler.
- **Compiler**: x86_64-w64-mingw32-gcc/g++.
- **Use Case**: Cross-compile Windows executables on Linux.
- **Execution**: Via Wine (for testing on Linux).
- **Configuration**: `env.gw@`, `env.gw.docker@` in `build.ini`.

#### MinGW (mingw) x86_64

- **Environment**: Native Windows.  
- **Compiler**: mingw-w64 (gcc/g++ Windows port).
- **Use Case**: Windows development with GNU toolchain.
- **Configuration**: `env.mingw@` in build.ini.
- **Path Example**: `P:\toolchain\mingw1320_64-posix\bin`

> Due to a MinGW v13 bug, it cannot be run from a shared drive since it converts its 
> install-directory to a UNC path which breaks the compiler.  
> _(A workaround is using a slower SSHFS share instead of Samba and
> requires [Cygwin](https://github.com/Scanframe/sf-cygwin-bin "Easy install Cygwin repo.").)_

#### MSVC (msvc) x86_64 

- **Environment**: Native Windows or Wine on Linux.
- **Compiler**: Microsoft Visual C++ (cl.exe).
- **Use Case**: Windows development with Visual Studio toolchain.
- **Configuration**: `env.msvc@`, `env.msvc.wine@`, `env.msvc.wine.docker@` in `build.ini`.

> This standalone script [`portable-msvc.py`](https://github.com/Scanframe/sf-cygwin-bin/blob/master/portable-msvc.py) 
> installs the 'Microsoft Visual C++ Compiler' using the CLI only in a portable way.

## Configuration File (build.ini)

The script uses `build.ini` for environment configuration with support for:

- **Section Inheritance**: Use `__inherit__` key to extend base configurations
- **Variable Expansion**: Environment variables expanded using `${VAR}` syntax
- **User Overrides**: Optional `user.ini` file for personal customizations
- **Toolchain Paths**: Configure compiler and tool locations per environment

### Key Configuration Sections

```ini
[.env.qt-ver]
RUN_QT_VER = 6.10.1

[.env.mingw]
PATH = P:\toolchain\mingw1320_64-posix\bin;${PATH}

[.env.msvc]
MSVC_ROOT = P:\toolchain\w64-x86_64-msvc-2022
PATH = ${RUN_DIR}\lib\qt\w64-x86_64\6.10.1\msvc_64\bin;${PATH}

[.env.msvc.wine]
__inherit__ = .env.qt-ver
MSVC_ROOT = Z:\mnt\server\userdata\applications\library\toolchain\w64-x86_64-msvc-2022

[env.gnu@]
SF_EXEC_DIR_SUFFIX = -gnu

[env.gw@]
SF_EXEC_DIR_SUFFIX = -gw
WINEPATH = Z:\usr\x86_64-w64-mingw32\lib;Z:\usr\lib\gcc\x86_64-w64-mingw32\13-posix

[env.mingw@]
SF_EXEC_DIR_SUFFIX = -mingw

[env.msvc@]
SF_EXEC_DIR_SUFFIX = -msvc
```

## Common Workflows

### Linux Native Development (GNU)

```bash
# Configure, build, and test
./build.py -mbt gnu-debug

# Run console application
./build.py run -p gnu-debug -- ./hello-world.bin

# Run Qt GUI application
./build.py run -p gnu-debug -- ./hello-world-qt.bin
```

### Cross-Compile for ARM64 (Linux x86_64 host)

```bash
# Build in Docker with ARM64 toolchain
./build.py docker -- -mbt ga-debug

# Run with QEMU emulation in Docker
./build.py docker -- run -p ga-debug -- ./hello-world.bin
```

### Cross-Compile for Windows (Linux host)

```bash
# Build with GNU MinGW
./build.py -mbt gw-debug

# Run with Wine
./build.py run -p gw-debug -- hello-world.exe

# Or build and run in Docker
./build.py docker -- -mbt gw-debug
./build.py docker -- run -p gw-debug -- hello-world.exe
```

### Windows Development with MSVC (on Linux via Wine)

```bash
# Build with MSVC in Wine
./build.py wine -- -mbt msvc-debug

# Run MSVC executable
./build.py wine -- run -p msvc-debug -- hello-world.exe

# Or nested in Docker
./build.py docker -- wine -- -mbt msvc-debug
./build.py docker -- wine -- run -p msvc-debug -- hello-world.exe
```

### Native Windows Development

```bash
# Using MSVC
./build.py -mbt msvc-debug
./build.py run -p msvc-debug -- hello-world.exe

# Using MinGW
./build.py -mbt mingw-debug
./build.py run -p mingw-debug -- hello-world.exe
```

## Preset Naming Convention

Presets follow the pattern: `<toolchain>-<buildtype>`

**Toolchains**: `gnu`, `ga`, `gw`, `mingw`, `msvc`
**Build Types**: `debug`, `release`, `relwithdebinfo`, `minsizerel`

Examples:

- `gnu-debug`: GNU compiler, debug build
- `msvc-release`: MSVC compiler, release build
- `gw-debug`: GNU for Windows (MinGW), debug build
- `ga-release`: GNU ARM64 cross-compiler, release build

## Environment Variables

Key environment variables used by the build system:

- `RUN_DIR`: Base directory of the project
- `RUN_QT_VER`: Qt version to use (e.g., 6.10.1)
- `RUN_QT_VER_DIR`: Qt installation directory
- `SF_EXEC_DIR_SUFFIX`: Suffix for executable directory (e.g., `-gnu`, `-msvc`)
- `MSVC_ROOT`: Root directory of MSVC installation
- `WINEPATH`: Wine library paths for Windows DLLs
- `WINEPREFIX`: Wine prefix directory (optional override)
- `GIT_SERVER_PORT`: Alternate port for git server (default: 9999)

## Advanced Features

### Curses-Based Interactive Menus

When presets are not specified, the script presents an interactive menu for selection. Disable with `--no-fancy`.

### Nested Environment Execution

Chain execution contexts: `docker -- wine -- <command>`

This executes the command inside Wine, which runs inside Docker, enabling MSVC builds on containerized Linux systems.

### Automatic Dependency Installation

The install-command can set up entire development environments:

```bash
./build.py install --required gcc
./build.py install --required mingw
./build.py install --required cross-gcc
```

### Test Execution Control

Fine-grained test control:

```bash
# List tests only
./build.py -l gnu-debug

# Run specific test pattern
./build.py -t gnu-debug -R '^test_module'

# Interactive test selection
./build.py -T gnu-debug
```

## Exit Codes

- `0`: Success
- `130`: User interrupt (Ctrl+C)
- Non-zero: Error occurred (propagated from underlying commands)

## Dependencies

**Python Packages**:

- Standard library modules (argparse, configparser, subprocess, etc.)
- `curses` (auto-installed on Windows via `windows-curses`)

**External Tools**:

- CMake (3.25+)
- Ninja (build system)
- Git
- Docker (for docker command)
- Wine (for wine command)
- Toolchains: gcc, g++, mingw-w64, MSVC Build Tools

