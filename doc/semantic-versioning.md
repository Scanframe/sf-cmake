# Semantic Versioning {#semantic-versioning}
## Conventional Commits Auto Version Bumping

To automatically bump the version using conventional commits, the [build.py](../bin/build.py) script provides 
a subcommand for it.


The script analyzes the commit messages up-to a certain commit and computes a new semantic version.
At the same time generates release-notes for this version.

```bash
# List all 
./build.py version info
```

## Commit Message Format

The Conventional Commit format is based on [ConventionalCommits.Orgte ](https://www.conventionalcommits.org/en/v1.0.0/)
and is as follows where the blank lines are separators between description, body and footer.

```
<header>

[optional body]

[optional footer]
```

### A Full Example

Below is a full example of a commit message where the body has multiple paragraphs and the footers are identifiable.

```
feat(compiler): add strict null pointer checking optimizations

The optimizer framework currently treats all pointer arithmetic as potentially 
null-unsafe, forcing redundant safety branches into the generated assembly. 
This heavily degrades pipeline execution speeds on tight loop structures.

Overhaul the pointer tracking system to identify statically proven non-null 
references. This allows the compiler to strip unnecessary branch instructions 
during the final code emission phase.

Fixes: #1420
Signed-off-by: Jane Doe <jane.doe@example.com>
Co-authored-by: Alex Smith <alex.smith@example.com>
Co-authored-by: Bob Jones <bob.jones@example.com>
Reviewed-by: Sarah Connor <sarah.connor@example.com>
See-also: https://github.com
```

### Header

The **header** and the first mandatory line of the commit message has a format as:

```
<type>(<scope>)!: <short summary>
│       │      │      │
│       │      │      └─⫸ Summary in an imperative mood.
│       │      │      
│       │      └─⫸ Optional exclamation mark '!' indicating a breaking change.
│       │
│       └─⫸ Commit Scope: common|compiler|config|cmake|changelog|docs-infra|pack|iface|etc...
│
└─⫸ Commit Type: build|ci|chore|docs|feat|fix|perf|refactor|style|test|revert
```

The commit message should be written in an imperative mood, which means it should describe 
the action that the commit will perform, rather than the action that has been performed. 
For example, "Fix bug" rather than "Fixed bug".

### The Body (Optional)

The body provides a detailed description of the change.
The Context: You may use past tense to describe the historical problem or the old state of the codebase.
The Solution: Use the imperative mood when describing the specific actions the new code executes to resolve the issue.

### The Footer(s) (Optional)

```
<token>: <description/value>
 │        │
 │        └─⫸ Description or a value. 
 │      
 └─⫸ Token without spaces.
```

The footer is reserved for tracking issues (e.g., Fixes: #123) or providing notes on changes.

```
Fixes: #1420
Signed-off-by: Jane Doe <jane.doe@example.com>
Co-authored-by: Alex Smith <alex.smith@example.com>
Co-authored-by: Bob Jones <bob.jones@example.com>
Reviewed-by: Sarah Connor <sarah.connor@example.com>
See-also: https://github.com
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

