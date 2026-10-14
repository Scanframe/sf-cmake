# Code Review {#code-review}

## General

The result of a review is added in the [`REVIEW.md`](./REVIEW.md) file in the designated chapter.
Each remark gets its own numbered paragraph and a link to the file (s) in question with a line numer behind it.
The remark should be written in an imperative mood, which means it should describe the action that is to be performed.
For example, "Fix bug" rather than "Fixed bug".

> Note: When JetBrains Junie is used in the console and issues are listed,
> create clickable links to the exact location in the file.

## Full Review

The name format of the chapter is `👀 <YYYY-MM-DDTHH:MM> General: <reviewer-name>`.

The term 'Full Review' means, all files belonging to the main repository but not its submodules.
The submodules are allowed to be viewed but not reviewed or only when there are severe issues
with it impacting the main repository.

The document has per issue 3 sections of which 2 are created by the reviewer and the 3rd is created by the author.

- 🔎 Finding or Observation (By reviewer)
- 💡 Remedy or Fix (By reviewer and optional)
- ✅ Remediation (By author)

The file `../../../.gitignore` is a guide to what is to be included in the review and what is not.

## Detail or Partial Review

The name format of the chapter is `👀 <YYYY-MM-DDTHH:MM> Detail: <reviewer-name>`.
A detail review is a review of a specific file, directory or files within the main repository.

## Review Doc Example

```markdown

# Review Remarks

---

## 👀 2026-10-14T13:08 General: My-name

### ⚠️ 1: CMake version limit

#### 🔎 Finding

Due to passing arguments for the applications in `ctest` using the command line version **4.2** or higher is required.

#### 💡 Remedy/Fix

Limit the lower CMake version in the range in file [./CMakeLists.txt](../../../doc/CMakeLists.txt)(:1) to version
**4.2**.

### ⚠️ 2: Formatting Checking

#### 🔎 Observation

Formatting is not according to the current company standard.

#### 💡 Remedy

Create a format check job in the GitLab-CI file [main.gitlab-ci.yml](gitlab-ci/main.gitlab-ci.yml).

Add a bash script link to [check-format.sh](cmake/lib/bin/check-format.sh) and a Git pre-commit hook.

#### ✅ Remediation

Change the formatting to match the current company standard using the `checkformat` script.

## 👀 2026-10-14T13:08 Detail: Your-name

### ⚠️ 1: Comment Lines

#### Observation

File [main-piper.cpp](src/tests/app/qt/cli/main-piper.cpp) is missing comments between the code-lines
explaining the code.

#### 💡 Remedy

Create comment lines of substance which is about 25% of all lines.

#### ✅ Remediation

Add comment lines to the file [main-piper.cpp](src/tests/app/qt/cli/main-piper.cpp) to match the current company
standard.
```
