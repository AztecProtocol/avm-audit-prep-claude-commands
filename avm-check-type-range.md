---
name: avm-check-type-range
description: Audit that PIL type/range constraints match tracegen value assignments. Check booleans, enums, bit-widths, and overflow-capable columns.
allowed-tools: Read, Glob, Grep, Task
---
# [TYPE/RANGE] — Type and Range Constraint Audit

Given the file(s) `$ARGUMENTS`, audit that every constrained column has a correct range check in PIL and that tracegen always assigns values within the declared range.

## Procedure

### 1. Identify the files

If given a `.pil` file at `barretenberg/cpp/pil/vm2/<name>.pil`, locate:
- **PIL file**: The constraint definitions (type annotations and range checks).
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.cpp`
- **Simulation gadget**: `barretenberg/cpp/src/barretenberg/vm2/simulation/gadgets/<name>.cpp` (to understand value provenance)
- **Event definition**: `barretenberg/cpp/src/barretenberg/vm2/simulation/events/<name>_event.hpp`

Use Glob if the naming doesn't match exactly.

### 2. PIL audit: identify all typed/range-constrained columns

Read the PIL file. For each committed column (`pol commit`), check:

#### a. Boolean columns (`// @boolean` annotation or `col * (1 - col) = 0`)
- Verify the boolean constraint exists: `col * (1 - col) = 0`.
- If the column is annotated `// @boolean` but lacks the constraint, flag it.
- If the column has the constraint but lacks the annotation, note it (minor).

#### b. Enum/multi-value columns
- Look for constraints of the form `col * (col - 1) * (col - 2) * ... = 0` or equivalent range checks.
- Verify the set of allowed values matches the intended enum.

#### c. Bit-width columns
- Look for range check lookups (e.g., into `range_check`) that bound a column to N bits.
- Verify the bit-width is sufficient for the column's purpose.

#### d. Derived or externally checked columns
- If a column's range is guaranteed by a precondition (e.g., it comes from a lookup destination that already constrains it, or it's a copy of another constrained column), verify this is documented with a comment in the PIL.
- Flag columns that lack both a direct constraint and an explanatory comment.

#### e. Overflow-aware columns
- For columns that capture arithmetic results which could overflow (e.g., sums, products, differences), check whether the range constraint is wide enough to capture the overflow case.
- Example: If a column holds `a - b` where both are 128-bit, the column might need to accommodate values up to the field modulus if the subtraction can underflow. The range check should match the proof strategy (e.g., proving non-underflow via a bounded absolute difference).

### 3. Tracegen audit: verify assigned values are in range

Read the tracegen `process()` method. For each column that has a type/range constraint in PIL:

#### a. Boolean columns
- Check every assignment to the column. Verify the value is always 0 or 1.
- Common patterns to verify:
  - `{ C::col, event.flag ? 1 : 0 }` — OK (ternary producing 0/1).
  - `{ C::col, 1 }` — OK (literal).
  - `{ C::col, event.some_bool }` — Check: is `some_bool` actually a `bool` type in the event? If it's an integer, it might not be 0/1.
  - `{ C::col, some_expression }` — Flag if the expression could produce values outside {0, 1}.

#### b. Enum columns
- Check that assigned values match the allowed enum values from the PIL constraint.
- If the tracegen casts an enum to an integer, verify the enum's range matches.

#### c. Bit-width columns
- Check that assigned values fit within the declared bit-width.
- Pay special attention to:
  - Values derived from subtraction (could underflow to large field elements).
  - Values derived from addition (could overflow the intended bit-width).
  - Casts from wider types to narrower columns.

#### d. Overflow cases
- If a column is meant to hold a value that wraps on overflow (field arithmetic), verify the range check is on the absolute difference or wrapped result, not the raw subtraction.
- If a column captures an error/overflow indicator, verify tracegen sets it correctly when overflow occurs.

### 4. Cross-check PIL vs Tracegen

For each constrained column, verify consistency:
- **PIL says boolean, tracegen assigns non-boolean**: Flag as **RANGE VIOLATION**.
- **PIL says N-bit, tracegen assigns wider value**: Flag as **RANGE VIOLATION**.
- **PIL has no constraint, but column should be bounded**: Flag as **MISSING CONSTRAINT** in PIL.
- **Tracegen always assigns in-range, but PIL lacks constraint**: Flag as **UNCONSTRAINED** — the prover could substitute any value.
- **Column range derived from precondition but undocumented**: Flag as **MISSING COMMENT** in PIL.

## Output format

```
## File: <PIL path>

### Constrained columns
| Column | Declared type | PIL constraint | Tracegen assigns | Status |
|--------|--------------|----------------|------------------|--------|
| `col` | boolean | `col * (1 - col) = 0` (line X) | `event.flag ? 1 : 0` (line Y) | OK / ISSUE |
| ... | ... | ... | ... | ... |

### Unconstrained columns (committed but no range check)
| Column | Expected type | Tracegen assigns | Comment present? | Status |
|--------|--------------|------------------|-----------------|--------|
| `col` | N-bit | `event.value` | YES: "bounded by lookup X" / NO | OK / MISSING CONSTRAINT / MISSING COMMENT |

### Issues
- (list each issue with file, line, and description, or "No issues found.")

### Summary
- X columns audited
- X correctly constrained and assigned
- X issues found
```

$ARGUMENTS
