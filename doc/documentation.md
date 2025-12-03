# Documentation {#documentation}

## Compiling

The documentation is compiled by the  '**document**' target.

From the command line this is:

```shell
 ./build.sh -b gnu-debug -n document
```

## Convention

This document outlines the conventions for writing project documentation in Markdown files within the source tree.
It is intended to ensure consistency, clarity, and maintainability across all documentation.

### Page/File Reference

A page is referenced by the file's basename, omitting the `.md` extension.  
A custom reference name and title can be specified using Doxygen's `@page` tag at the beginning of the file,
for example:

```
@page my-file My File
```

Alternatively, you can use `{#my-file}` in the heading, which improves Markdown readability
when viewed on **GitHub** or **GitLab**:

```
# My File {#my-file}
```

## Subpages & Structure

To provide an entry point to the documentation and help organize content, create an `index.md` file in the root
of a library or module within the documentation section of the source tree.
This file serves as an organizer of the documentation structure for that part of the codebase.
Use the `@subpage` tag within index.md to reference and link to subpages.
This creates a navigable structure in the generated documentation.  
For example:

```
@page my-index My Library

* @subpage my-lib-manual
* @subpage my-lib-module1
* @subpage my-lib-module2
```

Each subpage should define its own `@page` tag to enable proper cross-referencing.
