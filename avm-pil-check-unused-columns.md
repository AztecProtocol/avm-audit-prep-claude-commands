---
name: avm-pil-check-unused-columns
description: Check that every declared committed column appears in at least one relation or interaction constraint.
allowed-tools: Read, Glob, Grep
---
# [PIL_SANITY_1] — Unused Column Audit

Given the PIL file `$ARGUMENTS`, verify that every committed column (`pol commit`) is referenced in at least one relation or interaction constraint.

## Procedure

### 1. Read the PIL file

Read the target PIL file. Extract:
- **All committed columns**: Every `pol commit <name>;` declaration. Record the column name and line number.
- **All constraints**: Every polynomial identity (`expr = 0`), boolean check, lookup (`in`), and permutation (`is`).
- **All intermediate expressions**: Every `pol <NAME> = ...;` (non-committed).

### 2. For each committed column, check usage

For each committed column `col`, search the PIL file body for references to `col` outside its own declaration line. A column is "used" if it appears in any of:

- A polynomial identity constraint (e.g., `sel * (col - expr) = 0`).
- A boolean constraint (e.g., `col * (1 - col) = 0`).
- An intermediate expression that is itself used in a constraint (e.g., `pol X = col + 1;` where `X` appears in a constraint).
- A lookup or permutation tuple (source or destination side).
- A selector position in a lookup or permutation.

A column is **NOT used** if it only appears in:
- Its own `pol commit` declaration.
- A comment.
- Another column's constant-support constraint that only ties it to a constant (e.g., `sel * (constants.FOO - col) = 0`) without `col` being referenced anywhere else.

**Special case — constant-support columns**: Columns annotated with `// Lookup constant support` exist solely to hold a constant value for use in a lookup tuple. These are used if they appear in a lookup tuple. If they only appear in their constant-binding constraint but NOT in any lookup, flag them.

### 3. Check cross-file usage

Some columns may be referenced by other PIL files (as destination columns in lookups/permutations). Search for references to `<namespace>.<col>` across all PIL files in `barretenberg/cpp/pil/vm2/`:

```
<namespace>.<column_name>
```

If the column is referenced in another PIL file, it is used (as a lookup/permutation destination).

### 4. Report

## Output format

```
## File: <PIL path>

### Committed columns
| # | Column | Line | Used in constraint? | Used in interaction? | Used cross-file? | Status |
|---|--------|------|--------------------|--------------------|-----------------|--------|
| 1 | `col` | X | YES (line Y) / NO | YES (#[NAME]) / NO | YES (<file>) / NO | OK / UNUSED |

### Unused columns
- `col` (line X): Not referenced in any constraint, interaction, or cross-file lookup.

### Summary
- X committed columns declared
- X used in constraints or interactions
- X unused (list each)
```

$ARGUMENTS
