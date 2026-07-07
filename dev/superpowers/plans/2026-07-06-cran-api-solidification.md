# CRAN API Solidification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the accessor API (`has_differences()`, `n_differences()`, `get_differences()`, `get_cell_differences()`), remove the dataCompareR compat layer from 0.1.0, and fix the pre-submission documentation problems.

**Architecture:** All accessors are S3 generics with `datadiff_result` methods in a new `R/accessors.R`. Cell-level differences are recomputed from the stacked `$rows` tibble with `is_equal()` and the result's stored tolerance (the diff object records differing columns, not per-cell positions). The compat layer (R/rcompare*.R and friends) is deleted outright; git history retains it.

**Tech Stack:** R package; testthat (edition 3), devtools, roxygen2 (markdown), checkmate/rlang/tidyselect/cli/tibble/dplyr (all already in Imports).

**Spec:** `dev/superpowers/specs/2026-07-06-cran-api-solidification-design.md`

## Global Constraints

- S3 only — no S7, no new dependencies.
- Tidyverse style: snake_case, `|>` pipe, roxygen2 with markdown; input validation with checkmate; errors via `cli::cli_abort()`.
- The package name in user-facing output is **datadiffr** (not datadiff).
- Commit after each task. Do NOT `git push` (needs explicit user authorization).
- Run tests with: `R -s -e "devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/<file>')"` (the Makefile's per-file mapping is unreliable). Full suite: `R -s -e "devtools::test(stop_on_failure = TRUE)"`.

---

### Task 1: `has_differences()` and `n_differences()`

**Files:**
- Create: `R/accessors.R`
- Test: `tests/testthat/test-accessors.R`

**Interfaces:**
- Consumes: `compare_data()` returning `datadiff_result` (list: `$kind`, `$columns`, `$rows`, `$by`, `$tolerance`); `attr(x$rows, "n_differences")` (integer count of differing rows).
- Produces: exported S3 generics `has_differences(x, ...)` → `logical(1)` and `n_differences(x, ...)` → `integer(1)`, with `datadiff_result` methods. Later tasks reference these names in docs and vignettes.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-accessors.R`:

```r
# Accessors: the supported programmatic surface of a datadiff_result, so user
# code never reaches into the object's attributes or bookkeeping columns.

test_that("has_differences reports each result kind", {
  x <- tibble(a = 1:3)

  expect_false(has_differences(compare_data(x, x)))
  expect_true(has_differences(compare_data(x, tibble(a = c(1L, 9L, 3L)))))
  expect_true(has_differences(compare_data(x, tibble(b = 1:3))))
})

test_that("n_differences counts differing rows", {
  x <- tibble(a = 1:4)
  y <- tibble(a = c(1L, 9L, 3L, 8L))

  expect_identical(n_differences(compare_data(x, y)), 2L)
  expect_identical(n_differences(compare_data(x, x)), 0L)
})

test_that("n_differences is NA for schema results", {
  result <- compare_data(tibble(a = 1), tibble(b = 1))

  expect_identical(n_differences(result), NA_integer_)
})

test_that("n_differences counts all differing rows even when truncated", {
  x <- tibble(a = 1:5)
  y <- tibble(a = c(9L, 8L, 7L, 6L, 5L))

  result <- suppressMessages(compare_data(x, y, max_differences = 2))

  # rows 1-4 differ (5 == 5 does not); the cap truncates reporting, not the count
  expect_identical(n_differences(result), 4L)
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `R -s -e "devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-accessors.R')"`
Expected: FAIL with `could not find function "has_differences"`.

- [ ] **Step 3: Write the implementation**

Create `R/accessors.R`:

```r
#' Test for and count differences in a comparison result
#'
#' `has_differences()` reports whether a comparison found any differences,
#' in values or in the frames' columns. `n_differences()` counts the
#' differing rows a value comparison found.
#'
#' @param x A [datadiff_result] from [compare_data()] or [diffdata()].
#' @param ... Passed on to methods.
#' @return `has_differences()` returns `TRUE` or `FALSE`. `n_differences()`
#'   returns the number of differing rows as an integer: `0L` when the
#'   frames are identical, and `NA_integer_` for a `"schema"` result (values
#'   were never compared). Truncation via `max_differences` does not affect
#'   the count; every differing row found is counted.
#' @seealso [get_differences()] to extract the differences themselves.
#' @examples
#' x <- data.frame(id = 1:4, score = c(10, 20, 30, 40))
#' y <- data.frame(id = 1:4, score = c(10, 25, 30, 45))
#'
#' result <- compare_data(x, y)
#' has_differences(result)
#' n_differences(result)
#' @export
has_differences <- function(x, ...) {
  UseMethod("has_differences")
}

#' @export
has_differences.datadiff_result <- function(x, ...) {
  x$kind != "identical"
}

#' @rdname has_differences
#' @export
n_differences <- function(x, ...) {
  UseMethod("n_differences")
}

#' @export
n_differences.datadiff_result <- function(x, ...) {
  if (x$kind == "schema") {
    return(NA_integer_)
  }
  as.integer(attr(x$rows, "n_differences"))
}
```

- [ ] **Step 4: Document and run tests to verify they pass**

Run: `R -s -e "devtools::document()"` then
`R -s -e "devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-accessors.R')"`
Expected: all PASS. NAMESPACE gains `export(has_differences)`, `export(n_differences)`, and the two S3method lines.

- [ ] **Step 5: Commit**

```bash
git add R/accessors.R tests/testthat/test-accessors.R NAMESPACE man/
git commit -m "Add has_differences() and n_differences() accessors (#21)"
```

---

### Task 2: `get_differences()` and `get_cell_differences()`

**Files:**
- Modify: `R/accessors.R` (append)
- Test: `tests/testthat/test-accessors.R` (append)

**Interfaces:**
- Consumes: `datadiff_result` structure; `is_equal(x, y, tolerance)`; `$rows` layout — stacked tibble with bookkeeping columns `.row` (int), `.join_type` (`"both"`/`"x"`/`"y"`), `.diff_type` (`"diff"`/`"context"`), `.source` (`"x"`/`"y"`/`NA`); key columns (when `by=` was used) are always present in `$rows`.
- Produces: exported S3 generics `get_differences(x, columns = NULL, ...)` (row-oriented tibble: `.row`, `.source`, data columns, native types) and `get_cell_differences(x, columns = NULL, ...)` (cell-oriented tibble: `.row`, key columns, `column`, `value_x`, `value_y`, values as character). Both documented in one topic named `get_differences`.

- [ ] **Step 1: Write the failing tests for `get_differences()`**

Append to `tests/testthat/test-accessors.R`:

```r
test_that("get_differences returns differing rows without context", {
  x <- tibble(id = 1:4, score = c(10, 20, 30, 40))
  y <- tibble(id = 1:4, score = c(10, 25, 30, 40))

  out <- get_differences(compare_data(x, y))

  expect_s3_class(out, "tbl_df")
  expect_false(inherits(out, "datadiff_diff"))
  expect_named(out, c(".row", ".source", "id", "score"))
  expect_setequal(out$.row, 2L)
  expect_setequal(out$.source, c("x", "y"))
})

test_that("get_differences filters rows by selected columns", {
  x <- tibble(
    id = 1:4,
    score = c(10, 20, 30, 40),
    name = c("ann", "bob", "cara", "dan")
  )
  y <- tibble(
    id = 1:4,
    score = c(10, 25, 30, 40),
    name = c("ann", "bob", "cara", "dana")
  )
  result <- compare_data(x, y)

  expect_setequal(get_differences(result)$.row, c(2L, 4L))
  expect_setequal(get_differences(result, columns = score)$.row, 2L)
  expect_setequal(get_differences(result, columns = name)$.row, 4L)
})

test_that("get_differences keeps one-sided rows under any column selection", {
  x <- tibble(id = 1:3, score = c(10, 20, 30))
  y <- tibble(id = 1:2, score = c(10, 20))

  out <- get_differences(compare_data(x, y), columns = score)

  expect_equal(out$.row, 3L)
  expect_equal(out$.source, "x")
})

test_that("get_differences preserves native column types", {
  x <- tibble(id = 1:3, when = as.Date("2026-01-01") + 0:2)
  y <- tibble(id = 1:3, when = as.Date("2026-01-01") + c(0, 9, 2))

  out <- get_differences(compare_data(x, y))

  expect_s3_class(out$when, "Date")
})

test_that("get_differences on an identical result is an empty stable tibble", {
  x <- tibble(id = 1:3, score = c(1, 2, 3))

  out <- get_differences(compare_data(x, x))

  expect_identical(nrow(out), 0L)
  expect_named(out, c(".row", ".source", "id", "score"))
})

test_that("get_differences errors on schema results with guidance", {
  result <- compare_data(tibble(a = 1), tibble(b = 1))

  expect_error(get_differences(result), "schema")
})
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `R -s -e "devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-accessors.R')"`
Expected: Task-1 tests PASS; new tests FAIL with `could not find function "get_differences"`.

- [ ] **Step 3: Implement `get_differences()` and its internal helpers**

Append to `R/accessors.R`:

```r
#' Extract the differences from a comparison result
#'
#' `get_differences()` returns the differing rows (context rows excluded) in
#' the stacked layout the package prints: each changed row appears twice,
#' the `x` version above the `y` version, with native column types
#' preserved. `get_cell_differences()` returns one row per differing cell,
#' with the two values side by side as character.
#'
#' @param x A [datadiff_result] from [compare_data()] or [diffdata()].
#' @param columns <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional
#'   selection of compared columns. `get_differences()` keeps rows that
#'   differ in at least one selected column (rows present in only one frame
#'   differ in every column, so they are always kept);
#'   `get_cell_differences()` keeps cells from the selected columns.
#' @param ... Passed on to methods.
#' @return A tibble. `get_differences()`: `.row` (the row number the
#'   difference came from), `.source` (`"x"` or `"y"`), and the data
#'   columns. `get_cell_differences()`: `.row`, the key columns (when the
#'   comparison used `by =`), `column`, `value_x`, and `value_y`; values are
#'   rendered as character (`NA` when the value is `NA` or the row exists in
#'   only one frame — use `get_differences()` when native types or that
#'   distinction matter). Both error on a `"schema"` result and return a
#'   zero-row tibble for an `"identical"` one. A comparison truncated by
#'   `max_differences` yields only the reported rows; compare with
#'   `max_differences = Inf` to extract everything.
#' @examples
#' x <- data.frame(id = 1:4, score = c(10, 20, 30, 40))
#' y <- data.frame(id = 1:4, score = c(10, 25, 30, 45))
#'
#' result <- compare_data(x, y, by = "id")
#' get_differences(result)
#' get_cell_differences(result)
#' get_differences(result, columns = score)
#' @export
get_differences <- function(x, columns = NULL, ...) {
  UseMethod("get_differences")
}

#' @export
get_differences.datadiff_result <- function(x, columns = NULL, ...) {
  abort_schema_result(x)
  rows <- tibble::as_tibble(x$rows)
  rows <- rows[rows$.diff_type == "diff", ]

  selection <- rlang::enquo(columns)
  if (!rlang::quo_is_null(selection)) {
    wanted <- resolve_diff_columns(x, selection)
    cells <- diff_cells(x)
    rows <- rows[rows$.row %in% cells$.row[cells$column %in% wanted], ]
  }

  rows$.join_type <- NULL
  rows$.diff_type <- NULL
  rows
}

# Shared guard: value extraction is meaningless when values were never
# compared.
abort_schema_result <- function(x, call = rlang::caller_env()) {
  if (x$kind == "schema") {
    cli::cli_abort(
      c(
        "Can't extract differences from a schema result.",
        i = "The frames' columns differ; inspect {.code $columns} or run {.fun compare_columns}."
      ),
      call = call
    )
  }
}

# Resolve the `columns` tidy-select against the compared (non-key,
# non-bookkeeping) columns of the result.
resolve_diff_columns <- function(x, selection) {
  value_cols <- diff_value_columns(x)
  proto <- tibble::as_tibble(x$rows)[value_cols]
  names(tidyselect::eval_select(selection, data = proto))
}

diff_value_columns <- function(x) {
  setdiff(
    names(x$rows),
    c(".row", ".join_type", ".diff_type", ".source", x$by)
  )
}

# One row per differing cell, recomputed from the stacked diff rows with the
# result's tolerance (the diff object records differing columns, not cells).
diff_cells <- function(x) {
  rows <- tibble::as_tibble(x$rows)
  rows <- rows[rows$.diff_type == "diff", ]
  key_cols <- x$by %||% character()
  value_cols <- diff_value_columns(x)

  xs <- rows[rows$.source == "x", ]
  ys <- rows[rows$.source == "y", ]
  both_ids <- intersect(xs$.row, ys$.row)
  xb <- xs[match(both_ids, xs$.row), ]
  yb <- ys[match(both_ids, ys$.row), ]
  singles <- rows[!rows$.row %in% both_ids, ]

  one_column <- function(col) {
    differs <- !is_equal(xb[[col]], yb[[col]], tolerance = x$tolerance)
    matched <- tibble::tibble(
      xb[differs, c(".row", key_cols)],
      column = col,
      value_x = cell_chr(xb[[col]][differs]),
      value_y = cell_chr(yb[[col]][differs])
    )
    lone <- tibble::tibble(
      singles[c(".row", key_cols)],
      column = col,
      value_x = ifelse(
        singles$.source == "x",
        cell_chr(singles[[col]]),
        NA_character_
      ),
      value_y = ifelse(
        singles$.source == "y",
        cell_chr(singles[[col]]),
        NA_character_
      )
    )
    bind_rows(matched, lone)
  }

  proto <- tibble::tibble(
    rows[0, c(".row", key_cols)],
    column = character(),
    value_x = character(),
    value_y = character()
  )
  bind_rows(proto, lapply(value_cols, one_column)) |>
    arrange(.data$.row, match(.data$column, value_cols))
}

# Character rendering for cell values: NA stays NA, list-column elements
# collapse to one string. get_differences() preserves native types; this
# rendering exists only because mixed source types cannot share a typed
# column.
cell_chr <- function(v) {
  vapply(
    seq_along(v),
    function(i) {
      e <- if (is.list(v)) v[[i]] else v[i]
      if (is.atomic(e) && length(e) == 1L && is.na(e)) {
        return(NA_character_)
      }
      paste(format(e), collapse = ", ")
    },
    character(1)
  )
}
```

- [ ] **Step 4: Run tests to verify the `get_differences()` tests pass**

Run: `R -s -e "devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-accessors.R')"`
Expected: all PASS.

- [ ] **Step 5: Write the failing tests for `get_cell_differences()`**

Append to `tests/testthat/test-accessors.R`:

```r
test_that("get_cell_differences returns one row per differing cell", {
  x <- tibble(
    id = 1:4,
    score = c(10, 20, 30, 40),
    name = c("ann", "bob", "cara", "dan")
  )
  y <- tibble(
    id = 1:4,
    score = c(10, 25, 30, 40),
    name = c("ann", "bob", "cara", "dana")
  )

  out <- get_cell_differences(compare_data(x, y))

  expect_named(out, c(".row", "column", "value_x", "value_y"))
  expect_equal(nrow(out), 2L)
  expect_equal(out$.row, c(2L, 4L))
  expect_equal(out$column, c("score", "name"))
  expect_equal(out$value_x, c("20", "dan"))
  expect_equal(out$value_y, c("25", "dana"))
})

test_that("get_cell_differences includes key columns under keyed comparison", {
  x <- tibble(id = c("a", "b", "c"), score = 1:3)
  y <- tibble(id = c("a", "b", "c"), score = c(1L, 9L, 3L))

  out <- get_cell_differences(compare_data(x, y, by = "id"))

  expect_named(out, c(".row", "id", "column", "value_x", "value_y"))
  expect_equal(out$id, "b")
  expect_equal(out$column, "score")
})

test_that("one-sided rows appear with NA on the missing side", {
  x <- tibble(id = 1:3, score = c(10, 20, 30))
  y <- tibble(id = 1:2, score = c(10, 20))

  out <- get_cell_differences(compare_data(x, y))
  row3 <- out[out$.row == 3L, ]

  expect_setequal(row3$column, c("id", "score"))
  expect_true(all(is.na(row3$value_y)))
  expect_equal(row3$value_x[row3$column == "score"], "30")
})

test_that("get_cell_differences respects the comparison tolerance", {
  x <- tibble(a = c(1, 2))
  y <- tibble(a = c(1.05, 3))

  out <- get_cell_differences(compare_data(x, y, tolerance = 0.1))

  expect_equal(out$.row, 2L)
  expect_equal(nrow(out), 1L)
})

test_that("get_cell_differences filters cells by selected columns", {
  x <- tibble(score = c(10, 20), name = c("ann", "bob"))
  y <- tibble(score = c(11, 20), name = c("ann", "rob"))
  result <- compare_data(x, y)

  out <- get_cell_differences(result, columns = name)

  expect_equal(out$column, "name")
  expect_equal(out$.row, 2L)
})

test_that("get_cell_differences is empty-but-stable for identical frames", {
  x <- tibble(id = 1:3, score = c(1, 2, 3))

  out <- get_cell_differences(compare_data(x, x))

  expect_identical(nrow(out), 0L)
  expect_named(out, c(".row", "column", "value_x", "value_y"))
})

test_that("get_cell_differences errors on schema results", {
  result <- compare_data(tibble(a = 1), tibble(b = 1))

  expect_error(get_cell_differences(result), "schema")
})
```

- [ ] **Step 6: Run tests to verify the new ones fail**

Run: `R -s -e "devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-accessors.R')"`
Expected: FAIL with `could not find function "get_cell_differences"`.

- [ ] **Step 7: Implement `get_cell_differences()`**

Append to `R/accessors.R`:

```r
#' @rdname get_differences
#' @export
get_cell_differences <- function(x, columns = NULL, ...) {
  UseMethod("get_cell_differences")
}

#' @export
get_cell_differences.datadiff_result <- function(x, columns = NULL, ...) {
  abort_schema_result(x)
  cells <- diff_cells(x)

  selection <- rlang::enquo(columns)
  if (!rlang::quo_is_null(selection)) {
    wanted <- resolve_diff_columns(x, selection)
    cells <- cells[cells$column %in% wanted, ]
  }

  cells
}
```

- [ ] **Step 8: Document, run the full suite**

Run: `R -s -e "devtools::document()"` then `R -s -e "devtools::test(stop_on_failure = TRUE)"`
Expected: all tests pass (compat suites still present and green).

- [ ] **Step 9: Commit**

```bash
git add R/accessors.R tests/testthat/test-accessors.R NAMESPACE man/
git commit -m "Add get_differences() and get_cell_differences() (#23)"
```

---

### Task 3: Remove the dataCompareR compat layer

**Files:**
- Delete: `R/rcompare.R`, `R/rcompare-methods.R`, `R/rcompare-output.R`, `tests/testthat/test-rcompare.R`, `tests/testthat/test-rcompare-methods.R`, `tests/testthat/test-rcompare-output.R`, `tests/testthat/test-rcompare-parity.R`, `tests/testthat/helper-rcompare.R`
- Modify: `R/diff.R:97-99` and `R/diff.R:116-127`, `DESCRIPTION:32`, `.lintr`, `.github/workflows/R-CMD-check.yaml:43-52`, `.github/workflows/pkgdown.yaml:43-51`, `_pkgdown.yml`

**Interfaces:**
- Consumes: nothing from Tasks 1-2.
- Produces: package without `rCompare`/`saveReport`/`generateMismatchData`/`datadiff_compare`. NOTE: `vignettes/migrating-from-datacomparer.Rmd` still calls `rCompare()` after this task — vignettes are not run by `devtools::test()`, and Task 4 fixes the vignette before any full `R CMD check` runs (Task 7).

- [ ] **Step 1: Delete the compat sources and tests**

```bash
git rm R/rcompare.R R/rcompare-methods.R R/rcompare-output.R \
  tests/testthat/test-rcompare.R tests/testthat/test-rcompare-methods.R \
  tests/testthat/test-rcompare-output.R tests/testthat/test-rcompare-parity.R \
  tests/testthat/helper-rcompare.R
```

- [ ] **Step 2: Remove the `render_diff.datadiff_compare` method and its doc mention**

In `R/diff.R`, delete this block (lines 116-127):

```r
#' @rdname render_diff
#' @export
render_diff.datadiff_compare <- function(diff, output_file = NULL) {
  frames <- attr(diff, "cleaned")
  data_diff <- compare_data(
    frames$a,
    frames$b,
    by = frames$keys,
    tolerance = attr(diff, "tolerance")
  )
  render_diff(data_diff, output_file = output_file)
}
```

And change the `@param diff` line (currently lines 97-99) from:

```r
#' @param diff A `datadiff_result` (from [compare_data()]), a `datadiff_compare`
#'   (from [rCompare()]), or a bare diff data frame containing `.row`,
#'   `.join_type`, `.diff_type`, and `.source` columns.
```

to:

```r
#' @param diff A `datadiff_result` (from [compare_data()]) or a bare diff
#'   data frame containing `.row`, `.join_type`, `.diff_type`, and `.source`
#'   columns.
```

- [ ] **Step 3: Remove dataCompareR from DESCRIPTION Suggests**

Delete the line `    dataCompareR,` from `DESCRIPTION`.

- [ ] **Step 4: Drop the .lintr exclusions**

Replace the whole content of `.lintr` with:

```
encoding: "UTF-8"
linters: linters_with_defaults(
    line_length_linter = line_length_linter(120),
    object_usage_linter = NULL  # Disable "no visible binding" warnings (common with NSE in packages)
  )
```

- [ ] **Step 5: Remove the CRAN-archive installs from both workflows**

In `.github/workflows/R-CMD-check.yaml`, replace lines 43-52:

```yaml
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          # dataCompareR was archived from CRAN (2026-02); install the last
          # released version from the CRAN archive so the conditional parity
          # tests (skip_if_not_installed) can run and dependency resolution
          # doesn't fail on the missing Suggests.
          extra-packages: |
            any::rcmdcheck
            url::https://cran.r-project.org/src/contrib/Archive/dataCompareR/dataCompareR_0.1.4.tar.gz
          needs: check
```

with:

```yaml
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::rcmdcheck
          needs: check
```

In `.github/workflows/pkgdown.yaml`, replace lines 43-51:

```yaml
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          # dataCompareR is an archived Suggests (see R-CMD-check.yaml); install
          # it from the CRAN archive so dependency resolution succeeds.
          extra-packages: |
            any::pkgdown
            local::.
            url::https://cran.r-project.org/src/contrib/Archive/dataCompareR/dataCompareR_0.1.4.tar.gz
          needs: website
```

with:

```yaml
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: |
            any::pkgdown
            local::.
          needs: website
```

- [ ] **Step 6: Remove the compat section from `_pkgdown.yml`**

Delete this whole block:

```yaml
- title: dataCompareR compatibility
  desc: >
    Clean-room drop-in replacements for the archived dataCompareR package,
    returning objects with the same shape.
  contents:
  - rCompare
  - generateMismatchData
  - saveReport
  - print.datadiff_compare
  - summary.datadiff_compare
```

- [ ] **Step 7: Regenerate docs and hunt stragglers**

Run: `R -s -e "devtools::document()"` — roxygen removes the compat `man/*.Rd` files and NAMESPACE entries.
Run: `grep -rn "rCompare\|datadiff_compare\|dataCompareR" R/ tests/ man/ NAMESPACE` — expected: **no matches**. If any test outside the deleted files references the compat layer (e.g. a `render_diff.datadiff_compare` bridge test), delete that test block too.

- [ ] **Step 8: Run the full suite**

Run: `R -s -e "devtools::test(stop_on_failure = TRUE)"`
Expected: all remaining tests pass, zero skips related to dataCompareR.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Remove the dataCompareR compat layer from 0.1.0

Deferred, not abandoned: the clean-room implementation (verified 128/128
against the real dataCompareR on 2026-07-06) lives in git history at this
commit's parent, ready for a 0.2.0 revival or a standalone package. See
dev/superpowers/specs/2026-07-06-cran-api-solidification-design.md."
```

---

### Task 4: Rewrite the migration vignette; update the Get-started vignette

**Files:**
- Modify: `vignettes/migrating-from-datacomparer.Rmd` (full rewrite), `vignettes/datadiffr.Rmd:56-70` and `vignettes/datadiffr.Rmd:186-190`

**Interfaces:**
- Consumes: `get_differences()`, `get_cell_differences()`, `has_differences()`, `n_differences()` (Tasks 1-2); compat layer already gone (Task 3).
- Produces: vignettes that build without dataCompareR or `rCompare()`.

- [ ] **Step 1: Replace the full content of `vignettes/migrating-from-datacomparer.Rmd`**

The file's content starts at `---` and ends after the last bullet:

````markdown
---
title: "Migrating from dataCompareR"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Migrating from dataCompareR}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)
```

dataCompareR was archived by CRAN in February 2026 and its repository is
read-only. datadiffr covers the same workflow — compare two data frames,
summarize the result, extract the mismatches, save a report — with a
smaller, snake_case API. This guide maps each dataCompareR call to its
datadiffr equivalent.

## Call-by-call mapping

| dataCompareR | datadiffr |
|---------------------------------------------|--------------------------------------------------|
| `rCompare(dfA, dfB)` | `compare_data(x, y)` |
| `rCompare(dfA, dfB, keys = "id")` | `compare_data(x, y, by = "id")` |
| `rCompare(dfA, dfB, roundDigits = 2)` | `compare_data(x, y, tolerance = 0.005)` |
| `rCompare(dfA, dfB, trimChars = TRUE)` | trim first: `mutate(across(where(is.character), trimws))` |
| `summary(comparison)` | `summary(result)` |
| `comparison$mismatches` | `get_cell_differences(result)` |
| `generateMismatchData(comparison, dfA, dfB)` | `get_differences(result)` |
| `saveReport(comparison, "report")` | `render_diff(result, output_file = "report.html")` |

A worked example:

```{r}
library(datadiffr)

x <- data.frame(id = 1:4, score = c(10, 20, 30, 40))
y <- data.frame(id = 1:4, score = c(10, 25, 30, 45))

result <- compare_data(x, y, by = "id")
summary(result)

get_cell_differences(result)
```

## Differences worth knowing

* **Column mismatches.** dataCompareR silently compared the intersection of
  columns, matching names case-insensitively. datadiffr treats column
  differences as a result in their own right: `compare_data()` returns a
  `"schema"` result describing them (see `compare_columns()`) and does not
  compare values. To compare anyway, select the shared columns first.
* **Extra rows under positional matching.** dataCompareR truncated the
  longer frame; datadiffr reports the extra rows as differences.
* **Rounding vs tolerance.** `roundDigits = k` is approximately
  `tolerance = 0.5 * 10^-k`. Rounding can still call two nearly-equal
  values different when they round apart; tolerance compares distance
  directly.
* **Reports.** `render_diff()` and `diffdata()` produce a styled HTML diff
  with context rows rather than a text report; `summary(result)` covers the
  console.
````

- [ ] **Step 2: Update the Get-started vignette's internals description**

In `vignettes/datadiffr.Rmd`, replace lines 56-70 (from `` `"value"` means the two frames share `` through `...like a unified diff.`) with:

````markdown
`"value"` means the two frames share the same columns but some values differ.
(The other kinds are `"identical"`, when the frames match, and `"schema"`, when
the columns themselves differ — see [When the columns themselves
differ](#when-the-columns-themselves-differ) below.)

## Extracting differences

Four accessors expose the result programmatically. `has_differences()` and
`n_differences()` answer the quick questions:

```{r}
has_differences(diff)
n_differences(diff)
```

`get_differences()` returns the differing rows: each changed row appears
twice — the `"x"` (before) version above the `"y"` (after) version, like a
unified diff — with `.row` recording the row number it came from.
`get_cell_differences()` returns one row per changed cell:

```{r}
get_differences(diff)
get_cell_differences(diff)
```

Both accept a tidyselect `columns` argument to focus on particular columns,
for example `get_differences(diff, columns = score)`.
````

- [ ] **Step 3: Update the Get-started vignette's dataCompareR pointer**

In `vignettes/datadiffr.Rmd`, replace lines 186-190 (the `## Coming from dataCompareR?` section) with:

```markdown
## Coming from dataCompareR?

datadiffr covers the archived dataCompareR package's workflow with a smaller
API. See `vignette("migrating-from-datacomparer")` for a call-by-call
mapping.
```

- [ ] **Step 4: Build the vignettes to verify they knit**

Run: `R -s -e "devtools::build_vignettes(quiet = FALSE)"`
Expected: both vignettes build without error. (This also catches any stale `rCompare()` chunk.) Clean up: `git checkout -- doc/ Meta/ 2>/dev/null || true` if devtools leaves build artifacts outside `.gitignore`.

- [ ] **Step 5: Commit**

```bash
git add vignettes/
git commit -m "Vignettes: dataCompareR concept mapping; accessors in Get started"
```

---

### Task 5: `datadiff_result` topic, `@return` fixes, print-header rename

**Files:**
- Modify: `R/diff-class.R` (topic block + two header strings), `R/diff.R:103-104` (`@return`), `R/compare.R:22-26` (`@return`), `_pkgdown.yml` (reference additions)
- Test: existing suites (grep for header expectations)

**Interfaces:**
- Consumes: accessor names from Tasks 1-2 (cross-references).
- Produces: `man/datadiff_result.Rd`; pkgdown index covering every topic.

- [ ] **Step 1: Add the `datadiff_result` topic**

At the top of `R/diff-class.R` (after the file's opening comment, before `new_datadiff_diff`), insert:

```r
#' The result of a data frame comparison
#'
#' [compare_data()] and [diffdata()] return a `datadiff_result`: a list
#' carrying one comparison outcome and the settings that produced it, with
#' `print()` and `summary()` methods.
#'
#' @details
#' A `datadiff_result` has five elements:
#'
#' * `kind` — `"identical"` (no differences), `"schema"` (the frames'
#'   column names or types differ, so values were not compared), or
#'   `"value"` (row-level differences were found).
#' * `columns` — for `"schema"` results, the [compare_columns()] tibble
#'   describing the column differences; otherwise `NULL`.
#' * `rows` — for `"value"` and `"identical"` results, a tibble of the
#'   differing rows plus surrounding context rows; otherwise `NULL`.
#' * `by` — the key columns rows were matched on, or `NULL` for positional
#'   matching.
#' * `tolerance` — the numeric tolerance the comparison used.
#'
#' For programmatic access prefer the accessors — [has_differences()],
#' [n_differences()], [get_differences()], and [get_cell_differences()] —
#' over indexing into `rows`: the bookkeeping columns inside `rows`
#' (`.row`, `.join_type`, `.diff_type`, `.source`) and its attributes are
#' internal and may change.
#'
#' @examples
#' x <- data.frame(id = 1:4, score = c(10, 20, 30, 40))
#' y <- data.frame(id = 1:4, score = c(10, 25, 30, 45))
#'
#' result <- compare_data(x, y)
#' result$kind
#' summary(result)
#' @name datadiff_result
NULL
```

- [ ] **Step 2: Fix the print headers**

In `R/diff-class.R`, change both `format_inline` header strings (in `print.datadiff_diff`, line 107, and `print.summary.datadiff_diff`, line 148) from `"{.strong datadiff}: ..."` to `"{.strong datadiffr}: ..."`.
Then run `grep -rn "datadiff:" tests/` — update any test expecting the old header text (expected in `tests/testthat/test-diff-class.R` print-method tests, if present).

- [ ] **Step 3: Fix `render_diff()`'s `@return`**

In `R/diff.R`, replace lines 103-104:

```r
#' @return Invisibly returns the path to the HTML file (either `output_file` if
#'   provided, or a temporary file path).
```

with:

```r
#' @return For a `"value"` result (or a bare diff with rows), invisibly
#'   returns the path to the HTML file — `output_file` if provided, a
#'   temporary file otherwise. For `"identical"` and `"schema"` results and
#'   zero-row diffs nothing is rendered and `invisible(NULL)` is returned.
```

- [ ] **Step 4: Fix `compare_data()`'s `@return`**

In `R/compare.R`, replace lines 22-26:

```r
#' @return A `datadiff_result` object. `$kind` is `"identical"`, `"schema"`, or
#'   `"value"`. For `"schema"` (the frames have different column names or types)
#'   `$columns` holds a [compare_columns()] tibble and `$rows` is `NULL`. For
#'   `"value"`/`"identical"` `$rows` holds a `datadiff_diff` of the differences
#'   (empty when identical) and `$columns` is `NULL`.
```

with:

```r
#' @return A [datadiff_result] object: a list with elements `$kind`
#'   (`"identical"`, `"schema"`, or `"value"`), `$columns`, `$rows`, `$by`,
#'   and `$tolerance`. For `"schema"` (the frames have different column names
#'   or types) `$columns` holds a [compare_columns()] tibble and `$rows` is
#'   `NULL`; otherwise `$rows` holds a tibble of the differing rows plus
#'   context (empty when identical) and `$columns` is `NULL`. Use
#'   [get_differences()] and friends to extract the differences.
```

- [ ] **Step 5: Add the new topics to `_pkgdown.yml`**

After the `- title: Comparison` section, insert:

```yaml
- title: Results
  desc: The comparison result object and its accessors.
  contents:
  - datadiff_result
  - has_differences
  - get_differences
```

(`has_differences` covers the `n_differences` alias; `get_differences` covers `get_cell_differences`.)

- [ ] **Step 6: Document, test, verify pkgdown**

Run: `R -s -e "devtools::document()"` then `R -s -e "devtools::test(stop_on_failure = TRUE)"` then `R -s -e "pkgdown::check_pkgdown()"`
Expected: tests pass; `check_pkgdown()` reports no problems (all topics indexed).

- [ ] **Step 7: Commit**

```bash
git add R/ man/ _pkgdown.yml tests/
git commit -m "Docs: datadiff_result topic, accurate @return docs, datadiffr print header"
```

---

### Task 6: NEWS, README, cran-comments

**Files:**
- Modify: `NEWS.md` (full rewrite), `README.Rmd:94-99`, `cran-comments.md`
- Regenerate: `README.md`

**Interfaces:**
- Consumes: accessor names; compat removal.
- Produces: release-ready prose. README regeneration requires the Task 5 print-header fix (rendered output shows the header).

- [ ] **Step 1: Rewrite `NEWS.md`**

Replace the full content with:

```markdown
# datadiffr 0.1.0

First release.

datadiffr compares two data frames and reports the differences cell by cell,
with configurable context rows around each change, as a styled self-contained
HTML report.

* `compare_data()` compares two data frames — matching rows by position or by
  key columns (`by =`) — and returns a `datadiff_result`, whose `kind`
  reports whether the frames are `"identical"`, differ in their columns
  (`"schema"`), or differ in their values (`"value"`), with `print()` and
  `summary()` methods.
* Accessors extract results programmatically: `has_differences()` and
  `n_differences()` for quick checks, `get_differences()` for the differing
  rows, and `get_cell_differences()` for one row per changed cell.
* `diffdata()` runs the comparison and renders it as an HTML report in the
  RStudio viewer, browser, or a file; `render_diff()` renders an existing
  result.
* `compare_columns()` reports column name and type differences;
  `compare_groups()` compares group membership between two frames.
* `is_equal()` provides tolerance-aware, vectorized equality that handles
  `NA`, `NaN`, and infinite values, and compares factors, dates, datetimes,
  and list-columns sensibly. Tolerance applies on the natural scale for dates
  (days) and datetimes (seconds).
* Comparisons report configurable context rows around each change
  (`context_rows`), selectable context columns (`context_cols`), and a cap on
  reported differences (`max_differences`).
```

- [ ] **Step 2: Update README.Rmd's migration section**

Replace lines 94-99 (the `## Migrating from dataCompareR` section) with:

```markdown
## Migrating from dataCompareR

datadiffr covers the archived dataCompareR workflow — key-matched comparison,
summaries, mismatch extraction, and saved reports — with a smaller API. See
`vignette("migrating-from-datacomparer")` for a call-by-call mapping.
```

Leave the comparison-table row for dataCompareR (line 87) unchanged — it describes the competitor, not a compatibility claim.

- [ ] **Step 3: Update `cran-comments.md`**

Remove the entire `**Suggests or Enhances not in mainstream repositories: dataCompareR.**` bullet (the "New submission" bullet stays). Leave the rest; Task 7 re-verifies the check-results claim.

- [ ] **Step 4: Re-render the README**

Run: `R -s -e "devtools::build_readme()"`
Expected: `README.md` regenerates; the rendered example output now shows the `datadiffr:` header (not `datadiff:`). Verify: `grep -n "datadiff:" README.md` → no matches; `grep -n "datadiffr:" README.md` → at least one.

- [ ] **Step 5: Commit**

```bash
git add NEWS.md README.Rmd README.md cran-comments.md
git commit -m "Release prose: first-release NEWS, README migration section, cran-comments"
```

---

### Task 7: Full verification, renv sync, issue hygiene

**Files:**
- Modify: `renv.lock` (via snapshot), possibly `inst/WORDLIST`, possibly `cran-comments.md` (results line)

**Interfaces:**
- Consumes: everything above.
- Produces: a submission-ready tree; issues #21/#23 closed.

- [ ] **Step 1: Lint and spell check**

Run: `R -s -e "lintr::lint_package()"` → expected: no lints.
Run: `R -s -e "spelling::spell_check_package()"` → expected: no words. If obsolete WORDLIST entries remain (e.g. `keyless`, `reimplemented` were compat-only), remove them from `inst/WORDLIST` and re-run until clean; add any new legitimate words (e.g. `tidyselect` variants) instead of misspelling fixes.

- [ ] **Step 2: Full check as CRAN**

Run: `R -s -e "devtools::check(args = c('--as-cran'), error_on = 'never')"`
Expected: 0 errors, 0 warnings, 0 notes. If the note count differs from cran-comments.md's claim, update `cran-comments.md` to match reality.

- [ ] **Step 3: Sync renv**

Run: `make snapshot`
Expected: `renv.lock` updates (dataCompareR dropped). Commit says what changed.

- [ ] **Step 4: Verify pkgdown end-to-end**

Run: `R -s -e "pkgdown::build_site(preview = FALSE)"` then `git status docs/` — the build output in `docs/` is `.Rbuildignore`d and pkgdown-owned; leave it as the site workflow will rebuild in CI. Expected: build completes; reference index includes Results section.

- [ ] **Step 5: Commit and close issues**

```bash
git add -A
git commit -m "Pre-CRAN verification pass: renv sync, wordlist, cran-comments"
gh issue close 21 --comment "Shipped as S3 accessors in 0.1.0: has_differences(), n_differences(), plus summary() methods on datadiff_result. S7 was evaluated and declined — rationale in dev/superpowers/specs/2026-07-06-cran-api-solidification-design.md."
gh issue close 23 --comment "Shipped in 0.1.0: get_differences() (row-oriented) and get_cell_differences() (cell-oriented), both with tidyselect columns= filtering. The bit-field idea proved unnecessary — cells are recomputed from the stored diff with the result's tolerance."
```

- [ ] **Step 6: Report status**

Summarize: test count, check results, what's left before submission (win-builder devel+release, then submit).
