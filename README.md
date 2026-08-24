# CMake Library

<!-- TOC -->

* [CMake Library](#cmake-library)
* [Introduction](#introduction)
    * [General](#general)
    * [Toolchains Supported](#toolchains-supported)
    * [Quick start](#quick-start)
        * [Using: Ubuntu/Debian flavor of Linux:](#using-ubuntudebian-flavor-of-linux)
        * [Using: Windows](#using-windows)
    * [Project Directory Structure & Setup](#project-directory-structure--setup)
        * [Structure](#structure)
        * [Project Setup Information](#project-setup-information)
    * [Qt Library Download](#qt-library-download)
    * [Doxygen Document](#doxygen-document)
    * [Git Versioning](#git-versioning)
        * [Tagging](#tagging)
    * [Semantic Versioning](#semantic-versioning)
    * [GitLab-CI Pipeline](#gitlab-ci-pipeline)
        * [Debian Package Upload Scheme](#debian-package-upload-scheme)
    * [Coverage Reporting](#coverage-reporting)
        * [Tools](#tools)
        * [CMake Functions](#cmake-functions)
    * [Code Format Checking and Fixing with Clang](#code-format-checking-and-fixing-with-clang)
    * [Packaging](#packaging)
        * [Project](#project)
        * [Qt for Distribution](#qt-for-distribution)

<!-- TOC -->

# Introduction

## General

This repository makes using CMake in C++ projects easier and features:

* Allows building Qt and non-Qt projects from Linux and Windows from a fresh-installed OS from scratch.
* The project can be setup on a Linux system and shared with Windows using Samba ((`follow symlinks = yes`))
  or with VirtualBox shared folders.
* Supports building using the compilers GNU, MinGW and MSVC on Linux and MinGW and MSVC on Windows.
* Provides a Python [`build.py`](bin/build.py) script to:
    * Set up the required packages for the used OS (Linux/Debian and Windows).
    * CMake configure, build, test and package or combined in a workflow for in CI pipelines.
    * Set up an environment for running a nested version of the script in Linux/Wine for the MSVC compiler.
    * Run the nested script in a Docker container using
      a [dedicated image](https://hub.docker.com/repository/docker/avolphen/amd64-gnu-cpp/general "Link to Docker Hub.")
      also used for pipelines.
    * Downloading build tools and compiler for Windows or Linux/Wine.
* Provides a skeleton CMake [project](tpl/root/src) and [CMake presets](tpl/root/CMakePresets.json) which:
    * Find the newest installed GCC compiler or cross-compiler when more are installed on a system. (Linux only)
    * For Windows adds version and description to Windows DLL's and EXE's using an auto-created resource file using the
      CMake project information and current Git version tag.
    * Create source documentation in a smart way using Doxygen with a PlantUML (a version can be set) plugin installed.
    * Create installable packages for Windows (NSIS, zip) and Linux (deb, rpm).
    * A coverage build that reports the percentage of coverage as well as a detailed HTML-report. (GNU compiler only)
    * Locates the required Qt library version and downloads it when it does not exist.
* Provides a skeleton [`gitlab-ci`](tpl/root/gitlab-ci) configuration directory which:
    * Uploads to a Nexus APT repository of Debian packages or raw upload for Windows as ZIP or installer.
    * Uploads the coverage HTML report to a MinIO server and accessible from the GitLab merge request.
* A version bump bash script to determine the next version based on which (merge-)commit is released when using
  conventional commit messages.

## Toolchains Supported

The [`build.py`](bin/build.py) script supports several toolchains, each intended for specific host environments:

* `gnu` - The native GNU compiler on Linux, targeting Linux x86_64.
* `ga` - The GNU compiler on Linux, cross-compiling for the ARM (aarch64) architecture.
* `gw` - The GNU cross-compiler toolchain running on Linux, targeting Windows (mingw-w64).
* `mingw` - The MinGW compiler, running natively on Windows or within Wine, targeting Windows.
* `msvc` - The Microsoft Visual C++ compiler, running natively on Windows or within Wine, targeting Windows.

| Toolchain | Linux | Wine | Docker(Wine) | Windows |
|-----------|:-----:|:----:|:------------:|:-------:|
| `gnu`     | 🛠🚀  |  ➖  |     🛠🚀     |   ➖    |
| `ga`      | 🛠🚀  |  ➖  |     🛠🚀     |   ➖    |
| `gw`      |  🛠   |  🚀  |     🛠🚀     |   ➖    |
| `mingw`   |  ➖   | 🛠🚀 |     🛠🚀     |  🛠🚀   |
| `msvc`    |  ➖   | 🛠🚀 |     🛠🚀     |  🛠🚀   |

> 🛠 Build/Compile projects.
> 🚀 Execution of tests and applications.

The table below shows how to invoke `build.py` for a given toolchain `<tc>` in each supported environment:

| Environment    | Command to Make and Build                     |
|----------------|-----------------------------------------------|
| Linux          | `./build.py -mb <tc>-debug`                   |
| Linux + Wine   | `./build.py wine -- -mb <tc>-debug`           |
| Docker         | `./build.py docker -- -mb <tc>-debug`         |
| Docker + Wine  | `./build.py docker -- wine -- -mb <tc>-debug` |
| Native Windows | `build.py -mb <tc>-debug`                     |

## Quick start

Create an empty project directory like `cpp-project`.
Download the [`build.py`](bin/build.py) script the project directory.

Sources where to download from are:

- [Latest from Development server](https://www.scanframe.com/export/build.py)
- [Scanframe's GitLab server 'main' branch](https://git.scanframe.com/library/cmake-lib/-/raw/main/bin/build.py)
- [GitHub mirror from GitLab 'main' branch](https://raw.githubusercontent.com/Scanframe/sf-cmake/refs/heads/main/bin/build.py)

For Linux/Debian use `wget <url>` and for Windows, which has Curl installed by default, use `curl -O <url>`.

### Using: Ubuntu/Debian flavor of Linux:

For using only the Docker contained compilers:

```shell
# Show the help.
./build.py
# Installs the 'docker.io' package from the distro.
./build.py install --required dio
# Installs the 'docker-ce' from an external source.
./build.py install --required dce
```

For using only the GNU compiler:

```shell
# Show the help.
./build.py
# Installs required packages for GNU compiler.
./build.py install --required lnx
# Install the skeleton project by Git cloning and sets up a git repository with this repository as submodule.
./build.py install --project
# Make the build and run tests.
./build.py --build --test gnu-debug
```

For cross-compiling, install more packages:

```shell
# Installs required packages for Windows MingW x86_64 cross-compiler and Wine. (only when needed, must be preceded by 'lnx')
./build.py install --required win
# Installs required packages for GNU aarch64/arm64 cross-compiler. (only when needed, must be preceded by 'lnx')
./build.py install --required arm
````

For MSVC compiling:

```shell
# Installs required packages for Windows MingW x86_64 cross-compiler and Wine. (must be preceded by 'lnx')
./build.py install --required win
# Installs Multiple tools as CMake, Ninja, NSIS and Git client for Wine in subdirectory '<project>/lib/toolchain'.
./build.py install --toolchain tools
# Install the MSVC toolchain in subdirectory '<project>/lib/toolchain'.
./build.py install --toolchain msvc
 ````

### Using: Windows

Windows is more challenging to start since many of the Linux-ready available tools are not available on Windows.

A prerequisite is Python 3.12 or later. Python `.py` scripts are executable on Windows.

```shell
winget install --exact --id Python.Python.3.12
```

For MinGW/MSVC compiling:

```shell
# Install WinGet packages for the required buildtools.
build.py install --required win
```

When Git was not installed yet, reopen the console app to have the `git` command available.

```shell
# Install the skeleton project by Git cloning and sets up a git repository with this repository as submodule.
build.py install --project
```

For MinGW compiling:

```shell
# Install the MinGW toolchain in subdirectory '<project>/lib/toolchain'.
build.py install --toolchain mingw
# Compile the project which can download the appropriate Qt library.
build.py --build mingw-debug
```

For MSVC compiling:

```shell
# Install the MinGW toolchain in subdirectory '<project>/lib/toolchain'.
build.py install --toolchain msvc
# Compile the project which can download the appropriate Qt library.
build.py --build msvc-debug
```

For compiling a document with DoxyGen:

```shell
# Compile the non-default DoxyGen documentation project.
./build.py --build gnu-debug -n document
# Opens the Chrome browser in application mode with the generated pages.
bin/man/open.sh
```

> For Windows use preset `mingw-debug` or `msvc-debug`.

## Project Directory Structure & Setup

### Structure

A project directory tree could look like this:

```
<project-root>
    ├── .gitlab (CI/CD )
    ├── bin (build output of the project)
    │   ├── lnx64-gnu
    │   │   └── lib
    │   ├── lnx64-ga
    │   │   └── lib
    │   ├── win64-gw
    │   │   └── lib
    │   ├── win64-msvc
    │   │   └── lib
    │   ├── pkg (CPack generated output)
    │   ├── gcov (Coverage generated output)
    │   ├── man (Doxygen generated documentation)
    │   └── win64 (a suffixed could be applied)
    │       └── lib
    ├── cmake
    │   ├── cpack
    │   └── lib (This repository location)
    ├── cmake-build
    │   ├── docker-amd64-6.10.1 (mapped docker build root)
    │   │   ├── gnu-debug (Linux GNU)
    │   │   ├── ga-debug (Linux MinGW)
    │   │   └── msvc-debug (Windows MSVC)
    │   ├── gnu-debug (Linux GNU)
    │   ├── gw-debug (Linux MinGW)
    │   └── mingw-debug (Windows MinGW)
    ├── doc (Base documentation directory)
    ├── lib
    │   ├── qt (base of Qt versioned libraries)
    │   └── toolchain (Base of toolchains)
    └── src
        └── tests
```

| Path            | Description                                            |
|-----------------|--------------------------------------------------------|
| .gitlab         | GitLab CI/CD pipeline scripts.                         |
| bin             | Root for compiled results from builds.                 |
| bin/gcov        | Coverage report files from unittests.                  |
| bin/lnx64-*     | Binaries from Linux 64-bit builds.                     |
| bin/lnx64-*/lib | Dynamic libraries from Linux 64-bit builds.            |
| bin/win64-*     | Binaries from Windows 64-bit builds.                   |
| bin/win64-*/lib | Dynamic libraries from Windows 64-bit builds.          |
| bin/pkg         | Packages from all builds.                              |
| bin/man         | Doxygen generated documentation builds.                |
| cmake/cpack     | CPack files for packing the application and libraries. |
| cmake/lib       | Obligatory Location of this 'cmake-lib' git-submodule. |
| cmake-build     | CMake binary root directory.                           |
| doc             | Doxygen document project source.                       |
| lib             | Downloaded or symlinks to libraries.                   |
| lib/qt          | Linux Qt library directory or symlink.                 |
| lib/toolchain   | Base directory of toolchains.                          |
| src             | Application source files.                              |
| src/tests       | Test application source files.                         |

The directory `bin` and holds a placeholder file named `__output__` to find the designated `bin` build output directory
for subprojects. The reason for building only subprojects instead of all is to speed up debugging by compiling only the
dynamic loaded library separately. When directories are empty but needed, then add a file called `__placeholder__` so is
not ignoring them.

> The `build.ini` and the `CMakePresets.json` provides a way to extend the `bin/lnx64` or `bin/win64` directory
> by an environment variable (`SF_EXEC_DIR_SUFFIX`).

### Project Setup Information

## Qt Library Download

Instead of installing Qt with the "Qt Maintenance Tool" this CMake command will download the library in the subdirectory
`<project-dir>/lib/qt` depending on the target specified host OS.

```cmake
find_package(SfQtLibrary 6.10.1 CONFIG REQUIRED)
```

## Doxygen Document

For generating documentation from the code using [Doxygen](https://www.doxygen.nl/) the `doc` subdirectory is added to
the main `CMakeLists.txt` file.

```cmake
# Add Doxygen document project.
add_subdirectory(doc)
```

See the `doc` directory [`CMakeLists.txt`](tpl/root/doc/CMakeLists.txt) to see how files are automatically included in
the manual.

Look at [the Doxygen website](https://www.doxygen.nl/) for the syntax in C++ header comment blocks or Markdown files.

## Git Versioning

### Tagging

To create a version tag with this library, there are two options.
Create a release tag like `v1.2.3` or a release candidate tag like `1.2.3-rc.4`.

The CMake coding picks this up using function [Sf_GetGitTagVersion](SfBaseConfig.cmake "Link to file.") returns the
version depending on the result of the next Git-command.

```shell
# Only annotated tags so no '--tags' option.
git describe --dirty --match "v*.*.*"
```

Possible results from this command are:

```
v1.2.3
v1.2.3-dirty
v1.2.3-rc.4-dirty
v1.2.3-rc.4
v1.2.3-45-g914edbb-dirty
v1.2.3-rc.4-56-g914edbb-dirty
```

The CMake function `Sf_GetGitTagVersion` creates a version list from the result.

```cmake
Sf_GetGitTagVersion(_Versions "${CMAKE_CURRENT_LIST_DIR}")
list(GET _Versions 0 SF_GIT_TAG_VERSION)
list(GET _Versions 1 SF_GIT_TAG_RC)
list(GET _Versions 2 SF_GIT_TAG_COMMITS)
```

For example, when the result is `v1.2.3-rc.4-56-g914edbb-dirty`.

| Index | Description                       | Value |
|------:|-----------------------------------|------:|
|     0 | Main version number               | 1.2.3 |
|     1 | Optional release candidate number |     4 |
|     2 | Commit count since the tag        |    56 |

Index positions 1 and 2 are empty when not applicable.

## Semantic Versioning

For this item a separate page is created so see: [Semantic Versioning](doc/semantic-versioning.md)

## GitLab-CI Pipeline

### Debian Package Upload Scheme

There are three Nexus apt-repositories that can be described to:

| Name      | Usage                    |
|-----------|--------------------------|
| `stable`  | Actual releases.         |
| `staging` | Release candidates.      |
| `develop` | Development and testing. |

To have the latest release, subscribe only to `stable`. To have update when a release candidate (RC) becomes available
subscribe additionally to `staging`. When developing and testing debian packages subscribe additionally to `develop`.

Debian packages are deployed/uploaded to the appropriate apt-repository depending on if it:

* **MR**: Originates from a merge-request.
* **PRB**: Originates from a push to the release branch which is mainly `main`.
* **RC**: Is a Release Candidate.
* **CMT**: Has commits since tag was created.

| MR  | RC  | PRB | CMT | Destination |
|:---:|:---:|:---:|:---:|:-----------:|
| No  | No  | Yes | No  |  `stable`   |
| No  | No  | Yes | Yes |  `staging`  |
| No  | No  | No  |  *  |     n/a     |
| No  | Yes | Yes |  *  |  `staging`  |
| No  | Yes | No  |  *  |  `develop`  |
| Yes |  *  |  *  |  *  |  `develop`  |

> Windows ZIP and installer EXE files are uploaded to a `dist/<destination>` directory.

## Coverage Reporting

### Tools

The tools for this are `gcov` and `gcovr` of

### CMake Functions

The functions needed to perform coverage are located in [SfBaseConfig.cmake](SfBaseConfig.cmake).

| Function                 | Description                                                                                          |
|--------------------------|------------------------------------------------------------------------------------------------------|
| Sf_AddTargetForCoverage  | Sets compiler and linker options for the target depending on the target type.                        |
| Sf_AddAsCoverageTest     | Adds a test to the list which is used as a dependency for the test generating the report.            |
| Sf_AddTestCoverageReport | Adds the test generating the report calling the script [coverage-report.sh](bin/coverage-report.sh). |

## Code Format Checking and Fixing with Clang

To enable format check before a commit, modify or add the script
[`.git/hooks/pre-commit`](tpl/root/git-pre-commit-hook.sh) with the following content. It calls the
[`check-format.sh`](bin/check-format.sh) script, which indirectly calls the
[`clang-format.sh`](bin/clang-format.sh) from the CMake support library.
It also checks if it is a commit to the main or master branch and prevents it.

```bash
#!/bin/bash

# Redirect output to stderr.
exec 1>&2
# Get the branch name.
branch="$(git rev-parse --abbrev-ref HEAD)"
# Check if it is 'main' and prevent a commit on it.
if [[ "${branch}" == "main" || "${branch}" == "master" ]]; then
	echo "You can't commit directly to the '${branch}' branch!"
	exit 1
fi

# When the file 'check-format.sh' exists call it to check if the formatting is correct.
if [[ -f check-format.sh ]]; then
	if ! ./check-format.sh; then
		echo "Source is not formatted correctly!"
		exit 1
	fi
fi
```

This same script is used in the main pipeline configuration script
[`main.gitlab-ci.yml`](tpl/root/gitlab-ci/main.gitlab-ci.yml) in the job named '**check-env**'.
When the formatting of changed files is incorrect, the first job in the pipeline will fail.

## Packaging

### Project

Option `-p` or `--package` will package the executable files and its dependent dynamic libraries by checking non-system
dynamic library usage.

```bash
./build.py --package gnu-debug
```

> Dependencies found are mostly from the used toolchain.

### Qt for Distribution

To package the Qt library for distribution, set variable `SF_PACKAGE_QT`
which is also the Debian revision package number (use `0` for the first version).

```bash
./build.py --package gnu-debug -- -DSF_PACKAGE_QT=1
```

> The same name is also used for non debian package generators.

### Debian Package Versioning Specification

This repository uses a structured versioning scheme based on `git describe` to generate unique Debian package versions
for both automated CI/CD builds and local developer builds.

#### Version Structure

```text
<upstream-version>[~<pre-release>]+<commit-count>.<local-revision>
│                 │               │              └─ Optional local build iteration (e.g., .1, .2)
│                 │               └─ Commits since last tag (from `git describe`)
│                 └─ Release candidate / pre-release tag
└─ Base semantic version (e.g., 0.1.0)
```

> **Note on `~` vs `-`:** The tilde (`~`) is intentionally used before pre-release identifiers (e.g., `~rc1`) so `dpkg`
> correctly sorts pre-release packages as **older** than the final release (e.g., `0.1.0~rc1` < `0.1.0`).

#### Examples & Workflow

| Scenario                       | Git Tag / Context               | CPack / Package Version | `dpkg` Ordering                 |
|:-------------------------------|:--------------------------------|:------------------------|:--------------------------------|
| **MR / CI Build**              | `v0.1.0-rc.1-9-g86f4cd1`        | `0.1.0~rc1+9`           | Base version                    |
| **Local Dev Build**            | *(Same commit + local changes)* | `0.1.0~rc1+9.1`         | **Newer** than `0.1.0~rc1+9`    |
| **Subsequent Local Iteration** | *(Further local tweaks)*        | `0.1.0~rc1+9.2`         | **Newer** than `.1`             |
| **Final Tag Release**          | `v0.1.0`                        | `0.1.0`                 | **Newer** than all `~rc` builds |

#### CPack Configuration Guidelines

1. **CI Pipeline (Automated):**
   Parse output from `git describe --dirty --match 'v*.*.*'`:
    * Convert `-rc.` to `~rc`
    * Map the commit distance (`-9-`) to `+9`
    * Set package revision/suffix to empty (default)

2. **Local Developer Build:**
   When building locally to test fixes in the test APT repository, supply the optional revision number (e.g., `1`) to
   CPack:
   ```bash
   ./build.py -p gnu-debug -- -DSF_PACKAGE_REVISION=1
   cmake --build build --target package
   ```
   This appends `.1` to the version, ensuring `dpkg` treats it as an upgrade over the CI build.

To test version comparison, use:

```bash
dpkg --compare-versions "<version-1>" gt "<version-2>" && echo "True" || echo "False"
```