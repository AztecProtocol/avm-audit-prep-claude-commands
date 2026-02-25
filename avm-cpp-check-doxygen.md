---
name: avm-cpp-check-doxygen
description: Audit doxygen annotations on C++ functions/methods in simulation and tracegen files. Check completeness of briefs, params, returns, exceptions, preconditions, and event flavors.
allowed-tools: Read, Glob, Grep, Task
---
# [DOCU_FUNCTIONS] — Doxygen Annotation Audit

Given the file(s) `$ARGUMENTS`, audit every function and method for complete doxygen documentation.

This check applies both standalone (for functions not part of a specific component) and as a sub-task within per-component audits.

## Procedure

### 1. Identify the files

If given a `.pil` file, locate the sibling C++ files:
- **Simulation gadget**: `barretenberg/cpp/src/barretenberg/vm2/simulation/gadgets/<name>.cpp`
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.cpp`

If given `.cpp`/`.hpp` files directly, use those. Use Glob if naming doesn't match exactly.

**Important**: Doxygen comments go in `.cpp` files only, not `.hpp` or interface headers.

### 2. For each function/method, check the following

Read the `.cpp` file(s). For every function or method definition, verify:

#### a. `@brief` — required on all public/override methods and significant private helpers
- Must be a concise description of what the function does.
- Trivial one-line utilities may be exempt.
- For tracegen `process` methods, the convention is: `@brief Process the X events and populate the relevant columns in the trace.`

#### b. `@param` — required for every parameter
- Each parameter must have a `@param` tag with a description.
- Flag any parameter that is missing documentation.

#### c. `@return` — required if the function returns a non-void value
- Must describe what the return value represents.

#### d. `@throws` — required for every exception that can be thrown
- List each exception type the function may throw (directly or via called helpers that are documented to throw).
- **Ordering matters**: When multiple error cases exist, document them in the order they are checked in the code. If errors map to temporal groups (e.g., pre-validation errors before main logic errors), note this grouping.
- Example:
  ```
  @throws std::runtime_error If the opcode is not supported (checked first).
  @throws std::runtime_error If the input exceeds the maximum value (checked after opcode validation).
  ```

#### e. `@note` — for preconditions and assertions
- Any `assert()`, `ASSERT()`, or documented preconditions should appear as `@note Precondition: ...` or `@note Asserts that ...`.
- Check the function body for assert statements and verify they are documented.

### 3. Additional checks for tracegen `process` methods

Tracegen `process()` methods consume events that may have **multiple flavors** — the same event class can be emitted at different points in simulation and/or under different error conditions, leading to different invariants (some fields empty, different error enum values, etc.).

For each `process` method:
- Identify the event type it consumes (from the parameter type).
- Search the simulation code for all call sites that emit that event type (look for `emit()` calls or emitter usage).
- Document the different flavors: under what conditions is the event emitted, and what invariants differ between flavors (which fields are populated, which error values appear, etc.).
- Verify the doxygen documents these flavors. Flag if the documentation does not mention the distinct event flavors.

Expected documentation pattern:
```cpp
/**
 * @brief Process the Foo events and populate the relevant columns in the trace.
 *
 * Events are emitted in the following flavors:
 * - Normal execution: all fields populated, error = NONE.
 * - Overflow error: result field is empty, error = OVERFLOW.
 * - ...
 *
 * @param events Container of FooEvent to process.
 * @param trace The trace container to populate.
 */
```

## Output format

```
## File: <path>

### <function/method signature>
| Check | Status | Notes |
|-------|--------|-------|
| @brief | OK / MISSING / INCOMPLETE | ... |
| @param | OK / MISSING for `<param>` | ... |
| @return | OK / MISSING / N/A (void) | ... |
| @throws | OK / MISSING for `<exception>` / UNORDERED | ... |
| @note (preconditions) | OK / MISSING for `<assert>` / N/A | ... |
| Event flavors (tracegen only) | OK / MISSING / N/A | ... |

### Summary
- X functions audited
- X fully documented
- X with missing/incomplete doxygen
- Details of each gap
```

$ARGUMENTS
