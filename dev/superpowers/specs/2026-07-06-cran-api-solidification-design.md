# CRAN API solidification: accessors, compat-layer cut, doc fixes

**Date:** 2026-07-06
**Status:** Approved
**Context:** Final API/doc pass before the initial CRAN submission of datadiffr
0.1.0. Follows the 2026-07-06 pre-submission review (API-surface and docs
audits) and two decisions made with the maintainer: cut the dataCompareR
compat layer from 0.1.0, and ship both row- and cell-oriented extraction
functions.

## Goals

1. Give `datadiff_result` a supported programmatic surface (accessors) so no
   user code needs `attr()` or the object's internals — closing issues #21
   and #23 before the API freezes.
2. Remove the dataCompareR compat layer from the 0.1.0 release (deferred, not
   abandoned — git history retains it for a future 0.2.0 or standalone
   package).
3. Fix the documentation problems found in the pre-submission review.

## Non-goals

- S7. The package stays S3. Rationale: `$rows` is a tibble subclass (S3/vctrs
  territory regardless), users consume but never construct these objects (so
  validators guard nothing user-facing), S7's `@` access would regress the
  documented `result$kind`/`result$rows` ergonomics, and it would add a hard
  dependency to deliver what plain accessor generics already deliver. If a
  validated object hierarchy ever emerges, S7 can be adopted later without
  breaking the accessor contract.
