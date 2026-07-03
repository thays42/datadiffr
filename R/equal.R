#' Vectorized Equality Test
#'
#' Element-wise equality comparison that handles `NA` and `Inf` values correctly,
#' and supports numeric tolerance for floating-point comparisons.
#'
#' @details
#' Comparison semantics:
#' * `NA` values are equal to each other, and `NaN` values are equal to each
#'   other, but `NA` is not equal to `NaN`.
#' * Factors are compared by their character values, so factors with
#'   different level sets can be compared.
#' * Dates and datetimes are compared numerically, so `tol` applies on the
#'   underlying scale (days for `Date`, seconds for `POSIXct`).
#' * Lists are compared element-wise with [identical()]; `tol` does not apply.
#' * When `x` and `y` have incompatible types (e.g. numeric vs character),
#'   every element is `FALSE`.
#'
#' @param x,y Vectors to compare. Must be the same length, or either can be
#'   length 1.
#' @param tol Numeric tolerance for comparison. Only applies to numeric values.
#' @return A logical vector the same length as `x` and `y`, where each element
#'   is `TRUE` if the corresponding elements are equal (within tolerance for
#'   numeric values) and `FALSE` otherwise.
#' @export
is_equal <- function(x, y, tol = .Machine$double.eps^0.5) {
  checkmate::assert_number(tol, lower = 0, finite = TRUE)
  if (length(x) != length(y) && length(x) != 1L && length(y) != 1L) {
    cli::cli_abort(
      "`x` and `y` must be the same length, or either can be length 1."
    )
  }
  n <- max(length(x), length(y))

  # factors compare by their character values
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.factor(y)) {
    y <- as.character(y)
  }

  # dates and datetimes compare numerically so tolerance applies
  if (inherits(x, "POSIXlt")) {
    x <- as.POSIXct(x)
  }
  if (inherits(y, "POSIXlt")) {
    y <- as.POSIXct(y)
  }
  if (
    (inherits(x, "Date") && inherits(y, "Date")) ||
      (inherits(x, "POSIXct") && inherits(y, "POSIXct"))
  ) {
    x <- as.numeric(x)
    y <- as.numeric(y)
  } else if (
    inherits(x, c("Date", "POSIXct")) || inherits(y, c("Date", "POSIXct"))
  ) {
    return(rep(FALSE, n))
  }

  # lists compare element-wise by identical()
  if (is.list(x) || is.list(y)) {
    if (!(is.list(x) && is.list(y))) {
      return(rep(FALSE, n))
    }
    return(map2_lgl(x, y, identical))
  }

  if (is.numeric(x) != is.numeric(y)) {
    rep(FALSE, n)
  } else if (is.numeric(x)) {
    (
      # both NA or both NaN, but NA is not NaN
      (is.na(x) & is.na(y) & (is.nan(x) == is.nan(y))) |

        # both Inf or -Inf
        (is.infinite(x) & is.infinite(y) & sign(x) == sign(y)) |

        # both finite, within tolerance
        (!is.na(x) & !is.na(y) & abs(x - y) <= tol)
    )
  } else {
    (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & x == y)
  }
}
