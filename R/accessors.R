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
      !!!xb[differs, c(".row", key_cols)],
      column = col,
      value_x = cell_chr(xb[[col]][differs]),
      value_y = cell_chr(yb[[col]][differs])
    )
    lone <- tibble::tibble(
      !!!singles[c(".row", key_cols)],
      column = col,
      value_x = as.character(ifelse(
        singles$.source == "x",
        cell_chr(singles[[col]]),
        NA_character_
      )),
      value_y = as.character(ifelse(
        singles$.source == "y",
        cell_chr(singles[[col]]),
        NA_character_
      ))
    )
    bind_rows(matched, lone)
  }

  proto <- tibble::tibble(
    !!!rows[0, c(".row", key_cols)],
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
