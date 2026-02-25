---
name: avm-check-completeness
description: Verify that every PIL relation is satisfied by all tracegen codepaths — no codepath can produce a row violating any constraint.
allowed-tools: Read, Glob, Grep, Task
---
# [COMPLETENESS] — PIL/Tracegen Completeness Audit

Given the file(s) `$ARGUMENTS`, verify that every relation (constraint) in the PIL file is an invariant of the tracegen builder — i.e., for any codepath through `process()`, every constraint is satisfied.

## Procedure

### 1. Identify the files

If given a `.pil` file at `barretenberg/cpp/pil/vm2/<name>.pil`, locate:
- **PIL file**: The relation constraints.
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.cpp`
- **Event definition**: `barretenberg/cpp/src/barretenberg/vm2/simulation/events/<name>_event.hpp`

Use Glob if the naming doesn't match exactly.

### 2. Enumerate all relations in the PIL

Read the PIL file. For each constraint, extract:
- **Named constraints** (tagged `#[NAME]`): e.g., `#[GT_RESULT]`, `#[GT_RANGE]`.
- **Unnamed constraints**: boolean checks, selector implications, etc.
- **Interaction constraints**: lookups (`in`) and permutations (`is`).

Group them into:
- **Always-active constraints**: Not gated by any selector (must hold on every row).
- **Conditionally-active constraints**: Gated by `sel * (...)  = 0` or similar (must hold when selector is 1).
- **Skippable rows**: If `#[skippable_if] sel = 0`, then constraints only need to hold when `sel = 1`.

### 3. Enumerate all tracegen codepaths

Read the tracegen `process()` method. Identify every distinct codepath that produces a trace row:
- **Unconditional paths**: Code that runs for every event.
- **Conditional branches**: `if/else`, `switch`, ternary operators that produce different column assignments depending on event properties (error codes, flags, types, etc.).
- **Inactive rows**: Rows where `sel = 0` (either explicit or implicit due to unset columns defaulting to 0).

For each codepath, record the complete set of column assignments.

### 4. For each relation, verify all codepaths satisfy it

For each constraint in the PIL:

#### a. Polynomial identity constraints (`expr = 0`)
- Substitute the column values from each codepath into the expression.
- Verify the expression evaluates to 0.
- Pay special attention to:
  - **Conditional assignments**: If a column is set differently depending on a branch, check both branches.
  - **Unset columns**: Columns not explicitly set default to 0. Verify the constraint still holds with 0.
  - **Field arithmetic**: Subtraction in the field wraps; ensure the tracegen computes the same field value as the PIL expression.

#### b. Boolean constraints (`col * (1 - col) = 0`)
- Verify the column is always assigned 0 or 1 on active rows.
- Covered in more detail by the [TYPE/RANGE] audit, but flag obvious violations here too.

#### c. Selector implication constraints (`(sum of sub-selectors) * (1 - sel) = 0`)
- Verify that whenever any sub-selector is set to 1 in tracegen, `sel` is also set to 1.

#### d. Interaction constraints (lookups/permutations)
- Verify that the source selector is set to 1 if and only if the tuple columns are populated with valid values.
- Verify that the destination event is emitted in simulation on the same codepath (covered in more detail by [INTERACTION_SRC], but flag obvious mismatches).

### 5. Check edge cases

#### a. Empty events / zero rows
- If the event container is empty, no rows are written. Verify this is safe (no constraints require at least one active row).

#### b. Error codepaths
- If the event has error variants, check that error rows still satisfy all constraints. Common pitfall: an error row sets `sel = 1` but leaves some columns unpopulated, violating a constraint that assumes all columns are set.

#### c. Boundary values
- Check codepaths with boundary inputs: 0, 1, max value (2^128 - 1), equal inputs (a == b).
- For `a == b` in a GT gadget: `abs_diff = b - a = 0`, `res = 0`. Verify GT_RESULT holds: `sel * (A_LTE_B - abs_diff) = sel * (0 - 0) = 0`. OK.
- For `a = b + 1` (minimal GT): `abs_diff = a - b - 1 = 0`, `res = 1`. Verify GT_RESULT holds.

### 6. Summarize coverage

For each constraint, report whether all codepaths satisfy it.

## Output format

```
## File: <PIL path>

### Relations
| Relation | Line(s) | Active when | Codepaths checked | Status |
|----------|---------|-------------|-------------------|--------|
| `#[NAME]` or description | X | sel = 1 / always | all / list | OK / VIOLATION on <codepath> |

### Codepaths
| # | Condition | Columns set | Status |
|---|-----------|-------------|--------|
| 1 | <condition> | { col1=val, col2=val, ... } | All relations satisfied / VIOLATION in <relation> |

### Edge cases
| Case | Codepath | Status |
|------|---------|--------|
| Empty events | N/A | OK / ISSUE |
| a == b | #1 (res=0) | OK / ISSUE |
| a = b + 1 | #2 (res=1) | OK / ISSUE |
| ... | ... | ... |

### Issues
- (list each issue with relation, codepath, and explanation, or "No issues found.")

### Summary
- X relations checked
- X codepaths analyzed
- X edge cases verified
- X issues found
```

$ARGUMENTS
