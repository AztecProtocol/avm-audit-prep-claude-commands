---
name: avm-sim-check-events
description: Audit simulation event emission — initialization, construction style, and interaction completeness across all code paths.
allowed-tools: Read, Glob, Grep, Task
---
# [EVENT_INIT] [EMIT_EXPLICIT_EVENT] [INTERACTION_EVENTS] — Simulation Event Emission Audit

Given the file(s) `$ARGUMENTS`, audit how the simulation gadget constructs and emits events, checking initialization safety, construction style, and interaction event completeness across all code paths.

## Procedure

### 1. Identify the files

If given a `.pil` file at `barretenberg/cpp/pil/vm2/<name>.pil`, locate:
- **Simulation gadget**: `barretenberg/cpp/src/barretenberg/vm2/simulation/gadgets/<name>.cpp` and `.hpp`
- **Event definition**: `barretenberg/cpp/src/barretenberg/vm2/simulation/events/<name>_event.hpp`
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.cpp` (for interaction cross-reference)
- **Generated lookup/perm settings**: `barretenberg/cpp/src/barretenberg/vm2/generated/relations/lookups_<name>.hpp` and `perms_<name>.hpp`

If given `.cpp`/`.hpp` files directly, use those and locate sibling files. Use Glob if naming doesn't match exactly.

### 2. [EVENT_INIT] — Check that emitted events have no uninitialized members

Read the event struct definition. For each member field:

#### a. Check for default values in the struct definition
- Every field should have an explicit default initializer (e.g., `= 0`, `= false`, `= SomeEnum(0)`, `= MemoryValue::from_tag(...)`).
- This applies to ALL types, including `FF` and `uint256_t` which technically zero-initialize via their default constructors. Explicit `= 0` is required for consistency and clarity.
- Flag any field that has no explicit default initializer, regardless of whether the type's default constructor would zero-initialize.

#### b. Cross-check with emit sites
- Read the simulation `.cpp`. For every `events.emit({...})` call, check whether all struct fields are explicitly set via designated initializers (`.field = value`).
- If a field is NOT set at an emit site, it relies on the default value from the struct definition. This is only safe if the default was verified in step (a).
- Flag any emit site where a field without a safe default is omitted.

#### c. Document which fields rely on defaults and why
- Some fields intentionally use defaults (e.g., `c` in AluEvent defaults to zero because error paths don't produce a result). This is fine if the default matches what the circuit expects.
- Flag cases where the default value could lead to a mismatch with circuit expectations.

### 3. [EMIT_EXPLICIT_EVENT] — Check for incremental event construction

For each emit site in the simulation `.cpp`:

#### a. Preferred pattern: single-expression emit
The ideal pattern is a single `events.emit({...})` call with all fields set via designated initializers:
```cpp
events.emit({
    .field1 = value1,
    .field2 = value2,
    ...
});
```

#### b. Discouraged pattern: incremental building
Flag cases where an event is constructed and then mutated before emission:
```cpp
SomeEvent event;           // or SomeEvent event{...};
event.field1 = value1;     // incremental mutation
// ... more code ...
event.field2 = value2;     // mutation far from construction
events.emit(event);        // or events.emit(std::move(event));
```

This pattern is problematic because:
- It's harder to verify all fields are set (assignments scattered across code).
- Conditional branches may skip field assignments, leaving defaults.
- It obscures the "shape" of the event at the emit point.

#### c. Acceptable exceptions
- **Execution gadget**: Complex opcodes in `execution.cpp` may need incremental building due to the sheer number of fields and conditional logic. Note these but don't flag as issues.
- **Loop-accumulated fields**: If a field accumulates values across a loop iteration, incremental building may be necessary. Note but don't flag.
- **Try/catch patterns**: Where a success path and error path emit different events (like ALU), building two separate explicit emits in each branch is the right pattern — flag if the event is built before the try and mutated in catch instead.

### 4. [INTERACTION_EVENTS] — Check interaction event completeness across code paths

This is the most critical check. For each circuit interaction (lookup/permutation) where this component is the **source**:

#### a. Identify interactions
- Read the tracegen `.cpp` to find the `interactions` static member. Each `.add<Settings, Type>(...)` entry defines an interaction.
- For each interaction, identify the **destination component** (what is being looked up into — e.g., range_check, poseidon2, merkle_check).

#### b. Map simulation calls to destination events
- In the simulation gadget, find every call to a destination gadget (e.g., `range_check.assert_range(...)`, `poseidon2.hash(...)`, `merkle_db.storage_read(...)`). Each such call causes the destination to emit its own event.
- These destination events must be paired with the source event from this component.

#### c. Analyze every code path
For each function that emits this component's event, enumerate all code paths:

1. **Normal (success) path**: Both the source event (this component's `events.emit(...)`) and destination events (calls to other gadgets) should be emitted. Verify they are.

2. **Recoverable/specific error paths**: Errors that don't abort execution (the function catches or handles them, and continues or returns a result). Both source and destination events must still be emitted. Check:
   - Does the source event get emitted after the error?
   - Do the destination calls still happen (or did they happen before the error)?
   - **ISSUE if**: Source emitted but destination calls were skipped (or vice versa).

3. **Fatal error paths** (`std::runtime_error` / exceptions that propagate up): These abort the entire execution; the trace is discarded.
   - It is **correct** for the source event to NOT be emitted before the throw.
   - Destination events emitted before the throw are discarded with the entire trace.
   - **NOT an issue**: "Orphaned" destination events when a fatal error occurs.
   - **ISSUE if**: The source event IS emitted before a fatal throw, because if the exception is later caught higher up, the trace would contain the source event without its context being valid.

#### d. Check ordering: destination before source
The typical pattern is that the simulation calls the destination gadget (which emits the destination event) **before** emitting the source event. Verify this ordering. If the source event is emitted first, the destination might not get emitted if an error occurs between them.

#### e. Cross-reference with tracegen
For each interaction, verify:
- The tracegen `process()` method toggles the source selector under conditions that match when the simulation emits both events.
- If tracegen conditionally toggles (e.g., only when `error == NONE`), verify that the simulation's error path either: (a) doesn't emit either event, or (b) emits both events with an error indicator that tracegen uses to NOT toggle the selector.

### 5. Summarize

## Output format

```
## File: <simulation .cpp path>

