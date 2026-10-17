# CMake Strategy {#cmake-strategy}

## Overview

The `cmake/lib` Git submodule provides a complete C++ project boilerplate that enables cross-platform
development, building, testing, and packaging from a single codebase. It is designed to work from a
freshly installed operating system — Linux or Windows — without requiring manual toolchain setup.

The submodule delivers:

* **CMake packages** that encapsulate toolchain configuration, macros, build checks, testing, Qt integration,
	and Doxygen documentation generation.
* **CMake presets** (`CMakePresets.json` / `CMakeUserPresets.json`) that define toolchain-specific build
	configurations for GNU, MinGW, MSVC, and cross-compilation targets.
* **A Python build orchestrator** (`build.py`) that automates configure → build → test → package workflows,
	supports nested execution via Wine and Docker, and provides interactive preset selection.
	See @ref build-script for detailed usage.
* **Shell scripts** for code formatting, coverage reporting, Qt library location, and version management.
* **CPack templates** for creating platform-specific packages (deb, rpm, AppImage, NSIS, zip).
* **GitLab CI/CD configuration** with child pipelines for parallel multi-platform builds.

## Project Architecture

### Typical Project Usage

In a typical project, the `cmake/lib` submodule is added as a Git submodule. The project then creates its
own `CMakeLists.txt`, `CMakePresets.json`, and `build.ini` files — either by copying from the submodule's
`tpl/root/` templates or by creating them from scratch. The submodule's CMake packages are discovered via
`CMAKE_PREFIX_PATH` and loaded with `find_package()`.

## CMake Package System

The submodule provides several CMake packages, each discovered via `find_package()` in the top-level
`CMakeLists.txt`. The `CMAKE_PREFIX_PATH` is set to include both `cmake/` and `cmake/lib/` so that
project-specific and submodule packages are both found.

### SfBase (`SfBaseConfig.cmake`)

The foundational package that provides core functions and macros used throughout the build system:

* `Sf_GetGitTagVersion()` — Extracts the semantic version from Git tags.
* `Sf_AddTarget()` — Creates executables or libraries with optional flags (`VERSION`, `EXIF`, `COVERAGE`, `SHARED`,
	`STATIC`).
* `Sf_AddVersionResource()` — Embeds version metadata into binaries (Windows PE resources or Linux ELF `.meta`sections).
* `Sf_AddExifTarget()` — Creates a custom target that runs `exiftool.py` to report embedded metadata.
* `Sf_SetRunPath()` — Configures `RUNPATH` for all targets.
* `Sf_AddTestCoverageReport()` — Adds a coverage report test target.
* `Sf_AddExamples()` — Registers example files for documentation.

### SfToolChain (`SfToolChainConfig.cmake`)

Configures the compiler toolchain based on the `SF_COMPILER` cache variable and the host system. It
determines the correct compiler paths, architecture settings, and platform-specific flags.

### SfMacros (`SfMacrosConfig.cmake`)

Provides reusable CMake macros and functions for common tasks, such as setting target options, parsing
arguments, and managing file operations.

### SfBuildCheck (`SfBuildCheckConfig.cmake`)

Ensures that the current build directory is not within the source.

### SfQtLibrary (`SfQtLibraryConfig.cmake`)

Handles Qt library discovery and automatic download. When `SF_BUILD_QT` is enabled, it reads the Qt
version from `build.ini` and locates or downloads the required Qt libraries.

### SfCatch2 (`SfCatch2Config.cmake`)

Integrates the **Catch2** testing framework.

### SfGoogleTest (`SfGoogleTestConfig.cmake`)

Integrates the **GoogleTest** testing framework.

> When `SF_BUILD_TESTING` is enabled in the project, unittests become available in the project.
> Tests can be executed from the CLion IDE or via the command line.

### SfDoxygen (`SfDoxygenConfig.cmake`)

Configures Doxygen documentation generation with **PlantUML** support. With the flag `doc` passed to `Sf_AddTarget()`
when creating a target, documentation is generated for the target. See @ref documentation for conventions.

## CMake Presets

The build system uses CMake Presets (version 6) defined in two files:

### CMakePresets.json

Contains the base presets provided by the submodule.
Key preset categories include:

* **Hidden base preset** (`.cfg`) — Defines common settings: Ninja generator, output directories,
	ache variables (`CMAKE_BUILD_TYPE`, `SF_BUILD_QT`, `SF_BUILD_TESTING`, `SF_COMPILER`).
* **Platform condition presets** (`.lnx-only`, `.w64-only`) — Enable presets conditionally based on
	the host operating system.
* **Toolchain presets** (`.tc-gnu`, `.tc-ga`, `.tc-gw`, `.tc-mingw`, `.tc-msvc`) — Set the
	`SF_COMPILER` variable and CLion vendor toolchain hints.
* **Build type presets** — Debug, Release, and Coverage configurations.
* **Combined presets** — Merge platform, toolchain, and build type into named presets like
	`gnu-debug`, `msvc-release`, `gw-debug`, etc.

### CMakeUserPresets.json

