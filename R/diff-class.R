# The classed object returned by compare_data(). It is an ordinary tibble of
# diff rows with extra attributes recording how the diff was produced, so the
# renderer and any downstream code read the tolerance and truncation state
# from the object instead of re-deriving them.

new_datadiff_diff <- function(
  x,
  tolerance,
  diff_columns,
  n_differences,
  truncated
) {
  attr(x, "tolerance") <- tolerance
  attr(x, "diff_columns") <- diff_columns
  attr(x, "n_differences") <- n_differences
  attr(x, "truncated") <- truncated
  class(x) <- c("datadiff_diff", class(x))
  x
}

# The consolidated object returned by compare_data(). Exactly one facet is
# populated, keyed by `kind`: "schema" fills `columns` (a compare_columns
# tibble), "value"/"identical" fill `rows` (a datadiff_diff; empty for
# "identical"). `by` and `tolerance` record how the comparison was run.
new_datadiff_result <- function(
  kind,
  columns = NULL,
  rows = NULL,
  by = NULL,
  tolerance = NULL
) {
  structure(
    list(
      kind = kind,
      columns = columns,
      rows = rows,
      by = by,
      tolerance = tolerance
    ),
    class = "datadiff_result"
  )
}

# Count changed / added / removed rows from the diff rows of the object.
datadiff_diff_counts <- function(x) {
  diff_rows <- x[x$.diff_type == "diff", ]
  list(
    changed = length(unique(diff_rows$.row[diff_rows$.join_type == "both"])),
    added = length(unique(diff_rows$.row[diff_rows$.join_type == "y"])),
    removed = length(unique(diff_rows$.row[diff_rows$.join_type == "x"]))
  )
}

#' @export
print.datadiff_diff <- function(x, ...) {
  counts <- datadiff_diff_counts(x)
  cols <- attr(x, "diff_columns")
  lines <- cli::format_inline(
    "{.strong datadiff}: {counts$changed} changed, {counts$added} added, ",
    "{counts$removed} removed row{?s} across {length(cols)} column{?s}"
  )
  tol <- attr(x, "tolerance")
  if (!is.null(tol)) {
    lines <- c(lines, cli::format_inline("Tolerance: {tol}"))
  }
  if (isTRUE(attr(x, "truncated"))) {
    lines <- c(
      lines,
      cli::format_inline(
        "Truncated to the first differing rows of {attr(x, 'n_differences')} total."
      )
    )
  }
  cat(lines, sep = "\n")
  cat("\n")
  print(tibble::as_tibble(x), ...)
  invisible(x)
}

#' @export
summary.datadiff_diff <- function(object, ...) {
  counts <- datadiff_diff_counts(object)
  structure(
    list(
      rows_changed = counts$changed,
      rows_added = counts$added,
      rows_removed = counts$removed,
      columns_changed = attr(object, "diff_columns"),
      tolerance = attr(object, "tolerance"),
      n_differences = attr(object, "n_differences"),
      truncated = attr(object, "truncated")
    ),
    class = "summary.datadiff_diff"
  )
}

#' @export
print.summary.datadiff_diff <- function(x, ...) {
  lines <- cli::format_inline(
    "{.strong datadiff}: {x$rows_changed} changed, {x$rows_added} added, ",
    "{x$rows_removed} removed row{?s}"
  )
  if (length(x$columns_changed) > 0) {
    lines <- c(
      lines,
      cli::format_inline("Columns changed: {.field {x$columns_changed}}")
    )
  }
  lines <- c(lines, cli::format_inline("Tolerance: {x$tolerance}"))
  if (isTRUE(x$truncated)) {
    lines <- c(
      lines,
      cli::format_inline(
        "Truncated to the first differing rows of {x$n_differences} total."
      )
    )
  }
  cat(lines, sep = "\n")
  cat("\n")
  invisible(x)
}
