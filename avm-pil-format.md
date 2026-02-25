---
name: avm-pil-format
description: Format a PIL file to match the audit-prep conventions used across the AVM codebase.
allowed-tools: Read, Edit, Write, Glob, Grep
---
# PIL Formatting Convention

Apply the following formatting rules to the PIL file specified by `$ARGUMENTS`. Read the file first, then rewrite it to match these conventions. Do not change the semantics of any constraint. If something already matches, leave it alone.

## File Structure (top to bottom)

1. **Includes** at the very top, one per line, alphabetical within groups (relative paths first, then deeper paths).
2. **File-level block comment** using `/** ... */` (Javadoc/doxygen style, with ` * ` line prefixes) describing the gadget. Do NOT use `//` line comments for the file header — always use the `/** ... */` block style. Use uppercase labels for each section, following the alu.pil convention. The sections are, in order:
   - **Purpose** (no label needed, just the opening paragraph).
   - **`PRECONDITIONS:`** — What the caller must guarantee about the inputs.
   - **`USAGE:`** — Show the actual lookup syntax callers should use (see "Usage / Lookup Documentation" below).
   - **`TRACE SHAPE:`** — e.g., "1 single row per computation."
   - **`ERROR HANDLING:`** — Document error conditions or state there are none.
   - **`INTERACTIONS:`** — List other subtraces this gadget interacts with and why.
3. **`namespace`** declaration.
4. **`#[skippable_if]`** and `sel = 0;` immediately inside the namespace, before any column declarations.
5. **`pol commit sel;`** with `// @boolean` annotation and its boolean constraint `sel * (1 - sel) = 0;`.
6. **Body**: grouped into logical sections using section headers.

## Section Headers

Use one of these styles consistently within a file:
- `// ==== SECTION NAME ====` for lightweight separators.
- `/****...****/` block dividers for major sections (as in alu.pil, execution.pil).
- `/** ... */` Javadoc-style blocks when the section needs multi-line explanation.

## Column Declarations (`pol commit`)

