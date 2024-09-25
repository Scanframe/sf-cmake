# Semantic Versioning

<!-- TOC -->
* [Semantic Versioning](#semantic-versioning)
  * [Conventional Commits Auto Version Bumping](#conventional-commits-auto-version-bumping)
  * [Commit Message Format](#commit-message-format)
  * [Type of Commits](#type-of-commits)
  * [Examples of Message Headers](#examples-of-message-headers)
  * [Examples of Full Messages](#examples-of-full-messages)
<!-- TOC -->

## Conventional Commits Auto Version Bumping

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

## Commit Message Format

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

## Type of Commits

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

## Examples of Message Headers

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

## Examples of Full Messages

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
