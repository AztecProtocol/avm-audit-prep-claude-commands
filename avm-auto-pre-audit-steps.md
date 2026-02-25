---
name: avm-auto-pre-audit-steps
description: Run automated pre-audit fixes (doxygen, C++ headers, PIL headers) on a PIL file, committing after each step.
allowed-tools: Read, Glob, Grep, Task, Edit, Bash
---
# Automated Pre-Audit Steps

Given the PIL file `$ARGUMENTS`, run the following audit-and-fix steps **sequentially**. After each step that modifies files, `git add` the changed files and create a commit with a brief message.

**Important**: Each step must complete (audit + fix) before the next step begins. If a step finds no issues, skip the commit and move to the next step.

## Steps

### Step 1: Doxygen annotations

Run the `/avm-cpp-check-doxygen` audit in fix mode on the target PIL file. This audits and fixes doxygen comments on all simulation gadget and tracegen `.cpp` files corresponding to the PIL file.

After fixes are applied:
1. Identify all `.cpp` files that were modified.
2. `git add` those files.
3. Commit with message: `chore: add doxygen to <name> simulation and tracegen`

### Step 2: C++ headers

Run the `/avm-cpp-check-headers` audit in fix mode on the target PIL file. This audits and fixes `#include` directives in the simulation and tracegen `.hpp`/`.cpp` files.

After fixes are applied:
1. Identify all `.hpp` and `.cpp` files that were modified.
2. `git add` those files.
3. Commit with message: `chore: fix cpp includes for <name>`

### Step 3: PIL headers

Run the `/avm-pil-check-headers` audit in fix mode on the target PIL file. This audits and fixes `include` directives in the PIL file itself.

After fixes are applied:
1. `git add` the PIL file.
2. Commit with message: `chore: fix pil includes for <name>`

### Step 4: Event initialization

Run the `/avm-sim-check-events` audit in fix mode on the target PIL file. This audits event struct initialization and fixes missing default initializers. Only the `[EVENT_INIT]` fixes are auto-applied; `[INTERACTION_EVENTS]` issues are reported but not auto-fixed.

After fixes are applied:
1. Identify all event `.hpp` files that were modified.
2. `git add` those files.
3. Commit with message: `chore: add default initializers to <name> events`

## Commit conventions

- Replace `<name>` with the PIL component name (e.g., `update_check`, `alu`, `gt`).
- Do NOT include `Co-Authored-By` lines in commits.
- If a step finds zero issues, print "Step N: no issues found" and skip the commit.
- At the end, print a summary of how many steps produced commits.

$ARGUMENTS
