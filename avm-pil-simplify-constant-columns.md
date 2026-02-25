---
name: avm-pil-simplify-constant-columns
description: Simplify PIL assignment constraints from the verbose sel*(expr-col)=0 pattern to the direct col=sel*expr assignment style.
allowed-tools: Read, Glob, Grep, Edit
---
# Simplify PIL Assignment Constraints

Given the PIL file `$ARGUMENTS`, find and simplify all verbose assignment-style constraints into the direct assignment form.

## The pattern to find

The verbose pattern constrains a committed column to equal an expression when a selector is active:
```
sel * (constants.SOME_CONSTANT - col) = 0;
sel * (col - 3) = 0;
sel * (a + b - col) = 0;
```

These are all equivalent to the direct assignment form `col = sel * expr`, which is shorter and more readable.

## The simplified form

Replace each instance with:
```
col = sel * constants.SOME_CONSTANT;
col = sel * 3;
col = sel * (a + b);
```

## Rules

1. **Any gating selector works**. If the constraint uses `hash_not_zero * (K - col) = 0`, transform to `col = hash_not_zero * K`.

2. **Preserve annotations**. Keep any `// Lookup constant support` or other comments above the column. If multiple consecutive columns share a single annotation comment, keep one annotation above the group.

3. **Preserve the `pol commit` declaration** — the column is still committed, only the constraint form changes.

4. **Handle both forms of the constraint**:
   - `sel * (constants.FOO - col) = 0` → `col = sel * constants.FOO;`
   - `sel * (col - 3) = 0` → `col = sel * 3;`
   - `sel * (a + b - col) = 0` → `col = sel * (a + b);` (wrap compound expressions in parens)

5. **Verify correctness**: Both forms are algebraically equivalent. When `sel = 0`, both give `col = 0`. When `sel = 1`, both give `col = expr`. Confirm each transformation preserves this.

6. **Do not transform** if:
   - The constraint has a named label `#[CONSTRAINT_NAME]` — named constraints may be intentionally verbose for documentation/audit purposes.
   - The column appears on both sides of the constraint in a non-trivial way (i.e., it's not a simple assignment but a recurrence or self-referential constraint).

## Procedure

1. Read the PIL file.
2. Find all constraints of the form `SELECTOR * (EXPR - col) = 0` or `SELECTOR * (col - EXPR) = 0` where `col` is a committed column and `EXPR` does not reference `col`.
3. Apply the transformation using the Edit tool.
4. Report what was changed.

## Output format

```
## File: <PIL path>

### Transformations
| Column | Old constraint | New form | Selector |
|--------|---------------|----------|----------|
| `col` | `sel * (constants.FOO - col) = 0` | `col = sel * constants.FOO;` | `sel` |

### Skipped
| Column | Constraint | Reason |
|--------|-----------|--------|
| `col` | `#[NAME] sel * (expr - col) = 0` | Has named label |

### Summary
- X assignment constraints found
- X transformed
- X skipped (with reason)
```

$ARGUMENTS
