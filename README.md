# CMake Library

<!-- TOC -->

* [CMake Library](#cmake-library)
* [Introduction](#introduction)
	* [Usage](#usage)
		* [Fetching the Repository in CMake itself](#fetching-the-repository-in-cmake-itself)
		* [Repository as Sub-Module](#repository-as-sub-module)
	* [Project Directory Structure & Setup](#project-directory-structure--setup)
		* [Structure](#structure)
		* [Setup](#setup)
	* [Main Project Head Start](#main-project-head-start)
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

* Allows building from Linux for Linux & Windows and from Windows only for Windows itself.
	Building from Windows requires Cygwin to be installed.
* Shell script to make, build, test and package using CMake also use by CI-pipelines.
* Locating the installed Qt library or downloading them.
* Downloading build tools for Windows when needed.
* Adding version and description to Windows DLL's EXE's as resource from the project (Linux: SO-files are versioned
	only).
* Generating/compiling Doxygen documentation from the source with PlantUML plugin installed (downloaded by version).
* Find the newest installed GCC compiler when more are installed and a cross Windows compiler when used.
* Creating installable packages for Windows (NSIS, zip) and Linux (deb, rpm).
* Uploading to a Nexus APT repository of Debian packages or raw upload for Windows packages.
* Upload of generated HTML coverage reports of which a message containing a link is written to the GitLab merge request.
* Version bump script to determine the next version based on which (merge-)commit is released when using conventional
	commit messages.
* Script to build using Docker container using a special image containing all tools needed.

## Usage

### Fetching the Repository in CMake itself

Bellow an excerpt of a `CMakeLists.txt` to use the repository as CMake-package.
Disadvantage is that the shell scripts are not accessible before CMake make has been run and a chicken-and-egg problem
occurs.

```cmake
# Required to use the 'FetchContent_XXXX' functions. 
include(FetchContent)
# Download the main branch of the CMake common library.
FetchContent_Declare(Sf_CMakeLibrary
	GIT_REPOSITORY "https://github.com/Scanframe/sf-cmake.git"
	GIT_TAG main # Or a version tag.
)
FetchContent_MakeAvailable(Sf_CMakeLibrary)
# Add the source to the cmake file search path.
list(APPEND CMAKE_PREFIX_PATH "${sf_cmakelibrary_SOURCE_DIR}")
```

### Repository as Sub-Module

The preferred way is to create a Git submodule `lib` in the `<project-root>/cmake`

From private GitLab use:

```bash
  git submodule add -b main -- https://github.com/Scanframe/sf-cmake.git cmake/lib
```  

From GitHub use:

```bash
  git submodule add -b main -- https://git.scanframe.com/library/cmake-lib.git cmake/lib
```

## Project Directory Structure & Setup

### Structure

A project directory tree could look like this.

```
<project-root>
    ├── .gitlab
    ├── bin
    │   ├── gcov
    │   ├── lnx64
    │   │   └── lib
    │   ├── pkg
    │   ├── man
    │   └── win64
    │       └── lib
    ├── cmake
    │   ├── cpack
    │   └── lib (Repository location)
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
output directory for subprojects. Reason for building only subprojects instead of all is to speed
up debugging by compiling only the dynamic loaded library separately.
When directories are empty but needed then add a file called `__placeholder__` so is not ignoring them.

### Setup

To set up a project from scratch some files, directories or templates need to be copied or symlinked
as shown in the next table.

| Method  | Source                         | Destination                      |
|---------|--------------------------------|----------------------------------|
| Copy    | tpl/root/CMakeLists.tpl.cmake  | <prj-root>/CMakeLists.txt        | 
| Copy    | tpl/root/CMakePresets.json     | <prj-root>/CMakePresets.json     |
| Copy    | tpl/root/CMakeUserPresets.json | <prj-root>/CMakeUserPresets.json |
| Copy    | tpl/gitlab-ci/*                | <prj-root>/.gitlab               |
| Symlink | bin/build.sh                   | <prj-root>/build.sh              |
| Symlink | bin/docker-build.sh            | <prj-root>/docker-build.sh       |
| Symlink | bin/tools.sh                   | <prj-root>/tools.sh              |
| Symlink | bin/version-bump.sh            | <prj-root>/version-bump.sh       |
| Symlink | bin/check-format.sh            | <prj-root>/check-format.sh       |

## Main Project Head Start

To get a head start look into the **[tpl/root](./tpl/root)** directory for files that will
give a head start getting a project going.

## Qt Library Download

Instead of installing Qt with the "Qt Maintenance Tool" this CMake command will download the library
in `lib/Qt`, `lib/QtWin` or `lib/QtW64` depending on the host and target OS.

The tools for building on a Windows OS can also be installed using the symlink `./tools` in the project
root created from  `cmake/lib/bin/tools.sh`. A file `.tools-dir-<hostname>` is created where the tools
are installed and used by the `./build.sh` to add it to the `PATH` when executing CMake commands.

```cmake
find_package(SfQtLibrary 6.7.2 CONFIG REQUIRED)
```

## Doxygen Document

For generating documentation from the code using [Doxygen](https://www.doxygen.nl/) the `doc` subdirectory is to be
added.
in the main `CMakeLists.txt`.

```cmake
# Add Doxygen document project.
add_subdirectory(doc)
```

The `doc` directory `CMakeLists.txt` looks like this where header files are added to the config file.

```cmake
# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.18)
# Set the global project name.
project("document")
# Add doxygen project when SfDoxygen was found.
# On Windows this is only possible when doxygen is installed in Cygwin.
find_package(SfDoxygen QUIET)
if (SfDoxygen_FOUND)
	# Get the markdown files in this project directory including the README.md.
	file(GLOB _SourceList RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "*.md" "../*.md")
	# Get all the header files from the application.
	file(GLOB_RECURSE _SourceListTmp RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "../src/*.h" "../src/*.md")
	# Remove unwanted header file(s) ending on 'Private.h'.
	list(FILTER _SourcesListTmp EXCLUDE REGEX ".*Private\\.h$")
	# Append the list with headers.
	list(APPEND _SourceList ${_SourceListTmp})
	# Adds the actual manual target and the last argument is the optional PlantUML jar version to download use.
	Sf_AddDoxygenDocumentation("${PROJECT_NAME}" "${PROJECT_SOURCE_DIR}" "${PROJECT_SOURCE_DIR}/../bin/man" "${_SourceList}" "v1.2023.0")
endif ()
```

Look at [Doxygen](https://www.doxygen.nl/) website for the syntax in C++ header comment blocks or Markdown files.

## Git Versioning

### Tagging

To create a version tag with this library there are 2 options.  
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

The CMake function `Sf_GetGitTagVersion` creates a versions list from the result.

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

There are 3 Nexus apt-repositories which can be described to:

| Name      | Usage                    |
|-----------|--------------------------|
| `stable`  | Actual releases.         |
| `staging` | Release candidates.      |
| `develop` | Development and testing. |

In order to have the latest release subscribe only to `stable`.
To have update when a release candidate (RC) becomes available subscribe additionally to `staging`.
When developing and testing debian packages subscribe additionally to `develop`.

Debian packages are deployed/uploaded to the appropriate apt-repository depending on if it:

* **MR**: Originates from a merge-request.
* **PRB**: Originates from a push to the release branch which is mainly `main`.
* **RC**: Is a Release Candidate.
* **CMT**: Has commits since tag was create.

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

To enable format check before a commit modify or add the script `.git/hooks/pre-commit` with the following content.
It calls the [check-format.sh](./check-format.sh) script which in directly calls
the [`clang-format.sh`](https://github.com/Scanframe/sf-cmake/blob/main/bin/clang-format.sh) script
from the CMake support library. It also checks if it is a commit to the main or master branch and prevents it.

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

This same script is used in the main pipeline configuration script [`main.gitlab-ci.yml`](.gitlab/main.gitlab-ci.yml)
in the job named '**check-env**'.  
So when the format is incorrect the pipeline will fail.
