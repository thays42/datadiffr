#' Summarize a dataCompareR-compatible comparison
#'
#' Builds the same summary object as dataCompareR's
#' `summary.dataCompareRobject()`: a list of run metadata, column and row
#' matching counts, and per-column mismatch details, printable as a
#' markdown report.
#'
#' Unlike dataCompareR (which samples), detail tables are deterministic:
#' rows are sorted by decreasing absolute difference and the first
#' `mismatchCount` are kept.
#'
#' @param object A comparison object returned by [rCompare()].
#' @param mismatchCount Maximum number of rows to keep in each per-column
#'   detail table.
#' @param ... Ignored, for method compatibility.
#' @return A list of class
#'   `c("summary.datadiff_compare", "summary.dataCompareRobject")` with the
#'   dataCompareR summary fields.
#' @examples
#' a <- data.frame(id = 1:3, value = c(1, 2, 3))
#' b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
#' summary(rCompare(a, b, keys = "id"))
#' @export
summary.datadiff_compare <- function(object, mismatchCount = 5, ...) {
  checkmate::assert_count(mismatchCount, positive = TRUE)

  meta <- object$meta
  name_a <- meta$A$name
  name_b <- meta$B$name
  keys <- object$rowMatching$matchKeys
  keyed <- !anyNA(keys)
  mm <- object$mismatches

  n_diffs <- vapply(mm, nrow, integer(1))
  n_nas <- vapply(
    mm,
    function(tbl) sum(is.na(tbl$valueA) | is.na(tbl$valueB)),
    integer(1)
  )
  max_diff <- vapply(
    mm,
    function(tbl) {
      d <- tbl$diffAB
      if (is.numeric(d) && any(!is.na(d))) {
        as.character(max(abs(d), na.rm = TRUE))
      } else {
        NA_character_
      }
    },
    character(1)
  )
  type_a <- vapply(mm, function(tbl) tbl$typeA[[1]], character(1))
  type_b <- vapply(mm, function(tbl) tbl$typeB[[1]], character(1))
  type_mismatched <- type_a != type_b

  rows_in_a_only <- as.data.frame(object$rowMatching$inA)
  rows_in_b_only <- as.data.frame(object$rowMatching$inB)

  structure(
    list(
      datanameA = name_a,
      datanameB = name_b,
      nrowA = meta$A$rows,
      nrowB = meta$B$rows,
      rounding = !rc_unset(meta$roundDigits),
      roundDigits = if (rc_unset(meta$roundDigits)) {
        0
      } else {
        as.numeric(meta$roundDigits)
      },
      version = utils::packageVersion("datadiffr"),
      runtime = meta$runTimestamp,
      rversion = R.version.string,
      datasetSummary = data.frame(
        "Dataset Name" = c(name_a, name_b),
        "Number of Rows" = as.character(c(meta$A$rows, meta$B$rows)),
        "Number of Columns" = as.character(c(meta$A$cols, meta$B$cols)),
        check.names = FALSE
      ),
      ncolCommon = length(object$colMatching$inboth),
      ncolInAOnly = length(object$colMatching$inA),
      ncolInBOnly = length(object$colMatching$inB),
      colsInAOnly = object$colMatching$inA,
      colsInBOnly = object$colMatching$inB,
      colsInBoth = object$colMatching$inboth,
      ncolID = if (keyed) length(keys) else 0L,
      matchKey = keys,
      typeMismatch = rc_named_df(
        names(mm)[type_mismatched],
        type_a[type_mismatched],
        type_b[type_mismatched],
        names = c(
          "Column Name",
          paste0("Column Type (in ", name_a, ")"),
          paste0("Column Type (in ", name_b, ")")
        )
      ),
      typeMismatchN = sum(type_mismatched),
      nrowCommon = if (keyed) {
        nrow(object$rowMatching$inboth)
      } else {
        length(object$rowMatching$inboth)
      },
      nrowInAOnly = as.numeric(nrow(rows_in_a_only)),
      nrowInBOnly = as.numeric(nrow(rows_in_b_only)),
      rowsInAOnly = rows_in_a_only,
      rowsInBOnly = rows_in_b_only,
      ncolsAllEqual = length(object$matches),
      ncolsSomeUnequal = length(mm),
      colsWithUnequalValues = rc_named_df(
        names(mm),
        type_a,
        type_b,
        unname(n_diffs),
        unname(max_diff),
        unname(n_nas),
        names = c(
          "Column",
          paste0("Type (in ", name_a, ")"),
          paste0("Type (in ", name_b, ")"),
          "# differences",
          "Max difference",
          "# NAs"
        )
      ),
      nrowNAmismatch = sum(n_nas > 0),
      ColsMatching = object$matches,
      maxDifference = NA,
      colMismDetls = lapply(
        stats::setNames(names(mm), names(mm)),
        function(col) {
          rc_detail_table(
            mm[[col]],
            col = col,
            keys = if (keyed) keys else character(),
            name_a = name_a,
            name_b = name_b,
            max_rows = mismatchCount
          )
        }
      ),
      mismatchCount = as.numeric(mismatchCount)
    ),
    class = c("summary.datadiff_compare", "summary.dataCompareRobject")
  )
}

