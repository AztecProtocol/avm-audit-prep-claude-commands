---
name: avm-tracegen-check-interaction-declr
description: Verify that each interaction in a trace builder is declared with the correct type, selectors, and ordering assumptions.
allowed-tools: Read, Glob, Grep, Task
---
# [INTERACTIONS_DECL] — Interaction Declaration Audit

Given the PIL file `$ARGUMENTS`, locate the corresponding tracegen builder and audit every interaction declaration for correctness.

## Finding the files

Given a PIL file at `barretenberg/cpp/pil/vm2/<name>.pil`:
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.cpp` (interaction declarations)
- **Generated lookup settings**: `barretenberg/cpp/src/barretenberg/vm2/generated/relations/lookups_<name>.hpp` (SRC_SELECTOR, DST_SELECTOR, SRC_COLUMNS, DST_COLUMNS)
- **Simulation helper**: `barretenberg/cpp/src/barretenberg/vm2/simulation_helper.cpp` (event emitter setup — deduplicating vs non-deduplicating)
- **PIL file itself**: The lookup/permutation constraints that generated the settings

Use Glob if the naming doesn't match exactly (e.g., subdirectories like `trees/`).

## For each interaction, check the following

Read the `interactions` static member in the tracegen `.cpp` file. For every `.add<...>()` call, identify the InteractionType and the settings class, then apply the checks below.

### All types: Basic correctness

1. Read the generated settings class (in `lookups_<name>.hpp` or `perms_<name>.hpp`) and cross-reference SRC_COLUMNS and DST_COLUMNS against the PIL lookup/permutation constraint. Verify they match.
2. Verify that the InteractionType makes sense for the relationship described in the PIL file (see type-specific checks below).

### LookupSequential

- **No sorting/reordering**: Read the `process()` method of BOTH the source and destination trace builders. Verify that neither sorts or reorders events. Sequential lookups require source and destination rows to appear in matching order. Flag any `std::sort`, `std::stable_sort`, reordering logic, or non-sequential row assignment.
- **No deduplication on target**: Check `simulation_helper.cpp` for how the **destination** trace's event emitter is set up. If the destination uses a `DefaultDeduplicatingEventEmitter`, then `LookupSequential` is **incorrect** — deduplication can cause row reuse which breaks sequential scanning. Flag this and recommend `LookupGeneric` instead.
- **No deduplication on source**: Similarly check the source trace's emitter. Deduplication on the source side can also break ordering assumptions.

### LookupIntoIndexedByRow

- **First tuple element is the row index**: Read the generated settings and verify that `DST_COLUMNS[0]` is an index column (typically `precomputed_idx` or similar). The destination table must be a precomputed table indexed by row number.
- **First source column maps to that index**: `SRC_COLUMNS[0]` should be the value used to index into the precomputed table.

### LookupIntoBitwise

- **Correct table**: Verify the lookup is into the precomputed bitwise table (byte-pair AND/OR/XOR).
- **Tuple shape**: First two elements should be input bytes, remaining elements should be operation outputs.

### LookupIntoPDecomposition

- **Correct table**: Verify the lookup is into the P-adic decomposition precomputed table.
- **Tuple shape**: First elements should be radix and limb_index.

### LookupGeneric

- **Selector override parameter**: If a Column parameter is passed to `.add<>()` (e.g., `C::range_check_sel`), this is the **coarse selector** used to build the destination index. Verify:
  - The coarse selector column corresponds to the main `sel` of the destination trace.
  - The DST_SELECTOR in the settings is a **fine-grained sub-selector** (e.g., `range_check_sel_alu`, `gt_sel_sha256`) that is different from the coarse selector.
  - The fine-grained selector is declared as a boolean in the destination PIL file and is part of the sub-selector implication constraint (e.g., `(sel_alu + sel_sha256 + ...) * (1 - sel) = 0`).
- **No selector override**: If no Column parameter is passed, verify that DST_SELECTOR in the settings is the correct direct selector for the destination trace.

### Permutation

- Verify the PIL constraint uses `is` (not `in`).
- Verify source and destination selectors activate the same number of rows (1-to-1 mapping).

### MultiPermutation

- **Coarse selector**: The Column parameter passed to `.add<>()` (e.g., `C::memory_sel`) is the global destination table selector. Verify it is the main `sel` of the destination trace.
- **Fine-grained selectors**: Each settings class within the MultiPermutation group has its own DST_SELECTOR. Verify:
  - Each fine-grained DST_SELECTOR is a distinct column.
  - Each fine-grained DST_SELECTOR is declared as a boolean in the destination PIL.
  - The destination PIL has an implication constraint tying the fine-grained selectors to the coarse selector.
- **No overlap**: Each destination row should be claimed by at most one permutation in the group.

## Output format

For each interaction (by settings class name):
- **Type declared**: e.g., `LookupGeneric`
- **Type correct**: YES / NO (with reason if NO)
- **Selector check**: PASS / ISSUE (with details)
- **Type-specific checks**: PASS / ISSUE (with details)

At the end, provide a summary of all issues found.

$ARGUMENTS
