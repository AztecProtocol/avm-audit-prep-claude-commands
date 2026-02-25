---
name: avm-cpp-check-headers
description: Audit C++ includes for unused, missing (transitive), and redundant imports following the project's include rules.
allowed-tools: Read, Glob, Grep, Task, Edit
---
# [CPP_HEADERS] — C++ Include Audit

Given the file(s) `$ARGUMENTS`, audit the `#include` directives for correctness.

## Fix mode

If the first word of `$ARGUMENTS` is `fix`, remove it from the arguments and enable **fix mode**. In fix mode, after completing the audit, automatically apply all suggested fixes using the Edit tool. Do not ask for confirmation — just apply them all.

## Rules recap

1. **`.hpp` files**: Must directly include every header for every symbol they use. No relying on transitives from their own includes.
2. **`.cpp` files**: Must directly include every header for every symbol they use, **except** headers that are direct includes of their own `.hpp` counterpart (those can be skipped as redundant).
3. The only allowed transitive chain: `.cpp` → own `.hpp` → `.hpp`'s direct includes. One hop only.

## Procedure

### 1. Identify the file pair

If given a `.cpp`, find its `.hpp` counterpart (same basename). If given a `.hpp`, find its `.cpp`. If given a directory or PIL file, locate the corresponding simulation gadget or tracegen builder `.hpp`/`.cpp` pair. Read both files.

### 2. Audit the `.hpp` file

For each `#include` in the `.hpp`:
- **Check if any symbol from that header is used** in the `.hpp` file's own declarations (types in function signatures, base classes, member types, template parameters, etc.).
- If no symbol from the included header is used in the `.hpp`, flag it as **UNUSED in .hpp**.

For each symbol used in the `.hpp` (types, base classes, constants, functions):
- Determine which header defines it.
- If that header is not directly included, flag it as **MISSING in .hpp** (transitive dependency). Identify which current include provides it transitively.

### 3. Audit the `.cpp` file

First, collect the set of headers directly included by the `.hpp` counterpart.

For each `#include` in the `.cpp`:
- If it is the file's own `.hpp` header, skip (always required).
- If it duplicates an include already present in the `.hpp` counterpart, flag it as **REDUNDANT in .cpp** — the `.cpp` inherits it via its own `.hpp`.
- If no symbol from that header is used anywhere in the `.cpp`, flag it as **UNUSED in .cpp**.

For each symbol used in the `.cpp` that is NOT covered by the `.hpp` counterpart's includes:
- Determine which header defines it.
- If that header is not directly included in the `.cpp`, flag it as **MISSING in .cpp**.

### 4. Common symbols to check

When assessing whether an include is needed, look for usage of:
- **Types**: class/struct names in declarations, parameters, return types, local variables, casts, template arguments.
- **Standard library**: `uint8_t`/`uint32_t` → `<cstdint>`, `std::vector` → `<vector>`, `std::string` → `<string>`, `std::array` → `<array>`, `std::optional` → `<optional>`, `std::unique_ptr`/`std::shared_ptr`/`std::make_unique` → `<memory>`, `std::move`/`std::forward` → `<utility>`, `std::runtime_error` → `<stdexcept>`, `std::sort`/`std::transform` → `<algorithm>`, `std::numeric_limits` → `<limits>`, `size_t` → `<cstddef>`, `assert` → `<cassert>`.
- **Base classes**: Any class inherited from requires its header.
- **Forward declarations**: If a type is only used by pointer/reference in a `.hpp`, a forward declaration suffices instead of a full include.

## Output format

```
## File: <path>

### <filename>.hpp
| # | Include | Status | Notes |
|---|---------|--------|-------|
| 1 | `<header>` | OK / UNUSED / ... | ... |

Missing includes:
- `<header>` — needed for `<symbol>` (currently transitive via `<other header>`)

### <filename>.cpp
| # | Include | Status | Notes |
|---|---------|--------|-------|
| 1 | `<header>` | OK / REDUNDANT / UNUSED / ... | ... |

Missing includes:
- `<header>` — needed for `<symbol>` (not covered by own .hpp)

### Summary
- X unused includes
- X redundant includes (in .cpp, already in .hpp)
- X missing direct includes
```

$ARGUMENTS
