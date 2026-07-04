#' Extract the mismatching rows of a comparison
#'
#' Given a comparison from [rCompare()] and the two original data frames,
#' returns the rows of each frame that mismatch, as in dataCompareR's
#' `generateMismatchData()`. Keyed comparisons return rows whose keys
#' appear in any mismatch table, with cleaned upper-case column names;
#' keyless comparisons return the rows at the mismatching positions with
#' the original column names.
#'
#' @param x A comparison object returned by [rCompare()].
#' @param dfA,dfB The data frames that were compared. They are matched to
#'   the comparison by the names they were originally passed under.
#' @param ... Ignored, for compatibility.
#' @return A list of two data frames named `<name>_mm` after the original
#'   inputs.
#' @examples
#' a <- data.frame(id = 1:3, value = c(1, 2, 3))
#' b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
#' cmp <- rCompare(a, b, keys = "id")
#' generateMismatchData(cmp, a, b)
#' @export
generateMismatchData <- function(x, dfA, dfB, ...) {
  checkmate::assert_class(x, "dataCompareRobject")
  checkmate::assert_data_frame(dfA)
  checkmate::assert_data_frame(dfB)

  passed <- c(deparse(substitute(dfA)), deparse(substitute(dfB)))
  expected <- c(x$meta$A$name, x$meta$B$name)
  for (nm in passed) {
    if (!nm %in% expected) {
      cli::cli_abort(
        "Data frame named {.val {nm}} was not part of the original comparison."
      )
    }
  }
  frames <- stats::setNames(list(dfA, dfB), passed)
  da <- frames[[expected[[1]]]]
  db <- frames[[expected[[2]]]]

  keys <- x$rowMatching$matchKeys
  mm <- unclass(x$mismatches)
  if (!anyNA(keys)) {
    da <- rc_upper_names(da)
    db <- rc_upper_names(db)
    if (length(mm)) {
      key_union <- unique(do.call(rbind, lapply(mm, function(tbl) tbl[keys])))
      wanted <- rc_key_string(key_union)
      da_mm <- da[rc_key_string(da[keys]) %in% wanted, , drop = FALSE]
      db_mm <- db[rc_key_string(db[keys]) %in% wanted, , drop = FALSE]
    } else {
      da_mm <- da[integer(), , drop = FALSE]
      db_mm <- db[integer(), , drop = FALSE]
    }
  } else {
    # keyless mismatch tables carry the matched row position as row names
    idx <- sort(unique(as.integer(unlist(lapply(mm, rownames)))))
    da_mm <- da[idx[idx <= nrow(da)], , drop = FALSE]
    db_mm <- db[idx[idx <= nrow(db)], , drop = FALSE]
  }

  stats::setNames(list(da_mm, db_mm), paste0(expected, "_mm"))
}

#' Save a comparison report
#'
#' Writes the [summary.datadiff_compare()] report of a comparison to disk
#' as R Markdown and (optionally) rendered HTML, as in dataCompareR's
#' `saveReport()`.
#'
#' @param compareObject A comparison object returned by [rCompare()].
#' @param reportName File name for the report, without extension.
#' @param reportLocation Existing directory to write the report to.
#' @param HTMLReport If `TRUE`, render the report to HTML (requires
#'   pandoc); the intermediate markdown is kept alongside it.
#' @param showInViewer If `TRUE` and the session is interactive, open the
#'   rendered HTML report in the RStudio viewer or browser.
#' @param stylesheet Optional path to a CSS file for the HTML report, or
#'   `NA` for the default style.
#' @param printAll If `TRUE`, the per-column detail tables include every
#'   mismatching row instead of the first five.
#' @param ... Ignored, for compatibility.
#' @return `NULL`, invisibly.
#' @examplesIf rmarkdown::pandoc_available()
#' a <- data.frame(id = 1:3, value = c(1, 2, 3))
#' b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
#' cmp <- rCompare(a, b, keys = "id")
#' saveReport(
#'   cmp,
#'   reportName = "example",
#'   reportLocation = tempdir(),
#'   showInViewer = FALSE
#' )
#' @export
saveReport <- function(
  compareObject,
  reportName,
  reportLocation = ".",
  HTMLReport = TRUE,
  showInViewer = TRUE,
  stylesheet = NA,
  printAll = FALSE,
  ...
) {
  checkmate::assert_class(compareObject, "dataCompareRobject")
  checkmate::assert_string(reportName, min.chars = 1)
  checkmate::assert_directory_exists(reportLocation, access = "w")
  checkmate::assert_flag(HTMLReport)
  checkmate::assert_flag(showInViewer)
  if (!rc_unset(stylesheet)) {
    checkmate::assert_file_exists(stylesheet)
  }
  checkmate::assert_flag(printAll)

  mismatch_count <- if (printAll) {
    max(c(1L, vapply(unclass(compareObject$mismatches), nrow, integer(1))))
  } else {
    5
  }
  summ <- summary(compareObject, mismatchCount = mismatch_count)

  rmd_path <- file.path(reportLocation, paste0(reportName, ".Rmd"))
  writeLines(utils::capture.output(print(summ)), rmd_path)

  if (HTMLReport) {
    css <- if (rc_unset(stylesheet)) NULL else stylesheet
    out <- rmarkdown::render(
      rmd_path,
      output_format = rmarkdown::html_document(css = css, keep_md = TRUE),
      output_dir = reportLocation,
      quiet = TRUE
    )
    if (showInViewer && interactive()) {
      rc_open_file(out)
    }
  }
  invisible(NULL)
}

rc_upper_names <- function(df) {
  names(df) <- toupper(make.names(names(df), unique = TRUE))
  df
}

rc_open_file <- function(path) {
  if (
    requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()
  ) {
    rstudioapi::viewer(path)
  } else {
    utils::browseURL(path)
  }
}
