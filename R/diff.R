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
  # Identify blocks of rows for formatting the table
  row_groups <- diffs |>
    mutate(
      .rn = row_number(),
      .block = cumsum(replace_na(.data$.row > lag(.data$.row) + 1, FALSE))
    ) |>
    group_by(.data$.block) |>
    summarize(
      start_row = min(.data$.rn),
      end_row = max(.data$.rn)
    ) |>
    ungroup()

  # Identify row types
  ours <- which(diffs$.source == "x")
  theirs <- which(diffs$.source == "y")
  context <- which(diffs$.diff_type == "context")

  # Format cells
  diffs <- diffs |>
    group_by(.data$.row) |>
    mutate(across(!c(.join_type, .source), function(x) {
      case_when(
        .data$.source == "x" & !is_equal(x, lead(x)) | .data$.join_type == "x" ~
          f_red(x),
        .data$.source == "y" & !is_equal(x, lag(x)) | .data$.join_type == "y" ~
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
    kableExtra::column_spec(
      seq_along(diffs),
      border_left = "1px solid #eeeeee",
      border_right = "1px solid #eeeeee"
    ) |>
    kableExtra::row_spec(ours, background = "#e6a8a8") |>
    kableExtra::row_spec(theirs, background = "#a7d1a9") |>
    kableExtra::row_spec(context, color = "#959595")

  for (i in seq_len(nrow(row_groups))) {
    tbl <- kableExtra::pack_rows(
      tbl,
      start_row = row_groups$start_row[i],
      end_row = row_groups$end_row[i]
    )
  }

  tbl
}

#' Render a diff in a flexdashboard
#'
#' Opens the diff as an HTML report in the RStudio viewer (if available) or
#' browser. Optionally saves to a file.
#'
#' @param diff Data frame as returned by [compare_data()], containing `.row`,
#'   `.join_type`, `.diff_type`, `.source`, and data columns.
#' @param output_file Optional file path to save the HTML report. If provided,
#'   the report is saved to this location instead of (or in addition to) opening
#'   in the viewer.
#' @return Invisibly returns the path to the HTML file (either `output_file` if
#'   provided, or a temporary file path).
#' @export
render_diff <- function(diff, output_file = NULL) {
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