Allows project-specific overrides and additional presets without modifying the submodule's file.
Follows the same structure and can extend or override base presets. The inheritance tree for
each preset type is illustrated in the diagrams below.

#### Configure Presets

```plantuml
!include ../cmake/lib/doc/cmake-presets-configure.puml
```

#### Build Presets

```plantuml
!include ../cmake/lib/doc/cmake-presets-build.puml
```

#### Test Presets

```plantuml
!include ../cmake/lib/doc/cmake-presets-test.puml
```

#### Package Presets

```plantuml
!include ../cmake/lib/doc/cmake-presets-package.puml
```

### CLion IDE Integration

Presets include `vendor: {"jetbrains.com/clion": {"toolchain": "..."}}` entries that enable CLion to
automatically detect and configure the correct toolchain. This allows developers to switch between
compilers (GNU, MinGW, MSVC) directly within the IDE without manual CMake configuration.

## Build Workflow

The complete build workflow follows a linear pipeline orchestrated by `build.py`:

```plantuml
!include ../cmake/lib/doc/cmake-workflow.puml
```

1. **Configure** — `build.py` selects a preset and invokes `cmake --preset <name>` to generate
	 build files (Ninja).
2. **Build** — Compiles all targets using the configured toolchain.
3. **Test** — Runs CTest to execute Catch2 and GoogleTest unit tests.
4. **Package** — Invokes CPack to create distribution packages.

For detailed `build.py` usage, see @ref build-script.

## Binary Version Metadata

When `Sf_AddTarget()` is called with the `VERSION` flag, the function `Sf_AddVersionResource()` embeds
version information into the compiled binary. The approach differs between platforms:

```plantuml
!include ../cmake/lib/doc/cmake-metadata.puml
```

### Windows (PE Resources)

For Windows targets, `Sf_AddVersionResource()` processes the `version.rc` template via `configure_file()`,
substituting `@RC_*@` variables with project metadata (version, company name, description, compiler info,
build timestamp). The generated `.rc` file is added to the target sources and compiled into the PE resource
section. The resulting `.exe` or `.dll` contains `VS_VERSION_INFO` with:

* `FILEVERSION` and `PRODUCTVERSION` — Derived from the Git tag version.
* `CompanyName`, `FileDescription`, `ProductName` — From CMake project properties.
* `Comments` — Build host and compiler information.
* `BuildDateTime` — UTC timestamp of the build.

### Linux (ELF .meta Sections)

For Linux targets, `Sf_AddVersionResource()` processes the `version.cpp` template, which declares
`const char` arrays placed in custom ELF sections (`.meta.CompanyName`, `.meta.FileVersion`, etc.)
using `__attribute__((section(".meta.name")))`. These sections are embedded in the compiled binary
and can be read by `exiftool.py`.

### Metadata Verification (exiftool.py)

When `Sf_AddTarget()` is called with the `EXIF` flag, a custom `exif-<target>` target is created that
runs `exiftool.py` after the build. The script:

* Detects the binary format (PE via `MZ` magic bytes, ELF via `\x7fELF` magic bytes).
* For PE files — parses version information and imports using `pefile`.
* For ELF files — reads `.meta.*` sections and dynamic library dependencies using `pyelftools`.
* Reports: file name, type, CPU architecture, versions, company, description, imports, and RUNPATH.

The top-level `exif` custom target aggregates all `exif-<target>` targets, providing a single build
target that reports metadata for all binaries.

## Shell Scripts

The submodule provides several shell scripts in `cmake/lib/bin/` that support the build workflow.
These scripts are primarily used during Linux development.

### check-format.sh

Invoked by the Git pre-commit hook to verify code formatting before commits. This script works on
Windows as well when Git is configured to run the hook, making it cross-platform despite being a
shell script. The pre-commit hook is installed at `.git/hooks/pre-commit` and symlinks to
`cmake/lib/tpl/root/git-pre-commit-hook.sh`.

### Other Development Scripts

* **WineExec.sh** — Executes Windows binaries within a Wine environment.
* **QtLibDir.sh** — Locates the Qt library directory for the configured version.
* **coverage-report.sh** — Generates coverage reports from gcov data.
* **clang-format.sh** — Applies clang-format to source files.

## CTest Integration & Unit Testing

Testing is enabled when `SF_BUILD_TESTING` is set to `ON`. The submodule integrates two testing
frameworks:

### Catch2

Integrated via `SfCatch2Config.cmake`. Catch2 tests are defined in the `src/tests/catch/` directory
and can use the single-header framework for lightweight testing.

### GoogleTest

Integrated via `SfGoogleTestConfig.cmake`. GoogleTest tests are defined in `src/tests/google/` and
provide a more comprehensive testing framework with fixtures and parameterized tests.

### Running Tests

* **From CLion IDE** — Tests built with MinGW cross-compiler can be run directly from CLion without
	switching to a Windows machine. CLion detects the test targets via CMake and CTest integration.
* **From Command Line** — Use `build.py --test <preset>` to run all tests, or `build.py --test
  <preset> --test-regex "<pattern>"` to run specific tests.
