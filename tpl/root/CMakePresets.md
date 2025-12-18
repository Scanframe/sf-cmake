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

> The [build.py](../build.py) script option `--info` lists all available presets and also all the workflows.

A condition is added to the preset configuration to hide it when not applicable for the host. 

```json
  "condition": {
    "type": "equals",
    "lhs": "${hostSystemName}",
    "rhs": "Linux"
  }
```

## Set an Output Directory for Executables and Dynamic Libraries

In the `configurePresets` of the `CMakePresets.json` or `CMakeUserPresets.json` file the enviroment variables
`SF_EXECUTABLE_DIR` and `SF_LIBRARY_DIR` are used to change the binaries destinations.
They determine `CMAKE_RUNTIME_OUTPUT_DIRECTORY` and `CMAKE_LIBRARY_OUTPUT_DIRECTORY` cache variables.
Also sets the `LD_LIBRARY_PATH` environment variable when the target is compiled from a Docker container
and the `RUNPATH` in the binary is incorrect.

```json
    {
      "name": ".cfg-lnx",
      "inherits": [
        ".lnx-only",
        ".cfg"
      ],
      "hidden": true,
      "displayName": "Debug Linux Template",
      "description": "Debug config Linux template.",
      "environment": {
        "SF_EXECUTABLE_DIR" : "${sourceDir}/bin/lnx64",
        "SF_LIBRARY_DIR" : "$env{SF_EXECUTABLE_DIR}/lib",
        "LD_LIBRARY_PATH": "$env{SF_LIBRARY_DIR}:$penv{LD_LIBRARY_PATH}"
      },
      "cacheVariables": {
        "SF_BUILD_TESTING": {
          "type": "BOOL",
          "value": "ON"
        },
        "SF_COMPILER": {
          "type": "STRING",
          "value": "gnu"
        },
        "CMAKE_RUNTIME_OUTPUT_DIRECTORY": {
          "type": "STRING",
          "value": "$env{SF_EXECUTABLE_DIR}"
        },
        "CMAKE_LIBRARY_OUTPUT_DIRECTORY": {
          "type": "STRING",
          "value": "$env{SF_LIBRARY_DIR}"
        }
      },
      "vendor": {
        "compiler": "gnu"
      }
    }
```
