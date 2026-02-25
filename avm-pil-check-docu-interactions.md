---
name: avm-pil-check-docu-interactions
description: Audit PIL interaction documentation — usage patterns, tuple completeness, selector choices, and input/output clarity.
allowed-tools: Read, Glob, Grep, Task, Edit
---
# [DOCU_INTERACTIONS] — PIL Interaction Documentation Audit

Given the PIL file `$ARGUMENTS`, audit the documentation of every interaction (lookup/permutation) where this component appears as a destination.

## Fix mode

If the first word of `$ARGUMENTS` is `fix`, remove it from the arguments and enable **fix mode**. In fix mode, after completing the audit, automatically apply all suggested fixes using the Edit tool. Do not ask for confirmation — just apply them all.

## Procedure

### 1. Find all callers

Search all PIL files in `barretenberg/cpp/pil/vm2/` for lookups or permutations that reference this namespace as the destination. For a namespace `<ns>`, search for patterns like:
- `in <ns>.sel_XXX { <ns>.col1, <ns>.col2, ... }`
- `is <ns>.sel_XXX { <ns>.col1, <ns>.col2, ... }`

Collect every interaction where this file's namespace is on the right-hand side (destination).

### 2. Check: usage documentation in header

The PIL header should document each distinct usage pattern. A "usage pattern" is a distinct way callers look up into this component — different selectors, different subsets of columns, or different semantics.

For each usage pattern, verify the documentation includes:

#### a. Complete tuple specification
- **All tuple elements must be listed** — forgetting a field is a common footgun.
- Cross-reference the documented tuple against actual lookup constraints in caller PIL files.
- Flag if any element is missing from the documentation.

#### b. Selector documentation
- **Which selector to use**: Document the sub-selector column (e.g., `sel_alu`, `sel_gt`).
- **If multiple selectors are available**: Explain when to use which one and what the differences are.
- **Sub-selector assignment**: Clarify whether the caller or the lookup mechanism sets the sub-selector.

#### c. Input/output distinction
- For each column in the tuple, document whether it is an **input** (caller provides the value, gadget checks it) or an **output** (gadget computes the value, caller reads it).
- If the distinction is unclear for some columns (e.g., bidirectional constraints), document this explicitly.

### 3. Check: self-documenting usage block

The PIL file should include a USAGE section (typically in the header comment) showing the lookup pattern callers should follow. Example:
```
USAGE:
    caller_sel { a, b, result }
    in
    gadget.sel_XXX { gadget.col_a, gadget.col_b, gadget.col_res };
```

Verify this block exists and is accurate.

### 4. Check: interactions where this component is the source

For each interaction defined in this PIL file (where this namespace is on the left-hand side / source), verify:
- The destination usage is documented in the destination's PIL file.
- The tuple matches what the destination expects.

## Output format

```
## File: <PIL path>

### As destination (other files look up into this namespace)
| Caller PIL | Interaction name | Selector | Tuple | Documented? | Status |
|-----------|-----------------|----------|-------|-------------|--------|
| `<file>` | `<name>` | `sel_XXX` | `{ col1, col2, ... }` | YES / NO | OK / ISSUE |

### Tuple completeness
| Interaction | Expected tuple | Documented tuple | Status |
|------------|---------------|-----------------|--------|
| `<name>` | `{ a, b, c }` | `{ a, b }` | MISSING `c` / OK |

### Input/output clarity
| Interaction | Column | Role | Documented? | Status |
|------------|--------|------|-------------|--------|
| `<name>` | `col` | input / output / unclear | YES / NO | OK / MISSING |

### Selector documentation
| Selector | When to use | Documented? | Status |
|----------|------------|-------------|--------|
| `sel_XXX` | <condition> | YES / NO | OK / MISSING |

### Issues
- (list each issue, or "No issues found.")
```

$ARGUMENTS