* **MSVC on Linux** — MSVC-compiled tests can be built and run from the command line on Linux via
	Wine, but not directly from CLion.

## Coverage Reporting

Coverage analysis is available when building with the GNU compiler and the `Coverage` build type.

### Local Coverage

When `CMAKE_BUILD_TYPE` is set to `Coverage`, the build enables gcov instrumentation. After running
tests, `Sf_AddTestCoverageReport()` generates:

* **HTML report** — Detailed line-by-line coverage with source code highlighting.
* **JSON report** — Machine-readable coverage data for CI/CD integration.

The coverage report test is added as the last test to ensure all instrumented targets have been built.

### CI/CD Coverage Reporting

In the GitLab CI/CD pipeline, coverage HTML reports are uploaded to the Nexus `exchange` repository.
This approach solves a key limitation: **child pipelines cannot report coverage percentages back to
the parent pipeline**. By uploading the report to a shared Nexus repository, the main pipeline can
access and display the coverage results.

Example URL pattern:

```
https://nexus.scanframe.com/repository/exchange/gitlab-ci/shared/devops/pipeline/<id>/report.html
```

## CPack Packaging

When the build type is not `Coverage`, CPack configuration is applied via `SF_CPACK_PREPARE_FILE`,
which points to `cmake/lib/tpl/cpack/prepare.cmake`. The packaging system supports multiple generators:

### Linux Packages

* **deb** — Debian package generator with dependency management.
* **rpm** — Red Hat Package Manager format.
* **AppImage** — Self-contained portable application bundle.
* **archive** — Tarball (`.tar.gz`) for source or binary distribution.

### Windows Packages

* **NSIS** — Nullsoft Scriptable Install System for Windows installers.
* **archive** — ZIP archive for portable distribution.

Package configuration files are located in `cmake/lib/tpl/cpack/` and include platform-specific
settings for icons, licenses, installation directories, and component grouping.

## Doxygen Documentation

Documentation is generated by the `document` CMake target, which is added when the `doc/` directory
exists and `SfDoxygen` is found. The documentation system:

* Collects all `.md` files from `doc/` and `cmake/lib/doc/`.
* Scans `src/` subdirectories for `doc/` folders containing additional documentation.
* Extracts header files (`.h`, excluding `*Private.h` and `*_p.h`) from targets flagged with `doc`.
* Generates HTML documentation with PlantUML diagram rendering.

For documentation conventions, see @ref documentation.

To build documentation:

```bash
./build.py -b gnu-debug -n document
```

## GitLab CI/CD Pipeline

The submodule provides GitLab CI/CD configuration in `cmake/lib/tpl/root/gitlab-ci/` with two
approaches:

### build-single.gitlab-ci.yml (Preferred)

A single-job pipeline that performs configure, build, test, and package in one continuous job.
This approach avoids the CMake absolute path issue and is the recommended configuration.

### build-steps.gitlab-ci.yml (Multi-Step)

Splits the workflow into multiple jobs. This approach has a known limitation: CMake uses absolute
paths in its cache, and GitLab runners may not provide the same filesystem paths between jobs.
To work around this, the project directory must be bound to `/tmp` consistently across jobs.
Additionally, artifacts (including coverage reports) must be stored in the Nexus `exchange`
repository because child pipelines cannot pass data back to the parent pipeline.

### Child Pipelines

The main pipeline triggers child pipelines for each toolchain (GNU, MinGW/GW, MSVC, GNU Coverage).
This enables parallel builds across different compilers and platforms.

### Docker Images

Pipeline jobs run in Docker containers with pre-configured toolchains, eliminating the need for
manual compiler installation. The same Docker images are used for local Docker builds via `build.py`.

```plantuml
!include ../cmake/lib/tpl/root/doc/ci-pipeline.puml
```

## Cross-Platform & Cross-Compilation

The build system supports building for multiple platforms and architectures from a single codebase:

```plantuml
!include ../cmake/lib/doc/cmake-platforms.puml
```

### Development Workflow Advantage

Developers can work entirely on Linux:

* Write and debug code with the native GNU compiler.
* Cross-compile for Windows using MinGW (`gw`) and run tests via Wine.
* Build with MSVC via Wine and verify from the command line.
* Run all tests from CLion IDE when using MinGW cross-compiler.
* No need to switch to a Windows machine for most development tasks.

## Git Versioning

The function `Sf_GetGitTagVersion()` extracts the project version from Git tags. It analyzes the
current repository state and returns:

1. **Git tag version** — The semantic version string (e.g., `1.2.3`).
2. **Release candidate flag** — Whether the current commit is a pre-release.
3. **Commit count** — Number of commits since the last tag.

The version is set as the CMake `PROJECT_VERSION` and flows through to:

* Target `SOVERSION` and `VERSION` properties.
* Windows PE resource version information.
* Linux ELF `.meta` section metadata.
* CPack package versioning.
* Doxygen documentation headers.

For semantic versioning and conventional commit details, see @ref semantic-versioning.