#' Print a dataCompareR-compatible comparison
#'
#' Prints the one-line comparison status followed by head/tail excerpts of
#' each mismatching column's rows, in the dataCompareR console format.
#'
#' @param x A comparison object returned by [rCompare()].
#' @param nVars Number of mismatched variables to show from the start and
#'   end of the variable list.
#' @param nObs Number of observations to show from the start and end of
#'   each variable's mismatch table.
#' @param verbose If `TRUE`, print every mismatching row of every variable.
#' @param ... Ignored, for method compatibility.
#' @return `x`, invisibly.
#' @export
print.datadiff_compare <- function(
  x,
  nVars = 5,
  nObs = 5,
  verbose = FALSE,
  ...
) {
  checkmate::assert_count(nVars, positive = TRUE)
  checkmate::assert_count(nObs, positive = TRUE)
  checkmate::assert_flag(verbose)

  n_col_dropped <- length(x$colMatching$inA) + length(x$colMatching$inB)
  keyed <- !anyNA(x$rowMatching$matchKeys)
  n_common <- if (keyed) {
    nrow(x$rowMatching$inboth)
  } else {
    length(x$rowMatching$inboth)
  }
  n_row_dropped <- rc_side_rows(x$rowMatching$inA) +
    rc_side_rows(x$rowMatching$inB)
  n_compared_cols <- length(x$matches) + length(x$mismatches)

  col_txt <- if (n_col_dropped > 0) {
    paste0(n_col_dropped, " column(s) were dropped")
  } else {
    "All columns were compared"
  }
  row_txt <- if (n_common == 0 || n_compared_cols == 0) {
    "no rows compared because there were no rows or columns in common"
  } else if (n_row_dropped > 0) {
    paste0(n_row_dropped, " row(s) were dropped from comparison")
  } else {
    "all rows were compared"
  }
  cat(col_txt, ", ", row_txt, "\n", sep = "")

  nm <- length(x$mismatches)
  if (nm == 0) {
    if (n_compared_cols == 0) {
      cat("No variables match\n")
    } else {
      cat(
        "All compared variables match \n",
        "Number of rows compared: ",
        n_common,
        "\n",
        "Number of columns compared: ",
        n_compared_cols,
        "\n",
        sep = ""
      )
    }
  } else if (verbose) {
    tbl <- do.call(rbind, unname(as.list(x$mismatches)))
    rownames(tbl) <- NULL
    print(tbl)
  } else {
    cat("There are ", nm, " mismatched variables:\n", sep = "")
    hdr <- if (nm <= nVars) {
      paste0(
        "First and last ",
        nObs,
        " observations for the ",
        nm,
        " mismatched variables"
      )
    } else {
      paste0(
        "First and last ",
        nObs,
        " observations for first and last ",
        nVars,
        " mismatched variables"
      )
    }
    cat(hdr, "\n", sep = "")
    vars <- unique(c(
      utils::head(names(x$mismatches), nVars),
      utils::tail(names(x$mismatches), nVars)
    ))
    excerpts <- lapply(vars, function(v) {
      tbl <- x$mismatches[[v]]
      unique(rbind(utils::head(tbl, nObs), utils::tail(tbl, nObs)))
    })
    tbl <- do.call(rbind, excerpts)
    rownames(tbl) <- NULL
    print(tbl)
  }
  invisible(x)
}

