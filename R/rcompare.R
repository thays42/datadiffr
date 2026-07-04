#' Compare two data frames, dataCompareR style
#'
#' A drop-in replacement for `rCompare()` from the archived 'dataCompareR'
#' package. Compares two data frames — by row position, or by key columns
#' when `keys` is supplied — and returns a summary object with the same
#' shape as a `dataCompareRobject`, so existing code and scripts written
#' against 'dataCompareR' keep working.
#'
#' Following the dataCompareR contract: column names are cleaned with
#' [make.names()] and matched case-insensitively (shared columns are
#' reported in upper case, sorted alphabetically); factors are compared as
#' character and the coercion is recorded in `cleaninginfo`; `NA` matches
#' `NA` and `NaN` matches `NaN`, but `NA` does not match `NaN`; columns
#' whose classes differ between the two frames are reported as mismatching
#' on every row. Without `keys`, the longer frame is truncated to the
#' length of the shorter and rows are compared by position.
#'
#' `tolerance` is a datadiffr extension (dataCompareR only offers
#' `roundDigits`). The default `0` keeps faithful exact comparison.
#'
#' @param dfA,dfB Data frames to compare.
#' @param keys Character vector of key columns used to match rows, or `NA`
#'   (the default) to match rows by position. Keys must identify rows
#'   uniquely in each frame.
#' @param roundDigits If not `NA`, round double columns to this many digits
#'   before comparing.
#' @param mismatches If not `NA`, the maximum total number of mismatching
#'   values allowed; an error is thrown when the comparison finds more.
#' @param trimChars If `TRUE`, trim leading and trailing whitespace from
#'   character columns before comparing.
#' @param tolerance Numeric tolerance for comparing numeric values, as in
#'   [compare_data()]. Defaults to `0` (exact comparison, as dataCompareR
#'   behaves).
#' @return An object of class
#'   `c("datadiff_compare", "dataCompareRobject")`: a list with elements
#'   `meta`, `colMatching`, `rowMatching`, `cleaninginfo`, `mismatches`,
#'   and `matches`, mirroring dataCompareR's return value.
#' @examples
#' a <- data.frame(id = 1:3, value = c(1, 2, 3))
#' b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
#' rCompare(a, b, keys = "id")
#' @export
rCompare <- function(
  dfA,
  dfB,
  keys = NA,
  roundDigits = NA,
  mismatches = NA,
  trimChars = FALSE,
  tolerance = 0
) {
  checkmate::assert_data_frame(dfA)
  checkmate::assert_data_frame(dfB)
  if (!rc_unset(keys)) {
    checkmate::assert_character(
      keys,
      min.len = 1,
      any.missing = FALSE,
      unique = TRUE
    )
  }
  if (!rc_unset(roundDigits)) {
    checkmate::assert_int(roundDigits)
  }
  if (!rc_unset(mismatches)) {
    checkmate::assert_count(mismatches, positive = TRUE)
  }
  checkmate::assert_flag(trimChars)
  checkmate::assert_number(tolerance, lower = 0, finite = TRUE)

  meta <- list(
    args = match.call(),
    runTimestamp = Sys.time(),
    A = list(
      name = deparse(substitute(dfA)),
      rows = nrow(dfA),
      cols = ncol(dfA)
    ),
    B = list(
      name = deparse(substitute(dfB)),
      rows = nrow(dfB),
      cols = ncol(dfB)
    ),
    objVersion = 1,
    roundDigits = roundDigits
  )

  a <- as.data.frame(dfA)
  b <- as.data.frame(dfB)
  names(a) <- make.names(names(a), unique = TRUE)
  names(b) <- make.names(names(b), unique = TRUE)

  keys <- if (rc_unset(keys)) character() else keys
  for (k in keys) {
    if (!(k %in% names(a) && k %in% names(b))) {
      cli::cli_abort("Key {.field {k}} was not found in both data frames.")
    }
  }

  up_a <- toupper(names(a))
  up_b <- toupper(names(b))
  shared <- sort(intersect(up_a, up_b))
  col_matching <- list(
    inboth = shared,
    inA = names(a)[!up_a %in% up_b],
    inB = names(b)[!up_b %in% up_a]
  )

  a <- a[match(shared, up_a)]
  names(a) <- shared
  b <- b[match(shared, up_b)]
  names(b) <- shared
  keys <- toupper(keys)

  # factors are compared as character; record coercions as
  # (A before, B before, A after, B after), the dataCompareR layout
  cleaning <- list()
  for (col in shared) {
    cls_a <- class(a[[col]])[[1]]
    cls_b <- class(b[[col]])[[1]]
    if (is.factor(a[[col]])) {
      a[[col]] <- as.character(a[[col]])
    }
    if (is.factor(b[[col]])) {
      b[[col]] <- as.character(b[[col]])
    }
    new_a <- class(a[[col]])[[1]]
    new_b <- class(b[[col]])[[1]]
    if (new_a != cls_a || new_b != cls_b) {
      cleaning[[col]] <- c(cls_a, cls_b, new_a, new_b)
    }
  }
  if (is.null(names(cleaning))) {
    names(cleaning) <- character()
  }

  if (trimChars) {
    for (col in shared) {
      if (is.character(a[[col]])) {
        a[[col]] <- trimws(a[[col]])
      }
      if (is.character(b[[col]])) {
        b[[col]] <- trimws(b[[col]])
      }
    }
  }

  if (!rc_unset(roundDigits)) {
    digits <- as.integer(roundDigits)
    for (col in shared) {
      if (is.double(a[[col]])) {
        a[[col]] <- round(a[[col]], digits)
      }
      if (is.double(b[[col]])) {
        b[[col]] <- round(b[[col]], digits)
      }
    }
  }

  if (length(keys)) {
    key_a <- rc_key_string(a[keys])
    key_b <- rc_key_string(b[keys])
    if (anyDuplicated(key_a) || anyDuplicated(key_b)) {
      cli::cli_abort(
        "{.arg keys} must uniquely identify rows in both data frames."
      )
    }
    pos_in_b <- match(key_a, key_b)
    matched <- which(!is.na(pos_in_b))
    matched <- matched[rc_key_order(a[matched, keys, drop = FALSE])]
    idx_b <- pos_in_b[matched]

    inboth_keys <- a[matched, keys, drop = FALSE]
    rownames(inboth_keys) <- NULL
    only_a <- rc_sorted_keys(a[is.na(pos_in_b), keys, drop = FALSE])
    only_b <- rc_sorted_keys(b[!key_b %in% key_a, keys, drop = FALSE])

    row_matching <- list(
      matchKeys = keys,
      inboth = inboth_keys,
      inA = as.list(only_a),
      inB = as.list(only_b)
    )
    ma <- a[matched, , drop = FALSE]
    mb <- b[idx_b, , drop = FALSE]
    key_frame <- inboth_keys
  } else {
    n <- min(nrow(a), nrow(b))
    row_matching <- list(
      matchKeys = NA_character_,
      inboth = seq_len(n),
      inA = list(indices_removed = rc_removed(nrow(a), n)),
      inB = list(indices_removed = rc_removed(nrow(b), n))
    )
    ma <- a[seq_len(n), , drop = FALSE]
    mb <- b[seq_len(n), , drop = FALSE]
    key_frame <- NULL
  }

  mismatch_tables <- list()
  match_cols <- character()
  for (col in setdiff(shared, keys)) {
    xa <- ma[[col]]
    xb <- mb[[col]]
    comparable <- identical(class(xa), class(xb))
    eq <- if (comparable) {
      is_equal(xa, xb, tolerance = tolerance)
    } else {
      rep(FALSE, nrow(ma))
    }
    if (all(eq)) {
      match_cols <- c(match_cols, col)
      next
    }
    numeric_diff <- comparable && is.numeric(xa)
    tbl <- data.frame(
      valueA = xa,
      valueB = xb,
      variable = col,
      typeA = typeof(xa),
      typeB = typeof(xb),
      diffAB = if (numeric_diff) xa - xb else "",
      stringsAsFactors = FALSE
    )
    if (!is.null(key_frame)) {
      tbl <- cbind(key_frame, tbl)
    }
    mismatch_tables[[col]] <- tbl[!eq, , drop = FALSE]
  }
  if (is.null(names(mismatch_tables))) {
    names(mismatch_tables) <- character()
  }

  total <- sum(vapply(mismatch_tables, nrow, integer(1)))
  if (!rc_unset(mismatches) && total > mismatches) {
    cli::cli_abort(
      "Detected {total} mismatch{?es}, which exceeds the {.arg mismatches} cap of {mismatches}."
    )
  }

  structure(
    list(
      meta = meta,
      colMatching = col_matching,
      rowMatching = row_matching,
      cleaninginfo = structure(cleaning, class = "cleaninginfo"),
      mismatches = structure(mismatch_tables, class = "mismatches"),
      matches = structure(match_cols, class = "matches")
    ),
    tolerance = tolerance,
    class = c("datadiff_compare", "dataCompareRobject")
  )
}

# TRUE when an optional argument was left at its NA default
rc_unset <- function(x) {
  is.null(x) || (is.atomic(x) && length(x) == 1L && is.na(x))
}

rc_key_string <- function(key_df) {
  do.call(paste, c(unname(as.list(key_df)), list(sep = "\r")))
}

rc_key_order <- function(key_df) {
  do.call(order, unname(as.list(key_df)))
}

rc_sorted_keys <- function(key_df) {
  out <- key_df[rc_key_order(key_df), , drop = FALSE]
  rownames(out) <- NULL
  out
}

rc_removed <- function(total, kept) {
  if (total > kept) seq.int(kept + 1L, total) else integer()
}