- Declare columns **close to where they are first used**, not all bunched at the top.
- Annotate booleans: `pol commit foo; // @boolean` with parenthetical explanation of why, e.g. `// @boolean (by lookup into gt when sel_start == 1)`.
- Place the boolean constraint `foo * (1 - foo) = 0;` immediately after the declaration, or group boolean constraints together if many are declared in a block (as in execution.pil's opcode selectors).
- For intermediate expressions, use `pol` (not `pol commit`). Capitalise `pol` names that are pure expressions, e.g. `pol A_LTE_B = ...;`.

## Constraint Labels

- Every named constraint gets a label `#[CONSTRAINT_NAME]` on the **line immediately before** the constraint expression.
- Use UPPER_SNAKE_CASE for constraint names.
- The label and constraint should not have a blank line between them.

## Lookup and Permutation Formatting

These rules apply **everywhere** a lookup or permutation appears — both in actual PIL code and in USAGE documentation comments.

- **Lookups** use `in`, **permutations** use `is`.
- Short lookups/permutations (3 or fewer columns) may be kept on one or two lines:
  ```
  selector { col_a, col_b } in destination.sel { destination.col_a, destination.col_b };
  ```
- For longer lookups (4+ columns), put `in` or `is` on its own line, and list columns vertically with one per line.
- **Never collapse**: If a lookup is already formatted as multi-line, leave it multi-line even if it has 3 or fewer columns. Multi-line is always acceptable; only expand short-to-long when needed, never collapse long-to-short.
  ```
  selector {
      col_a,
      col_b,
      col_c,
      col_d
  } in destination.sel {
      destination.col_a,
      destination.col_b,
      destination.col_c,
      destination.col_d
  };
  ```
- In actual PIL code, place the `#[CONSTRAINT_NAME]` label on the line immediately before the lookup.
- When a column in a lookup tuple is not obvious, add an inline comment: `/*radix=*/register[1]`.

## Usage / Lookup Documentation

In the file-level comment's USAGE section, show each lookup that callers use to invoke this gadget. Format the lookup examples using the same short/long rules from "Lookup and Permutation Formatting" above. For each lookup:
1. Reference the constraint label name: `#[LOOKUP_NAME]:`.
2. Show the full lookup syntax with column names (use the actual column names from the gadget).
3. After the lookup, add bullet points describing:
   - Inputs and any preconditions on them.
   - Outputs and what they are constrained to.
   - Which selector to use.
   - Any other notes (e.g., trace size consumed).

Example (short lookup, from ff_gt.pil):
```
 * USAGE:
 *
 * sel_caller { a, b, result }
 * in
 * ff_gt.sel_gt { ff_gt.a, ff_gt.b, ff_gt.result };
 *
 * - Inputs: Any field elements a and b (no preconditions required).
 * - Output: `result` is constrained to be boolean (1 if a > b, 0 otherwise).
 * - Selector: Use `sel_gt` for the lookup.
 * - Trace size: Consumes 5 rows.
```

Example (long lookup, from alu.pil):
```
 * USAGE:
 *
 *        #[DISPATCH_TO_ALU]:
 *        sel_exec_dispatch_alu {
 *           register[0], mem_tag_reg[0], register[1],
 *           mem_tag_reg[1], register[2], mem_tag_reg[2], subtrace_operation_id, sel_opcode_error
 *        } in alu.sel {
 *           alu.ia, alu.ia_tag, alu.ib, alu.ib_tag, alu.ic, alu.ic_tag, alu.op_id, alu.sel_err
 *        };
```

When a gadget has multiple entry points (e.g., `sel_gt` and `sel_dec`), document each separately.

## Comments

- **Explain why**, not just what. Every constraint should have a comment explaining what property it enforces and why it is correct/needed unless it is immediately obvious.
- **Link recipe docs for standard idioms**: When using the zero check recipe / error-setting idiom (`x * (e * (1 - y) + y) - 1 + e = 0`), add a link to the recipe: `// See https://hackmd.io/moq6viBpRJeLpWrHAogCZw#With-Error-Support.` (see `addressing.pil` for the established convention).
- Document **preconditions** for lookups into other gadgets (e.g., "gt gadget requires both inputs bounded by 2^128").
- Document **deactivation cascades**: when `sel == 0` implies other selectors are 0, explain the chain.
- Use `// Note that ...` or `// Observe that ...` for non-obvious logical deductions.
- Never say "non-negative" when discussing field arithmetic. Say "doesn't underflow" instead.

## Constraint Scenario Documentation

When a constraint handles multiple cases (e.g., different selector values, modes, or opcodes), document each scenario in `//` comments before the constraint label. Use the pattern that best fits the complexity:

### Simple two-case branching (gt.pil style)
For constraints that split on a boolean selector, use inline "When X = Y" comments:
```
// When res = 1, GT_RESULT constrains abs_diff = a - b - 1.
// When res = 0, GT_RESULT constrains abs_diff = b - a.
#[GT_RESULT]
sel * ( (A_GT_B - A_LTE_B) * res + A_LTE_B - abs_diff ) = 0;
```

### Equivalence assertions (bitwise.pil style)
For is-zero idioms and boolean equivalences, use `<==>`:
```
// When start = 1: tag_a == 0 <==> sel_tag_ff_err = 1
#[INPUT_TAG_CANNOT_BE_FF]
start * (TAG_A_DIFF * (sel_tag_ff_err * (1 - tag_a_inv) + tag_a_inv) - 1 + sel_tag_ff_err) = 0;
```

### Numbered error/case lists (alu.pil style)
For consolidated selectors or multi-error paths, use a `/** */` block with numbered cases:
```
/**
 * sel_err is the main consolidated error selector.
 * Three base error cases:
 * 1) FF_TAG_ERR: Input tagged as a field for NOT, DIV, SHL, SHR ...
 * 2) sel_ab_tag_mismatch: Mismatched tags for inputs a and b ...
 * 3) sel_div_0_err: occurs when DIV or FDIV is performed and b == 0.
 */
```

### Deep correctness proofs (ff_gt.pil style)
For non-trivial algebraic properties that need full case analysis, use hierarchical numbering `(1)(a)(i)`:
```
// (1) Assume a proof satisfies the constraints for LTE(x,y,1), i.e., x <= y
//    (a) We do not swap the operands, so a = x and b = y,
//    (b) IS_GT = 1 - ic = 0
//    ...
//     (i)  borrow == 0 ==> y_lo >= x_lo && y_hi >= x_hi
//     (ii) borrow == 1 ==> y_hi >= x_hi + 1 ==> y_hi > x_hi
```

### General guidelines
- Use `==>` for logical implication within a line.
- After listing per-case behavior, add a brief summary of how the cases combine to enforce the overall property.
- Match the depth of documentation to the complexity of the constraint — a simple two-case branch needs two lines, not a full proof.

## Lookup Sub-selectors

When a gadget exposes multiple sub-selectors for lookup (e.g., `sel_sha256`, `sel_alu`, etc.):
- Declare them as a group with `// @boolean` annotations.
- Add boolean constraints as a group.
- Add the implication constraint: `(sel_a + sel_b + ...) * (1 - sel) = 0;` with comment `// If any of the above selectors is 1, then sel must be 1.`

## Error Handling Documentation

Document error handling inside the file-level `/** ... */` block comment under the `ERROR HANDLING:` section:
- If the gadget has no errors: `ERROR HANDLING: This gadget does not have error conditions.`
- If it does: list the error types, how they're flagged, and how they interact with the caller's error handling.

## Misc

- No trailing whitespace.
- 4-space indentation inside namespaces.
- Blank line between logically separate groups of constraints, but no blank line between a `#[LABEL]` and its constraint.
- `pol commit` declarations for "constant support" columns (workarounds for PIL not supporting constants in lookups) should be annotated: `// Lookup constant support: Can be removed when we support constants in lookups.`

$ARGUMENTS