#' @rdname summary.datadiff_compare
#' @param x A summary object returned by
#'   `summary.datadiff_compare()`.
#' @export
print.summary.datadiff_compare <- function(x, ...) {
  md <- c(
    "",
    "Data Comparison",
    "===============",
    "",
    paste0("Date comparison run: ", format(x$runtime), "  "),
    paste0("Comparison run on ", x$rversion, "  "),
    paste0("With datadiffr version ", x$version, "  "),
    "",
    "Meta Summary",
    "============",
    "",
    rc_md_table(x$datasetSummary),
    "",
    "Variable Summary",
    "================",
    "",
    paste0("Number of columns in common: ", x$ncolCommon, "  "),
    paste0(
      "Number of columns only in ",
      x$datanameA,
      ": ",
      x$ncolInAOnly,
      "  "
    ),
    paste0(
      "Number of columns only in ",
      x$datanameB,
      ": ",
      x$ncolInBOnly,
      "  "
    ),
    paste0(
      "Number of columns with a type mismatch: ",
      x$typeMismatchN,
      "  "
    ),
    if (x$typeMismatchN > 0) c("", rc_md_table(x$typeMismatch), ""),
    if (x$ncolID > 0) {
      paste0(
        "Match keys : ",
        x$ncolID,
        "   - ",
        paste(x$matchKey, collapse = ", ")
      )
    } else {
      "Match keys : none (rows are compared in order)"
    },
    if (x$ncolInAOnly + x$ncolInBOnly > 0) {
      c(
        "",
        if (x$ncolInAOnly > 0) {
          paste0(
            "Columns only in ",
            x$datanameA,
            ": ",
            paste(x$colsInAOnly, collapse = ", "),
            "  "
          )
        },
        if (x$ncolInBOnly > 0) {
          paste0(
            "Columns only in ",
            x$datanameB,
            ": ",
            paste(x$colsInBOnly, collapse = ", "),
            "  "
          )
        },
        paste0(
          "Columns in both : ",
          paste(x$colsInBoth, collapse = ", "),
          "  "
        )
      )
    },
    "",
    "",
    "Row Summary",
    "===========",
    "",
    paste0(
      "Total number of rows read from ",
      x$datanameA,
      ": ",
      x$nrowA,
      "  "
    ),
    paste0(
      "Total number of rows read from ",
      x$datanameB,
      ": ",
      x$nrowB,
      "  "
    ),
    paste0("Number of rows in common: ", x$nrowCommon, "  "),
    paste0(
      "Number of rows dropped from ",
      x$datanameA,
      ": ",
      x$nrowInAOnly,
      "  "
    ),
    paste0(
      "Number of rows dropped from ",
      x$datanameB,
      ": ",
      x$nrowInBOnly,
      "  "
    ),
    "",
    "",
    "Data Values Comparison Summary",
    "==============================",
    "",
    paste0(
      "Number of columns compared with ALL rows equal: ",
      x$ncolsAllEqual,
      "  "
    ),
    paste0(
      "Number of columns compared with SOME rows unequal: ",
      x$ncolsSomeUnequal,
      "  "
    ),
    paste0(
      "Number of columns with missing value differences: ",
      x$nrowNAmismatch,
      "  "
    )
  )
  if (x$ncolsSomeUnequal > 0) {
    md <- c(
      md,
      "",
      "Summary of columns with some rows unequal: ",
      "",
      rc_md_table(x$colsWithUnequalValues),
      "",
      "",
      "Unequal column details",
      "======================"
    )
    for (v in names(x$colMismDetls)) {
      md <- c(
        md,
        "",
        paste0("#### Column -  ", v),
        "",
        rc_md_table(x$colMismDetls[[v]])
      )
    }
  }
  if (x$nrowInAOnly > 0 || x$nrowInBOnly > 0) {
    md <- c(md, "", "Dropped Rows Details", "====================", "")
    if (x$nrowInAOnly > 0) {
      md <- c(
        md,
        paste0("The following rows were dropped from ", x$datanameA),
        "",
        rc_md_table(x$rowsInAOnly),
        ""
      )
    }
    if (x$nrowInBOnly > 0) {
      md <- c(
        md,
        paste0("The following rows were dropped from ", x$datanameB),
        "",
        rc_md_table(x$rowsInBOnly),
        ""
      )
    }
  }
  cat(md, sep = "\n")
  cat("\n")
  invisible(x)
}

# data.frame with verbatim (non-syntactic) column names
rc_named_df <- function(..., names) {
  out <- data.frame(..., check.names = FALSE, stringsAsFactors = FALSE)
  colnames(out) <- names
  rownames(out) <- NULL
  out
}

# per-column summary detail: keys + renamed value/type columns, sorted by
# decreasing absolute difference, first max_rows rows
rc_detail_table <- function(tbl, col, keys, name_a, name_b, max_rows) {
  vals <- rc_named_df(
    tbl$valueA,
    tbl$valueB,
    tbl$typeA,
    tbl$typeB,
    tbl$diffAB,
    names = c(
      paste0(col, " (", name_a, ")"),
      paste0(col, " (", name_b, ")"),
      paste0("Type (", name_a, ")"),
      paste0("Type (", name_b, ")"),
      "Difference"
    )
  )
  out <- if (length(keys)) {
    cbind(tbl[keys], vals)
  } else {
    vals
  }
  if (is.numeric(tbl$diffAB)) {
    out <- out[order(-abs(tbl$diffAB)), , drop = FALSE]
  }
  out <- utils::head(out, max_rows)
  rownames(out) <- NULL
  out
}

# number of unmatched rows recorded for one side of rowMatching
rc_side_rows <- function(side) {
  if (length(side)) length(side[[1]]) else 0L
}

rc_md_table <- function(df) {
  as.character(knitr::kable(df, format = "pipe", row.names = FALSE))
}
