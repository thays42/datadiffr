# Consolidated comparison result: `datadiff_result`

**Date:** 2026-07-05
**Status:** Approved, pre-implementation
**Issue:** #12 (inconsistent return value in `diffdata()`)

## Problem

`diffdata()` has three return paths returning two structurally incompatible
objects, with the split driven by a *failure* condition:

| Condition          | Returns                    | Shape                                   | Visibility |
| ------------------ | -------------------------- | --------------------------------------- | ---------- |
| Columns differ     | `compare_columns()` tibble | `.diff / column / x_type / y_type`      | visible    |
| No row differences | empty `datadiff_diff`      | `.row / .source / .join_type / …`       | invisible  |
| Row differences    | `datadiff_diff`            | diff rows                               | invisible  |

Visible-vs-invisible is the symptom. The real defect: the native high-level API
has an **impoverished data model**. Column differences are a *valid kind of
difference to present*, but the code treats them as a fatal error — it fires
`cli_alert_danger("Cannot diff data with column differences")` yet still returns
a data frame as if it succeeded. A programmatic caller cannot predict the return
type or distinguish success from failure.

A consolidated model already exists in the codebase — `rCompare()`'s
`datadiff_compare` object carries schema differences (`colMatching`), row
add/remove (`rowMatching`), and cell-level value diffs (`mismatches`) in one
structure — but it is walled off inside the dataCompareR-compatibility surface
and wears that contract's field names/semantics. The native path should have its
own consolidated object.

### Secondary defect (fixed as a side effect)

`compare_data()` and `diffdata()` are currently **inconsistent with each other**:

- `compare_data()` aborts only on type conflicts / no column overlap, but will
  diff the *intersection* when column names differ.
- `diffdata()` refuses on *any* column difference.

The design unifies both under one rule.

## Decisions

- **Approach A — thin wrapper class.** Chosen over bolting a schema slot onto
  `datadiff_diff` (which would make a tibble lie about its own shape) and over
  reusing the rCompare object natively (which would invert the dependency from
  native API onto the compat contract).
- **Schema-only when columns differ.** When columns differ (names *or* types),
  report the schema difference only — do **not** compute a value diff on the
  intersection. Name-only column differences will *stop* producing an
  intersection value-diff; this is intentional and makes `compare_data()` and
  `diffdata()` consistent.
- **Console-only schema rendering.** When columns differ, `render_diff()` prints
  the schema table to the console; it does not open an HTML report. HTML schema
  rendering is a deferred fast-follow (seeds issue #22).
- **Timing: before CRAN.** `compare_data()`'s return type changes from a bare
  `datadiff_diff` to `datadiff_result`. The package is unreleased (0.1.0), so
  there are no users and no deprecation path is required. After first CRAN
  release this would need migration handling.

## Design

### 1. The object — `datadiff_result`

A plain-list S3 record returned by `compare_data()`:

```r
structure(
  list(
    kind      = "value",   # "identical" | "schema" | "value"
    columns   = NULL,      # compare_columns() tibble; set only when kind == "schema"
    rows      = NULL,      # datadiff_diff;          set only when kind == "value"
    by        = by,        # metadata on every result
    tolerance = tolerance
  ),
  class = "datadiff_result"
)
```

- Keyed by `kind`: `schema` populates `columns` (with `rows == NULL`); `value`
  and `identical` populate `rows` (with `columns == NULL`). For `identical`,
  `rows` is the empty `datadiff_diff` (zero diff rows) — same payload type as
  `value`, so consumers of `$rows` do not special-case it.
- `datadiff_diff` is **unchanged** and remains the `rows` payload; its existing
  `print` / `summary` / renderer logic is reused, not rewritten.
- Constructor `new_datadiff_result()` lives next to `new_datadiff_diff()` in
  `R/diff-class.R`.

### 2. `compare_data()` — the column gate decides `kind`

The two `cli_abort` calls (no overlap, type conflict) and the implicit
intersection-diffing on name-only differences collapse into one gate:

```r
col_diff <- compare_columns(x, y)
if (nrow(col_diff) > 0) {
  return(new_datadiff_result(kind = "schema", columns = col_diff,
                             by = by, tolerance = tolerance))
}
rows <- compare_join(x, y, by = by) |> compare_diff(...)  # existing datadiff_diff
kind <- if (nrow(rows) == 0) "identical" else "value"
new_datadiff_result(kind = kind, rows = rows, by = by, tolerance = tolerance)
```

Input validation (checkmate asserts on `x`, `y`, `by`, `context_rows`,
`context_cols`, `max_differences`, `tolerance`) is unchanged. Only the
column-shape aborts are replaced by the schema branch.

### 3. `diffdata()` — one return type, always invisible

Remove the visible `col_diff` return and the `cli_alert_danger`. `diffdata()`
becomes `compare_data()` + render + invisible return:

```r
result <- compare_data(x, y, by = by, context_rows = context_rows,
                       context_cols = all_of(context_cols),
                       max_differences = max_differences, tolerance = tolerance)
render_diff(result, output_file = output_file)
invisible(result)
```

All three cases return `datadiff_result` invisibly. The `compare_columns()`
pre-check currently in `diffdata()` is removed — the gate now lives in
`compare_data()`. User-facing messaging moves into the render/print methods.

The `@return` roxygen updates to document the single `datadiff_result` type.

### 4. Methods (dispatch on `kind`)

- **`print.datadiff_result`**
  - `identical` → `cli::cli_alert_success("No differences found.")`
  - `schema` → a "Columns differ" message + print the `columns` table
  - `value` → delegate to existing `print.datadiff_diff` on `x$rows`
- **`summary.datadiff_result`** — same three-way split; reuse
  `summary.datadiff_diff` for the value case. Returns a
  `summary.datadiff_result` with its own `print` method.
- **`render_diff.datadiff_result`**
  - `value` → existing row renderer on `x$rows`
    (today's `render_diff.default` path)
  - `identical` → success message, no report opened
  - `schema` → **console-only**: print the schema table; do not open HTML

`render_diff.default` continues to accept a bare `datadiff_diff` (used
internally by the value path and by `render_diff.datadiff_compare`).

### 5. Tests (TDD)

- Update `test-compare.R` / `test-diffdata.R` assertions that index a bare
  tibble returned by `compare_data()` — they now receive `datadiff_result`
  (`$rows`, `$kind`, `$columns`).
- New tests:
  - `compare_data()` returns `kind == "schema"` with a populated `columns`
    slot when column names differ and when types conflict, and no longer aborts.
  - `kind == "identical"` when frames match with no differences.
  - `kind == "value"` with populated `rows` when values differ.
  - Each method (`print` / `summary` / `render_diff`) dispatches correctly per
    kind.
  - `diffdata()` returns invisibly in all three cases.
- `datadiff_diff`'s own tests are untouched.
- `rCompare()` / `datadiff_compare` surface is untouched.

## Out of scope / deferred

- HTML rendering of schema differences (console-only for now).
- Diffing the intersection of columns when columns differ (explicitly rejected).
- `n_differences()` / `has_differences()` / `get_differences()` accessors
  (#21 / #23) — separate post-1.0 work.
- Any change to the `rCompare` / dataCompareR-compat surface.
