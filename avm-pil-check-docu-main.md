---
name: avm-pil-check-docu-main
description: Audit PIL file top-level documentation — trace shape, errors, preconditions, destination components, and examples.
allowed-tools: Read, Glob, Grep, Task
---
# [DOCU_MAIN] — PIL Main Documentation Audit

Given the PIL file `$ARGUMENTS`, audit that the file's header documentation is complete and accurate.

## Procedure

### 1. Read the PIL file

Read the PIL file and its header comment block (typically a `/** ... */` block before the `namespace` declaration).

### 2. Check: trace shape documentation

The header should explain:
- **How many rows per event/computation**: Is it 1 row per event, or multiple? Is it fixed or variable?
- **Different use cases**: If the gadget serves multiple callers or modes (e.g., different opcodes, different error paths), document how the trace shape varies across them.
- **Example/illustration**: If the trace shape is non-trivial (multi-row, variable-length, latched), the header should include an ASCII example or diagram showing the row layout. This is not a hard requirement for single-row gadgets.

Flag if:
- **MISSING TRACE SHAPE**: No mention of how many rows are used.
- **MISSING MULTI-CASE SHAPE**: Gadget handles multiple use cases but only documents one shape.
- **MISSING EXAMPLE**: Non-trivial trace shape (multi-row or variable) without an illustration.

### 3. Check: error documentation

Search the PIL file and the corresponding simulation gadget for error conditions. The header should:
- **List all errors** that can occur and when they trigger.
- **Document the effect on trace shape**: Does an error stop at the first row? Does it produce a partial trace? Does it fill all rows with a default?
- If the gadget has no error conditions, the header should state this explicitly (e.g., "This gadget does not have error conditions.").

Flag if:
- **MISSING ERROR LIST**: Errors exist in simulation but are not documented in PIL.
- **MISSING ERROR TRACE EFFECT**: Errors are listed but their effect on the trace is not described.

### 4. Check: preconditions documentation

The header should list all preconditions the gadget relies on — assumptions about input values that must be enforced by the caller. Look for:
- Range bounds on inputs (e.g., "inputs must be bounded by 2^128").
- Type constraints (e.g., "inputs must not be FF-tagged").
- Ordering constraints (e.g., "events must arrive in order").
- Cross-reference with simulation `BB_ASSERT` / `assert` statements and `@note Precondition` in doxygen.

Flag if:
- **MISSING PRECONDITION**: Simulation asserts or assumes something about inputs that is not documented in the PIL header.
- **UNDOCUMENTED CALLER OBLIGATION**: A precondition exists but it's unclear who enforces it.

### 5. Check: destination components listed

For each interaction (lookup or permutation) defined in this PIL file where this namespace is the **source**, the header should list the destination component. For example:
- "range_check.pil: To prove that abs_diff < 2^128."

Read all interaction constraints in the PIL (lines with `in` or `is` keywords). For each, identify the destination namespace and verify it appears in the header's INTERACTIONS section.

Flag if:
- **MISSING DESTINATION**: An interaction targets a destination not mentioned in the header.

### 6. Check: usage documentation (for destination gadgets)

If other PIL files look up into this namespace (i.e., this gadget appears as a **destination**), the header should document:
- The usage pattern (how callers should set up the lookup).
- The selector to use.

Search for references to this namespace in other PIL files:
```
<namespace>.<column>
```
If found, verify the PIL header documents itself as a lookup destination.

Flag if:
- **MISSING USAGE AS DESTINATION**: Other files look up into this namespace but it's not documented.

## Output format

```
## File: <PIL path>

### Documentation checks
| Check | Status | Notes |
|-------|--------|-------|
| Trace shape | OK / MISSING / INCOMPLETE | ... |
| Example/illustration | OK / N/A (trivial) / MISSING | ... |
| Error list | OK / MISSING | ... |
| Error trace effect | OK / MISSING / N/A | ... |
| Preconditions | OK / MISSING for <precondition> | ... |
| Destination components | OK / MISSING for <dest> | ... |
| Usage as destination | OK / N/A / MISSING | ... |

### Issues
- (list each issue, or "No issues found.")
```

$ARGUMENTS
