# CMake Library

<!-- TOC -->
* [CMake Library](#cmake-library)
* [Introduction](#introduction)
  * [Quick start](#quick-start)
    * [Using: Debian Linux:](#using-debian-linux)
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
<!-- TOC -->

# Introduction

This repository makes using CMake in C++ projects easier and features:

* Allows building Qt and non-Qt projects from Linux and Windows from a fresh installed OS from scratch.
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
  * Uploads the coverage HTML-report to a MinIO server and accessible from the GitLab merge request.
* A version bump bash script to determine the next version based on which (merge-)commit is released
  when using conventional commit messages.

## Quick start

Create an empty project directory like `cpp-project`.  
Download the [`build.py`](bin/build.py) script the project directory.

Sources where to download from are:
- https://www.scanframe.com/export/build.py
- https://git.scanframe.com/library/cmake-lib/-/raw/main/bin/build.py
- https://raw.githubusercontent.com/Scanframe/sf-cmake/refs/heads/main/bin/build.py

For Linux/Debian use `wget <url>` and for Windows, which has Curl installed by default, 
use `curl -O <url>`.

### Using: Debian Linux:

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
build.py install --build mingw-debug
```

For MSVC compiling: 

```shell
# Install the MinGW toolchain in subdirectory '<project>/lib/toolchain'.
build.py install --toolchain msvc
# Compile the project which can download the appropriate Qt library.
build.py install --build msvc-debug
```

For compiling a document with DoxyGen: 

```shell
# Compile the non-default DoxGen documentation project.
./build.py -b gnu-debug -n document
# Opens the Chrome browser in application mode with the generated pages.
bin/man/open.sh
```
> For Windows use preset `mingw-debug` or `mingw-debug`.

## Project Directory Structure & Setup

### Structure

A project directory tree could look like this.

```
<project-root>
    ├── .gitlab
    ├── bin
    │   ├── gcov
    │   ├── lnx64 (a suffixed could be applied)
    │   │   └── lib
    │   ├── pkg
    │   ├── man
    │   └── win64 (a suffixed could be applied)
    │       └── lib
    ├── cmake
    │   ├── cpack
    │   └── lib (This repository location)
    ├── cmake-build
    │   ├── gnu-debug (Linux GNU)
    │   ├── gw-debug (Linux MinGW)
    │   └── mingw-debug (Windows MinGW)
    ├── doc
    ├── lib
    │   └── qt
    └── src
        └── tests
```

| Path          | Description                                            |
|---------------|--------------------------------------------------------|
| .gitlab       | GitLab CI/CD pipeline scripts.                         | 
| bin           | Root for compiled results from builds.                 |
| bin/gcov      | Coverage report files from unittests.                  |
| bin/lnx64     | Binaries from Linux 64-bit builds.                     |
| bin/lnx64/lib | Dynamic libraries from Linux 64-bit builds.            |
| bin/win64     | Binaries from Windows 64-bit builds.                   |
| bin/win64/lib | Dynamic libraries from Windows 64-bit builds.          |
| bin/pkg       | Packages from all builds.                              |
| bin/man       | Doxygen generated documentation builds.                |
| cmake/cpack   | CPack files for packing the application and libraries. |
| cmake/lib     | Obligatory Location of this 'cmake-lib' git-submodule. |
| cmake-build   | CMake binary root directory.                           |
| doc           | Doxygen document project source.                       |
| lib           | Downloaded or symlinks to libraries.                   |
| lib/qt        | Linux Qt library directory or symlink.                 |
| src           | Application source files.                              |
| src/test      | Test application source files.                         |

The directory `bin` and holds a placeholder file named `__output__` to find the designated `bin` build
output directory for subprojects. The reason for building only subprojects instead of all is to speed
up debugging by compiling only the dynamic loaded library separately.
When directories are empty but needed then add a file called `__placeholder__` so is not ignoring them.

> The `build.ini` and the `CMakePresets.json` provides a way to extend the `bin/lnx64` or `bin/win64` directory
> by an environment variable (`SF_EXEC_DIR_SUFFIX`).

### Project Setup Information

## Qt Library Download

Instead of installing Qt with the "Qt Maintenance Tool" this CMake command will download the library
in the subdirectory `<project-dir>/lib/qt` depending on the target specified host OS.

```cmake
find_package(SfQtLibrary 6.10.1 CONFIG REQUIRED)
```

## Doxygen Document

For generating documentation from the code using [Doxygen](https://www.doxygen.nl/) the `doc` subdirectory
is added to the main `CMakeLists.txt` file.

```cmake
# Add Doxygen document project.
add_subdirectory(doc)
```

See the `doc` directory [`CMakeLists.txt`](tpl/root/doc/CMakeLists.txt) to see how files are automatically 
included in the manual.

Look at [the Doxygen website](https://www.doxygen.nl/) for the syntax in C++ header comment blocks or 
Markdown files.

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

For example when the result is `v1.2.3-rc.4-56-g914edbb-dirty`.

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

To have the latest release, subscribe only to `stable`.
To have update when a release candidate (RC) becomes available subscribe additionally to `staging`.
When developing and testing debian packages subscribe additionally to `develop`.

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

To enable format check before a commit, modify or add the script [
`.git/hooks/pre-commit`](tpl/root/git-pre-commit-hook.sh) with the following content.
It calls the [check-format.sh](bin/check-format.sh) script, which indirectly calls the
[clang-format.sh`](bin/clang-format.sh) from the CMake support library.  
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
