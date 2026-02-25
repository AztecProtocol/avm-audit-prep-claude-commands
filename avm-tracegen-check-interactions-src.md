---
name: avm-tracegen-check-interactions-src
description: Verify that interaction source selectors are toggled iff the corresponding event was emitted, with correct criteria matching simulation.
allowed-tools: Read, Glob, Grep, Task
---
# [INTERACTION_SRC] — Interaction Source Selector Audit

Given the file(s) `$ARGUMENTS`, audit that every interaction source selector in the tracegen builder is toggled if and only if the corresponding event was actually emitted in simulation, and that the toggling criteria match the simulation logic.

## Procedure

### 1. Identify the files

If given a `.pil` file at `barretenberg/cpp/pil/vm2/<name>.pil`, locate:
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.cpp` and `.hpp`
- **Generated lookup/perm settings**: `barretenberg/cpp/src/barretenberg/vm2/generated/relations/lookups_<name>.hpp` and `perms_<name>.hpp`
- **Simulation gadget**: `barretenberg/cpp/src/barretenberg/vm2/simulation/gadgets/<name>.cpp` and `.hpp`
- **Event definition**: `barretenberg/cpp/src/barretenberg/vm2/simulation/events/<name>_event.hpp`
- **PIL file itself**: The interaction constraints

Use Glob if the naming doesn't match exactly (e.g., subdirectories, `_trace` suffix, etc.).

### 2. Identify all interactions and their source selectors

Read the `interactions` static member in the tracegen `.cpp`. For each `.add<SettingsClass, InteractionType>(...)` call:
- Read the generated settings class to find `SRC_SELECTOR` — this is the column that must be set to 1 on rows where the interaction is active.
- Note the `DST_SELECTOR` and destination namespace to understand what the interaction targets.

### 3. Find where the source selector is toggled in the `process()` method

In the tracegen `process()` method, find every place the source selector column is set (e.g., `{ C::some_sel, 1 }` or conditional assignment). For each:
- **Determine the toggling condition**: Is it always set for every event? Is it conditional on an error enum, a boolean field, or some other event property?
- **Record the criteria**: e.g., "set when `event.error == ErrorCode::NONE`", or "always set", or "set when `event.some_flag`".

### 4. Trace back to simulation: verify the event carries sufficient information

Read the event struct definition. Check that:
- The event contains the fields used by tracegen to decide whether to toggle the selector.
- If tracegen uses an error enum or boolean to conditionally toggle, verify that field exists in the event struct.

### 5. Verify simulation emits the event under the right conditions

Read the simulation gadget `.cpp`. For each call site that emits the event type:
- **Check what conditions lead to the emit**: Is it emitted on success only? On all paths? On specific error conditions?
- **Check whether the destination interaction's event is also emitted**: If the source selector gates a lookup into another trace (e.g., range_check), verify that the simulation also triggers the destination event (e.g., calls `range_check.assert_range()`) on exactly the same paths where the source event would have the selector-toggling criteria met.

### 6. Cross-check: selector toggled ⟺ destination event emitted

For each interaction, verify the bidirectional invariant:
- **If the source selector is toggled** (based on tracegen criteria), then the simulation must have emitted the corresponding destination event on that same path.
- **If the simulation emits the destination event**, then the source selector must be toggled in tracegen for that row.

Flag mismatches:
- **SELECTOR WITHOUT DESTINATION**: Source selector is toggled but simulation does not emit the destination event on that path.
- **DESTINATION WITHOUT SELECTOR**: Simulation emits the destination event but source selector is not toggled (lookup/permutation would be unbalanced).
- **MISSING EVENT FIELD**: Tracegen needs to conditionally toggle but the event struct lacks the necessary discriminating field.
- **CRITERIA MISMATCH**: Tracegen toggles on condition X, but simulation emits the destination event on condition Y (where X ≠ Y).

## Output format

```
## File: <tracegen .cpp path>

### Interaction: <settings class name>
- **Source selector**: `<column name>`
- **Toggling condition in tracegen**: <description>
- **Event field(s) used**: <field names>
- **Simulation emit sites**:
  - <file:line> — emitted when <condition>. Destination event emitted: YES/NO.
- **Selector ⟺ Destination match**: PASS / ISSUE

### Summary
- X interactions audited
- X pass
- X with issues (list each)
```

$ARGUMENTS
