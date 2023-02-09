# CMake Library

<!-- TOC -->
* [CMake Library](#cmake-library)
* [Introduction](#introduction)
  * [Usage](#usage)
    * [Fetching the Repository in CMake itself](#fetching-the-repository-in-cmake-itself)
    * [Repository as Sub-Module](#repository-as-sub-module)
  * [Project Structure](#project-structure)
  * [Head Start](#head-start)
  * [DoxyGen Document](#doxygen-document)
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

## Project Directory Structure

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
    └── doc
```

| Path     | Description                            |
|----------|----------------------------------------|
| src      | Application source files.              |
| src/test | Test application source files.         |
| bin      | Root for compiled results from builds. |
| doc      | DoxyGen document project.              |

The directory `bin` and holds a placeholder file named `__output__` to find the designated `bin` build
output directory for subprojects. Reason for building only subprojects instead of all is to speed
up debugging by compiling only the dynamic loaded library separately.
When directories are empty but needed then add a file called `__placeholder__` so is not ignoring them.  

## Main Project Head Start

To get a head start look into the **[tpl/root](./tpl/root)** directory for files that will
give a head start getting a project going.

## DoxyGen Document

For generating documentation from the code using [DoxyGen](https://www.doxygen.nl/) the `doc` subdirectory is to be added. 
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
# Add doxygen project when SfDoxyGen was found.
# On Windows this is only possible when doxygen is installed in Cygwin.
find_package(SfDoxyGen QUIET)
if (SfDoxyGen_FOUND)
	# Get the markdown files in this project directory including the README.md.
	file(GLOB _SourceList RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "*.md" "../*.md")
	# Get all the header files from the application.
	file(GLOB_RECURSE _SourceListTmp RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "../src/*.h" "../src/*.md")
	# Remove unwanted header file(s) ending on 'Private.h'.
	list(FILTER _SourcesListTmp EXCLUDE REGEX ".*Private\\.h$")
	# Append the list with headers.
	list(APPEND _SourceList ${_SourceListTmp})
	# Adds the actual manual target and the last argument is the optional PlantUML jar version to download use.
	Sf_AddManual("${PROJECT_NAME}" "${PROJECT_SOURCE_DIR}" "${PROJECT_SOURCE_DIR}/../bin/man" "${_SourceList}" "v1.2023.0")
endif ()
```

