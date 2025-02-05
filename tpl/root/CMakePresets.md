# CMAke Presets

## Introduction

Most IDE's can import this JSON-file in their projects to build the project for different purposes (type) like Debug and Release.
The [CMake manual](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html) has more on this.

There are 2 files having presets:
* `CMakePresets.json`
* `CMakeUserPresets.json`

The `CMakePresets` contains the actual presets part of the repository and used in pipeline.

The `CMakeUserPresets.json` is not version controlled or stored. 
It used by a developer to fumble around with locally where it can use 
configurations and build presets from within `CMakePresets.json`.

## CMake Steps and Workflow

> This document is based on CMake version 3.30 having the "Workflow" option using preset json-file version **6**.

CMake, CTest, CPack has the steps:
1) Configure
2) Build
3) Test
4) Pack

All the different steps can be combined in a workflow configurable in [CMakePresets.json](CMakePresets.json) as well.

To view these individual steps which are:

```bash
# List configuration presets.
cmake --list-presets
# List build presets.
cmake --build --list-presets
# List testing presets.
ctest --list-presets
# List packaging presets.
cpack --list-presets
```  

> The [build.sh](../build.sh) script option `--info` lists all available presets and also all the workflows.

To limit a preset for a host a condition is added and listing and availability of a preset depends on it. 

```json
  ...
  "condition": {
    "type": "equals",
    "lhs": "${hostSystemName}",
    "rhs": "Linux"
  }
  ...
```

## Use a Different Output Directory

To use a different output directory for a user-preset e.g. 

The CMake cache variable `SF_OUTPUT_DIR_SUFFIX` is used for that in the `configurePresets` section of 
the `CMakePresets.json` or `CMakeUserPresets.json` file.  

When running a test using `ctest` which calls an intermediate shell script also the environment 
variable named `SF_OUTPUT_DIR_SUFFIX` has to be set. This appends the directory name with that value.

When running **CTest** from **CLion** add the environment variable `SF_OUTPUT_DIR_SUFFIX` to 
the designated **Run/Debug configuration**. 