### [EVENT_INIT] — Uninitialized Members
#### Event struct: <event type name> (<event .hpp path>)
| Field | Type | Default | Safe? | Notes |
|-------|------|---------|-------|-------|
| field1 | uint128_t | = 0 | YES | |
| field2 | bool | (none) | NO | Missing default initializer |

#### Emit sites
| Location | Fields omitted | Relies on default | Safe? |
|----------|---------------|-------------------|-------|
| <file:line> | field2 | YES | NO — no default defined |

### [EMIT_EXPLICIT_EVENT] — Construction Style
| Emit site | Pattern | Status | Notes |
|-----------|---------|--------|-------|
| <file:line> | Single-expression | OK | |
| <file:line> | Incremental | FLAG | Event built over 15 lines |

### [INTERACTION_EVENTS] — Interaction Completeness
#### Interaction: <destination component> (<settings class>)
- **Destination call(s)**: <e.g., range_check.assert_range()>
- **Code paths**:
  | Path | Source emitted? | Dest emitted? | Fatal? | Status |
  |------|----------------|---------------|--------|--------|
  | Normal | YES (line X) | YES (line Y) | N/A | OK |
  | Error: tag mismatch | YES (line X) | NO — skipped | No (recoverable) | ISSUE |
  | Error: overflow | NO — throws before emit | YES (line Y) | Yes (fatal) | OK — trace discarded |
- **Ordering**: Dest before source: YES/NO
- **Tracegen cross-check**: Selector toggled under matching conditions: YES/NO

### Summary
- **[EVENT_INIT]**: X fields checked, X without safe defaults
- **[EMIT_EXPLICIT_EVENT]**: X emit sites, X use single-expression, X incremental
- **[INTERACTION_EVENTS]**: X interactions audited, X code paths analyzed, X issues found
- **Issues**: (list each, or "No issues found.")
```

$ARGUMENTS