- The open rendering/UX issues (#1 colors, #3 column tabs, #22 summary tab,
  #24 styled console, #26 tolerance specs) — all additive, post-release.
- Renderer performance work.

## 1. Accessor surface (new exports)

All are S3 generics with `datadiff_result` methods. Generic + method (not
plain functions) so future classes can participate.

```r
has_differences(x, ...)                       # logical(1)
n_differences(x, ...)                         # integer(1)
get_differences(x, columns = NULL, ...)       # tibble, row-oriented
get_cell_differences(x, columns = NULL, ...)  # tibble, cell-oriented
```

Semantics by `$kind`:

| accessor               | `"identical"`        | `"value"`             | `"schema"`                          |
|------------------------|----------------------|-----------------------|-------------------------------------|
| `has_differences()`    | `FALSE`              | `TRUE`                | `TRUE`                              |
| `n_differences()`      | `0L`                 | count of differing rows (the existing `n_differences` attribute; documented as rows, not cells) | `NA_integer_` |
| `get_differences()`    | zero-row tibble, stable schema | differing rows | error (cli), pointing at `result$columns` |
| `get_cell_differences()` | zero-row tibble, stable schema | differing cells | error (cli), pointing at `result$columns` |

`get_differences(x, columns = NULL)`:

- Row-oriented: the differing rows only (`.diff_type == "diff"`), context rows
  excluded, in the existing stacked x/y layout with native column types.
- `columns` is tidy-select (consistent with `context_cols`/`group_cols`).
  When supplied, returns only rows that have a difference in at least one
  selected column; selection is validated against the compared columns.
- Truncated results (`max_differences`) return the truncated set; the docs
  say to use `max_differences = Inf` for complete extraction.

`get_cell_differences(x, columns = NULL)`:

- Cell-oriented: one row per differing cell with columns `.row`, the key
  columns (when the comparison used `by=`), `column`, `value_x`, `value_y`.
- `value_x`/`value_y` are character (mixed source types cannot share a typed
  column); formatting via a single documented coercion (`format()`-based,
  `NA` stays `NA`). Docs point to `get_differences()` when native types
  matter.
- Rows present in only one frame contribute one row per compared column with
  `NA` on the missing side.
- `columns` filters as above.

With accessors shipped, documentation declares internal (subject to change):
the `$rows` bookkeeping columns (`.row`, `.join_type`, `.diff_type`,
`.source`), the `datadiff_diff` class and its attributes (`tolerance`,
`diff_columns`, `n_differences`, `truncated`). The supported contract is:
construct via `compare_data()`/`diffdata()`; consume via print/summary,
accessors, `render_diff()`, and the documented `$kind`/`$columns`/`$rows`/
`$by`/`$tolerance` list elements.

## 2. Cut the dataCompareR compat layer

Remove from the package (retained in git history):

- `R/rcompare.R`, `R/rcompare-methods.R`, `R/rcompare-output.R`
- `tests/testthat/test-rcompare*.R`, `tests/testthat/helper-rcompare.R`
- `render_diff.datadiff_compare` method (in `R/diff.R`)
- `dataCompareR` from `Suggests`
- The dataCompareR CRAN-archive install steps in
  `.github/workflows/R-CMD-check.yaml` and `.github/workflows/pkgdown.yaml`
- `.lintr` object_name_linter exclusions for the compat files
- Any WORDLIST entries only needed by the compat docs

Replace the "Migrating from dataCompareR" vignette with a concept-mapping
guide (title kept close, e.g. "Coming from dataCompareR"): a table mapping
`rCompare(a, b, keys=)` → `compare_data(x, y, by=)`,
`generateMismatchData()` → `get_differences()` /
`get_cell_differences()`, `saveReport()` → `render_diff(output_file=)`,
`summary()` → `summary()`, plus the semantic differences worth knowing
(schema-refusal vs intersection matching; extra positional rows reported vs
truncated; tolerance default).

DESCRIPTION keeps the positioning sentence naming the archived dataCompareR
but drops any drop-in/compatibility claim. README comparison table updated
likewise. cran-comments.md drops the archived-Suggests explanation.
`_pkgdown.yml` reference index drops the compat entries.

Record in `dev/` (this spec suffices) that the compat layer lives at the
pre-cut git history and the parity suite passed 128/128 against the real
dataCompareR on 2026-07-06, so a future revival starts from verified code.

## 3. Documentation fixes

1. **`?datadiff_result` topic**: a dedicated roxygen topic (documented on the
   print/summary methods or an `@name datadiff_result` block) covering the
   list structure, the three kinds, print/summary behavior, and pointers to
   the accessors. Added to `_pkgdown.yml` reference index.
2. **`render_diff()` `@return`**: document the `invisible(NULL)` branches
   (identical/schema kinds, zero-row diff) alongside the invisible-path
   return.
3. **`compare_data()` `@return`**: mention `$by` and `$tolerance`; describe
   `$rows` as "a tibble of differing rows plus context" instead of naming the
   internal class; link to the `datadiff_result` topic and accessors.
4. **Print headers**: `"datadiff"` → `"datadiffr"` in
   `print.datadiff_diff` / `print.summary.datadiff_diff`
   (R/diff-class.R:107, :148). Re-render README.Rmd and re-knit vignettes so
   rendered output matches.
5. **NEWS.md**: rewritten as a first-release feature list — no
   changelog-against-prior-version phrasing, no issue references, and the
   compare_data return-value bullets made consistent (it returns a
   `datadiff_result`); accessors and the compat-cut reflected.
6. **cran-comments.md**: re-verify the NOTEs claim after the compat cut
   (expected: only the new-submission NOTE remains); update text.

## 4. Issue hygiene

- Close #21 (comment: shipped as S3 accessors — `has_differences()`,
  `n_differences()`, `summary()`; S7 evaluated and declined, see this spec)
  and #23 (comment: `get_differences()` + `get_cell_differences()`).
- Leave #1, #3, #22, #24, #26 open (post-release).

## 5. Testing & verification

- Accessors are developed test-first: a kind × accessor matrix
  (identical/schema/value for all four), `columns` tidy-select filtering
  (including a no-match selection), one-side-only rows in the cell layout,
  key-column presence under `by=`, zero-row schema stability, truncation
  interaction.
- Compat removal: full test suite green after deletion; `R CMD check
  --as-cran` clean; `pkgdown::check_pkgdown()` clean; README/vignettes
  re-rendered without errors.
- Final gate before submission (outside this spec): win-builder
  devel + release.
