# Agent Instructions: C++ Project

## Overview

This is a modern cross-platform build environment test project with CMake for Docker, Wine, native Linux and native
Windows.  
It is used to test the build environment for C++ projects. Qt6 only uses up to C++17. License: GNU General Public
License v3.0 (GPL-3.0).

## Commands

All targets are built from the command line using the single command `../../../../build.py`. When run without arguments,
it will show the help to build using a given toolchain and optional target.

### Build the Project

To build the complete 'Debug' project.

```bash
./build.py --build gnu-debug
# Or only a specific target.
./build.py --build gnu-debug --target t_devops-shared-test-catch 
```

### Running Unit Tests

The command to run CTest on the project executing only tests using a regex pattern.

```bash
./build.py --test gnu-debug --test-regex "catch$"
# Short version. 
./build.py -t gnu-debug -R "catch$"
```

The command combining a build and test of a specific target using a regex pattern.

```bash
./build.py --build --test gnu-debug --target t_devops-shared-test-catch --test-regex "catch$"
# Short version. 
./build.py -bt gnu-debug -n t_devops-shared-test-catch -R "catch$"
```

The command to get a project overview including the names of the tests available.

```bash
./build.py --info gnu-debug
./build.py -i gnu-debug
```

## Boundaries

Follow these operational safety guardrails:

- **Always do**: Use smart pointers (`std::unique_ptr`, `std::shared_ptr`) for general resource management.
- **Always do**: Adhere strictly to RAII practices.
- **Never do**: Do not bypass explicit `noexcept` specifications on move constructors.
- **Qt Ownership**: For `QObject` derived classes, prefer parent-child ownership over smart pointers where applicable.
- **Logging**: Use `qCInfo`, `qCDebug`, `qCWarning`, `qCCritical` with the centralized `logCategory()` defined in
  `logging.h` when used.

## Code Style

### Clang Format

Match the constraints configured and set in the file [`../../../../.clang-format`](../../../../.clang-format).

### Standards & Patterns

- **Header Guards**: Always use `#pragma once`.
- **Doxygen**: Use Doxygen-style comments in header files only.
- **Bracing**: Use Allman style (braces on new lines).
- **Indentation**: Use tabs (size 2).
- **Qt Signals/Slots**: Use the modern function-pointer-based `connect()` syntax.
- **Utilities**: Leverage `helpers.h` for Qt-specific utility functions (e.g., `enumToString`).

### Naming Conventions

Follow the described code conventions from document [`doc/code-conventions.md`](doc/code-conventions.md).  
Key points:

- **Classes/Structs**: PascalCase.
- **Methods**: camelCase.
- **Members**: _camelCase (leading underscore).
- **Arguments/Variables**: lower_snake_case.

## Testing Strategy

- **Rule**: Both testing frameworks **Catch2** and **GoogleTest** are the only allowed frameworks and preferably in that
  order.
- **Rule**: Core, headless and backend libraries have a `tests/` directory.

## Commit Style

### Message

Conventional commits are preferred as described in
file ['cmake/lib/doc/semantic-versioning.md'](../../doc/semantic-versioning.md). Files not part of the repository should
be excluded from commit messages, which means ignore untracked files.  
Use bullet points for commit messages to make them more readable and concise.  
Use backticks when referencing a path in one of the bullet points.

### AI Chat Response

When assembling a commit message, include a separate "Locations" section in the AI response.  
For every commit-message bullet, list the relevant source location(s) as clickable Markdown 
links using project relative file paths when possible and optional line numbers.  
These locations are supporting context and should not be
included in the commit message itself.

