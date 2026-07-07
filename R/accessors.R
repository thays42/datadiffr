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
