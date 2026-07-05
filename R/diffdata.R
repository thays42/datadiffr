#' Diff Data Frames
#'
#' High-level function that compares two data frames and renders the result as
#' an HTML report in the RStudio viewer or browser.
#'
#' @param x,y Data frames to diff.
#' @param by Optional character vector of key columns to match rows on, like
#'   a join. When `NULL` (the default), rows are matched by position. See
#'   [compare_data()] for details.
#' @param context_rows Integer vector of length two indicating the number of context
#'   rows to include before and after a difference row.
#' @param context_cols <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns to include as context.
#' @param max_differences Maximum number of differing rows to report. Defaults
#'   to 10 (unlike [compare_data()], which reports everything) to keep
#'   reports fast to render.
#' @param tolerance Numeric tolerance for comparing numeric values.
#' @param output_file Optional file path to save the HTML report. If provided,
#'   the report is saved to this location instead of opening in the viewer.
#' @return Invisibly, a `datadiff_result` object (see [compare_data()]). Called
#'   for its side effect: when columns match and values differ it renders an
#'   HTML report; when columns differ it prints the schema differences to the
#'   console; when the frames are identical it reports no differences.
#' @examplesIf interactive()
#' x <- data.frame(id = 1:5, score = c(10, 20, 30, 40, 50))
#' y <- data.frame(id = 1:5, score = c(10, 25, 30, 40, 55))
#'
#' # Opens a styled HTML diff report in the RStudio viewer or browser
#' diffdata(x, y)
#'
#' # Or write the report to a file instead of opening it
#' diffdata(x, y, output_file = tempfile(fileext = ".html"))
#' @export
diffdata <- function(
  x,
  y,
  by = NULL,
  context_rows = c(3L, 3L),
  context_cols = everything(),
  max_differences = 10,
  tolerance = .Machine$double.eps^0.5,
  output_file = NULL
) {
  checkmate::assert_data_frame(x, min.rows = 1)
  checkmate::assert_data_frame(y, min.rows = 1)
  checkmate::assert_number(max_differences, lower = 0)
  checkmate::assert_integerish(
    context_rows,
    len = 2,
    lower = 0,
    any.missing = FALSE
  )
  checkmate::assert_number(tolerance, lower = 0)
  checkmate::assert_string(output_file, null.ok = TRUE)

  max_differences <- as.integer(max_differences)
  context_rows <- as.integer(context_rows)

  # resolve the tidy-select expression against x; selections do not survive
  # bare forwarding between functions
  context_cols <- names(
    tidyselect::eval_select(rlang::enquo(context_cols), data = x)
  )

  result <- compare_data(
    x,
    y,
    by = by,
    context_rows = context_rows,
    context_cols = all_of(context_cols),
    max_differences = max_differences,
    tolerance = tolerance
  )

  render_diff(result, output_file = output_file)

  invisible(result)
}
