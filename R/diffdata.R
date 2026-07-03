#' Diff Data Frames
#'
#' High-level function that compares two data frames and renders the result as
#' an HTML report in the RStudio viewer or browser.
#'
#' @param x,y Data frames to diff.
#' @param max_differences Maximum number of differing rows to report.
#' @param context_rows Integer vector of length two indicating the number of context
#'   rows to include before and after a difference row.
#' @param context_cols <[`tidy-select`][dplyr_tidy_select]> Columns to include as context.
#' @param tolerance Numeric tolerance for comparing numeric values.
#' @param output_file Optional file path to save the HTML report. If provided,
#'   the report is saved to this location instead of opening in the viewer.
#' @return If `x` and `y` have column differences (different names or types),
#'   returns a visible data frame describing those differences (from [compare_columns()]).
#'   Otherwise, invisibly returns the diff data frame (from [compare_data()]).
#' @export
diffdata <- function(
  x,
  y,
  max_differences = 10,
  context_rows = c(3L, 3L),
  context_cols = everything(),
  tolerance = .Machine$double.eps^0.5,
  output_file = NULL
) {
  stopifnot(
    "x must be a data frame" = is.data.frame(x),
    "x must have at least one row" = nrow(x) > 0,
    "y must be a data frame" = is.data.frame(y),
    "y must have at least one row" = nrow(y) > 0,
    "max_differences must be numeric" = is.numeric(max_differences),
    "max_differences must be length 1" = length(max_differences) == 1,
    "context_rows must be numeric" = is.numeric(context_rows),
    "context_rows must be length 2" = length(context_rows) == 2,
    "tolerance must be numeric" = is.numeric(tolerance),
    "tolerance must be length 1" = length(tolerance) == 1,
    "tolerance must be non-negative" = tolerance >= 0
  )

  max_differences <- as.integer(max_differences)
  context_rows <- as.integer(context_rows)

  # resolve the tidy-select expression against x; selections do not survive
  # bare forwarding between functions
  context_cols <- names(
    tidyselect::eval_select(rlang::enquo(context_cols), data = x)
  )

  col_diff <- compare_columns(x, y)
  if (nrow(col_diff) > 0) {
    cli::cli_alert_danger("Cannot diff data with column differences.")
    return(col_diff)
  }

  data_diff <- compare_data(
    x,
    y,
    context_rows = context_rows,
    context_cols = all_of(context_cols),
    max_differences = max_differences,
    tolerance = tolerance
  )

  if (nrow(data_diff) == 0) {
    cli::cli_alert_success("No differences found.")
    return(invisible(data_diff))
  }

  render_diff(data_diff, output_file = output_file)

  invisible(data_diff)
}
