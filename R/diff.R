f_green <- formattable::formatter(
  "span",
  style = "color:green; white-space: nowrap; display: block; overflow: clip; max-width: 200px"
)
f_red <- formattable::formatter(
  "span",
  style = "color:red; white-space: nowrap; display: block; overflow: clip; max-width: 200px"
)
f_ctx <- formattable::formatter(
  "span",
  style = "white-space: nowrap; display: block; overflow: clip; max-width: 200px"
)

#' Render HTML diff
#'
#' @param diffs Data frame as returned by [compare_data()]
#' @return A formattable/kableExtra HTML table object.
#' @noRd
show_diff <- function(diffs) {
  tolerance <- attr(diffs, "tolerance") %||% .Machine$double.eps^0.5

  # Blocks are runs of contiguous rows; a gap in `.row` starts a new block.
  # Each new block (after the first) gets a top border to separate it visually.
  # This replaces kableExtra::pack_rows(), which is O(n^2) in the block count.
  block_separators <- which(c(
    FALSE,
    diffs$.row[-1] > diffs$.row[-nrow(diffs)] + 1
  ))

  # Identify row types
  ours <- which(diffs$.source == "x")
  theirs <- which(diffs$.source == "y")
  context <- which(diffs$.diff_type == "context")

  # Format cells
  diffs <- diffs |>
    group_by(.data$.row) |>
    mutate(across(!c(.join_type, .source), function(x) {
      case_when(
        .data$.source == "x" &
          !is_equal(x, lead(x), tolerance = tolerance) |
          .data$.join_type == "x" ~
          f_red(x),
        .data$.source == "y" &
          !is_equal(x, lag(x), tolerance = tolerance) |
          .data$.join_type == "y" ~
          f_green(x),
        TRUE ~ f_ctx(x)
      )
    })) |>
    ungroup() |>
    select(-c(.join_type, .diff_type, .source))

  # Build table
  tbl <- formattable::formattable(diffs) |>
    kableExtra::kbl(escape = FALSE, row.names = FALSE) |>
    kableExtra::kable_paper(
      full_width = FALSE,
      fixed_thead = TRUE,
      html_font = "monospace"
    ) |>
    kableExtra::row_spec(ours, background = "#e6a8a8") |>
    kableExtra::row_spec(theirs, background = "#a7d1a9") |>
    kableExtra::row_spec(context, color = "#959595")

  if (length(block_separators) > 0) {
    tbl <- kableExtra::row_spec(
      tbl,
      block_separators,
      extra_css = "border-top: 2px solid #cccccc;"
    )
  }

  add_column_borders(tbl)
}

# Column separators via a scoped stylesheet rule instead of per-cell
# kableExtra::column_spec(), which rewrites every <td> and is O(rows * cols).
# The lightable table is a self-contained HTML string (no html dependency),
# so prepending a <style> and restoring the kable attributes is safe.
add_column_borders <- function(tbl) {
  style <- paste0(
    "<style>.lightable-paper td, .lightable-paper th ",
    "{ border-left: 1px solid #eeeeee; border-right: 1px solid #eeeeee; }",
    "</style>\n"
  )
  out <- paste0(style, as.character(tbl))
  attributes(out) <- attributes(tbl)
  out
}

#' Render a diff in a flexdashboard
#'
#' Opens the diff as an HTML report in the RStudio viewer (if available) or
#' browser. Optionally saves to a file.
#'
#' @param diff A `datadiff_result` (from [compare_data()]) or a bare diff
#'   data frame containing `.row`, `.join_type`, `.diff_type`, and `.source`
#'   columns.
#' @param output_file Optional file path to save the HTML report. If provided,
#'   the report is saved to this location instead of (or in addition to) opening
#'   in the viewer.
#' @return For a `"value"` result (or a bare diff with rows), invisibly
#'   returns the path to the HTML file — `output_file` if provided, a
#'   temporary file otherwise. For `"identical"` and `"schema"` results and
#'   zero-row diffs nothing is rendered and `invisible(NULL)` is returned.
#' @examplesIf interactive()
#' x <- data.frame(id = 1:5, score = c(10, 20, 30, 40, 50))
#' y <- data.frame(id = 1:5, score = c(10, 25, 30, 40, 55))
#'
#' diff <- compare_data(x, y)
#' render_diff(diff)
#' @export
render_diff <- function(diff, output_file = NULL) {
  UseMethod("render_diff")
}

#' @rdname render_diff
#' @export
render_diff.datadiff_result <- function(diff, output_file = NULL) {
  switch(
    diff$kind,
    identical = {
      cli::cli_alert_success("No differences found.")
      invisible(NULL)
    },
    schema = {
      cli::cli_alert_info("Columns differ; showing schema differences.")
      print(diff$columns)
      invisible(NULL)
    },
    value = render_diff(diff$rows, output_file = output_file)
  )
}

#' @rdname render_diff
#' @export
render_diff.default <- function(diff, output_file = NULL) {
  checkmate::assert_data_frame(diff)
  checkmate::assert_names(
    names(diff),
    must.include = c(".row", ".join_type", ".diff_type", ".source")
  )
  checkmate::assert_string(output_file, null.ok = TRUE)

  if (nrow(diff) == 0) {
    cli::cli_alert_info("No differences to render.")
    return(invisible(NULL))
  }

  if (!is.null(output_file) && !dir.exists(dirname(output_file))) {
    cli::cli_abort(
      "The `output_file` directory {.path {dirname(output_file)}} does not exist."
    )
  }

  if (!requireNamespace("flexdashboard", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.pkg flexdashboard} must be installed to render diffs.",
      i = "Install it with {.code install.packages(\"flexdashboard\")}."
    ))
  }

  tempdir(TRUE)
  fp <- tempfile()

  diff |>
    show_diff() |>
    saveRDS(fp)

  out <- system.file("report.Rmd", package = "datadiffr", mustWork = TRUE) |>
    rmarkdown::render(
      params = list(data = fp),
      output_dir = tempdir(),
      quiet = TRUE
    )

  if (!is.null(output_file)) {
    file.copy(out, output_file, overwrite = TRUE)
    return(invisible(output_file))
  }

  if (!interactive()) {
    return(invisible(out))
  }

  if (
    requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()
  ) {
    rstudioapi::viewer(out)
  } else {
    utils::browseURL(out)
  }

  invisible(out)
}
