---
name: avm-pil-check-docu-inside
description: Audit inline PIL comments for non-trivial steps, underconstrained columns, and potential footguns.
allowed-tools: Read, Glob, Grep, Task
---
# [DOCU_INSIDE] — PIL Inline Comments Audit

Given the PIL file `$ARGUMENTS`, audit that inline comments are present for every non-trivial step, underconstrained column, and potential footgun.

## Procedure

### 1. Read the PIL file

Read the entire PIL file. For each section of constraints, check the criteria below.

### 2. Check: non-trivial steps have comments

For each constraint or group of constraints, assess whether the logic is self-evident:
- **Trivial**: Simple boolean constraint (`col * (1 - col) = 0`), basic selector implication — no comment needed.
- **Non-trivial**: Algebraic tricks, conditional expressions using selector multiplication, multi-row constraints with shifts, polynomial identities that encode a specific property. These **must** have a comment explaining **why** the constraint works, not just **what** it does.

Flag if:
- **MISSING COMMENT ON NON-TRIVIAL CONSTRAINT**: A complex constraint lacks an explanatory comment.

### 3. Check: underconstrained columns are documented

A column is "underconstrained" if it is not constrained on every active row. Common patterns:
- A column only constrained in the first or last row of a multi-row latch.
- A column that is free (unconstrained) on inactive rows.
- A column constrained only via an interaction (lookup/permutation) but not by local relations.
- A column that is constrained conditionally (e.g., only when `sel = 1`).

For each such column, verify there is a comment explaining:
- **On which rows the column is constrained** (e.g., "only constrained when sel = 1").
- **What happens on other rows** (e.g., "free on inactive rows", "value doesn't matter when sel = 0").
- **Why this is safe** (e.g., "inactive rows are skipped by the skippable_if directive").

Flag if:
- **MISSING UNDERCONSTRAINT COMMENT**: A column is underconstrained but no comment explains this.
- **FOOTGUN RISK**: A column is underconstrained in a way that could be exploited (e.g., a malicious prover could set it to any value on active rows) without documentation.

### 4. Check: important properties are commented

Look for constraints that enforce important security or correctness properties:
- **Non-underflow/overflow proofs**: Constraints that prove a subtraction didn't wrap. Should be commented with why the range check suffices.
- **Uniqueness guarantees**: Constraints that ensure a value appears at most once.
- **Ordering constraints**: Constraints that enforce monotonicity or sequencing.
- **Conditional behavior**: Constraints that behave differently based on a selector or mode column. Each branch should be commented.

Flag if:
- **MISSING PROPERTY COMMENT**: An important property is enforced but not explained.

### 5. Check: interaction constraints are commented

For each lookup (`in`) or permutation (`is`) constraint:
- There should be a comment explaining **what** the interaction proves and **why** it is needed.
- The named tag (e.g., `#[GT_RANGE]`) should have a nearby comment if the name alone is not self-explanatory.

Flag if:
- **MISSING INTERACTION COMMENT**: A lookup/permutation lacks an explanatory comment.

### 6. Check: section organization

PIL files should be organized with section headers (comment blocks) separating logical groups:
- Selector declarations
- Input/output columns
- Intermediate computation columns
- Constraints
- Interactions

Flag if:
- **MISSING SECTION HEADERS**: The file lacks organizational comments, making it hard to navigate.

## Output format

```
## File: <PIL path>

### Non-trivial constraints
| Line(s) | Constraint | Comment present? | Status |
|---------|-----------|-----------------|--------|
| X | `<constraint summary>` | YES / NO | OK / MISSING COMMENT |

### Underconstrained columns
| Column | Constrained when | Comment present? | Status |
|--------|-----------------|-----------------|--------|
| `col` | only when sel = 1 | YES: "<comment>" / NO | OK / MISSING COMMENT |

### Important properties
| Line(s) | Property | Comment present? | Status |
|---------|----------|-----------------|--------|
| X | non-underflow proof | YES / NO | OK / MISSING |

### Interaction comments
| Line(s) | Interaction | Comment present? | Status |
|---------|------------|-----------------|--------|
| X | `#[NAME]` | YES / NO | OK / MISSING |

### Section organization
| Expected section | Present? | Status |
|-----------------|----------|--------|
| Selectors | YES / NO | OK / MISSING |
| Inputs/outputs | YES / NO | OK / MISSING |
| Constraints | YES / NO | OK / MISSING |
| Interactions | YES / NO | OK / MISSING |

### Issues
- (list each issue, or "No issues found.")
```

$ARGUMENTS
