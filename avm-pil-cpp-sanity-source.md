---
name: avm-pil-cpp-sanity-source
description: Check a PIL file's sibling C++ components (simulation + tracegen) for source quality criteria.
allowed-tools: Read, Glob, Grep, Task
---
# [SANITY_SOURCE] — Source Quality Check

Given the PIL file `$ARGUMENTS`, locate the corresponding C++ simulation and tracegen components and audit them for the criteria below.

## Finding the sibling components

Given a PIL file at `barretenberg/cpp/pil/vm2/<name>.pil`:
- **Simulation gadget**: `barretenberg/cpp/src/barretenberg/vm2/simulation/gadgets/<name>.hpp` and `.cpp`
- **Tracegen builder**: `barretenberg/cpp/src/barretenberg/vm2/tracegen/<name>_trace.hpp` and `.cpp`

If the PIL file is in a subdirectory (e.g., `trees/merkle_check.pil`), check for the component under a matching path or flattened name. Use Glob to find the files if the naming doesn't match exactly.

## Criteria to check

### 1. Sufficient comments and clarity
- Public methods in `.cpp` files should have doxygen comments (`@brief`, `@param`, `@return` as appropriate).
- Non-obvious logic should have inline comments explaining **why**, not just what.
- Flag any method longer than ~30 lines that lacks any comments.

### 2. `override` keyword on interface methods
- Any method that implements a virtual method from a base class or interface must use `override`.
- Check the `.hpp` files: find classes that inherit from an interface (look for `: public SomeInterface` or `: public SomeBase`) and verify every overridden method is marked `override`.
- Common interfaces to check: `TraceBuilderInterface` (tracegen), gadget base classes (simulation).

### 3. No catching generic exceptions
- Search for `catch (std::runtime_error`, `catch (std::exception`, `catch (...)` in the `.cpp` files.
- These are **not acceptable** — specific exception types should be defined and caught instead. We do not want to accidentally swallow truly unexpected errors.
- Report each occurrence with file path and line number.
- Note: `throw std::runtime_error(...)` is fine for fatal errors that abort execution. The concern is only about **catching** generic exceptions.

## Output format

Report findings grouped by file path. For each file, list:
- **PASS** or **ISSUE** for each criterion.
- For issues, include the line number and a brief description.
- At the end, provide a summary: total issues found, grouped by criterion.

$ARGUMENTS
