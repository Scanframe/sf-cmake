# C++/Qt CMake Project Template

## Introduction

This repository is a cross-platform C++ project skeleton built with CMake. It includes examples for a command-line
application, an optional Qt GUI application, a reusable shared library, unit tests, documentation, and packaging.

The project is designed to build on Linux and Windows and can also use Docker and Wine for cross-compilation and Windows
execution. The `build.py` helper and the CMake presets provide one consistent interface for local development and CI
builds.

The example source can be replaced with application code while keeping the build infrastructure and directory layout.

## Quick start

The commands below assume that the project contains `build.py` in its root directory.

### Linux

Install the native GNU build tools and create the project structure:

```shell
./build.py install --required lnx
./build.py install --project
```

Build and test the Debug configuration:

```shell
./build.py --build --test gnu-debug
```

To see the available presets, targets, and tests:

```shell
./build.py --info gnu-debug
```

### Windows

Install the required Windows tools, initialize the project, and choose either MinGW or MSVC:

```shell
build.py install --required win
build.py install --project
build.py --build --test mingw-debug
# Or using MSVC
build.py --build --test msvc-debug
```

Use `msvc-debug` instead when building with Microsoft Visual C++.

### Docker and Wine

The same build helper can run commands in a prepared Docker environment:

```shell
./build.py docker -- --build --test gnu-debug
./build.py docker -- --build --test gw-debug
```

For Windows builds and execution through Wine:

```shell
./build.py docker -- wine -- --build --test msvc-debug
```

See [`cmake/lib/doc/build.md`](cmake/lib/doc/build.md) for all command options and supported environments.

## Toolchains and presets

The available preset families are:

| Preset family | Target         | Typical environment                              |
|---------------|----------------|--------------------------------------------------|
| `gnu-*`       | Linux          | Native Linux or Docker                           |
| `ga-*`        | Linux aarch64  | Linux cross-compilation or Docker                |
| `gw-*`        | Windows x86_64 | Linux MinGW cross-compilation, usually with Wine |
| `mingw-*`     | Windows x86_64 | Native Windows MinGW or Wine                     |
| `msvc-*`      | Windows x86_64 | Native Windows MSVC or Wine                      |

Each family normally has `debug`, `release`, and other configurations defined in `CMakePresets.json`. Keep personal
overrides in `CMakeUserPresets.json`; do not add machine-specific settings to the version-controlled presets.

The helper also supports the individual CMake stages:

```shell
# Configure and generate build files.
./build.py --make gnu-debug

# Build without running tests.
./build.py --build-only gnu-debug

# Run tests, optionally selecting tests by name.
./build.py --test gnu-debug
./build.py --test gnu-debug --test-regex "catch$"

# Create installable packages.
./build.py --package gnu-release

# Run a complete configured workflow.
./build.py --workflow gnu-debug
```

## Project contents

```text
project-root/
├── CMakeLists.txt          Top-level CMake project
├── CMakePresets.json       Shared configure/build/test/package presets
├── CMakeUserPresets.json   Optional local presets
├── build.py                Build and environment helper
├── build.ini               Nested Docker/Wine and runtime settings
├── cmake/                  CMake support files and packaging configuration
├── src/
│   ├── cli/                Command-line application example
│   ├── hwl/                Reusable hello-world library example
│   ├── qt/                 Optional Qt GUI application example
│   └── tests/              Catch2 and GoogleTest examples
├── doc/                    Doxygen documentation project
└── bin/                    Build output, reports, and packages
```

The example library is exposed through the `Sf::Hello` target. The CLI and Qt targets link to it, which demonstrates how
application targets can share common code. Replace the example targets and sources as the project grows.

## Optional features

### Qt

Qt support is controlled by the `SF_BUILD_QT` CMake cache variable. Presets that enable Qt locate the configured Qt
version through the CMake support library and can download it when it is not already available.

```shell
./build.py --build gnu-debug
```

The Qt example uses Qt Widgets and is only added when Qt support is enabled. Qt is currently configured for C++17 in the
template.

### Unit tests

Testing is controlled by `SF_BUILD_TESTING`. The template contains both Catch2 and GoogleTest examples. Build and run
the tests with:

```shell
./build.py --build --test gnu-debug
```

Use `--test-regex` to run a subset of tests.

### Documentation

When a `doc` directory is present, it is added to the CMake project. Build the Doxygen target with:

```shell
./build.py --build gnu-debug --target document
```

The generated documentation is placed below `bin/man` when the corresponding preset is configured.

### Formatting

The template includes `.clang-format` and a pre-commit hook template. Install or update the hook as appropriate for the
project, then run the project’s format-check script before committing changes.

### Packaging

CPack configuration is included for creating platform packages. Package output is written below `bin/pkg`:

```shell
./build.py --package gnu-release
```

## Building and running an executable

The presets select executable output directories.  
Use the `run` command to apply the configured runtime environment, including library paths and Qt paths:

```shell
./build.py run --preset gnu-debug -- ./hello-world.bin
./build.py run --preset gnu-debug -- ./hello-world-qt.bin
```

The exact executable suffix depends on the target platform and compiler. Use `./build.py --info <preset>` to inspect the
generated targets and output locations.

## CI/CD

The `gitlab-ci` directory contains reusable GitLab CI pipeline fragments for configuring, building, testing, coverage,
and packaging. Copy the relevant files into the project’s `.gitlab` directory and adapt repository, credential, and
deployment variables for the target infrastructure.

See [`gitlab-ci/README.md`](gitlab-ci/README.md) for the required GitLab variables and pipeline configuration.

## Further reading

- [`cmake/lib/doc/build.md`](cmake/lib/doc/build.md): complete `build.py` command reference.
- [`CMakePresets.md`](cmake/lib/tpl/root/CMakePresets.md): configure, build, test, package, and workflow presets.
- [`gitlab-ci/README.md`](cmake/lib/tpl/root/gitlab-ci/README.md): GitLab CI variables and deployment setup.
- [`cmake/lib/README.md`](cmake/lib/README.md): CMake library features, toolchains, coverage, and packaging details.

## License

The generated project should declare the license selected by its maintainers. Replace this section with the project’s
actual license and copyright information.
