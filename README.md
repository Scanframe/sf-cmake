# CMake Library

<!-- TOC -->
* [CMake Library](#cmake-library)
* [Introduction](#introduction)
  * [Usage](#usage)
    * [Fetching the Repository in CMake itself](#fetching-the-repository-in-cmake-itself)
    * [Repository as Sub-Module](#repository-as-sub-module)
  * [Project Structure](#project-structure)
  * [Head Start](#head-start)
<!-- TOC -->

# Introduction

Contains `.cmake` files for:

* Finding the Qt library files location for Windows 'C:\Qt' and for Linux `~/lib/Qt'.
* Adding version and description to Windows DLL's EXE's and only version to Linux SO-files.
* Generating/compiling DoxyGen manual from the source with PlantUML.
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
  git submodule add -b main -- ssh://git@git.scanframe.com:8022/library/cmake-lib.git lib
```

## Project Structure

A project directory tree could look like this.

```
<project-root>
    ├── src
    │   └── tests
    ├── bin
    │   ├── lnx64
    │   ├── man
    │   └── win64
    ├── cmake
    │   └── lib
    └── manual
```

| Path     | Description                            |
|----------|----------------------------------------|
| src      | Application source files.              |
| src/test | Test application source files.         |
| bin      | Root for compiled results from builds. |

The directory `bin` and holds a placeholder file named `__output__` to find the designated `bin` build
output directory for subprojects. Reason for building only subprojects instead of all is to speed
up debugging by compiling only the dynamic loaded library separately.

## Head Start

To get a head start look into the **[tpl/root](./tpl/root)** directory for files that will
give a head start getting a project going. 