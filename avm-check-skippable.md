---
name: avm-check-skippable
description: Verify the PIL skippable condition is correct and that tracegen complies — all columns in non-nullified sub-relations must be zero when skippable fires.
allowed-tools: Read, Glob, Grep, Task
---
# [SKIPPABLE] — Skippable Condition Audit

Given the file(s) `$ARGUMENTS`, verify that the `#[skippable_if]` condition is correct and that tracegen complies.

## Background

`#[skippable_if]` is a **per-row prover optimization**. When the condition evaluates to zero on a row, the prover skips accumulating all sub-relations for that row during sumcheck. This is NOT enforced during verification — it is purely a completeness concern.

**Key invariant**: When the skippable condition holds (e.g., `sel = 0`), every sub-relation must evaluate to zero — not just "be satisfiable," but actually evaluate to the zero polynomial. This is because sumcheck merges pairs of rows using a random challenge: `merged = (1-α)*row_i + α*row_{i+1}`. If a column is non-zero on a skipped row, its merged value becomes random, and a sub-relation that is "satisfied" (e.g., `b*(1-b)=0` with `b=1`) will evaluate to non-zero after merging (e.g., `b_merged*(1-b_merged) ≠ 0`).

**Consequence**: On rows where skippable fires, every column appearing in any sub-relation must be zero (or the sub-relation must be algebraically nullified by the skippable column itself, e.g., `sel * expr = 0` is nullified when `sel = 0`).

## Procedure

### 1. Identify the files

If given a `.pil` file at `barretenberg/cpp/pil/vm2/<name>.pil`, locate:
- **PIL file**: The `#[skippable_if]` condition and all constraints.
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.cpp`
- **Generated relation**: `barretenberg/cpp/src/barretenberg/vm2/generated/relations/<name>.hpp` — verify the generated `skip()` method matches the PIL condition.

Use Glob if the naming doesn't match exactly.

### 2. Extract the skippable condition

Read the PIL file and find the `#[skippable_if]` directive. Common patterns:
- **Simple**: `sel = 0` — skip when the main selector is zero.
- **Compound**: `sel + last = 0` — skip when both columns are zero.
- **Cross-file**: The skippable column may be defined in another PIL file sharing the same namespace.

Verify the generated `skip()` method in the relation `.hpp` matches the PIL condition.

### 3. Classify every sub-relation by nullification

For each constraint in the PIL, determine whether it is **algebraically nullified** by the skippable condition:

- **Nullified**: The constraint is of the form `S * expr = 0` where `S` is the skippable column (or a column that is zero whenever the skippable condition holds). When skippable fires, `S = 0`, so the entire expression is zero regardless of other column values. **Safe.**

- **Self-nullifying**: The constraint is of the form `col * (1 - col) = 0` where `col` is itself part of the skippable condition (e.g., `sel * (1 - sel) = 0` when skippable is `sel = 0`). When `sel = 0`, this evaluates to `0 * 1 = 0`. **Safe.**

- **NOT nullified**: The constraint involves columns that are NOT multiplied by the skippable column. Example: `col * (1 - col) = 0` where `col` is a sub-selector NOT in the skippable condition. When skippable fires, `col` must actually be zero for this to evaluate to zero. **Requires tracegen compliance.**

For each NOT-nullified constraint, record which columns must be zero on skipped rows.

### 4. Verify tracegen compliance

Read the tracegen `process()` method. Check that on rows where the skippable condition holds, every column identified in step 3 is zero:

#### a. Inactive rows (no event written)
- Columns default to 0 (the trace container initializes to zero). **Usually safe**, but verify no pre-initialization or sentinel values are set on rows that should be skipped.

#### b. Sentinel / gadget rows
- Some gadgets reserve row 0 as a "skippable gadget row" with `sel = 0`. Verify no other columns are set on this row.
- Watch for patterns like `trace.set(C::some_col, 0, value)` that set a column at row 0 — if `some_col` appears in a non-nullified sub-relation, this is a bug.

#### c. Compound skippable conditions
- If the condition is `sel + last = 0`, both must be zero for the skip. Check that tracegen never sets `last = 1` on a row where `sel = 0` (the bitwise trace has an explicit guard for this on empty event lists).

#### d. Cross-namespace columns
- If the skippable condition uses a column from another namespace (e.g., `execution.sel`), verify that the OTHER tracegen also sets that column correctly on rows relevant to this relation.

### 5. Check contiguous trace invariant

The skippable optimization relies on active rows (`sel = 1`) being contiguous — once `sel` becomes 0, it stays 0. Verify:
- Tracegen writes active rows sequentially starting from row 0 (or row 1 if using a gadget row).
- No gaps: active rows are not interleaved with inactive rows.
- If the PIL has `(1 - sel) * sel' = 0` (contiguity constraint), this is explicitly enforced. If not, verify it holds by tracegen construction.

### 6. Check empty event edge case

If the event container is empty:
- No rows are written (or only a sentinel row with `sel = 0`).
- Verify the skippable condition holds on ALL rows (including sentinel).
- For compound conditions like `sel + last = 0`, verify that `last` is NOT set to 1 when there are no events.

## Output format

```
## File: <PIL path>

### Skippable condition
- **Condition**: `<expr> = 0`
- **Generated skip() matches**: YES / NO

### Sub-relation nullification
| Line(s) | Constraint | Nullified by skippable? | Columns that must be zero | Status |
|---------|-----------|------------------------|--------------------------|--------|
| X | `sel * expr = 0` | YES (multiplied by sel) | N/A | OK |
| X | `col * (1 - col) = 0` | NO | `col` | OK / ISSUE |

### Tracegen compliance
| Check | Status | Notes |
|-------|--------|-------|
| Inactive rows default to zero | OK / ISSUE | ... |
| Sentinel/gadget rows | OK / N/A / ISSUE | ... |
| Compound condition compliance | OK / N/A / ISSUE | ... |
| Contiguous trace invariant | OK / ISSUE | ... |
| Empty events edge case | OK / ISSUE | ... |

### Issues
- (list each issue, or "No issues found.")
```

$ARGUMENTS
