# CMake Library

<!-- TOC -->
* [CMake Library](#cmake-library)
* [Introduction](#introduction)
  * [Usage](#usage)
    * [Fetching the Repository in CMake itself](#fetching-the-repository-in-cmake-itself)
    * [Repository as Sub-Module](#repository-as-sub-module)
  * [Project Directory Structure](#project-directory-structure)
  * [Main Project Head Start](#main-project-head-start)
  * [Doxygen Document](#doxygen-document)
  * [Git Versioning](#git-versioning)
    * [Tagging](#tagging)
  * [Semantic Versioning](#semantic-versioning)
    * [Conventional Commits Auto Version Bumping](#conventional-commits-auto-version-bumping)
    * [Commit Message Format](#commit-message-format)
    * [Type of Commits](#type-of-commits)
    * [Examples of Message Headers](#examples-of-message-headers)
    * [Examples of Full Messages](#examples-of-full-messages)
  * [GitLab-CI Pipeline](#gitlab-ci-pipeline)
    * [Debian Package Upload Scheme](#debian-package-upload-scheme)
  * [Coverage Reporting](#coverage-reporting)
    * [Tools](#tools)
    * [CMake Functions](#cmake-functions)
<!-- TOC -->

# Introduction

Contains `.cmake` files for:

* Finding the Qt library files location for Windows 'C:\Qt' and for Linux `~/lib/Qt'.
* Adding version and description to Windows DLL's EXE's and only version to Linux SO-files.
* Generating/compiling Doxygen documentation from the source with PlantUML.
* Find the newest installed GCC compiler when more are installed and a cross Windows compiler when requested.
* Shell script to make, build and test the project and subprojects also easy to use in CI-pipelines.
* Building a debian package file from the project. (is under development)

## Usage

### Fetching the Repository in CMake itself

Bellow an excerpt of a `CMakeLists.txt` to use the repository as CMake-package.
Disadvantage is that the shell scripts are not accessible before CMake make has been run and a chicken and egg problem occurs.

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

```bash
  git submodule add -b main -- https://github.com/Scanframe/sf-cmake.git lib
  git submodule add -b main -- https://git.scanframe.com/library/cmake-lib.git lib
```

## Project Directory Structure

A project directory tree could look like this.

```
<project-root>
    ├── src
    │   └── tests
    ├── bin
    │   ├── gcov
    │   ├── lnx64
    │   ├── pkg
    │   ├── man
    │   └── win64
    ├── cmake
    │   └── lib
    └── doc
```

| Path      | Description                            |
|-----------|----------------------------------------|
| src       | Application source files.              |
| src/test  | Test application source files.         |
| bin       | Root for compiled results from builds. |
| bin/gcov  | Coverage report files from unittests.  |
| bin/lnx64 | Binaries from Linux 64-bit builds.     |
| bin/pkg   | Packages from all builds.              |
| bin/man   | Generated documentation builds.        |
| doc       | DoxgGen document project source.       |

The directory `bin` and holds a placeholder file named `__output__` to find the designated `bin` build
output directory for subprojects. Reason for building only subprojects instead of all is to speed
up debugging by compiling only the dynamic loaded library separately.
When directories are empty but needed then add a file called `__placeholder__` so is not ignoring them.

## Main Project Head Start

To get a head start look into the **[tpl/root](./tpl/root)** directory for files that will
give a head start getting a project going.

## Doxygen Document

For generating documentation from the code using [Doxygen](https://www.doxygen.nl/) the `doc` subdirectory is to be added.
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

### Conventional Commits Auto Version Bumping

To automatically bumping the version using conventional commits
the script [VersionBump.sh](bin/VersionBump.sh) can be called indirect by creating
bash script in the project root called `version-bump.sh` like:

```bash
#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${DIR}" "${DIR}/cmake/lib/bin/VersionBump.sh" "${@}"
```

The script analyses the commit messages up-to a certain commit and computes a new semantic version.
At the same time generates release-notes for this version.

### Commit Message Format

The Conventional Commit format is based on [Angular](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit)
and is as follows where the blank lines are separators between description, body and footer.

```
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```

The description which is the first message line and is mandatory formatted as follows:

```
<type>(<scope>)!: <short summary>
│       │      │      │
│       │      │      └─⫸ Summary in present tense.
│       │      │      
│       │      └─⫸ Optional exclamation mark '!' indicating a breaking change.
│       │
│       └─⫸ Commit Scope: common|compiler|config|cmake|changelog|docs-infra|pack|iface|etc...
│
└─⫸ Commit Type: build|ci|chore|docs|feat|fix|perf|refactor|style|test|revert
```

### Type of Commits

| Type       | Description                                                                                                | Version Effect                                                                |
|------------|------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `fix`      | Fixes a bug in the codebase.                                                                               | Patch version bump or unless a breaking change.                               |
| `feat`     | Introduces a new feature to the codebase.                                                                  | Minor version bump unless a breaking change.                                  |
| `build`    | Changes that affect the build process or build tools.                                                      | No direct effect, but may indirectly influence semantic versioning decisions. |
| `chore`    | Changes that affect the build process or maintain the project (e.g., documentation changes, tool updates). | No direct effect.                                                             |
| `ci`       | Changes to the continuous integration configuration.                                                       | No direct effect.                                                             |
| `docs`     | Changes to the project documentation.                                                                      | No direct effect.                                                             |
| `style`    | Changes that only affect code style or formatting.                                                         | No direct effect.                                                             |
| `refactor` | Changes that improve the internal structure of the code without adding new features or fixing bugs.        | No direct effect.                                                             |
| `perf`     | Changes that improve performance.                                                                          | No direct effect, but when gains are significant it could.                    |
| `test`     | Changes that add or modify tests.                                                                          | No direct effect.                                                             |
| `revert`   | Reverts a previous commit mentioning the concerned commit hash.                                            | No direct effect.                                                             |

> **Note:**
>
> While some types don't directly affect version numbers, they can still be valuable for understanding
> the project history and making informed decisions about semantic versioning.  
> The by the standard mentioned special footer `BREAKING CHANGE:` is not honored and is replaced the
> header containing the `!` exclamation-mark to cause a major version bump.

### Examples of Message Headers

1. `feat(auth)!: Implement a new authentication system.`  
   This message introduces a new feature (`feat`) that likely has backward-incompatibilities (`!`) and might require a major version bump.
2. `fix: Update dependency versions to address security vulnerabilities.`  
   This message fixes a bug (`fix`) by updating dependencies,
   but doesn't introduce new features or breaking changes, so the version should likely remain unchanged.
3. `build(deps): Upgrade build tools to the latest version.`  
   This message clarifies the scope (`build(deps)`) of changes affecting build dependencies and doesn't directly impact the project's functionality,
   so versioning is likely unaffected.
4. `chore: Update project documentation.`  
   This message reflects maintenance changes (`chore`) to documentation and doesn't introduce new features or bugs,
   so the version likely stays the same.
5. `ci: Configure continuous integration for merge requests.`  
   This message describes changes to the CI process (`ci`), which typically don't affect the project's public version, so the versioning remains unchanged.
6. `docs: Add a new tutorial for beginners.`  
   Similar to updating project documentation (`chore`), adding a tutorial (`docs`) doesn't impact functionality and likely does not warrant a version change.
7. `style: Fix code formatting issues.`  
   This message addresses code style (`style`), which doesn't introduce new features or fix bugs, so the version shouldn't change.
8. `refactor: Improve code readability and maintainability.`  
   While refactoring code (`refactor`) doesn't directly introduce new features or fix bugs, significant improvements might influence a minor version bump, but
   it depends on project specifics.
9. `perf: Optimize performance for large datasets.`  
   Similar to refactoring, performance improvements (`perf`) might warrant a minor version bump for significant optimizations, but the decision depends on
   project context.
10. `test(auth): Add unit tests for a new feature.`  
    Adding tests (`test`) is a good practice and doesn't affect the project's functionality or introduce breaking changes, so the version likely remains
    unchanged.

### Examples of Full Messages

**Example having a multiline body**

```
docs(config): Update deployment instructions.

Updated deployment instructions in README.md to 
include new environment variables.
```

**Example with ignored `BREAKING CHANGE` footer**

```
feat(iface)!: Added argument to user authentication function. 

Feature is added for which the interface.

BREAKING CHANGE: Interface has changed for plugins.
```

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
