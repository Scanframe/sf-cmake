# Agent Instructions: C/C++ Project

## Overview

This is a modern cross-platform build environment test project with CMake for Docker, Wine, native
Linux, and native
Windows.
It is used to test the build environment for C++ projects. Qt6 only uses up to C++17. License: GNU
General Public
License v3.0 (GPL-3.0).

## Response Rules

- Do not make assumptions.
- When there is doubt, ask for clarification.
- Base decisions on facts, so no hallucinations.
- The user is the final authority on when a plan is complete.
  This means a plan can be presented but must always be able to be discussed.

## Commands

The command to run CTest on the project executing only tests using a regex pattern.

```bash
./build.py --test gnu-debug --test-regex "catch$"
# Short version.
./build.py -t gnu-debug -R "catch$"
```

The command combining a build and test of a specific target using a regex pattern.

```bash
./build.py --build --test gnu-debug --target devops-shared-test-catch --test-regex "catch$"
# Short version.
./build.py -bt gnu-debug -n devops-shared-test-catch -R "catch$"
```

The command to get a project overview including the names of the tests available.

```bash
./build.py --info gnu-debug
./build.py -i gnu-debug
```

## Boundaries

Follow these operational safety guardrails:

- **Always do**: Use smart pointers (`std::unique_ptr`, `std::shared_ptr`) for general resource
  management.
- **Always do**: Adhere strictly to RAII practices.
- **Never do**: Do not bypass explicit `noexcept` specifications on move constructors.
- **Qt Ownership**: For `QObject` derived classes, prefer parent-child ownership over smart pointers
  where applicable.
- **Logging**: Use `qCInfo`, `qCDebug`, `qCWarning`, `qCCritical` with the centralized
  `logCategory()` defined in
  `logging.h` when used.

## C++ Code Style

### Clang Format

Match the constraints configured and set in the file [
`../../../../.clang-format`](../../../../.clang-format).

### Standards & Patterns

- **Header Guards**: Always use `#pragma once`.
- **Doxygen**: Use Doxygen-style comments in header files only.
- **Bracing**: Use Allman style (braces on new lines).
- **Indentation**: Use tabs (size 2).
- **Qt Signals/Slots**: Use the modern function-pointer-based `connect()` syntax.
- **Utilities**: Leverage `helpers.h` for Qt-specific utility functions (e.g., `enumToString`).

### Naming Conventions

Follow the described code conventions from document [
`doc/code-conventions.md`](doc/code-conventions.md).
Key points:

- **Classes/Structs**: PascalCase.
- **Methods**: camelCase.
- **Private/Protected Members**: _camelCase.
- **Public Members**: camelCase.
- **Arguments/Variables**: lower_snake_case.

## Testing Strategy

- **Rule**: Both testing frameworks **Catch2** and **GoogleTest** are the only allowed
  frameworks and preferably in that order.
- **Rule**: Core, headless, and backend libraries have a `tests/` directory.

## Commit Style

### Message

Conventional commits are preferred as described in
file [`cmake/lib/doc/semantic-versioning.md`](../../doc/semantic-versioning.md). Files not part of
the repository should
be excluded from commit messages, which means ignore untracked files.
Use bullet points for commit messages to make them more readable and concise.
Use backticks when referencing a path in one of the bullet points.

### Commit Message & AI Chat Response

When the user requests a commit message, the following steps are **mandatory** and
**non-negotiable**.

**Failure to follow these instructions exactly will result in incorrect release notes generation.**

**WARNING:** Do not place the commit message directly in the chat instead of creating the file.
Do not provide only the chat response without creating `COMMITMSG.md`. Both actions are required.

1. **Create `COMMITMSG.md` file** — You **must** use the file creation tool to write a file named
   `COMMITMSG.md` in the project root directory. This file contains **only the commit message text**
   and nothing else. The user applies it with `git commit -F COMMITMSG.md`. **Do not skip this step
   under any circumstances.**
   Placing the commit message in the chat response is not a substitute for creating the file.

2. **Format the commit message correctly** — The message **must** follow
   the example in [semantic-versioning.md](../../doc/semantic-versioning.md).
   This means using Markdown bullet points (unordered lists) and backticks for file paths.
   The `build.py version` command parses this file to generate release notes automatically.
   **Deviation from this format breaks the release notes pipeline.**

3. **List affected file locations in a separate Markdown file named `COMMITLST.md`.  
   It contains the same information as file `COMMITMSG.md` adding the affected location under
   each item. Use the Markdown simple link format `Filepath#Line` which the IDE recognizes as a
   clickable navigation link (e.g. `[CMakePresets.json:174](CMakePresets.json#174)`).
   Use project-relative paths. **Line numbers must match the actual file exactly** — count every
   line including empty lines. Do not skip any lines when determining the line number. **Do not omit
   this step.** The chat response is incomplete without the file locations. To prevent too many file
   links, each link must at least be 10 lines apart from each other.

**Remember:** All three steps above are mandatory. Creating `COMMITMSG.md` is not optional.
Providing the file links in the chat response is not optional. Both must be done.

## Review of Code

For reviewing look at
document [reviewer-doc.md](cmake/lib/doc/reviewer-doc.md "Convention for reviewing documentation.")