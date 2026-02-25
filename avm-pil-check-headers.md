---
name: avm-pil-check-headers
description: Check that PIL file includes are all required and avoid indirect/transitive imports.
allowed-tools: Read, Glob, Grep, Edit
---
# [HEADERS_SANITY] — PIL Include Audit

Given the PIL file `$ARGUMENTS`, audit that every `include` directive is required and that the file does not rely on transitive includes.

## Fix mode

If the first word of `$ARGUMENTS` is `fix`, remove it from the arguments and enable **fix mode**. In fix mode, after completing the audit, automatically apply all suggested fixes using the Edit tool. Do not ask for confirmation — just apply them all.

## Procedure

### 1. Read the target PIL file

Read the PIL file specified by `$ARGUMENTS`. Extract:
- **All `include` directives** at the top of the file (lines matching `include "...";`).
- **All cross-namespace references** in the body: any qualified identifier of the form `<namespace>.<column>` (e.g., `range_check.value`, `memory.sel`). Collect the set of referenced foreign namespaces.

### 2. Map namespaces to PIL files

For each foreign namespace referenced in the body, determine which PIL file defines it. Use Grep to search for `namespace <name>;` declarations across `barretenberg/cpp/pil/vm2/**/*.pil`. Build a map: `namespace → PIL filename`.

### 3. Check: every include is required

For each `include` directive in the target file, verify that the included file defines at least one namespace that is referenced in the target file's body.

If an include is **not required** (no namespace from the included file is referenced), flag it:
- **UNUSED INCLUDE**: `include "<file>";` — no references to any namespace defined in `<file>` found in the body.

**Exception**: The file may include a `.pil` file that defines constants or macros used without a namespace prefix. If you suspect this, search the included file for `pol` or `constant` definitions and check if any unqualified identifiers in the target match. Only flag as unused if you're confident nothing from the include is used.

### 4. Check: no missing direct includes (no transitive reliance)

For each foreign namespace referenced in the body, verify that the PIL file defining that namespace is **directly included** by the target file.

If a namespace is used but its defining file is **not directly included**, check whether it might be transitively included (i.e., included by one of the target's direct includes). If so, flag it:
- **TRANSITIVE INCLUDE**: Namespace `<ns>` (defined in `<file>`) is used but not directly included. It is only available transitively via `include "<intermediate>";` → `include "<file>";`. Add a direct `include "<file>";`.

### 5. Check: no duplicate includes

Flag any file that appears in more than one `include` directive:
- **DUPLICATE INCLUDE**: `include "<file>";` appears multiple times.

## Output format

```
## File: <path to PIL file>

### Includes
| # | Include | Status |
|---|---------|--------|
| 1 | `<file>` | OK / UNUSED / DUPLICATE |
| ... | ... | ... |

### Foreign namespace references
| Namespace | Defining PIL file | Directly included? | Status |
|-----------|-------------------|-------------------|--------|
| `<ns>` | `<file>` | YES / NO (transitive via `<X>`) | OK / TRANSITIVE INCLUDE |
| ... | ... | ... | ... |

### Issues
- (list each issue, or "No issues found.")
```

$ARGUMENTS
